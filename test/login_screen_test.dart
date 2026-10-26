import 'package:flutter/material.dart';
import 'package:flutter_customer_app/core/theme/app_theme.dart';
import 'package:flutter_customer_app/features/auth/login_screen.dart';
import 'package:flutter_customer_app/features/auth/validators.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Widget app(Widget child) => ProviderScope(child: MaterialApp(theme: AppTheme.light, home: child));

  testWidgets('validates before calling the backend', (tester) async {
    await tester.pumpWidget(app(const LoginScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign in').last);
    await tester.pumpAndSettle();

    expect(find.text('Enter your mobile number'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
  });

  testWidgets('shows the session notice and toggles password visibility', (tester) async {
    await tester.pumpWidget(app(const LoginScreen(notice: 'Your session has expired. Please sign in again.')));
    await tester.pumpAndSettle();

    expect(find.text('Your session has expired. Please sign in again.'), findsOneWidget);
    expect(find.byTooltip('Show password'), findsOneWidget);
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(find.byTooltip('Hide password'), findsOneWidget);
  });

  testWidgets('demo helper is hidden without the DEMO_* defines', (tester) async {
    await tester.pumpWidget(app(const LoginScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Use demo account'), findsNothing);
  });

  test('validators', () {
    expect(Validators.mobile('9000000001'), isNull);
    expect(Validators.mobile('12345'), isNotNull);
    expect(Validators.mobile('1234567890'), isNotNull);
    expect(Validators.otp('7760'), isNull);
    expect(Validators.otp('77a0'), isNotNull);
    expect(Validators.newPassword('short1'), isNotNull);
    expect(Validators.newPassword('longenough'), isNotNull);
    expect(Validators.newPassword('Demo@1234'), isNull);
  });
}
