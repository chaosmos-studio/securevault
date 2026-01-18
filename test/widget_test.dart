import 'package:flutter_test/flutter_test.dart';
import 'package:securevault/main.dart';

void main() {
  testWidgets('App loads correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const SecureVaultApp());
    await tester.pumpAndSettle();
    expect(find.byType(SecureVaultApp), findsOneWidget);
  });
}
