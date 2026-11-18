import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:securevault/core/constants/app_constants.dart';
import 'package:securevault/core/models/vault_note.dart';
import 'package:securevault/core/providers/app_state.dart';
import 'package:securevault/core/services/vault_service.dart';
import 'package:securevault/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'capture.dart';

/// Loads the app's own fonts as well as the phone's.
Future<void> loadAppFonts() => loadPhoneFonts(extra: {
      'RedHatText': [
        'assets/fonts/RedHatText-Regular.otf',
        'assets/fonts/RedHatText-Medium.otf',
        'assets/fonts/RedHatText-SemiBold.otf',
      ],
    });

/// Starts the real app on whatever device the fakes hold.
Future<AppState> pumpApp(WidgetTester tester, {AppState? state}) async {
  final app = state ?? AppState();
  if (state == null) await tester.runAsync(app.initialize);
  await tester.pumpWidget(
      ChangeNotifierProvider.value(value: app, child: const SecureVaultApp()));
  await settle(tester);
  return app;
}

Future<void> setPrefs(Map<String, Object> values) async {
  final prefs = await SharedPreferences.getInstance();
  for (final e in values.entries) {
    final v = e.value;
    if (v is String) await prefs.setString(e.key, v);
    if (v is bool) await prefs.setBool(e.key, v);
    if (v is int) await prefs.setInt(e.key, v);
  }
}

/// A finished setup on [disguise], with the vault already opened once.
Map<String, Object> setUpOn(DisguiseType disguise) => {
      'is_setup_complete': true,
      'current_disguise': disguise.id,
      'auto_lock_seconds': 0,
    };

/// A vault named [name] with [photos] (paths) and a few notes, unlocked.
Future<String> makeVault({
  String pin = '482915',
  String name = 'My vault',
  List<File> photos = const [],
  int videos = 0,
  bool notes = true,
}) async {
  final id = await VaultService.createVault(pin, name: name, isMaster: true);
  final vault = (await VaultService.unlockVault(pin))!;
  for (final f in photos) {
    final bytes = Uint8List.fromList(await f.readAsBytes());
    await VaultService.addItem(
        vault: vault,
        password: pin,
        type: VaultItemType.photo,
        name: f.uri.pathSegments.last,
        data: bytes,
        thumbnail: bytes);
  }
  for (var i = 0; i < videos; i++) {
    await VaultService.addItem(
        vault: vault,
        password: pin,
        type: VaultItemType.video,
        name: 'VID_2026110${i + 1}.mp4',
        data: Uint8List(64));
  }
  if (notes) {
    final now = DateTime.now();
    for (final n in [
      VaultNote(id: '1', title: 'Locker 14', content: 'Code 2207, top row', updatedAt: now, isPinned: true),
      VaultNote(id: '2', title: 'Passport', content: 'Renew before March', updatedAt: now.subtract(const Duration(days: 3)), colorIndex: 7),
      VaultNote(id: '3', title: 'Gift ideas for Maa', content: 'Silver earrings, the blue shawl', updatedAt: now.subtract(const Duration(days: 9)), colorIndex: 4),
    ]) {
      await VaultService.addItem(
          vault: vault, password: pin, type: VaultItemType.note, name: n.id, data: n.encode());
    }
  }
  return id;
}

String encodeDisguiseNotes() => json.encode([
      {'id': '1', 'title': 'Shopping', 'content': 'Bread, eggs, milk, coffee beans', 'updatedAt': '2026-11-17T08:00:00.000', 'colorIndex': 0, 'isPinned': true},
      {'id': '2', 'title': 'Books to read', 'content': 'The Overstory\nPiranesi\nKlara and the Sun', 'updatedAt': '2026-11-16T19:20:00.000', 'colorIndex': 3, 'isPinned': false},
      {'id': '3', 'title': 'Gym', 'content': 'Mon legs, Wed back, Fri push', 'updatedAt': '2026-11-15T07:10:00.000', 'colorIndex': 6, 'isPinned': false},
      {'id': '4', 'title': "Wi-Fi at Mum's", 'content': 'Ask for the new password', 'updatedAt': '2026-11-12T21:00:00.000', 'colorIndex': 0, 'isPinned': false},
      {'id': '5', 'title': '', 'content': 'Call the plumber on Monday about the kitchen tap', 'updatedAt': '2026-11-10T21:00:00.000', 'colorIndex': 9, 'isPinned': false},
    ]);
