import 'package:flutter/material.dart';

import '../../../core/data/models.dart';
import '../../../core/ui/ui.dart';

/// The one dark surface in the app: the customer's gold balance across all
/// plans. Home shows the short form; Savings passes [detailed] for the full
/// breakdown.
class HoldingsPanel extends StatelessWidget {
  const HoldingsPanel({super.key, required this.holdings, this.goldRate, this.detailed = false, this.onTap});

  final Holdings holdings;

  /// Today's primary gold rate; when present the indicative value is shown.
  final MetalRate? goldRate;
  final bool detailed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final open = holdings.openAccounts.length;
    final closed = holdings.accounts.length - open;
    final rate = goldRate;
    final indicative = rate != null && rate.rate > 0 && holdings.totalWeight > 0 ? holdings.totalWeight * rate.rate : null;

    final content = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text('TOTAL GOLD SAVED', style: AppText.overline.copyWith(color: AppColors.panelMuted))),
        if (onTap != null) const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.panelMuted),
      ]),
      const SizedBox(height: Space.xs),
      _Weight(holdings.totalWeight),
      if (indicative != null) ...[
        const SizedBox(height: Space.sm),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text('≈ ${Fmt.money(indicative)}', style: AppText.amountM.copyWith(color: AppColors.gold)),
        ),
        const SizedBox(height: 2),
        Text('Indicative value at today’s ${rate!.label.trim()} rate',
            style: AppText.caption.copyWith(color: AppColors.panelMuted)),
      ],
      const SizedBox(height: Space.lg),
      const Divider(color: AppColors.panelLine, height: 1),
      const SizedBox(height: Space.md),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: _Stat('Total paid', Fmt.money(holdings.totalPaid))),
        const SizedBox(width: Space.md),
        Expanded(
          child: detailed
              ? _Stat('Instalments paid', '${holdings.installments}')
              : _Stat('Open plans', '$open'),
        ),
      ]),
      if (detailed) ...[
        const SizedBox(height: Space.md),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: _Stat('Active plans', '$open')),
          const SizedBox(width: Space.md),
          Expanded(child: _Stat('Closed plans', '$closed')),
        ]),
      ],
    ]);

    return Semantics(
      container: true,
      button: onTap != null,
      child: Material(
        color: AppColors.panel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.lg)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashColor: AppColors.panelLine,
          highlightColor: AppColors.panelLine.withValues(alpha: 0.4),
          child: Padding(padding: const EdgeInsets.all(Space.lg), child: content),
        ),
      ),
    );
  }
}

/// "12.345 g" with the unit set smaller than the figure.
class _Weight extends StatelessWidget {
  const _Weight(this.grams);

  final double grams;

  @override
  Widget build(BuildContext context) {
    final text = Fmt.grams(grams);
    final split = text.lastIndexOf(' ');
    final figure = split > 0 ? text.substring(0, split) : text;
    final unit = split > 0 ? text.substring(split) : '';
    return Semantics(
      label: '$figure grams',
      excludeSemantics: true,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text.rich(TextSpan(children: [
          TextSpan(text: figure, style: AppText.amountXL.copyWith(color: AppColors.inkInverse, fontSize: 36)),
          TextSpan(text: unit, style: AppText.amountL.copyWith(color: AppColors.panelMuted, fontWeight: FontWeight.w600)),
        ])),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: AppText.caption.copyWith(color: AppColors.panelMuted)),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: AppText.amountM.copyWith(color: AppColors.inkInverse)),
        ),
      ]),
    );
  }
}

/// Loading placeholder with the panel's shape and rhythm.
class HoldingsPanelSkeleton extends StatefulWidget {
  const HoldingsPanelSkeleton({super.key, this.detailed = false});

  final bool detailed;

  @override
  State<HoldingsPanelSkeleton> createState() => _HoldingsPanelSkeletonState();
}

class _HoldingsPanelSkeletonState extends State<HoldingsPanelSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);

  static const _dim = AppColors.panelLine;
  static const _bright = Color(0xFF4A4740);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Semantics(
      label: 'Loading your holdings',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(Space.lg),
          decoration: BoxDecoration(color: AppColors.panel, borderRadius: BorderRadius.circular(Radii.lg)),
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final color = Color.lerp(_dim, _bright, reduceMotion ? 0.3 : _c.value)!;
              Widget block(double? w, double h) => Container(
                    width: w,
                    height: h,
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(Radii.sm)),
                  );
              Widget statRow() => Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      block(64, 10),
                      const SizedBox(height: Space.xs),
                      block(110, 16),
                    ])),
                    const SizedBox(width: Space.md),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      block(64, 10),
                      const SizedBox(height: Space.xs),
                      block(40, 16),
                    ])),
                  ]);
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                block(120, 10),
                const SizedBox(height: Space.sm),
                block(170, 34),
                const SizedBox(height: Space.sm),
                block(130, 14),
                const SizedBox(height: Space.lg),
                const Divider(color: AppColors.panelLine, height: 1),
                const SizedBox(height: Space.md),
                statRow(),
                if (widget.detailed) ...[const SizedBox(height: Space.md), statRow()],
              ]);
            },
          ),
        ),
      ),
    );
  }
}
