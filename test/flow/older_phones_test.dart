import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:securevault/core/constants/app_constants.dart';
import 'package:securevault/core/providers/app_state.dart';
import 'package:securevault/core/services/downloads.dart';

import '../support/app_harness.dart';
import '../support/capture.dart';
import '../support/fakes.dart';

/// Android 7 to 10 don't let the app write to Downloads, so copies leave
/// through the share sheet instead.
void main() {
  const share = MethodChannel('dev.fluttercommunity.plus/share');
  final shared = <String>[];
  late Directory phone;
  late Directory downloads;

  setUpAll(loadAppFonts);

  setUp(() {
    shared.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(share, (call) async {
      shared.addAll(((call.arguments as Map)['paths'] as List).cast<String>());
      return 'dev.fluttercommunity.plus/share/unavailable';
    });
  });

  tearDown(() async {
    setWritable(downloads, true);
    await phone.delete(recursive: true);
  });

  Future<void> openVault(WidgetTester tester, {List<File> photos = const []}) async {
    usePhoneScreen(tester);
    final state = AppState();
    await tester.runAsync(() async {
      phone = await useFreshDevice();
      downloads = await Directory('${phone.path}/Download').create();
      setWritable(downloads, false);
      Downloads.folder = downloads;
      await setPrefs(setUpOn(DisguiseType.calculator));
      await makeVault(photos: photos, notes: false);
      await state.initialize();
      await state.unlock('482915');
    });
    await pumpApp(tester, state: state);
    await settle(tester, ms: 1500);
  }

  testWidgets('Back up hands the backup to the share sheet', (tester) async {
    await openVault(tester);
    await tester.tap(find.byTooltip('Settings'));
    await settle(tester);
    await tester.tap(find.text('Back up and restore'));
    await settle(tester);

    await tester.tap(find.text('Back up this vault'));
    await settle(tester, ms: 1500);

    expect(shared, hasLength(1));
    expect(shared.single, endsWith('.svb'));
    expect(await tester.runAsync(() => File(shared.single).length()), greaterThan(0));
    expect(find.textContaining('Ready to send'), findsOneWidget);
    expect(downloads.listSync(), isEmpty);
  });

  testWidgets('Save to phone hands the photo to the share sheet', (tester) async {
    final beach = File('test/fixtures/v1_0_3/plain/photo_beach.png');
    await openVault(tester, photos: [beach]);
    await tester.tap(find.byType(Image).first);
    await settle(tester, ms: 1500);

    await tester.tap(find.text('Save to phone'));
    await settle(tester, ms: 800);

    expect(shared, hasLength(1));
    expect(await tester.runAsync(() => File(shared.single).readAsBytes()),
        await tester.runAsync(beach.readAsBytes));
    expect(downloads.listSync(), isEmpty);
  });
}
