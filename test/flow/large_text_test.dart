import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:securevault/core/constants/app_constants.dart';
import 'package:securevault/core/providers/app_state.dart';

import '../support/app_harness.dart';
import '../support/capture.dart';
import '../support/fakes.dart';

void main() {
  setUpAll(loadAppFonts);

  testWidgets('the vault fits on screen at twice the text size', (tester) async {
    usePhoneScreen(tester);
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final state = AppState();
    late Directory phone;
    await tester.runAsync(() async {
      phone = await useFreshDevice();
      await setPrefs(setUpOn(DisguiseType.calculator));
      await makeVault(videos: 2, photos: [
        File('test/fixtures/v1_0_3/plain/photo_beach.png'),
        File('test/fixtures/v1_0_3/plain/photo_garden.png'),
      ]);
      await state.initialize();
      await state.unlock('482915');
    });
    addTearDown(() => phone.delete(recursive: true));
    await pumpApp(tester, state: state);
    await settle(tester, ms: 1500);

    final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
    for (final tab in ['Photos', 'Videos', 'Notes']) {
      final rect = tester.getRect(find.textContaining(tab));
      expect(rect.left, greaterThanOrEqualTo(0), reason: tab);
      expect(rect.right, lessThanOrEqualTo(width), reason: tab);
    }
  });
}
