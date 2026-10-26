import 'package:flutter/material.dart';

import '../constants/brand_config.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// White surface with a hairline border. The single container style used for
/// grouped content; elevation is never used for hierarchy.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Space.md),
    this.onTap,
    this.color = AppColors.surface,
    this.borderColor = AppColors.line,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color color;
  final Color borderColor;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Radii.lg),
      side: BorderSide(color: borderColor),
    );
    final content = Padding(padding: padding, child: child);
    return Semantics(
      label: semanticLabel,
      button: onTap != null,
      container: true,
      child: Material(
        color: color,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: onTap == null ? content : InkWell(onTap: onTap, child: content),
      ),
    );
  }
}

/// Primary call to action. Shows a spinner and blocks taps while [loading],
/// which is how every submit in the app prevents duplicate requests.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, required this.onPressed, this.loading = false, this.icon});

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: loading ? null : onPressed,
      style: loading
          ? FilledButton.styleFrom(
              disabledBackgroundColor: AppColors.ink.withValues(alpha: 0.85),
              disabledForegroundColor: AppColors.inkInverse)
          : null,
      child: loading
          ? Row(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.inkInverse)),
              const SizedBox(width: Space.sm),
              Text('Please wait…', style: AppText.body.copyWith(color: AppColors.inkInverse, fontWeight: FontWeight.w700)),
            ])
          : Row(mainAxisSize: MainAxisSize.min, children: [
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
              if (icon != null) ...[const SizedBox(width: Space.xs), Icon(icon, size: 18)],
            ]),
    );
  }
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({super.key, required this.label, required this.onPressed, this.icon});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: Space.xs)],
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
      ]),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.actionLabel, this.onAction, this.padding});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(Space.gutter, Space.xl, Space.gutter, Space.sm),
      child: Row(children: [
        Expanded(child: Semantics(header: true, child: Text(title, style: AppText.heading))),
        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: Space.xs), minimumSize: const Size(48, 40)),
            child: Text(actionLabel!),
          ),
      ]),
    );
  }
}

enum Tone { positive, negative, caution, neutral, gold }

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.label, {super.key, this.tone = Tone.neutral});

  final String label;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      Tone.positive => (AppColors.positiveWash, AppColors.positive),
      Tone.negative => (AppColors.negativeWash, AppColors.negative),
      Tone.caution => (AppColors.cautionWash, AppColors.caution),
      Tone.gold => (AppColors.goldWash, AppColors.goldDeep),
      Tone.neutral => (AppColors.neutralWash, AppColors.inkSecondary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Radii.pill)),
      child: Text(label, style: AppText.caption.copyWith(color: fg, fontWeight: FontWeight.w700)),
    );
  }
}

/// Label on the left, value on the right; used in reviews and detail lists.
class DetailRow extends StatelessWidget {
  const DetailRow(this.label, this.value, {super.key, this.emphasize = false, this.valueColor});

  final String label;
  final String value;
  final bool emphasize;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: MergeSemantics(
        child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Expanded(child: Text(label, style: emphasize ? AppText.smallStrong : AppText.small)),
          const SizedBox(width: Space.md),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: (emphasize ? AppText.amountM : AppText.tabular(AppText.smallStrong))
                  .copyWith(color: valueColor),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Small round icon tile used in list rows and quick actions.
class IconTile extends StatelessWidget {
  const IconTile(this.icon, {super.key, this.size = 40, this.background = AppColors.surfaceSunken, this.color = AppColors.ink});

  final IconData icon;
  final double size;
  final Color background;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(Radii.md)),
      alignment: Alignment.center,
      child: Icon(icon, size: size * 0.5, color: color),
    );
  }
}

/// Monogram / Brand Emblem: renders the centralized brand logo image inside
/// an elegant gold-bordered frame with graceful fallback to the display serif initial.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 56, this.onDark = false});

  final double size;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: onDark ? AppColors.panel : AppColors.surface,
          borderRadius: BorderRadius.circular(size * 0.28),
          border: Border.all(color: AppColors.gold, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.12),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        alignment: Alignment.center,
        child: Image.asset(
          BrandConfig.logoAsset,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Text(
            BrandConfig.appName.characters.first,
            style: AppText.brand.copyWith(
              fontSize: size * 0.56,
              height: 1,
              color: onDark ? AppColors.gold : AppColors.goldDeep,
            ),
          ),
        ),
      ),
    );
  }
}

/// Unified inline brand identity widget for headers, navigation bars, and shells
class BrandHeaderLogo extends StatelessWidget {
  const BrandHeaderLogo({super.key, this.size = 32, this.showTagline = false});

  final double size;
  final bool showTagline;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        BrandMark(size: size),
        const SizedBox(width: Space.sm),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              BrandConfig.appName,
              style: AppText.brand.copyWith(
                fontSize: size * 0.58,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
                letterSpacing: 0.2,
              ),
            ),
            if (showTagline) ...[
              const SizedBox(height: 1),
              Text(
                BrandConfig.appTagline,
                style: AppText.caption.copyWith(fontSize: 11, color: AppColors.inkSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// A thin determinate bar for instalment progress.
class ProgressBar extends StatelessWidget {
  const ProgressBar(this.value, {super.key, this.track = AppColors.surfaceSunken, this.fill = AppColors.gold});

  final double value;
  final Color track;
  final Color fill;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.pill),
      child: LinearProgressIndicator(value: value.clamp(0, 1), minHeight: 6, backgroundColor: track, color: fill),
    );
  }
}
