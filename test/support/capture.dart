import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// A Nothing Phone (2a): 1084 x 2412 pixels at about 2.6 pixels per point.
const Size kPhoneSize = Size(1084, 2412);
const double kPhonePixelRatio = 2.625;

final String _flutterRoot = Platform.environment['FLUTTER_ROOT'] ??
    '${Platform.environment['HOME']}/develop/flutter';

/// Fonts as a phone would draw them, instead of the test font's boxes.
/// The emoji and Devanagari faces are added to every family as fallbacks.
Future<void> loadPhoneFonts({Map<String, List<String>> extra = const {}}) async {
  final material = '$_flutterRoot/bin/cache/artifacts/material_fonts';
  const fallbacks = [
    '/usr/share/fonts/google-noto-color-emoji-fonts/Noto-COLRv1.ttf',
    '/usr/share/fonts/google-noto-vf/NotoSansDevanagari[wght].ttf',
  ];
  final roboto = [
    '$material/Roboto-Regular.ttf',
    '$material/Roboto-Medium.ttf',
    '$material/Roboto-Bold.ttf',
    '$material/Roboto-Light.ttf',
    '$material/Roboto-Thin.ttf',
  ];
  final families = <String, List<String>>{
    'Roboto': roboto,
    // Text with no family set falls back to the test font, which a phone never shows.
    'FlutterTest': roboto,
    'MaterialIcons': ['$material/MaterialIcons-Regular.otf'],
    ...extra,
  };
  for (final entry in families.entries) {
    final loader = FontLoader(entry.key);
    for (final path in [...entry.value, if (entry.key != 'MaterialIcons') ...fallbacks]) {
      final file = File(path);
      if (file.existsSync()) {
        loader.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
      }
    }
    await loader.load();
  }
}

void usePhoneScreen(WidgetTester tester) {
  tester.view.physicalSize = kPhoneSize;
  tester.view.devicePixelRatio = kPhonePixelRatio;
  addTearDown(tester.view.reset);
}

/// Lets real file and crypto work finish, then settles the frames.
/// Each await on real I/O needs real time, then a pump to run what follows it.
Future<void> settle(WidgetTester tester, {int ms = 300}) async {
  for (var i = 0; i < ms ~/ 25; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
    await tester.pump(const Duration(milliseconds: 20));
  }
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

/// Writes what is on screen, the whole view at phone pixels, to [dir]/[name].png.
Future<void> capture(WidgetTester tester, String dir, String name) async {
  await precacheShownImages(tester);
  // Tests draw shadows as black outlines, so repaint everything with real
  // shadows for the picture, then switch them back off for the test's checks.
  debugDisableShadows = false;
  // Its future waits for a frame that only the pump below draws.
  final reassembled = tester.binding.reassembleApplication();
  await tester.pump();
  await reassembled;
  try {
    await _write(tester, dir, name);
  } finally {
    debugDisableShadows = true;
  }
}

Future<void> _write(WidgetTester tester, String dir, String name) async {
  // The root layer already scales points to pixels, so render it 1:1.
  final RenderObject root = tester.binding.rootElement!.renderObject!;
  final layer = root.debugLayer! as OffsetLayer;
  await tester.runAsync(() async {
    final ui.Image image = await layer.toImage(
      Offset.zero & tester.view.physicalSize,
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$dir/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
  });
}

/// Decodes every image on screen for real, so captures show pictures, not gaps.
Future<void> precacheShownImages(WidgetTester tester) async {
  final images = tester.widgetList<Image>(find.byType(Image)).toList();
  if (images.isEmpty) return;
  await tester.runAsync(() async {
    for (final image in images) {
      final element = find.byWidget(image).evaluate();
      if (element.isEmpty) continue;
      await precacheImage(image.image, element.first);
    }
  });
  await tester.pump(const Duration(milliseconds: 100));
}
