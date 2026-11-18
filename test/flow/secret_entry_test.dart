import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:securevault/core/constants/app_constants.dart';
import 'package:securevault/core/providers/app_state.dart';
import 'package:securevault/core/services/vault_service.dart';

import '../support/app_harness.dart';
import '../support/capture.dart';
import '../support/fakes.dart';

/// A phone set up on [disguise] with a vault for each of [pins].
Future<AppState> phoneOn(WidgetTester tester, DisguiseType disguise,
    {List<String> pins = const ['482915']}) async {
  usePhoneScreen(tester);
  await tester.runAsync(() async {
    await useFreshDevice();
    await setPrefs(setUpOn(disguise));
    for (final pin in pins) {
      await VaultService.createVault(pin, name: 'Vault $pin');
    }
  });
  return pumpApp(tester);
}

Future<void> tapKeys(WidgetTester tester, String keys) async {
  for (final k in keys.split('')) {
    await tester.tap(find.text(k).last);
    await tester.pump();
  }
}

void main() {
  testWidgets('Calculator: a PIN and = opens the vault, other sums just calculate',
      (tester) async {
    final state = await phoneOn(tester, DisguiseType.calculator);

    await tapKeys(tester, '12+3');
    await tester.tap(find.text('=').last);
    await settle(tester);
    expect(state.isUnlocked, isFalse);
    expect(find.text('15'), findsOneWidget);

    await tester.tap(find.text('AC'));
    await tapKeys(tester, '482915');
    await tester.tap(find.text('=').last);
    await settle(tester, ms: 800);
    expect(state.isUnlocked, isTrue);
    expect(state.currentVaultInfo!.name, 'Vault 482915');
  });

  testWidgets('Calculator: a four-digit password from older versions still opens',
      (tester) async {
    final state = await phoneOn(tester, DisguiseType.calculator, pins: ['1234']);

    await tapKeys(tester, '1234');
    await tester.tap(find.text('=').last);
    await settle(tester, ms: 800);
    expect(state.isUnlocked, isTrue);
  });

  testWidgets('Notes: searching for the PIN opens the vault', (tester) async {
    final state = await phoneOn(tester, DisguiseType.notes);

    await tester.enterText(find.byType(TextField), '48291');
    await settle(tester, ms: 600);
    expect(state.isUnlocked, isFalse);
    await tester.enterText(find.byType(TextField), '482915');
    await settle(tester, ms: 800);
    expect(state.isUnlocked, isTrue);
  });

  testWidgets('Clock: the PIN on the Timer, then Start, opens the vault', (tester) async {
    final state = await phoneOn(tester, DisguiseType.clock);

    await tester.tap(find.byIcon(Icons.hourglass_empty));
    await settle(tester);
    await tapKeys(tester, '482915');
    await tester.tap(find.byTooltip('Start'));
    await settle(tester, ms: 800);
    expect(state.isUnlocked, isTrue);
  });

  testWidgets('Clock: a short time on the Timer just starts it', (tester) async {
    final state = await phoneOn(tester, DisguiseType.clock);

    await tester.tap(find.byIcon(Icons.hourglass_empty));
    await settle(tester);
    await tapKeys(tester, '500');
    await tester.tap(find.byTooltip('Start'));
    await settle(tester, ms: 800);
    expect(state.isUnlocked, isFalse);
    expect(find.byType(CircularProgressIndicator), findsOneWidget, reason: 'the timer runs');
  });

  testWidgets('MoodSpace: the PIN as a note, then Save, opens the vault', (tester) async {
    final state = await phoneOn(tester, DisguiseType.moodspace);

    await tester.enterText(find.byType(TextField), '482915');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await settle(tester, ms: 800);
    expect(state.isUnlocked, isTrue);
  });

  for (final disguise in DisguiseType.values) {
    testWidgets('${disguise.displayName}: Request a feature opens a vault with a letters password',
        (tester) async {
      final state = await phoneOn(tester, disguise, pins: ['monsoon7']);

      await tester.tap(find.byIcon(Icons.more_vert));
      await settle(tester);
      await tester.tap(find.text('Request a feature'));
      await settle(tester);
      await tester.enterText(find.byType(TextField).last, 'monsoon7');
      await tester.tap(find.text('Send'));
      await settle(tester, ms: 800);
      expect(state.isUnlocked, isTrue);
    });
  }

  testWidgets('Lock returns to the disguise', (tester) async {
    final state = await phoneOn(tester, DisguiseType.calculator);
    await tapKeys(tester, '482915');
    await tester.tap(find.text('=').last);
    await settle(tester, ms: 800);
    expect(state.isUnlocked, isTrue);

    await tester.tap(find.text('Lock'));
    await settle(tester);
    expect(state.isUnlocked, isFalse);
    expect(find.text('AC'), findsOneWidget);
  });
}
