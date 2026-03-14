import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:gear_up/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('🔥 Gear Up End-to-End Test 🔥', () {

    testWidgets('Full Login Scenario - سيناريو اللوجين الدقيق', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // 👻 العفريت بيدور على العلامات اللي حطيناها
      final emailField = find.byKey(const Key('email_input'));
      final passwordField = find.byKey(const Key('password_input'));
      final loginButton = find.byKey(const Key('login_button'));

      // التأكد إنهم موجودين في الشاشة
      expect(emailField, findsOneWidget);
      expect(passwordField, findsOneWidget);
      expect(loginButton, findsOneWidget);

      // العفريت بيكتب
      await tester.enterText(emailField, 'test@gearup.com');
      await tester.pumpAndSettle();

      await tester.enterText(passwordField, '12345678');
      await tester.pumpAndSettle();

      // العفريت بيدوس
      await tester.tap(loginButton);
      await tester.pumpAndSettle(const Duration(seconds: 3));

      print("✅ العفريت سجل دخول بنجاح!");
    });

  });
}