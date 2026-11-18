import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Adds SecureVault's own licence and its font's licence to the licence page,
/// beside the packages Flutter lists by itself.
void registerLicenses() {
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(['SecureVault'], await rootBundle.loadString('LICENSE'));
    yield LicenseEntryWithLineBreaks(
        ['Red Hat Text'], await rootBundle.loadString('assets/fonts/RedHatText-OFL.txt'));
  });
}
