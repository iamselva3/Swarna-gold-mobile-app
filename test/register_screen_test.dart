import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_customer_app/core/theme/app_theme.dart';
import 'package:flutter_customer_app/features/auth/register_screen.dart';

void main() {
  testWidgets('RegisterScreen renders form fields and WhatsApp verification notice', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: const RegisterScreen(),
        ),
      ),
    );

    expect(find.text('Create account'), findsOneWidget);
    expect(find.text('Full name'), findsOneWidget);
    expect(find.text('WhatsApp Mobile number'), findsOneWidget);
    expect(find.text('4-digit MPIN'), findsOneWidget);
    expect(find.text('Account password'), findsOneWidget);
    expect(find.text('WhatsApp Verification'), findsOneWidget);
    expect(find.text('Continue to WhatsApp OTP'), findsOneWidget);
    expect(find.text('Already have an account? '), findsOneWidget);
  });

  testWidgets('RegisterScreen validates inputs on empty submission', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: const RegisterScreen(),
        ),
      ),
    );

    await tester.ensureVisible(find.text('Continue to WhatsApp OTP'));
    await tester.tap(find.text('Continue to WhatsApp OTP'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter your full name (at least 2 letters)'), findsOneWidget);
    expect(find.text('Enter your mobile number'), findsOneWidget);
    expect(find.text('Please set a 4-digit numeric MPIN'), findsOneWidget);
    expect(find.text('Password must be at least 6 characters'), findsOneWidget);
  });
}
