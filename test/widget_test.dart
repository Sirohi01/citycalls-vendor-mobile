import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:citycalls_vendor/screens/otp_request_screen.dart';

void main() {
  // Pumps the OTP-request screen directly (wrapped in a bare ProviderScope)
  // rather than through CityCallsVendorApp/SplashScreen — the splash makes a
  // real session-restore call and its spinner animates indefinitely, which
  // leaves pumpAndSettle waiting on scheduled frames forever in a widget
  // test (same pattern as citycalls-customer-mobile's widget_test.dart).
  testWidgets('Shows the mobile-number entry screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: OtpRequestScreen())));

    expect(find.text('Welcome, Partner'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Mobile number'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Send OTP'), findsOneWidget);
  });

  testWidgets('Shows a validation error for an invalid mobile number',
      (WidgetTester tester) async {
    await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: OtpRequestScreen())));

    final sendOtp = find.widgetWithText(FilledButton, 'Send OTP');
    await tester.ensureVisible(sendOtp);
    await tester.pumpAndSettle();
    await tester.tap(sendOtp);
    await tester.pump();

    expect(find.text('Enter a valid 10-digit mobile number'), findsOneWidget);
  });
}
