import '../../core/data/models.dart';
import '../../core/utils/formatters.dart';

/// Display labels for a plan's rules, shared by the detail and enrolment screens.
extension PlanFormat on SchemeDetail {
  /// Digital silver (14) is a digital plan the in-app buy flow does not sell.
  bool get isDigitalSilver => schemeType == 14;

  String get frequencyLabel => switch (installmentType) {
        1 => 'Monthly',
        2 => 'Weekly',
        3 => 'Daily',
        4 => 'Yearly',
        _ => frequency,
      };

  /// The backend counts the maturity period in the unit of the instalment
  /// frequency (months for monthly plans, weeks for weekly, and so on).
  String? get maturityLabel {
    if (maturityPeriod <= 0) return null;
    final unit = switch (installmentType) { 1 => 'month', 2 => 'week', 3 => 'day', 4 => 'year', _ => null };
    if (unit == null) return '$maturityPeriod';
    return '$maturityPeriod $unit${maturityPeriod == 1 ? '' : 's'}';
  }

  String get metalLabel {
    final label = [purity, metal].where((s) => s.trim().isNotEmpty).join(' ');
    return label.isEmpty ? '—' : label;
  }

  /// "₹500 – ₹10,000", "From ₹500", "Up to ₹10,000" or null when no limits are set.
  String? get amountRange => rangeLabel(minAmount, maxAmount, (v) => Fmt.money(v, compact: true));

  String? get weightRange => rangeLabel(minWeight, maxWeight, Fmt.grams);

  String get feeLabel => '${trimNumber(convenienceFeePercent)}%';
}

String? rangeLabel(double min, double max, String Function(double value) f) {
  if (min > 0 && max > 0) return min == max ? f(min) : '${f(min)} – ${f(max)}';
  if (min > 0) return 'From ${f(min)}';
  if (max > 0) return 'Up to ${f(max)}';
  return null;
}

/// 2 → "2", 2.5 → "2.5", 2.25 → "2.25".
String trimNumber(double v) {
  if (v == v.roundToDouble()) return v.toStringAsFixed(0);
  return v.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
}
