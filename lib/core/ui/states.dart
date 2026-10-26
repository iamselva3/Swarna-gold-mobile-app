import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// A pulsing placeholder block. Skeletons mirror the layout they replace so the
/// page does not jump when data arrives.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.width, this.height = 14, this.radius = Radii.sm});

  final double? width;
  final double height;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Color.lerp(AppColors.surfaceSunken, AppColors.line, reduceMotion ? 0.3 : _c.value),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        ),
      ),
    );
  }
}

/// A card-shaped skeleton with a title line and [lines] text lines.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key, this.lines = 2, this.height});

  final int lines;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      child: Container(
        height: height,
        padding: const EdgeInsets.all(Space.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(Radii.lg),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          const Skeleton(width: 120, height: 12),
          const SizedBox(height: Space.sm),
          const Skeleton(width: 180, height: 22),
          for (var i = 0; i < lines; i++) ...[
            const SizedBox(height: Space.sm),
            Skeleton(width: i.isEven ? double.infinity : 160),
          ],
        ]),
      ),
    );
  }
}

/// Converts any error into a sentence for the customer.
String errorMessage(Object error) {
  if (error is ApiException) return error.message;
  return 'Something went wrong. Please try again.';
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, this.onRetry, this.compact = false});

  final Object error;
  final VoidCallback? onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final offline = error is ApiException && (error as ApiException).isConnectivity;
    final icon = offline ? Icons.wifi_off_rounded : Icons.error_outline_rounded;
    final title = offline ? 'You appear to be offline' : 'Couldn’t load this';

    if (compact) {
      return Container(
        padding: const EdgeInsets.all(Space.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(Radii.lg),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(children: [
          Icon(icon, color: AppColors.negative, size: 22),
          const SizedBox(width: Space.sm),
          Expanded(child: Text(errorMessage(error), style: AppText.small)),
          if (onRetry != null) TextButton(onPressed: onRetry, child: const Text('Retry')),
        ]),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.xxl, vertical: Space.xxxl),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 36, color: AppColors.inkTertiary),
        const SizedBox(height: Space.md),
        Text(title, style: AppText.heading, textAlign: TextAlign.center),
        const SizedBox(height: Space.xs),
        Text(errorMessage(error), style: AppText.small, textAlign: TextAlign.center),
        if (onRetry != null) ...[
          const SizedBox(height: Space.lg),
          SizedBox(
            width: 160,
            child: OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try again'),
            ),
          ),
        ],
      ]),
    );
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.icon, required this.title, required this.message, this.action});

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.xxl, vertical: Space.xxxl),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(color: AppColors.goldWash, borderRadius: BorderRadius.circular(Radii.lg)),
          child: Icon(icon, color: AppColors.goldDeep, size: 26),
        ),
        const SizedBox(height: Space.md),
        Text(title, style: AppText.heading, textAlign: TextAlign.center),
        const SizedBox(height: Space.xs),
        Text(message, style: AppText.small, textAlign: TextAlign.center),
        if (action != null) ...[const SizedBox(height: Space.lg), action!],
      ]),
    );
  }
}

/// Renders an [AsyncValue] with a skeleton while loading, an [ErrorView] with
/// retry on failure, and [data] otherwise. During a refresh the previous data
/// stays on screen.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({
    super.key,
    required this.value,
    required this.data,
    required this.onRetry,
    this.loading,
    this.compactError = false,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback onRetry;
  final Widget? loading;
  final bool compactError;

  @override
  Widget build(BuildContext context) {
    return value.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      data: data,
      loading: () => loading ?? const SkeletonCard(),
      error: (e, _) => ErrorView(error: e, onRetry: onRetry, compact: compactError),
    );
  }
}

void showAppSnack(BuildContext context, String message, {bool error = false}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(children: [
        Icon(error ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
            color: error ? const Color(0xFFF2B8B0) : AppColors.gold, size: 20),
        const SizedBox(width: Space.sm),
        Expanded(child: Text(message)),
      ]),
    ));
}
