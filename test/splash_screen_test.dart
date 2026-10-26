import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_customer_app/core/constants/brand_config.dart';
import 'package:flutter_customer_app/core/theme/app_theme.dart';
import 'package:flutter_customer_app/features/splash/splash_screen.dart';

void main() {
  testWidgets('SplashScreen renders BrandMark, brand name, and gold standard', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const SplashScreen(),
      ),
    );

    // Initial render
    expect(find.text(BrandConfig.appName), findsOneWidget);
    expect(find.text(BrandConfig.appTagline), findsOneWidget);
    expect(find.text(BrandConfig.goldStandard.toUpperCase()), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    // Advance animation
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text(BrandConfig.appName), findsOneWidget);
  });

  testWidgets('SplashScreen shows recoverable error state when error message provided', (tester) async {
    bool retried = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: SplashScreen(
          errorMessage: 'Network timeout. Could not reach server.',
          onRetry: () => retried = true,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Network timeout. Could not reach server.'), findsOneWidget);
    expect(find.text('Retry Connection'), findsOneWidget);

    await tester.tap(find.text('Retry Connection'));
    expect(retried, isTrue);
  });
}
