// Writes a device snapshot made by the app's own vault code.
// The committed snapshot in test/fixtures/v1_0_3/ was made by running this
// file against the 1.0.3 release (commit 3b726a7):
//   SV_FIXTURE_OUT=<dir> SV_FIXTURE_PLAIN=test/fixtures/v1_0_3/plain \
//     flutter test test/fixtures/make_fixture_test.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:securevault/core/constants/app_constants.dart';
import 'package:securevault/core/services/migration_service.dart';
import 'package:securevault/core/services/vault_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fakes.dart';

void main() {
  final out = Platform.environment['SV_FIXTURE_OUT'];
  final plain = Platform.environment['SV_FIXTURE_PLAIN'];

  test('make a device snapshot', () async {
    final root = await useFreshDevice();
    Future<List<int>> sample(String name) =>
        File('$plain/$name').readAsBytes();

    await MigrationService.runMigrations();

    final personalId = await VaultService.createVault(
      '482915',
      name: 'Personal',
      isMaster: true,
    );
    final personal = (await VaultService.unlockVault('482915'))!;
    final beach = await sample('photo_beach.png');
    await VaultService.addItem(
      vault: personal,
      password: '482915',
      type: VaultItemType.photo,
      name: 'IMG_0412.png',
      data: Uint8List.fromList(beach),
      thumbnail: Uint8List.fromList(beach),
    );
    await VaultService.addItem(
      vault: personal,
      password: '482915',
      type: VaultItemType.video,
      name: 'VID_0007.mp4',
      data: Uint8List.fromList(await sample('video_clip.bin')),
    );
    await VaultService.addItem(
      vault: personal,
      password: '482915',
      type: VaultItemType.note,
      name: '1767225600000',
      data: utf8.encode(json.encode({
        'id': '1767225600000',
        'title': 'Locker 14',
        'content': 'Code 2207. Chai ☕ at 5 — नमस्ते.',
        'updatedAt': '2026-01-01T10:00:00.000',
        'colorIndex': 3,
        'isPinned': true,
      })),
    );

    await VaultService.createVault(
      '135790',
      name: 'Work',
      createdByVaultId: personalId,
    );
    final work = (await VaultService.unlockVault('135790'))!;
    await VaultService.addItem(
      vault: work,
      password: '135790',
      type: VaultItemType.note,
      name: '1767312000000',
      data: utf8.encode(json.encode({
        'id': '1767312000000',
        'title': 'Groceries',
        'content': 'Milk, rice, dal',
        'updatedAt': '2026-01-02T09:30:00.000',
        'colorIndex': 0,
        'isPinned': false,
      })),
    );

    await VaultService.createVault(
      'monsoon7',
      name: 'Old',
      createdByVaultId: personalId,
    );
    final old = (await VaultService.unlockVault('monsoon7'))!;
    final garden = await sample('photo_garden.png');
    await VaultService.addItem(
      vault: old,
      password: 'monsoon7',
      type: VaultItemType.photo,
      name: 'garden.png',
      data: Uint8List.fromList(garden),
      thumbnail: Uint8List.fromList(garden),
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_disguise', DisguiseType.clock.id);
    await prefs.setBool('first_time_instructions', false);
    await prefs.setBool('is_setup_complete', true);
    await prefs.setInt('theme_mode', 2);
    await prefs.setString(
      'disguise_notes',
      json.encode([
        {
          'id': '1767398400000',
          'title': 'Shopping',
          'content': 'Bread, eggs',
          'updatedAt': '2026-01-03T08:00:00.000',
          'colorIndex': 2,
          'isPinned': false,
        },
      ]),
    );
    await prefs.setString(
      'mood_log_data',
      json.encode({
        '2026-01-03': [
          {
            'mood': 'Calm',
            'emoji': '😌',
            'timestamp': '2026-01-03T21:15:00.000',
          },
        ],
      }),
    );

    await snapshotDevice(root, Directory(out!));
  }, skip: out == null || plain == null ? 'Set SV_FIXTURE_OUT and SV_FIXTURE_PLAIN' : false);
}
