import 'package:flutter_test/flutter_test.dart';
import 'package:copany_app/main.dart';

void main() {
  testWidgets('اختبار شاشة تسجيل الدخول', (WidgetTester tester) async {
    await tester.pumpWidget(const SharqAbhaApp());

    expect(find.text('شركة شرق أبها'), findsOneWidget);
    expect(find.text('البريد الإلكتروني'), findsOneWidget);
    expect(find.text('كلمة المرور'), findsOneWidget);
    expect(find.text('تسجيل الدخول'), findsOneWidget);
  });
}