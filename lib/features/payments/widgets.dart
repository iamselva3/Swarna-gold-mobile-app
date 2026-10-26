import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/network/api_client.dart';
import '../../core/ui/ui.dart';

/// Inline banner for flow messages (rate changes, overdue notes, errors).
/// Announced to screen readers when it appears.
class Notice extends StatelessWidget {
  const Notice({super.key, required this.message, this.title, this.tone = Tone.caution, this.action});

  final String message;
  final String? title;
  final Tone tone;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, icon) = switch (tone) {
      Tone.negative => (AppColors.negativeWash, AppColors.negative, Icons.error_outline_rounded),
      Tone.positive => (AppColors.positiveWash, AppColors.positive, Icons.check_circle_outline_rounded),
      Tone.gold => (AppColors.goldWash, AppColors.goldDeep, Icons.info_outline_rounded),
      Tone.neutral => (AppColors.neutralWash, AppColors.inkSecondary, Icons.info_outline_rounded),
      Tone.caution => (AppColors.cautionWash, AppColors.caution, Icons.info_outline_rounded),
    };
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, Space.sm),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Radii.md)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(top: 1), child: Icon(icon, size: 20, color: fg)),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (title != null) ...[
                Text(title!, style: AppText.smallStrong.copyWith(color: fg)),
                const SizedBox(height: 2),
              ],
              Text(message, style: AppText.small.copyWith(color: fg, fontWeight: FontWeight.w600)),
              if (action != null) ...[const SizedBox(height: Space.xxs), action!],
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Accepts a plain decimal number with at most [decimals] fractional digits
/// and [maxWhole] whole digits. Anything else keeps the previous value, so the
/// caret never jumps and pasted text cannot smuggle in separators.
class DecimalInputFormatter extends TextInputFormatter {
  DecimalInputFormatter({this.decimals = 2, this.maxWhole = 7})
      : _pattern = RegExp('^\\d{0,$maxWhole}(\\.\\d{0,$decimals})?\$');

  final int decimals;
  final int maxWhole;
  final RegExp _pattern;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty || _pattern.hasMatch(newValue.text)) return newValue;
    return oldValue;
  }
}

/// Large numeric input with a fixed prefix (₹) or suffix (g).
class AmountField extends StatelessWidget {
  const AmountField({
    super.key,
    required this.controller,
    required this.label,
    required this.onChanged,
    this.prefix,
    this.suffix,
    this.decimals = 2,
    this.helper,
    this.error,
    this.enabled = true,
    this.focusNode,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final ValueChanged<String> onChanged;
  final String? prefix;
  final String? suffix;
  final int decimals;
  final String? helper;
  final String? error;
  final bool enabled;
  final FocusNode? focusNode;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final big = AppText.amountL;
    return TextField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.done,
      inputFormatters: [DecimalInputFormatter(decimals: decimals)],
      style: big,
      decoration: InputDecoration(
        labelText: label,
        hintText: '0',
        hintStyle: big.copyWith(color: AppColors.inkTertiary, fontWeight: FontWeight.w600),
        prefixText: prefix == null ? null : '$prefix ',
        prefixStyle: big.copyWith(color: AppColors.inkSecondary),
        suffixText: suffix,
        suffixStyle: AppText.body.copyWith(color: AppColors.inkSecondary, fontWeight: FontWeight.w700),
        helperText: error == null ? helper : null,
        helperMaxLines: 3,
        helperStyle: AppText.caption,
        errorText: error,
        errorMaxLines: 3,
      ),
    );
  }
}

/// Where the Pay step is up to.
enum PayPhase { checkingRate, creatingOrder, inGateway, failed }

/// Body of the "Pay" step: a short summary and either the current phase or
/// the reason the order could not be created.
class PayStepView extends StatelessWidget {
  const PayStepView({
    super.key,
    required this.title,
    required this.totalLabel,
    required this.phase,
    this.rows = const [],
    this.error,
  });

  final String title;
  final String totalLabel;
  final PayPhase phase;
  final List<Widget> rows;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final (heading, detail) = switch (phase) {
      PayPhase.checkingRate => ('Confirming today’s rate…', 'Making sure you pay at the current rate.'),
      PayPhase.creatingOrder => ('Creating a secure payment order…', 'This takes a moment. Please keep the app open.'),
      PayPhase.inGateway => (
          'Complete the payment on the secure page',
          'When you are done, we will confirm the payment with the bank.'
        ),
      PayPhase.failed => ('Payment not started', ''),
    };

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('TOTAL PAYABLE', style: AppText.overline),
          const SizedBox(height: Space.xxs),
          Text(totalLabel, style: AppText.amountXL),
          const SizedBox(height: Space.xxs),
          Text(title, style: AppText.small),
          if (rows.isNotEmpty) ...[
            const SizedBox(height: Space.sm),
            const Divider(),
            const SizedBox(height: Space.xs),
            ...rows,
          ],
        ]),
      ),
      const SizedBox(height: Space.lg),
      if (phase == PayPhase.failed && error != null)
        Notice(title: 'Payment not started', message: error!, tone: Tone.negative)
      else
        Semantics(
          liveRegion: true,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            const SizedBox(width: Space.sm),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(heading, style: AppText.heading),
                if (detail.isNotEmpty) ...[
                  const SizedBox(height: Space.xxs),
                  Text(detail, style: AppText.small),
                ],
              ]),
            ),
          ]),
        ),
      const SizedBox(height: Space.lg),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.lock_outline_rounded, size: 16, color: AppColors.inkTertiary),
        const SizedBox(width: Space.xs),
        Expanded(
          child: Text(
            'Payments are processed by Cashfree Payments. Card and UPI details are entered on their secure page, '
            'never in this app.',
            style: AppText.caption,
          ),
        ),
      ]),
    ]);
  }
}

/// The message for a failed order creation. No order means the payment page
/// never opened, so the customer cannot have been charged — say so plainly.
String orderNotCreatedMessage(Object error) {
  final base = errorMessage(error);
  if (error is ApiException && base.toLowerCase().contains('charged')) return base;
  return '$base You have not been charged.';
}

/// "4 of 12", or "4" when the plan has no fixed number of instalments.
String instalmentLabel(int number, int total) => total > 0 ? '$number of $total' : '$number';

/// Fee rows read better as "None" than "₹0.00".
String feeLabel(double fee) => fee <= 0 ? 'None' : Fmt.money(fee);
