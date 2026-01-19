import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'encryption_service.dart';

class BackupService {
  static const _storage = FlutterSecureStorage();
  static const int _currentBackupVersion = 1;

  static Future<File?> createLocalBackup(String password) async {
    try {
      final backupData = await _gatherBackupData(password);
      if (backupData == null) return null;

      final downloadsDir = await _getBackupDirectory();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
      final backupFile = File('${downloadsDir.path}/securevault_backup_$timestamp.svb');

      final key = await EncryptionService.deriveKeyFromPassword(password);
      final encryptedBackup = await EncryptionService.encryptBytes(
        Uint8List.fromList(utf8.encode(jsonEncode(backupData))),
        key,
      );

      await backupFile.writeAsBytes(encryptedBackup);
      return backupFile;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> restoreFromBackup(File backupFile, String password) async {
    try {
      final encryptedData = await backupFile.readAsBytes();
      final key = await EncryptionService.deriveKeyFromPassword(password);
      
      final decryptedData = await EncryptionService.decryptBytes(encryptedData, key);
      final backupJson = jsonDecode(utf8.decode(decryptedData)) as Map<String, dynamic>;
      
      return await _restoreBackupData(backupJson, password);
    } catch (e) {
      return false;
    }
  }

  static Future<Directory> _getBackupDirectory() async {
    if (Platform.isAndroid) {
      final dir = Directory('/storage/emulated/0/Download');
      if (await dir.exists()) return dir;
    }
    return await getApplicationDocumentsDirectory();
  }

  static Future<Map<String, dynamic>?> _gatherBackupData(String password) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final vaultsDir = Directory('${appDir.path}/vaults');
      
      if (!await vaultsDir.exists()) return null;

      final backupData = <String, dynamic>{
        'version': _currentBackupVersion,
        'createdAt': DateTime.now().toIso8601String(),
        'vaults': <Map<String, dynamic>>[],
      };

      final vaultIndex = await _storage.read(key: 'vault_index');
      if (vaultIndex != null) {
        backupData['vaultIndex'] = vaultIndex;
      }

      await for (final entity in vaultsDir.list()) {
        if (entity is Directory) {
          final vaultId = entity.path.split('/').last.split('\\').last;
          final vaultData = await _backupVault(entity, vaultId);
          if (vaultData != null) {
            (backupData['vaults'] as List).add(vaultData);
          }
        }
      }

      final prefs = <String, String>{};
      final allKeys = ['disguise_type', 'auto_lock_seconds', 'mood_log', 'data_version'];
      for (final key in allKeys) {
        final value = await _storage.read(key: key);
        if (value != null) prefs[key] = value;
      }
      backupData['preferences'] = prefs;

      return backupData;
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> _backupVault(Directory vaultDir, String vaultId) async {
    try {
      final metaFile = File('${vaultDir.path}/meta.enc');
      if (!await metaFile.exists()) return null;

      final vaultData = <String, dynamic>{
        'id': vaultId,
        'meta': base64Encode(await metaFile.readAsBytes()),
        'assets': <Map<String, String>>[],
      };

      final assetsDir = Directory('${vaultDir.path}/assets');
      if (await assetsDir.exists()) {
        await for (final asset in assetsDir.list()) {
          if (asset is File) {
            final assetName = asset.path.split('/').last.split('\\').last;
            final assetData = base64Encode(await asset.readAsBytes());
            (vaultData['assets'] as List).add({
              'name': assetName,
              'data': assetData,
            });
          }
        }
      }

      return vaultData;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> _restoreBackupData(Map<String, dynamic> backupData, String password) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final vaultsDir = Directory('${appDir.path}/vaults');
      await vaultsDir.create(recursive: true);

      if (backupData['vaultIndex'] != null) {
        await _storage.write(key: 'vault_index', value: backupData['vaultIndex']);
      }

      final vaults = backupData['vaults'] as List;
      for (final vault in vaults) {
        await _restoreVault(vaultsDir, vault as Map<String, dynamic>);
      }

      final prefs = backupData['preferences'] as Map<String, dynamic>?;
      if (prefs != null) {
        for (final entry in prefs.entries) {
          await _storage.write(key: entry.key, value: entry.value);
        }
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<void> _restoreVault(Directory vaultsDir, Map<String, dynamic> vaultData) async {
    final vaultId = vaultData['id'] as String;
    final vaultDir = Directory('${vaultsDir.path}/$vaultId');
    await vaultDir.create(recursive: true);

    final metaData = base64Decode(vaultData['meta'] as String);
    await File('${vaultDir.path}/meta.enc').writeAsBytes(metaData);

    final assetsDir = Directory('${vaultDir.path}/assets');
    await assetsDir.create(recursive: true);

    final assets = vaultData['assets'] as List;
    for (final asset in assets) {
      final assetMap = asset as Map<String, dynamic>;
      final assetName = assetMap['name'] as String;
      final assetData = base64Decode(assetMap['data'] as String);
      await File('${assetsDir.path}/$assetName').writeAsBytes(assetData);
    }
  }

  static Future<List<File>> listBackupFiles() async {
    try {
      final backupDir = await _getBackupDirectory();
      final files = <File>[];
      
      await for (final entity in backupDir.list()) {
        if (entity is File && entity.path.endsWith('.svb')) {
          files.add(entity);
        }
      }
      
      files.sort((a, b) => b.path.compareTo(a.path));
      return files;
    } catch (e) {
      return [];
    }
  }

  static String getBackupFileName(File file) {
    return file.path.split('/').last.split('\\').last;
  }

  static Future<DateTime?> getBackupDate(File file) async {
    try {
      final stat = await file.stat();
      return stat.modified;
    } catch (e) {
      return null;
    }
  }
}
