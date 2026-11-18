import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';
import 'encryption_service.dart';

class VaultItem {
  final String id;
  final VaultItemType type;
  final String name;
  final DateTime createdAt;
  final String? thumbnailPath;

  VaultItem({
    required this.id,
    required this.type,
    required this.name,
    required this.createdAt,
    this.thumbnailPath,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.index,
    'name': name,
    'createdAt': createdAt.toIso8601String(),
    'thumbnailPath': thumbnailPath,
  };

  factory VaultItem.fromJson(Map<String, dynamic> json) => VaultItem(
    id: json['id'],
    type: VaultItemType.values[json['type']],
    name: json['name'],
    createdAt: DateTime.parse(json['createdAt']),
    thumbnailPath: json['thumbnailPath'],
  );
}

class Vault {
  final String id;
  final String passwordHash;
  List<VaultItem> items;

  Vault({
    required this.id,
    required this.passwordHash,
    List<VaultItem>? items,
  }) : items = items ?? [];

  Map<String, dynamic> toJson() => {
    'id': id,
    'passwordHash': passwordHash,
    'items': items.map((i) => i.toJson()).toList(),
  };

  factory Vault.fromJson(Map<String, dynamic> json) => Vault(
    id: json['id'],
    passwordHash: json['passwordHash'],
    items: (json['items'] as List).map((i) => VaultItem.fromJson(i)).toList(),
  );
}

class VaultInfo {
  final String id;
  final String name;
  final bool isMaster;
  final String? createdByVaultId;
  final List<String> canSeeVaultIds;
  
  VaultInfo({
    required this.id,
    required this.name,
    this.isMaster = false,
    this.createdByVaultId,
    List<String>? canSeeVaultIds,
  }) : canSeeVaultIds = canSeeVaultIds ?? [];
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'isMaster': isMaster,
    'createdByVaultId': createdByVaultId,
    'canSeeVaultIds': canSeeVaultIds,
  };
  
  factory VaultInfo.fromJson(Map<String, dynamic> json) => VaultInfo(
    id: json['id'],
    name: json['name'] ?? 'Vault',
    isMaster: json['isMaster'] ?? false,
    createdByVaultId: json['createdByVaultId'],
    canSeeVaultIds: (json['canSeeVaultIds'] as List?)?.cast<String>() ?? [],
  );
  
  VaultInfo copyWith({
    String? id,
    String? name,
    bool? isMaster,
    String? createdByVaultId,
    List<String>? canSeeVaultIds,
  }) => VaultInfo(
    id: id ?? this.id,
    name: name ?? this.name,
    isMaster: isMaster ?? this.isMaster,
    createdByVaultId: createdByVaultId ?? this.createdByVaultId,
    canSeeVaultIds: canSeeVaultIds ?? this.canSeeVaultIds,
  );
}

class VaultService {
  static const _storage = FlutterSecureStorage();
  static const _vaultIndexKey = 'vault_index';
  static const _uuid = Uuid();

