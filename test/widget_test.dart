import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssh_dashboard/main.dart';

void main() {
  testWidgets('ServerCommanderApp smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const ServerCommanderApp());
    await tester.pumpAndSettle();
    expect(find.text('Dashboard & Resources'), findsOneWidget);
    expect(find.text('No Server Connected'), findsOneWidget);
  });
}
