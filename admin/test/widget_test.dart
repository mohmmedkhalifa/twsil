import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:twsil_admin/main.dart';

void main() {
  testWidgets('admin app renders login screen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const AdminApp());
    expect(find.text('لوحة تحكم توصيل'), findsOneWidget);
  });
}