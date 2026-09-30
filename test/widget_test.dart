import 'package:flutter_test/flutter_test.dart';
import 'package:wholeshole_mvp/main.dart';

void main() {
  testWidgets('VyaparSetuApp renders splash & app title', (WidgetTester tester) async {
    await tester.pumpWidget(const VyaparSetuApp());
    expect(find.text('VyaparSetu'), findsOneWidget);
    await tester.pumpAndSettle();
  });
}
