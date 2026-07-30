import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:citycalls_vendor/screens/login_screen.dart';
import 'package:citycalls_vendor/theme/app_theme.dart';

// Pumps the login screen directly rather than through
// CityCallsVendorApp/SplashScreen — the splash makes a real network/secure-
// storage call (session restore) and its spinner runs an indeterminate
// animation, which leaves pumpAndSettle waiting on scheduled frames forever
// in a widget test (same pattern as citycalls-customer-mobile's widget_test.dart).
Widget _wrapped(Widget child) => ProviderScope(
      child: MaterialApp(theme: AppTheme.light(), home: child),
    );

void main() {
  testWidgets('App boots to the login screen with required fields', (WidgetTester tester) async {
    await tester.pumpWidget(_wrapped(const LoginScreen()));

    expect(find.text('CityCalls Field'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Mobile number or email'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Password'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Sign In'), findsOneWidget);
  });

  testWidgets('Shows validation errors when submitting an empty form', (WidgetTester tester) async {
    await tester.pumpWidget(_wrapped(const LoginScreen()));

    await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
    await tester.pump();

    expect(find.text('Enter a valid mobile or email'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
  });
}
