import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:securevault/core/constants/app_constants.dart';
import 'package:securevault/core/services/encryption_service.dart';
import 'package:securevault/core/services/vault_service.dart';

import '../support/fakes.dart';

final _photo = Uint8List.fromList(List.generate(5000, (i) => i * 7 % 251));
final _video = Uint8List.fromList(List.generate(4096, (i) => i % 13));

Future<Vault> _vault(String pin) async {
  await VaultService.createVault(pin, name: 'Mine', isMaster: true);
  final vault = (await VaultService.unlockVault(pin))!;
  await VaultService.addItem(
      vault: vault, password: pin, type: VaultItemType.photo, name: 'a.jpg', data: _photo, thumbnail: _photo);
  await VaultService.addItem(
      vault: vault, password: pin, type: VaultItemType.video, name: 'b.mp4', data: _video);
  return (await VaultService.unlockVault(pin))!;
}

Future<void> _expectContents(String pin) async {
  final vault = await VaultService.unlockVault(pin);
  expect(vault, isNotNull, reason: 'the vault opens with $pin');
  final photo = vault!.items.singleWhere((i) => i.type == VaultItemType.photo);
  final video = vault.items.singleWhere((i) => i.type == VaultItemType.video);
  expect(await VaultService.getItemData(vault, pin, photo.id), _photo);
  expect(await VaultService.getThumbnail(vault, pin, photo), _photo);
  expect(await VaultService.getItemData(vault, pin, video.id), _video);
}

/// Stages the new files a password change writes before it switches the index.
Future<Directory> _stage(Vault vault, String oldPin, String newPin) async {
  final dir = Directory('${_root.path}/documents/vaults/${vault.id}');
  final oldKey = await EncryptionService.deriveKeyFromPassword(oldPin);
  final newKey = await EncryptionService.deriveKeyFromPassword(newPin);
  await for (final f in Directory('${dir.path}/assets').list()) {
    if (f is File && f.path.endsWith('.enc')) {
      final plain = await EncryptionService.decryptBytes(await f.readAsBytes(), oldKey);
      await File('${f.path}.new').writeAsBytes(await EncryptionService.encryptBytes(plain, newKey));
    }
  }
  final hash = await EncryptionService.hashPassword(newPin);
  final rekeyed = Vault(id: vault.id, passwordHash: hash, items: vault.items);
  await File('${dir.path}/metadata.enc.new')
      .writeAsString(await EncryptionService.encryptData(json.encode(rekeyed.toJson()), newKey));
  return dir;
}

late Directory _root;

Future<void> _switchIndex(String oldPin, String newPin) async {
  const storage = FlutterSecureStorage();
  final index = json.decode((await storage.read(key: 'vault_index'))!) as Map<String, dynamic>;
  final oldHash = await EncryptionService.hashPassword(oldPin);
  final newHash = await EncryptionService.hashPassword(newPin);
  index[newHash] = index.remove(oldHash);
  await storage.write(key: 'vault_index', value: json.encode(index));
}

void main() {
  setUp(() async => _root = await useFreshDevice());
  tearDown(() => _root.delete(recursive: true));

  test('a new PIN opens every file and the old one stops working', () async {
    final vault = await _vault('482915');

    expect(await VaultService.changePassword(vault, '482915', '777000'), isTrue);

    expect(await VaultService.unlockVault('482915'), isNull);
    await _expectContents('777000');
    final leftovers = await Directory('${_root.path}/documents')
        .list(recursive: true)
        .where((f) => f.path.endsWith('.new'))
        .toList();
    expect(leftovers, isEmpty);
  });

  test('refuses a PIN another vault uses, and changes nothing', () async {
    final vault = await _vault('482915');
    await VaultService.createVault('135790', name: 'Other');

    expect(await VaultService.changePassword(vault, '482915', '135790'), isFalse);

    await _expectContents('482915');
  });

  test('finishes a change that stopped after the switch to the new PIN', () async {
    final vault = await _vault('482915');
    await _stage(vault, '482915', '777000');
    await _switchIndex('482915', '777000');

    await _expectContents('777000');
  });

  test('rolls back a change that stopped before the switch', () async {
    final vault = await _vault('482915');
    await _stage(vault, '482915', '777000');

    await _expectContents('482915');
    expect(await VaultService.unlockVault('777000'), isNull);
  });
}
