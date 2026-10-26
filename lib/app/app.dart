import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/auth/auth_controller.dart';
import '../core/constants/brand_config.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/login_screen.dart';
import '../features/splash/splash_screen.dart';
import 'main_shell.dart';

final navigatorKey = GlobalKey<NavigatorState>();

/// Start-up work shown behind the single splash: restore the session and
/// load the typefaces (bounded, so a slow network never blocks start-up).
final bootProvider = FutureProvider<void>((ref) async {
  final fonts = GoogleFonts.pendingFonts(AppText.preload).timeout(const Duration(seconds: 3), onTimeout: () => []);
  await Future.wait<Object?>([
    ref.read(authControllerProvider.notifier).restore(),
    fonts.catchError((_) => <void>[]),
    // Long enough to read the brand, short enough to never feel like a wait.
    Future<void>.delayed(const Duration(milliseconds: 650)),
  ]);
});

class CustomerApp extends ConsumerWidget {
  const CustomerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // When the session ends (sign-out or expiry) close every pushed screen so
    // nothing from the previous session stays on the stack.
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (previous is SignedIn && next is SignedOut) {
        navigatorKey.currentState?.popUntil((route) => route.isFirst);
      }
    });

    return MaterialApp(
      title: BrandConfig.appName,
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: AppTheme.light,
      themeMode: ThemeMode.light,
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: AppTheme.overlay,
          child: MediaQuery(
            // Honour the system text size, within the range the layouts are designed for.
            data: media.copyWith(textScaler: media.textScaler.clamp(minScaleFactor: 0.9, maxScaleFactor: 1.35)),
            child: child!,
          ),
        );
      },
      home: const _Root(),
    );
  }
}

class _Root extends ConsumerWidget {
  const _Root();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boot = ref.watch(bootProvider);
    final auth = ref.watch(authControllerProvider);

    final Widget screen;
    if (boot.hasError) {
      screen = SplashScreen(
        key: const ValueKey('splash-error'),
        errorMessage: 'Unable to initialize application. Please check your network connection.',
        onRetry: () => ref.invalidate(bootProvider),
      );
    } else if (boot.isLoading || auth is AuthRestoring) {
      screen = const SplashScreen(key: ValueKey('splash'));
    } else if (auth is SignedIn) {
      screen = MainShell(key: ValueKey('shell-${auth.session.customerId}'));
    } else {
      final notice = auth is SignedOut ? auth.notice : null;
      screen = LoginScreen(key: const ValueKey('login'), notice: notice);
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: screen,
    );
  }
}
