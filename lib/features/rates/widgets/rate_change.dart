import 'package:flutter/material.dart';

import '../../../core/data/models.dart';
import '../../../core/ui/ui.dart';

/// Movement since the previously published rate: an up/down marker, the
/// rupee difference and, when available, the percentage.
///
/// Rendered as a single rich text run so it wraps safely inside narrow
/// columns and works inside unbounded rows.
class RateChange extends StatelessWidget {
  const RateChange(this.rate, {super.key, this.suffix, this.showPercent = true});

  final MetalRate rate;

  /// Neutral trailing text, e.g. " vs previous".
  final String? suffix;
  final bool showPercent;

  @override
  Widget build(BuildContext context) {
    final change = rate.change;
    final previous = rate.previousRate;

    if (change == null || previous == null) {
      return Semantics(
        label: 'No previous rate to compare',
        excludeSemantics: true,
        child: Text('No previous rate', style: AppText.caption),
      );
    }

    final flat = change.abs() < 0.005;
    final up = change > 0;
    final color = flat ? AppColors.inkTertiary : (up ? AppColors.positive : AppColors.negative);
    final icon = flat ? Icons.remove_rounded : (up ? Icons.arrow_drop_up_rounded : Icons.arrow_drop_down_rounded);
    final amount = Fmt.money(change.abs());
    final percent = previous > 0 ? '${(change.abs() / previous * 100).toStringAsFixed(2)}%' : null;
    final figure = flat ? 'No change' : (showPercent && percent != null ? '$amount ($percent)' : amount);
    final spoken = flat
        ? 'Unchanged since the previous rate'
        : '${up ? 'Up' : 'Down'} $amount${percent == null ? '' : ', $percent,'} since the previous rate';

    final valueStyle = AppText.tabular(AppText.small).copyWith(color: color, fontWeight: FontWeight.w700);

    return Semantics(
      label: spoken,
      excludeSemantics: true,
      child: Text.rich(
        TextSpan(children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: EdgeInsets.only(right: flat ? Space.xxs : 0),
              child: Icon(icon, size: flat ? 14 : 20, color: color),
            ),
          ),
          TextSpan(text: figure, style: valueStyle),
          if (suffix != null) TextSpan(text: suffix, style: AppText.caption),
        ]),
      ),
    );
  }
}

/// Rates grouped by metal in board order (gold first), e.g. Gold → [24K, 22K].
List<({String metal, List<MetalRate> rates})> groupRatesByMetal(RateBoard board) {
  final groups = <String, List<MetalRate>>{};
  for (final r in board.rates) {
    groups.putIfAbsent(r.metal, () => []).add(r);
  }
  return [for (final e in groups.entries) (metal: e.key, rates: e.value)];
}
