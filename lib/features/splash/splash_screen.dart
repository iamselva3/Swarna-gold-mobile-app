import 'package:flutter/material.dart';

import '../../core/constants/brand_config.dart';
import '../../core/ui/ui.dart';

/// The polished, premium splash screen for SwarnaGold.
///
/// Matches the native Android launch window background (#FAF7F0) for a seamless,
/// flash-free start-up experience. Displays the prominent brand logo mark,
/// elegant typography, and a restrained gold loading accent while the session
/// is restored.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.errorMessage, this.onRetry});

  final String? errorMessage;
  final VoidCallback? onRetry;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _scaleAnim = Tween<double>(begin: 0.94, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Centered Brand Identity Hero
          Center(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ScaleTransition(
                      scale: _scaleAnim,
                      child: const BrandMark(size: 96),
                    ),
                    const SizedBox(height: Space.lg),
                    Text(
                      BrandConfig.appName,
                      style: AppText.brand.copyWith(
                        fontSize: 28,
                        letterSpacing: 0.8,
                        color: AppColors.ink,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: Space.xs),
                    Text(
                      BrandConfig.appTagline,
                      style: AppText.small.copyWith(
                        color: AppColors.inkSecondary,
                        letterSpacing: 0.2,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Progress Indicator or Recoverable Error State
          Positioned(
            left: 0,
            right: 0,
            bottom: 40,
            child: SafeArea(
              top: false,
              child: FadeTransition(
                opacity: _fadeAnim,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.errorMessage != null) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: Space.xl),
                        child: Column(
                          children: [
                            Text(
                              widget.errorMessage!,
                              style: AppText.small.copyWith(color: AppColors.negative),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: Space.md),
                            if (widget.onRetry != null)
                              SecondaryButton(
                                label: 'Retry Connection',
                                icon: Icons.refresh_rounded,
                                onPressed: widget.onRetry,
                              ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Semantics(
                        label: 'Initializing application',
                        child: SizedBox(
                          width: 140,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(Radii.pill),
                            child: const LinearProgressIndicator(
                              minHeight: 2.5,
                              backgroundColor: AppColors.line,
                              color: AppColors.gold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: Space.md),
                      Text(
                        BrandConfig.goldStandard.toUpperCase(),
                        style: AppText.caption.copyWith(
                          letterSpacing: 1.4,
                          fontSize: 10,
                          color: AppColors.inkTertiary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
