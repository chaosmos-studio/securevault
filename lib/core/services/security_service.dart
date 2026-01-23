import 'package:screen_protector/screen_protector.dart';

class SecurityService {
  static Future<void> preventScreenshots() async {
    try {
      await ScreenProtector.preventScreenshotOn();
    } catch (e) {
      // Ignore errors on platforms that don't support this
    }
  }

  static Future<void> allowScreenshots() async {
    try {
      await ScreenProtector.preventScreenshotOff();
    } catch (e) {
      // Ignore errors on platforms that don't support this
    }
  }
}
