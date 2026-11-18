import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:securevault/core/licenses.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test("the licence page holds SecureVault's GPL and the font's OFL", () async {
    registerLicenses();

    final entries = await LicenseRegistry.licenses.toList();
    String text(String package) => entries
        .where((e) => e.packages.contains(package))
        .expand((e) => e.paragraphs)
        .map((p) => p.text)
        .join('\n');

    expect(text('SecureVault'), contains('GNU GENERAL PUBLIC LICENSE'));
    expect(text('SecureVault'), contains('Version 3, 29 June 2007'));
    expect(text('Red Hat Text'), contains('SIL OPEN FONT LICENSE'));
  });
}
