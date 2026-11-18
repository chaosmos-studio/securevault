// Renders every screen at a real phone's size into SV_CAPTURE_OUT, for review
// and for store pictures. Skipped unless SV_CAPTURE_OUT is set.
//   SV_CAPTURE_OUT=/tmp/shots SV_PHOTOS=<folder of jpgs> \
//     flutter test test/capture/capture_screens_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:securevault/core/constants/app_constants.dart';
import 'package:securevault/core/providers/app_state.dart';
import 'package:securevault/core/services/vault_service.dart';

import '../support/app_harness.dart';
import '../support/capture.dart';
import '../support/fakes.dart';

final _out = Platform.environment['SV_CAPTURE_OUT'];
final _photos = Platform.environment['SV_PHOTOS'];
final _skip = _out == null;

List<File> _photoFiles() {
  if (_photos == null) return const [];
  return Directory(_photos!).listSync().whereType<File>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));
}

Future<void> _tapText(WidgetTester tester, String text, {int ms = 300}) async {
  await tester.tap(find.text(text).last);
  await settle(tester, ms: ms);
}

void main() {
  setUpAll(loadAppFonts);

  Future<void> shot(WidgetTester tester, String name) => capture(tester, _out!, name);

  testWidgets('setup', (tester) async {
    usePhoneScreen(tester);
    await tester.runAsync(useFreshDevice);
    await pumpApp(tester);
    await shot(tester, '01-setup-intro');
    await _tapText(tester, 'Get started');
    await shot(tester, '02-setup-disguise');
    await _tapText(tester, 'Use Calculator');
    for (final d in '482915'.split('')) {
      await tester.tap(find.text(d).last);
      await tester.pump();
    }
    await settle(tester);
    await shot(tester, '03-setup-pin');
    await _tapText(tester, 'Next');
    for (final d in '482916'.split('')) {
      await tester.tap(find.text(d).last);
      await tester.pump();
    }
    await settle(tester, ms: 500);
    await shot(tester, '04-setup-confirm-mismatch');
    for (final d in '482915'.split('')) {
      await tester.tap(find.text(d).last);
      await tester.pump();
    }
    await settle(tester, ms: 1500);
    await shot(tester, '05-setup-practice-calculator');
    for (final k in '482915'.split('')) {
      await tester.tap(find.text(k).last);
      await tester.pump();
    }
    await tester.tap(find.text('=').last);
    await settle(tester, ms: 1500);
    await shot(tester, '06-vault-welcome');
  }, skip: _skip);

  for (final disguise in DisguiseType.values) {
    testWidgets('practice on ${disguise.id}', (tester) async {
      usePhoneScreen(tester);
      await tester.runAsync(useFreshDevice);
      final state = AppState();
      await tester.runAsync(() async {
        await makeVault(notes: false);
        await state.initialize();
        await state.finishSetup(disguise, '482915');
      });
      await pumpApp(tester, state: state);
      await shot(tester, '07-practice-${disguise.id}');
    }, skip: _skip);
  }

  testWidgets('calculator', (tester) async {
    usePhoneScreen(tester);
    await tester.runAsync(() async {
      await useFreshDevice();
      await setPrefs(setUpOn(DisguiseType.calculator));
    });
    await pumpApp(tester);
    for (final k in ['1', '2', '8', '×', '4', '+', '3', '6']) {
      await tester.tap(find.text(k).last);
      await tester.pump();
    }
    await settle(tester);
    await shot(tester, '10-calculator');
    await tester.tap(find.byIcon(Icons.more_vert));
    await settle(tester);
    await shot(tester, '11-disguise-menu');
    await _tapText(tester, 'About');
    await shot(tester, '12-disguise-about');
    await _tapText(tester, 'Close');
    await tester.tap(find.byIcon(Icons.more_vert));
    await settle(tester);
    await _tapText(tester, 'Request a feature');
    await shot(tester, '13-disguise-request-feature');
  }, skip: _skip);

  testWidgets('calculator dark', (tester) async {
    usePhoneScreen(tester);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.runAsync(() async {
      await useFreshDevice();
      await setPrefs(setUpOn(DisguiseType.calculator));
    });
    await pumpApp(tester);
    for (final k in ['7', '2', '÷', '8']) {
      await tester.tap(find.text(k).last);
      await tester.pump();
    }
    await settle(tester);
    await shot(tester, '14-calculator-dark');
  }, skip: _skip);

  testWidgets('notes', (tester) async {
    usePhoneScreen(tester);
    await tester.runAsync(() async {
      await useFreshDevice();
      await setPrefs({...setUpOn(DisguiseType.notes), 'disguise_notes': encodeDisguiseNotes()});
    });
    await pumpApp(tester);
    await shot(tester, '20-notes');
    await _tapText(tester, 'Books to read');
    await shot(tester, '21-notes-editor');
  }, skip: _skip);

  testWidgets('notes empty', (tester) async {
    usePhoneScreen(tester);
    await tester.runAsync(() async {
      await useFreshDevice();
      await setPrefs(setUpOn(DisguiseType.notes));
    });
    await pumpApp(tester);
    await shot(tester, '22-notes-empty');
  }, skip: _skip);

  testWidgets('clock', (tester) async {
    usePhoneScreen(tester);
    await tester.runAsync(() async {
      await useFreshDevice();
      await setPrefs({
        ...setUpOn(DisguiseType.clock),
        'clock_alarms': json.encode([
          {'hour': 6, 'minute': 30, 'enabled': true, 'label': 'Gym'},
          {'hour': 7, 'minute': 45, 'enabled': true, 'label': ''},
          {'hour': 9, 'minute': 0, 'enabled': false, 'label': 'Weekend'},
        ]),
      });
    });
    await pumpApp(tester);
    await shot(tester, '30-clock');
    await tester.tap(find.byIcon(Icons.alarm).last);
    await settle(tester);
    await shot(tester, '31-clock-alarm');
    await tester.tap(find.byIcon(Icons.hourglass_empty));
    await settle(tester);
    for (final k in ['5', '0', '0']) {
      await tester.tap(find.text(k).last);
      await tester.pump();
    }
    await settle(tester);
    await shot(tester, '32-clock-timer');
    await tester.tap(find.byIcon(Icons.timer_outlined));
    await settle(tester);
    await shot(tester, '33-clock-stopwatch');
  }, skip: _skip);

  testWidgets('moodspace', (tester) async {
    usePhoneScreen(tester);
    final now = DateTime.now();
    String day(int back) {
      final d = now.subtract(Duration(days: back));
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    }

    Map<String, Object> entry(String mood, int back, [String note = '']) => {
          'mood': mood,
          'emoji': '',
          'timestamp': now.subtract(Duration(days: back, hours: 2)).toIso8601String(),
          if (note.isNotEmpty) 'note': note,
        };
    await tester.runAsync(() async {
      await useFreshDevice();
      await setPrefs({
        ...setUpOn(DisguiseType.moodspace),
        'mood_log_data': json.encode({
          day(1): [entry('Good', 1, 'Long walk after work')],
          day(2): [entry('Great', 2, 'Finished the book')],
          day(3): [entry('Okay', 3)],
          day(5): [entry('Low', 5, 'Bad sleep')],
          day(8): [entry('Good', 8)],
          day(12): [entry('Great', 12)],
        }),
      });
    });
    await pumpApp(tester);
    await tester.tap(find.text('Good').first);
    await settle(tester);
    await shot(tester, '40-moodspace');
    await tester.tap(find.byIcon(Icons.history));
    await settle(tester);
    await shot(tester, '41-moodspace-history');
    await tester.tap(find.byIcon(Icons.calendar_month_outlined));
    await settle(tester);
    await shot(tester, '42-moodspace-calendar');
  }, skip: _skip);

  Future<AppState> openVault(WidgetTester tester, {bool empty = false}) async {
    final state = AppState();
    await tester.runAsync(() async {
      await useFreshDevice();
      await setPrefs(setUpOn(DisguiseType.calculator));
      if (empty) {
        await makeVault(notes: false);
      } else {
        final id = await makeVault(photos: _photoFiles(), videos: 2);
        await VaultService.createVault('135790', name: 'Work', createdByVaultId: id);
        await VaultService.createVault('246802', name: 'Travel', createdByVaultId: id);
      }
      await state.initialize();
      await state.unlock('482915');
    });
    await pumpApp(tester, state: state);
    await settle(tester, ms: 2500);
    return state;
  }

  testWidgets('vault', (tester) async {
    usePhoneScreen(tester);
    await openVault(tester);
    await shot(tester, '50-vault-photos');
    await tester.longPress(find.byType(Image).at(1));
    await settle(tester);
    await tester.tap(find.byType(Image).at(3));
    await settle(tester);
    await shot(tester, '51-vault-selecting');
    await tester.tap(find.byTooltip('Cancel'));
    await settle(tester);
    await tester.tap(find.textContaining('Videos'));
    await settle(tester);
    await shot(tester, '52-vault-videos');
    await tester.tap(find.textContaining('Notes'));
    await settle(tester, ms: 1500);
    await shot(tester, '53-vault-notes');
    await _tapText(tester, 'Passport');
    await shot(tester, '54-vault-note-editor');
    await tester.tap(find.byTooltip('Back'));
    await settle(tester, ms: 800);
    await tester.tap(find.textContaining('Photos'));
    await settle(tester, ms: 800);
    await tester.tap(find.byType(Image).first);
    await settle(tester, ms: 2000);
    await shot(tester, '55-vault-photo-viewer');
    await tester.tap(find.byType(BackButton));
    await settle(tester, ms: 800);
    await tester.tap(find.byTooltip('Settings'));
    await settle(tester);
    await shot(tester, '56-vault-settings');
    await tester.tap(find.text('Disguise'));
    await settle(tester);
    await shot(tester, '57-vault-disguise-sheet');
    await tester.tapAt(const Offset(200, 60));
    await settle(tester);
    await _tapText(tester, 'Vaults', ms: 800);
    await shot(tester, '58-vault-vaults');
    await tester.tap(find.byTooltip('Back'));
    await settle(tester);
    await _tapText(tester, 'Change PIN');
    await shot(tester, '59-vault-change-pin');
    await tester.tap(find.byTooltip('Back'));
    await settle(tester);
    await _tapText(tester, 'Back up and restore');
    await shot(tester, '60-vault-backup');
  }, skip: _skip);

  testWidgets('vault dark', (tester) async {
    usePhoneScreen(tester);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await openVault(tester);
    await shot(tester, '61-vault-photos-dark');
  }, skip: _skip);

  testWidgets('vault empty', (tester) async {
    usePhoneScreen(tester);
    await openVault(tester, empty: true);
    await shot(tester, '62-vault-empty');
  }, skip: _skip);
}
