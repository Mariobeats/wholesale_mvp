import 'package:flutter_test/flutter_test.dart';
import 'package:wholeshole_mvp/main.dart';

void main() {
  testWidgets('WholesaleApp renders splash & app title', (WidgetTester tester) async {
    await tester.pumpWidget(const WholesaleApp());
    expect(find.text('Wholesale Order Management'), findsOneWidget);
    await tester.pumpAndSettle();
  });
}