  static Future<Directory> _getVaultsDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final vaultsDir = Directory('${appDir.path}/vaults');
    if (!await vaultsDir.exists()) {
      await vaultsDir.create(recursive: true);
    }
    return vaultsDir;
  }

  static Future<Map<String, VaultInfo>> _getVaultIndex() async {
    final indexData = await _storage.read(key: _vaultIndexKey);
    if (indexData == null) return {};
    
    final decoded = json.decode(indexData) as Map<String, dynamic>;
    final result = <String, VaultInfo>{};
    
    for (final entry in decoded.entries) {
      if (entry.value is String) {
        result[entry.key] = VaultInfo(id: entry.value, name: 'Vault');
      } else {
        result[entry.key] = VaultInfo.fromJson(entry.value);
      }
    }
    return result;
  }

  static Future<void> _saveVaultIndex(Map<String, VaultInfo> index) async {
    final toSave = index.map((key, value) => MapEntry(key, value.toJson()));
    await _storage.write(key: _vaultIndexKey, value: json.encode(toSave));
  }

  static Future<bool> hasAnyVault() async {
    final index = await _getVaultIndex();
    return index.isNotEmpty;
  }

  static Future<bool> isPasswordTaken(String password) async {
    final passwordHash = await EncryptionService.hashPassword(password);
    final index = await _getVaultIndex();
    return index.containsKey(passwordHash);
  }

  static Future<String> createVault(
    String password, {
    String name = 'Vault',
    bool isMaster = false,
    String? createdByVaultId,
  }) async {
    final passwordHash = await EncryptionService.hashPassword(password);
    
    final index = await _getVaultIndex();
    if (index.containsKey(passwordHash)) {
      throw Exception('A vault with this password already exists');
    }
    
    final vaultId = _uuid.v4();
    index[passwordHash] = VaultInfo(
      id: vaultId,
      name: name,
      isMaster: isMaster,
      createdByVaultId: createdByVaultId,
    );
    await _saveVaultIndex(index);
    
    final vault = Vault(id: vaultId, passwordHash: passwordHash);
    await _saveVault(vault, password);
    
    final vaultsDir = await _getVaultsDirectory();
    final vaultAssetsDir = Directory('${vaultsDir.path}/$vaultId/assets');
    await vaultAssetsDir.create(recursive: true);
    
    return vaultId;
  }

  static Future<Vault?> unlockVault(String password) async {
    final passwordHash = await EncryptionService.hashPassword(password);
    final index = await _getVaultIndex();
    
    final vaultInfo = index[passwordHash];
    if (vaultInfo == null) return null;

    await _settleStaged(vaultInfo.id, password);
    return await _loadVault(vaultInfo.id, password);
  }

  static Future<void> _saveVault(Vault vault, String password) async {
    final vaultsDir = await _getVaultsDirectory();
    final vaultFile = File('${vaultsDir.path}/${vault.id}/metadata.enc');
    
    await vaultFile.parent.create(recursive: true);
    
    final key = await EncryptionService.deriveKeyFromPassword(password);
    final encrypted = await EncryptionService.encryptData(
      json.encode(vault.toJson()),
      key,
    );
    
    await vaultFile.writeAsString(encrypted);
  }

  static Future<Vault?> _loadVault(String vaultId, String password) async {
    final vaultsDir = await _getVaultsDirectory();
    final vaultFile = File('${vaultsDir.path}/$vaultId/metadata.enc');
    
    if (!await vaultFile.exists()) return null;
    
    try {
      final encrypted = await vaultFile.readAsString();
      final key = await EncryptionService.deriveKeyFromPassword(password);
      final decrypted = await EncryptionService.decryptData(encrypted, key);
      return Vault.fromJson(json.decode(decrypted));
    } catch (e) {
      return null;
    }
  }

  static Future<String> addItem({
    required Vault vault,
    required String password,
    required VaultItemType type,
    required String name,
    required Uint8List data,
    Uint8List? thumbnail,
    String? key,
    String? itemId,
    DateTime? createdAt,
  }) async {
    itemId ??= _uuid.v4();
    final vaultsDir = await _getVaultsDirectory();
    final encryptionKey = key ?? await EncryptionService.deriveKeyFromPassword(password);
    
    final assetPath = '${vaultsDir.path}/${vault.id}/assets/$itemId.enc';
    final encryptedData = await EncryptionService.encryptBytes(data, encryptionKey);
    await File(assetPath).writeAsBytes(encryptedData);
    
    String? thumbnailPath;
    if (thumbnail != null) {
      thumbnailPath = '${vaultsDir.path}/${vault.id}/assets/${itemId}_thumb.enc';
      final encryptedThumb = await EncryptionService.encryptBytes(thumbnail, encryptionKey);
      await File(thumbnailPath).writeAsBytes(encryptedThumb);
    }
    
    final item = VaultItem(
      id: itemId,
      type: type,
      name: name,
      createdAt: createdAt ?? DateTime.now(),
      thumbnailPath: thumbnailPath,
    );
    
    vault.items.add(item);
    await _saveVault(vault, password);
    
    return itemId;
  }

  static Future<Uint8List?> getItemData(Vault vault, String password, String itemId, {String? key}) async {
    final vaultsDir = await _getVaultsDirectory();
    final assetPath = '${vaultsDir.path}/${vault.id}/assets/$itemId.enc';
    final file = File(assetPath);
    
    if (!await file.exists()) return null;
    
    try {
      final encryptionKey = key ?? await EncryptionService.deriveKeyFromPassword(password);
      final encryptedData = await file.readAsBytes();
      return await EncryptionService.decryptBytes(encryptedData, encryptionKey);
    } catch (e) {
      return null;
    }
  }

  static Future<Uint8List?> getThumbnail(Vault vault, String password, VaultItem item, {String? key}) async {
    if (item.thumbnailPath == null) return null;
    
    final file = File(item.thumbnailPath!);
    if (!await file.exists()) return null;
    
    try {
      final encryptionKey = key ?? await EncryptionService.deriveKeyFromPassword(password);
      final encryptedData = await file.readAsBytes();
      return await EncryptionService.decryptBytes(encryptedData, encryptionKey);
    } catch (e) {
      return null;
    }
  }

  static Future<void> deleteItem(Vault vault, String password, String itemId) async {
    final vaultsDir = await _getVaultsDirectory();
    
    final assetFile = File('${vaultsDir.path}/${vault.id}/assets/$itemId.enc');
    if (await assetFile.exists()) await assetFile.delete();
    
    final thumbFile = File('${vaultsDir.path}/${vault.id}/assets/${itemId}_thumb.enc');
    if (await thumbFile.exists()) await thumbFile.delete();
    
    vault.items.removeWhere((item) => item.id == itemId);
    await _saveVault(vault, password);
  }

  static const _pendingSuffix = '.new';

  /// Re-encrypts a vault under a new password, in a way a crash cannot break:
  /// every file is first written beside the old one, then the password index
  /// switches over, and only then do the new files replace the old ones.
  /// A switch interrupted half way is finished on the next unlock.
  static Future<bool> changePassword(Vault vault, String oldPassword, String newPassword) async {
    final vaultsDir = await _getVaultsDirectory();
    final vaultDir = Directory('${vaultsDir.path}/${vault.id}');
    final staged = <File>[];
    try {
      final oldHash = await EncryptionService.hashPassword(oldPassword);
      final newHash = await EncryptionService.hashPassword(newPassword);
      final index = await _getVaultIndex();
      final vaultInfo = index[oldHash];
      if (vaultInfo == null || vaultInfo.id != vault.id || index.containsKey(newHash)) {
        return false;
      }

      final oldKey = await EncryptionService.deriveKeyFromPassword(oldPassword);
      final newKey = await EncryptionService.deriveKeyFromPassword(newPassword);

      final assetsDir = Directory('${vaultDir.path}/assets');
      if (await assetsDir.exists()) {
        await for (final file in assetsDir.list()) {
          if (file is File && file.path.endsWith('.enc')) {
            final plain = await EncryptionService.decryptBytes(await file.readAsBytes(), oldKey);
            final next = File('${file.path}$_pendingSuffix');
            await next.writeAsBytes(await EncryptionService.encryptBytes(plain, newKey), flush: true);
            staged.add(next);
          }
        }
      }
      final rekeyed = Vault(id: vault.id, passwordHash: newHash, items: vault.items);
      final metadata = File('${vaultDir.path}/metadata.enc$_pendingSuffix');
      await metadata.writeAsString(
          await EncryptionService.encryptData(json.encode(rekeyed.toJson()), newKey),
          flush: true);
      staged.add(metadata);

      index.remove(oldHash);
      index[newHash] = vaultInfo;
      await _saveVaultIndex(index);
    } catch (e) {
      for (final file in staged) {
        if (await file.exists()) await file.delete();
      }
      return false;
    }

    await _commitStaged(vaultDir);
    return true;
  }

  /// Moves staged files into place, the metadata last: while its staged copy
  /// exists, the change is not finished.
  static Future<void> _commitStaged(Directory vaultDir) async {
    final metadata = File('${vaultDir.path}/metadata.enc$_pendingSuffix');
    final staged = await vaultDir
        .list(recursive: true)
        .where((f) => f is File && f.path.endsWith(_pendingSuffix) && f.path != metadata.path)
        .cast<File>()
        .toList();
    for (final file in [...staged, if (await metadata.exists()) metadata]) {
      await file.rename(file.path.substring(0, file.path.length - _pendingSuffix.length));
    }
  }

  /// Finishes or rolls back a password change that a crash interrupted:
  /// staged files that open with [password] are the new ones.
  static Future<void> _settleStaged(String vaultId, String password) async {
    final vaultsDir = await _getVaultsDirectory();
    final vaultDir = Directory('${vaultsDir.path}/$vaultId');
    final metadata = File('${vaultDir.path}/metadata.enc$_pendingSuffix');
    if (!await vaultDir.exists()) return;
    final hasStaged = await vaultDir
        .list(recursive: true)
        .any((f) => f is File && f.path.endsWith(_pendingSuffix));
    if (!hasStaged) return;

    // Without staged metadata, either the files were never complete or the
    // index never switched, so the staged files are dropped.
    var opensWithPassword = false;
    if (await metadata.exists()) {
      try {
        final key = await EncryptionService.deriveKeyFromPassword(password);
        await EncryptionService.decryptData(await metadata.readAsString(), key);
        opensWithPassword = true;
      } catch (_) {
        opensWithPassword = false;
      }
    }
    if (opensWithPassword) {
      await _commitStaged(vaultDir);
    } else {
      await for (final file in vaultDir.list(recursive: true)) {
        if (file is File && file.path.endsWith(_pendingSuffix)) await file.delete();
      }
    }
  }

  static Future<List<Map<String, dynamic>>> getAllVaults() async {
    final index = await _getVaultIndex();
    return index.entries.map((e) => {
      'name': e.value.name,
      'id': e.value.id,
      'isMaster': e.value.isMaster,
      'canSeeVaultIds': e.value.canSeeVaultIds,
    }).toList();
  }

  static Set<String> _getAncestorIds(String vaultId, Map<String, VaultInfo> index) {
    final ancestors = <String>{};
    String? currentId = vaultId;
    
    while (currentId != null) {
      VaultInfo? vaultInfo;
      for (final entry in index.entries) {
        if (entry.value.id == currentId) {
          vaultInfo = entry.value;
          break;
        }
      }
      
      if (vaultInfo?.createdByVaultId != null) {
        ancestors.add(vaultInfo!.createdByVaultId!);
        currentId = vaultInfo.createdByVaultId;
      } else {
        break;
      }
    }
    
    return ancestors;
  }

  static Set<String> _getDescendantIds(String vaultId, Map<String, VaultInfo> index) {
    final descendants = <String>{};
    final toProcess = <String>[vaultId];
    
    while (toProcess.isNotEmpty) {
      final currentId = toProcess.removeLast();
      
      for (final entry in index.entries) {
        if (entry.value.createdByVaultId == currentId && 
            !descendants.contains(entry.value.id)) {
          descendants.add(entry.value.id);
          toProcess.add(entry.value.id);
        }
      }
    }
    
    return descendants;
  }

  static Future<List<Map<String, dynamic>>> getVisibleVaults(String currentVaultId) async {
    final index = await _getVaultIndex();
    VaultInfo? currentVaultInfo;
    
    for (final entry in index.entries) {
      if (entry.value.id == currentVaultId) {
        currentVaultInfo = entry.value;
        break;
      }
    }
    
    if (currentVaultInfo == null) return [];
    
    final ancestors = _getAncestorIds(currentVaultId, index);
    final descendants = _getDescendantIds(currentVaultId, index);
    
    final visibleVaults = <Map<String, dynamic>>[];
    
    for (final entry in index.entries) {
      final vaultInfo = entry.value;
      
      if (vaultInfo.id == currentVaultId) {
        visibleVaults.add({
          'name': vaultInfo.name,
          'id': vaultInfo.id,
          'isMaster': vaultInfo.isMaster,
          'isCurrent': true,
        });
        continue;
      }
      
      if (ancestors.contains(vaultInfo.id)) {
        continue;
      }
      
      if (currentVaultInfo.isMaster) {
        visibleVaults.add({
          'name': vaultInfo.name,
          'id': vaultInfo.id,
          'isMaster': vaultInfo.isMaster,
          'isCurrent': false,
          'isDescendant': descendants.contains(vaultInfo.id),
        });
      } else {
        if (!vaultInfo.isMaster && !ancestors.contains(vaultInfo.id)) {
          visibleVaults.add({
            'name': vaultInfo.name,
            'id': vaultInfo.id,
            'isMaster': vaultInfo.isMaster,
            'isCurrent': false,
            'isDescendant': descendants.contains(vaultInfo.id),
          });
        }
      }
    }
    
    return visibleVaults;
  }

  static Future<VaultInfo?> getVaultInfo(String vaultId) async {
    final index = await _getVaultIndex();
    for (final entry in index.entries) {
      if (entry.value.id == vaultId) {
        return entry.value;
      }
    }
    return null;
  }

  static Future<bool> updateVaultPermissions(
    String vaultId, {
    bool? isMaster,
    List<String>? canSeeVaultIds,
  }) async {
    final index = await _getVaultIndex();
    
    for (final entry in index.entries) {
      if (entry.value.id == vaultId) {
        index[entry.key] = entry.value.copyWith(
          isMaster: isMaster,
          canSeeVaultIds: canSeeVaultIds,
        );
        await _saveVaultIndex(index);
        return true;
      }
    }
    return false;
  }

  static Future<bool> renameVault(String vaultId, String name) async {
    final index = await _getVaultIndex();
    for (final entry in index.entries) {
      if (entry.value.id == vaultId) {
        index[entry.key] = VaultInfo(
          id: entry.value.id,
          name: name,
          isMaster: entry.value.isMaster,
          createdByVaultId: entry.value.createdByVaultId,
          canSeeVaultIds: entry.value.canSeeVaultIds,
        );
        await _saveVaultIndex(index);
        return true;
      }
    }
    return false;
  }

  static Future<String?> getVaultName(String vaultId) async {
    final index = await _getVaultIndex();
    for (final entry in index.entries) {
      if (entry.value.id == vaultId) {
        return entry.value.name;
      }
    }
    return null;
  }
}
