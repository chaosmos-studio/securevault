import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import '../constants/app_constants.dart';
import 'encryption_service.dart';
import 'vault_service.dart';

class BackupException implements Exception {
  const BackupException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// One vault in one file, to keep somewhere else and bring back after a
/// reinstall or on a new phone.
///
/// The file is "SVB2", the salt of the phone that made it, then the list of
/// items encrypted with the vault's key, then each item's file exactly as it
/// is stored in the vault, already encrypted. Opening it needs the vault's PIN.
class BackupService {
  static const _magic = 'SVB2\n';

  static Future<Directory> _downloads() async {
    if (Platform.isAndroid) {
      final dir = Directory('/storage/emulated/0/Download');
      if (await dir.exists()) return dir;
    }
    return getApplicationDocumentsDirectory();
  }

  /// Writes a backup of [vault] and returns the file. [folder] is for tests.
  static Future<File> backUp({
    required Vault vault,
    required String vaultName,
    required String password,
    Directory? folder,
  }) async {
    final salt = await EncryptionService.deviceSalt();
    final key = EncryptionService.deriveKeyWithSalt(password, salt);
    final vaultsDir = Directory('${(await getApplicationDocumentsDirectory()).path}/vaults/${vault.id}');

    final files = <Map<String, Object>>[];
    for (final item in vault.items) {
      for (final name in ['${item.id}.enc', if (item.thumbnailPath != null) '${item.id}_thumb.enc']) {
        final file = File('${vaultsDir.path}/assets/$name');
        if (await file.exists()) files.add({'name': name, 'size': await file.length()});
      }
    }
    final manifest = utf8.encode(json.encode({
      'version': 2,
      'app': AppConstants.version,
      'createdAt': DateTime.now().toIso8601String(),
      'vaultName': vaultName,
      'items': vault.items.map((i) => i.toJson()).toList(),
      'files': files,
    }));
    final sealed = await EncryptionService.encryptBytes(Uint8List.fromList(manifest), key);

    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final dir = folder ?? await _downloads();
    final out = File('${dir.path}/backup-${now.year}-${two(now.month)}-${two(now.day)}-'
        '${two(now.hour)}${two(now.minute)}.svb');
    final sink = await out.open(mode: FileMode.write);
    try {
      await sink.writeFrom(utf8.encode('$_magic$salt\n'));
      await sink.writeFrom((ByteData(4)..setUint32(0, sealed.length)).buffer.asUint8List());
      await sink.writeFrom(sealed);
      for (final f in files) {
        await sink.writeFrom(await File('${vaultsDir.path}/assets/${f['name']}').readAsBytes());
      }
    } finally {
      await sink.close();
    }
    return out;
  }

  /// Adds the items in [backup] that [vault] does not have yet, and returns
  /// how many were added. [backupPassword] is the PIN the backed-up vault had.
  static Future<int> restore({
    required File backup,
    required String backupPassword,
    required Vault vault,
    required String password,
    String? key,
  }) async {
    final input = await backup.open();
    try {
      final head = await input.read(_magic.length);
      if (utf8.decode(head, allowMalformed: true) != _magic) {
        throw const BackupException('This file is not a SecureVault backup');
      }
      final saltBytes = <int>[];
      for (var b = await input.readByte(); b != 0x0A; b = await input.readByte()) {
        if (b < 0 || saltBytes.length > 64) {
          throw const BackupException('This backup is damaged');
        }
        saltBytes.add(b);
      }
      final salt = ascii.decode(saltBytes);
      final backupKey = EncryptionService.deriveKeyWithSalt(backupPassword, salt);

      final length = ByteData.sublistView(await input.read(4)).getUint32(0);
      final Map<String, dynamic> manifest;
      try {
        final plain = await EncryptionService.decryptBytes(await input.read(length), backupKey);
        manifest = json.decode(utf8.decode(plain)) as Map<String, dynamic>;
      } catch (_) {
        throw const BackupException('That PIN does not open this backup');
      }

      final offsets = <String, (int, int)>{};
      var position = await input.position();
      for (final f in (manifest['files'] as List).cast<Map<String, dynamic>>()) {
        final size = f['size'] as int;
        offsets[f['name'] as String] = (position, size);
        position += size;
      }

      Future<Uint8List?> read(String name) async {
        final at = offsets[name];
        if (at == null) return null;
        await input.setPosition(at.$1);
        return EncryptionService.decryptBytes(await input.read(at.$2), backupKey);
      }

      final have = vault.items.map((i) => i.id).toSet();
      // A note keeps its name when edited, while its item id changes.
      final notes = vault.items
          .where((i) => i.type == VaultItemType.note)
          .map((i) => i.name)
          .toSet();
      var added = 0;
      for (final json in (manifest['items'] as List).cast<Map<String, dynamic>>()) {
        final item = VaultItem.fromJson(json);
        if (have.contains(item.id)) continue;
        if (item.type == VaultItemType.note && notes.contains(item.name)) continue;
        final data = await read('${item.id}.enc');
        if (data == null) continue;
        await VaultService.addItem(
          vault: vault,
          password: password,
          key: key,
          type: item.type,
          name: item.name,
          data: data,
          thumbnail: item.thumbnailPath == null ? null : await read('${item.id}_thumb.enc'),
          itemId: item.id,
          createdAt: item.createdAt,
        );
        added++;
      }
      return added;
    } finally {
      await input.close();
    }
  }
}
