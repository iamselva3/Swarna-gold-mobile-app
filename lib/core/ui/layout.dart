import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Scroll layout for a bottom-navigation tab: large serif title, optional
/// subtitle and trailing action, pull-to-refresh, then [slivers].
class TabPage extends StatelessWidget {
  const TabPage({
    super.key,
    required this.title,
    required this.slivers,
    this.subtitle,
    this.trailing,
    this.brandHeader,
    this.onRefresh,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? brandHeader;
  final List<Widget> slivers;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final scroll = CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      slivers: [
        SliverSafeArea(
          bottom: false,
          sliver: SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, Space.xs),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (brandHeader != null) ...[
                  brandHeader!,
                  const SizedBox(height: Space.sm),
                ],
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Semantics(header: true, child: Text(title, style: AppText.title)),
                      if (subtitle != null) ...[
                        const SizedBox(height: Space.xxs),
                        Text(subtitle!, style: AppText.small),
                      ],
                    ]),
                  ),
                  if (trailing != null && brandHeader == null) trailing!,
                ]),
              ]),
            ),
          ),
        ),
        ...slivers,
        const SliverToBoxAdapter(child: SizedBox(height: Space.xxl)),
      ],
    );

    if (onRefresh == null) return scroll;
    return RefreshIndicator(
      color: AppColors.goldDeep,
      backgroundColor: AppColors.surface,
      onRefresh: onRefresh!,
      child: scroll,
    );
  }
}

/// Horizontal padding wrapper for sliver content.
class Gutter extends StatelessWidget {
  const Gutter({super.key, required this.child, this.top = 0, this.bottom = 0});

  final Widget child;
  final double top;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(Space.gutter, top, Space.gutter, bottom),
      child: child,
    );
  }
}

/// "Step 2 of 3 · Review" with a segmented bar.
class StepIndicator extends StatelessWidget {
  const StepIndicator({super.key, required this.current, required this.labels});

  /// Zero-based.
  final int current;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Step ${current + 1} of ${labels.length}: ${labels[current]}',
      excludeSemantics: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('STEP ${current + 1} OF ${labels.length}  ·  ${labels[current].toUpperCase()}', style: AppText.overline),
        const SizedBox(height: Space.xs),
        Row(children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: 4,
                decoration: BoxDecoration(
                  color: i <= current ? AppColors.gold : AppColors.line,
                  borderRadius: BorderRadius.circular(Radii.pill),
                ),
              ),
            ),
          ],
        ]),
      ]),
    );
  }
}

/// Bottom-pinned action area for flows. Sits above the keyboard and the
/// system navigation bar.
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({super.key, required this.child, this.note});

  final Widget child;
  final Widget? note;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.canvas,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: Space.sm),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, 0),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (note != null) ...[note!, const SizedBox(height: Space.sm)],
            child,
          ]),
        ),
      ),
    );
  }
}
