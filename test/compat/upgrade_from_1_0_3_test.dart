// A phone that used 1.0.3 must open every vault, file and setting after the
// update, and the update itself must not rewrite any of them.
// The snapshot in test/fixtures/v1_0_3/ was written by the 1.0.3 code itself
// (see test/fixtures/make_fixture_test.dart).
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:securevault/core/constants/app_constants.dart';
import 'package:securevault/core/providers/app_state.dart';
import 'package:securevault/core/services/migration_service.dart';
import 'package:securevault/core/services/vault_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fakes.dart';

final _fixture = Directory('test/fixtures/v1_0_3');

Future<List<int>> _plain(String name) =>
    File('${_fixture.path}/plain/$name').readAsBytes();

Future<Map<String, Object?>> _decodeNote(Vault vault, String password, VaultItem item) async {
  final bytes = await VaultService.getItemData(vault, password, item.id);
  return json.decode(utf8.decode(bytes!)) as Map<String, Object?>;
}

void main() {
  late Directory root;
  late Map<String, List<int>> filesBefore;
  late Map<String, String> secureBefore;

  setUp(() async {
    root = await useDeviceSnapshot(_fixture);
    filesBefore = await readTree(Directory('${root.path}/documents'));
    secureBefore = await const FlutterSecureStorage().readAll();
  });

  tearDown(() => root.delete(recursive: true));

  Future<AppState> startUpdatedApp() async {
    await MigrationService.runMigrations();
    final state = AppState();
    await state.initialize();
    return state;
  }

  test('opens on the disguise the user chose, with their settings', () async {
    final state = await startUpdatedApp();

    expect(state.isSetupComplete, isTrue);
    expect(state.currentDisguise, DisguiseType.clock);
    expect(state.themeMode, ThemeMode.dark);
    expect(state.isUnlocked, isFalse);
  });

  test('unlocks the master vault with its photo, video and note', () async {
    final state = await startUpdatedApp();

    expect(await state.unlock('482915'), isTrue);
    final vault = state.currentVault!;
    expect(state.currentVaultInfo!.name, 'Personal');
    expect(state.isMasterVault, isTrue);

    final photo = vault.items.singleWhere((i) => i.type == VaultItemType.photo);
    expect(photo.name, 'IMG_0412.png');
    expect(await VaultService.getItemData(vault, '482915', photo.id),
        await _plain('photo_beach.png'));
    expect(await VaultService.getThumbnail(vault, '482915', photo),
        await _plain('photo_beach.png'));

    final video = vault.items.singleWhere((i) => i.type == VaultItemType.video);
    expect(await VaultService.getItemData(vault, '482915', video.id,
            key: state.currentKey),
        await _plain('video_clip.bin'));

    final note = vault.items.singleWhere((i) => i.type == VaultItemType.note);
    final noteJson = await _decodeNote(vault, '482915', note);
    expect(noteJson['title'], 'Locker 14');
    expect(noteJson['content'], 'Code 2207. Chai ☕ at 5 — नमस्ते.');
    expect(noteJson['isPinned'], isTrue);
  });

  test('unlocks the decoy and the letters password vaults', () async {
    final state = await startUpdatedApp();

    expect(await state.unlock('135790'), isTrue);
    expect(state.currentVaultInfo!.name, 'Work');
    expect(state.isMasterVault, isFalse);
    final work = state.currentVault!;
    expect(work.items.single.type, VaultItemType.note);
    expect((await _decodeNote(work, '135790', work.items.single))['content'],
        'Milk, rice, dal');
    state.lock();

    expect(await state.unlock('monsoon7'), isTrue);
    expect(state.currentVaultInfo!.name, 'Old');
    final old = state.currentVault!;
    expect(await VaultService.getItemData(old, 'monsoon7', old.items.single.id),
        await _plain('photo_garden.png'));
  });

  test('keeps the vault family: the master still sees its vaults', () async {
    final state = await startUpdatedApp();
    await state.unlock('482915');

    final visible = await VaultService.getVisibleVaults(state.currentVault!.id);
    expect(visible.map((v) => v['name']).toSet(), {'Personal', 'Work', 'Old'});
  });

  test('refuses a wrong password', () async {
    final state = await startUpdatedApp();

    expect(await state.unlock('482916'), isFalse);
    expect(await state.unlock(''), isFalse);
    expect(state.isUnlocked, isFalse);
  });

  test('keeps the disguise apps\' own notes and moods', () async {
    await startUpdatedApp();
    final prefs = await SharedPreferences.getInstance();

    final notes = json.decode(prefs.getString('disguise_notes')!) as List;
    expect((notes.single as Map)['title'], 'Shopping');
    final moods = json.decode(prefs.getString('mood_log_data')!) as Map;
    expect(((moods['2026-01-03'] as List).single as Map)['mood'], 'Calm');
  });

  test('leaves every vault file and secure key byte for byte as it was', () async {
    final state = await startUpdatedApp();
    for (final password in ['482915', '135790', 'monsoon7']) {
      expect(await state.unlock(password), isTrue);
      state.lock();
    }

    final filesAfter = await readTree(Directory('${root.path}/documents'));
    expect(filesAfter.keys.toSet(), filesBefore.keys.toSet());
    for (final path in filesBefore.keys) {
      expect(filesAfter[path], filesBefore[path], reason: path);
    }
    expect(await const FlutterSecureStorage().readAll(), secureBefore);
  });
}
