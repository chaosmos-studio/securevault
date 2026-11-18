import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:securevault/core/constants/app_constants.dart';
import 'package:securevault/screens/disguises/coach_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/app_harness.dart';
import '../support/capture.dart';
import '../support/fakes.dart';

Future<void> typeKeys(WidgetTester tester, String keys) async {
  for (final k in keys.split('')) {
    await tester.tap(find.text(k).last);
    await tester.pump();
  }
  await settle(tester);
}

void main() {
  testWidgets('a first-timer sets up, practises on the disguise and opens the vault',
      (tester) async {
    usePhoneScreen(tester);
    await tester.runAsync(useFreshDevice);
    final state = await pumpApp(tester);

    await tester.tap(find.text('Get started'));
    await settle(tester);
    await tester.tap(find.text('Clock'));
    await settle(tester);
    await tester.tap(find.text('Use Clock'));
    await settle(tester);
    expect(find.textContaining('You type it into the Timer'), findsOneWidget);

    await typeKeys(tester, '482915');
    await tester.tap(find.text('Next'));
    await settle(tester);
    await typeKeys(tester, '482915');
    await settle(tester, ms: 1500);

    expect(state.isSetupComplete, isTrue);
    expect(state.currentDisguise, DisguiseType.clock);
    expect(find.byType(CoachCard), findsOneWidget);
    expect(find.textContaining('Type 482915 then Start'), findsOneWidget);

    // The clock opens on its Timer for the practice run.
    await typeKeys(tester, '482915');
    await tester.tap(find.byTooltip('Start'));
    await settle(tester, ms: 1500);

    expect(state.isUnlocked, isTrue);
    expect(find.text('Your vault is ready'), findsOneWidget);
    await tester.tap(find.text('Got it'));
    await settle(tester);

    final prefs = await tester.runAsync(SharedPreferences.getInstance);
    expect(prefs!.getString('pending_icon'), 'clock');
    expect(prefs.getBool('coach_pending'), isFalse);
    expect(prefs.getBool('welcome_pending'), isFalse);
    expect(prefs.getInt('auto_lock_seconds'), 0);
    expect(state.currentVaultInfo!.name, 'My vault');
  });

  testWidgets('a PIN typed differently the second time is asked for again', (tester) async {
    usePhoneScreen(tester);
    await tester.runAsync(useFreshDevice);
    final state = await pumpApp(tester);

    await tester.tap(find.text('Get started'));
    await settle(tester);
    await tester.tap(find.text('Use Calculator'));
    await settle(tester);
    await typeKeys(tester, '482915');
    await tester.tap(find.text('Next'));
    await settle(tester);
    await typeKeys(tester, '482916');

    expect(find.text("Those PINs don't match"), findsOneWidget);
    expect(state.isSetupComplete, isFalse);

    await typeKeys(tester, '482915');
    await settle(tester, ms: 1500);
    expect(state.isSetupComplete, isTrue);
  });

  testWidgets('Next stays off until the PIN has six digits', (tester) async {
    usePhoneScreen(tester);
    await tester.runAsync(useFreshDevice);
    await pumpApp(tester);
    await tester.tap(find.text('Get started'));
    await settle(tester);
    await tester.tap(find.text('Use Calculator'));
    await settle(tester);

    await typeKeys(tester, '12345');
    final next = find.widgetWithText(FilledButton, 'Next');
    expect(tester.widget<FilledButton>(next).onPressed, isNull);
    await typeKeys(tester, '6');
    expect(tester.widget<FilledButton>(next).onPressed, isNotNull);
  });
}
