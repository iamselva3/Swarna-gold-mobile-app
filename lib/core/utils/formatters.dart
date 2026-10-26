import 'package:intl/intl.dart';

/// Display formatting for money, weight and dates (Indian conventions).
class Fmt {
  Fmt._();

  static final NumberFormat _inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
  static final NumberFormat _inrWhole = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
  static final DateFormat _date = DateFormat('d MMM yyyy');
  static final DateFormat _dateTime = DateFormat('d MMM yyyy, h:mm a');
  static final DateFormat _time = DateFormat('h:mm a');

  /// ₹1,23,456.50 — whole rupees drop the paise when [compact] is true.
  static String money(num? value, {bool compact = false}) {
    final v = value ?? 0;
    if (compact && v == v.roundToDouble()) return _inrWhole.format(v);
    return _inr.format(v);
  }

  /// Gold weight in grams, three decimals (milligram precision).
  static String grams(num? value) => '${(value ?? 0).toStringAsFixed(3)} g';

  static String date(DateTime? value) => value == null ? '—' : _date.format(value.toLocal());

  static String dateTime(DateTime? value) => value == null ? '—' : _dateTime.format(value.toLocal());

  static String time(DateTime? value) => value == null ? '—' : _time.format(value.toLocal());

  /// "Today, 10:42 AM" / "Yesterday, …" / "12 Oct 2026, …".
  static String relativeDateTime(DateTime? value) {
    if (value == null) return '—';
    final local = value.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today, ${_time.format(local)}';
    if (diff == 1) return 'Yesterday, ${_time.format(local)}';
    return _dateTime.format(local);
  }

  /// Masks a mobile number for display: 90••••0001.
  static String maskedMobile(String mobile) {
    if (mobile.length < 6) return mobile;
    return '${mobile.substring(0, 2)}${'•' * (mobile.length - 6)}${mobile.substring(mobile.length - 4)}';
  }
}

/// Lenient parsing for loosely typed API payloads.
class Parse {
  Parse._();

  static double number(dynamic v, [double fallback = 0]) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.trim()) ?? fallback;
    return fallback;
  }

  static int integer(dynamic v, [int fallback = 0]) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v.trim()) ?? double.tryParse(v.trim())?.toInt() ?? fallback;
    return fallback;
  }

  static String text(dynamic v, [String fallback = '']) {
    if (v == null) return fallback;
    final s = v.toString().trim();
    return s.isEmpty || s == 'null' ? fallback : s;
  }

  static String? id(dynamic v) {
    if (v == null) return null;
    if (v is Map) return v['_id']?.toString();
    final s = v.toString();
    return s.isEmpty ? null : s;
  }

  /// ISO timestamps and the backend's "dd-MM-yyyy" maturity dates.
  static DateTime? date(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    if (s.isEmpty || s == 'null') return null;
    final iso = DateTime.tryParse(s);
    if (iso != null) return iso;
    final dmy = RegExp(r'^(\d{1,2})[-/](\d{1,2})[-/](\d{4})$').firstMatch(s);
    if (dmy != null) {
      return DateTime(int.parse(dmy.group(3)!), int.parse(dmy.group(2)!), int.parse(dmy.group(1)!));
    }
    return null;
  }

  static Map<String, dynamic> map(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : const {};

  static List<Map<String, dynamic>> list(dynamic v) =>
      v is List ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : const [];
}
