import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:securevault/core/constants/app_constants.dart';
import 'package:securevault/core/providers/app_state.dart';

import '../support/app_harness.dart';
import '../support/capture.dart';
import '../support/fakes.dart';

/// Hands back photos from a folder in the app's cache, as the photo picker does
/// on Android: it copies each picked photo there in plain form.
class _CachePicker extends ImagePickerPlatform with MockPlatformInterfaceMixin {
  _CachePicker(this.copies);

  final List<File> copies;

  @override
  Future<List<XFile>> getMultiImageWithOptions({
    MultiImagePickerOptions options = const MultiImagePickerOptions(),
  }) async =>
      [for (final f in copies) XFile(f.path)];
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('no plain copy of an added photo stays in the cache', (tester) async {
    usePhoneScreen(tester);
    final state = AppState();
    late Directory phone;
    late Directory cache;
    await tester.runAsync(() async {
      phone = await useFreshDevice();
      await setPrefs(setUpOn(DisguiseType.calculator));
      await makeVault(notes: false);
      await state.initialize();
      await state.unlock('482915');
      cache = Directory('${phone.path}/tmp');
      final copy = File('${cache.path}/0b6e2c4a-91d3-4c55-a7f0-2f1d6c0e8b13/IMG_0412.png');
      await copy.parent.create(recursive: true);
      await File('test/fixtures/v1_0_3/plain/photo_beach.png').copy(copy.path);
      ImagePickerPlatform.instance = _CachePicker([copy]);
    });
    addTearDown(() => phone.delete(recursive: true));
    await pumpApp(tester, state: state);
    await settle(tester, ms: 1500);

    await tester.tap(find.text('Add photos'));
    await settle(tester);
    await tester.tap(find.text('Choose photos'));
    await settle(tester, ms: 2000);

    expect(state.currentVault!.items.where((i) => i.type == VaultItemType.photo), hasLength(1));
    final left = await tester.runAsync(() => cache.list(recursive: true).toList());
    expect(left, isEmpty);
  });
}
