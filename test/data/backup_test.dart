import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:securevault/core/constants/app_constants.dart';
import 'package:securevault/core/models/vault_note.dart';
import 'package:securevault/core/services/backup_service.dart';
import 'package:securevault/core/services/downloads.dart';
import 'package:securevault/core/services/encryption_service.dart';
import 'package:securevault/core/services/vault_service.dart';

import '../support/fakes.dart';

final _photo = Uint8List.fromList(List.generate(9000, (i) => i * 31 % 256));
final _video = Uint8List.fromList(List.generate(3200, (i) => i % 7));
final _note = VaultNote(id: '42', title: 'Locker', content: 'Code 2207 ☕', updatedAt: DateTime(2026, 11, 1));

void main() {
  late Directory phoneA;
  late Directory phoneB;
  late Directory carried;

  setUp(() async {
    carried = await Directory.systemTemp.createTemp('securevault_carried_');
    Downloads.folder = carried;
  });

  tearDown(() async {
    setWritable(carried, true);
    for (final d in [phoneA, phoneB, carried]) {
      if (await d.exists()) await d.delete(recursive: true);
    }
  });

  Future<SavedCopy> backUpOnPhoneA() async {
    phoneA = await useFreshDevice();
    await VaultService.createVault('482915', name: 'Mine', isMaster: true);
    final vault = (await VaultService.unlockVault('482915'))!;
    await VaultService.addItem(vault: vault, password: '482915', type: VaultItemType.photo,
        name: 'IMG_1.jpg', data: _photo, thumbnail: Uint8List.fromList(_photo.sublist(0, 900)));
    await VaultService.addItem(vault: vault, password: '482915', type: VaultItemType.video,
        name: 'VID_1.mp4', data: _video);
    await VaultService.addItem(vault: vault, password: '482915', type: VaultItemType.note,
        name: _note.id, data: _note.encode());
    return BackupService.backUp(
      vault: (await VaultService.unlockVault('482915'))!,
      vaultName: 'Mine',
      password: '482915',
    );
  }

  test('brings a vault back on a new phone with a new PIN', () async {
    final backup = (await backUpOnPhoneA()).file;
    final saltA = await EncryptionService.deviceSalt();

    phoneB = await useFreshDevice();
    await VaultService.createVault('111222', name: 'Fresh', isMaster: true);
    expect(await EncryptionService.deviceSalt(), isNot(saltA));

    final added = await BackupService.restore(
      backup: backup,
      backupPassword: '482915',
      vault: (await VaultService.unlockVault('111222'))!,
      password: '111222',
    );

    expect(added, 3);
    final vault = (await VaultService.unlockVault('111222'))!;
    final photo = vault.items.singleWhere((i) => i.type == VaultItemType.photo);
    expect(photo.name, 'IMG_1.jpg');
    expect(await VaultService.getItemData(vault, '111222', photo.id), _photo);
    expect(await VaultService.getThumbnail(vault, '111222', photo), _photo.sublist(0, 900));
    final video = vault.items.singleWhere((i) => i.type == VaultItemType.video);
    expect(await VaultService.getItemData(vault, '111222', video.id), _video);
    final note = vault.items.singleWhere((i) => i.type == VaultItemType.note);
    final noteBytes = await VaultService.getItemData(vault, '111222', note.id);
    expect(VaultNote.decode(noteBytes!).content, 'Code 2207 ☕');
  });

  test('a backup made where Downloads is read-only waits in the app folder and restores',
      () async {
    setWritable(carried, false);
    final copy = await backUpOnPhoneA();
    expect(copy.inDownloads, isFalse);
    expect(carried.listSync(), isEmpty);

    phoneB = await useFreshDevice();
    await VaultService.createVault('111222', name: 'Fresh', isMaster: true);
    final added = await BackupService.restore(
      backup: copy.file,
      backupPassword: '482915',
      vault: (await VaultService.unlockVault('111222'))!,
      password: '111222',
    );

    expect(added, 3);
  });

  test('restoring the same backup twice adds nothing the second time', () async {
    final backup = (await backUpOnPhoneA()).file;
    phoneB = phoneA;

    final added = await BackupService.restore(
      backup: backup,
      backupPassword: '482915',
      vault: (await VaultService.unlockVault('482915'))!,
      password: '482915',
    );

    expect(added, 0);
    expect((await VaultService.unlockVault('482915'))!.items, hasLength(3));
  });

  test('a wrong PIN or another file is refused without touching the vault', () async {
    final backup = (await backUpOnPhoneA()).file;
    phoneB = await useFreshDevice();
    await VaultService.createVault('111222', name: 'Fresh');
    final vault = (await VaultService.unlockVault('111222'))!;

    await expectLater(
      BackupService.restore(backup: backup, backupPassword: '000000', vault: vault, password: '111222'),
      throwsA(isA<BackupException>()),
    );
    final notABackup = await File('${carried.path}/photo.jpg').writeAsBytes(_photo);
    await expectLater(
      BackupService.restore(backup: notABackup, backupPassword: '482915', vault: vault, password: '111222'),
      throwsA(isA<BackupException>()),
    );
    expect((await VaultService.unlockVault('111222'))!.items, isEmpty);
  });
}
