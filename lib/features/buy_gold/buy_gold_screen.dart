import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/data/models.dart';
import '../../core/data/providers.dart';
import '../../core/ui/ui.dart';
import '../payments/checkout.dart';
import '../payments/widgets.dart';

/// Buy digital gold in three steps: amount, review, pay.
///
/// The rate is locked when the customer reaches Review and re-checked against
/// the backend right before the order is created; if it moved, the customer
/// confirms again. Nothing is credited until the backend confirms the payment.
class BuyGoldScreen extends ConsumerStatefulWidget {
  const BuyGoldScreen({super.key});

  @override
  ConsumerState<BuyGoldScreen> createState() => _BuyGoldScreenState();
}

enum _Step { amount, review, pay }

class _BuyGoldScreenState extends ConsumerState<BuyGoldScreen> {
  static const double _defaultMin = 100;
  static const double _defaultMax = 200000;
  static const List<double> _quickAmounts = [500, 1000, 2000, 5000];
  static const List<String> _labels = ['Amount', 'Review', 'Pay'];

  final _amountCtrl = TextEditingController();
  final _gramsCtrl = TextEditingController();

  _Step _step = _Step.amount;
  bool _byGrams = false;
  bool _showErrors = false;

  // Locked when the customer continues to Review.
  MetalRate? _locked;
  DateTime? _lockedAt;
  double _amount = 0;
  bool _acknowledged = false;

  // Pay step.
  bool _submitting = false;
  PayPhase _phase = PayPhase.checkingRate;
  String? _payError;

  /// The order for the current attempt. Created once per Pay tap and cleared
  /// only when the customer returns to Review after a failed attempt.
  PaymentOrder? _order;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _gramsCtrl.dispose();
    super.dispose();
  }

  // ── Rules ──────────────────────────────────────────────────────────────────

  double _min(SchemeDetail s) => s.minAmount > 0 ? s.minAmount : _defaultMin;
  double _max(SchemeDetail s) => s.maxAmount > 0 ? s.maxAmount : _defaultMax;

  static double _round2(double v) => double.parse(v.toStringAsFixed(2));

  static bool _rateMoved(MetalRate a, MetalRate b) => (a.rate - b.rate).abs() >= 0.005;

  MetalRate? _rateFor(RateBoard? board, SchemeDetail scheme) {
    if (board == null) return null;
    return board.forPurity(scheme.purityId) ?? board.primaryGold;
  }

  /// Rupee value of what is typed, in either mode.
  double? _entered(MetalRate? rate) {
    if (_byGrams) {
      final grams = double.tryParse(_gramsCtrl.text);
      if (grams == null || rate == null) return null;
      return _round2(grams * rate.rate);
    }
    return double.tryParse(_amountCtrl.text);
  }

  String? _problem(double? amount, SchemeDetail scheme) {
    if (amount == null || amount <= 0) return _byGrams ? 'Enter the weight you want to buy' : 'Enter an amount';
    final prefix = _byGrams ? 'That is ${Fmt.money(amount)}. ' : '';
    if (amount < _min(scheme)) return '${prefix}The minimum purchase is ${Fmt.money(_min(scheme), compact: true)}';
    if (amount > _max(scheme)) {
      return '${prefix}The maximum per purchase is ${Fmt.money(_max(scheme), compact: true)}';
    }
    return null;
  }

  String _metalLabel(SchemeDetail scheme, MetalRate? rate) {
    final label = [scheme.purity, scheme.metal].where((s) => s.trim().isNotEmpty).join(' ');
    if (label.isNotEmpty) return label;
    return rate?.label ?? 'Gold';
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  void _switchMode(bool grams, MetalRate? rate) {
    if (grams == _byGrams) return;
    setState(() {
      if (rate != null) {
        if (grams) {
          final amount = double.tryParse(_amountCtrl.text);
          _gramsCtrl.text = amount != null && amount > 0 ? (amount / rate.rate).toStringAsFixed(3) : '';
        } else {
          final weight = double.tryParse(_gramsCtrl.text);
          _amountCtrl.text = weight != null && weight > 0 ? (weight * rate.rate).toStringAsFixed(2) : '';
        }
      }
      _byGrams = grams;
    });
  }

  void _setQuickAmount(double value) {
    final text = value.toStringAsFixed(0);
    _amountCtrl.value = TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
    setState(() {});
  }

  void _continue(SchemeDetail scheme, MetalRate rate) {
    final amount = _entered(rate);
    if (_problem(amount, scheme) != null) {
      setState(() => _showErrors = true);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _locked = rate;
      _lockedAt = DateTime.now();
      _amount = amount!;
      _acknowledged = false;
      _step = _Step.review;
    });
  }

  /// The customer accepts a rate that changed while they were reviewing.
  void _acceptRate(SchemeDetail scheme, MetalRate current) {
    var amount = _amount;
    if (_byGrams) {
      final grams = double.tryParse(_gramsCtrl.text) ?? 0;
      amount = _round2(grams * current.rate);
    }
    final outOfRange = _problem(amount, scheme) != null;
    setState(() {
      _locked = current;
      _lockedAt = DateTime.now();
      _acknowledged = false;
      if (outOfRange) {
        _step = _Step.amount;
        _showErrors = true;
      } else {
        _amount = amount;
      }
    });
  }

  Future<void> _pay(SchemeDetail scheme) async {
    final locked = _locked;
    if (_submitting || locked == null) return;
    setState(() {
      _submitting = true;
      _payError = null;
      _phase = PayPhase.checkingRate;
      _step = _Step.pay;
    });

    final fee = scheme.convenienceFeeFor(_amount);
    final PaymentOrder order;
    try {
      var existing = _order;
      if (existing == null) {
        // Confirm the rate is still today's rate before committing to it.
        final board = await ref.refresh(ratesProvider.future);
        if (!mounted) return;
        final current = _rateFor(board, scheme);
        if (current == null) {
          _failPay('Today’s gold rate is not available right now, so purchases are paused. '
              'You have not been charged.');
          return;
        }
        if (_rateMoved(current, locked)) {
          // Review shows the change and asks for a fresh confirmation.
          setState(() {
            _submitting = false;
            _acknowledged = false;
            _step = _Step.review;
          });
          return;
        }

        setState(() => _phase = PayPhase.creatingOrder);
        existing = await ref.read(repositoryProvider).createDigiGoldOrder(
              scheme: scheme,
              amount: _amount,
              metalRate: locked.rate,
              convenienceFee: fee,
            );
        _order = existing;
      }
      order = existing;
    } catch (e) {
      if (mounted) _failPay(orderNotCreatedMessage(e));
      return;
    }
    if (!mounted) return;

    setState(() => _phase = PayPhase.inGateway);
    final exit = await checkoutAndVerify(
      context,
      order: order,
      title: 'Digital gold purchase',
      amountLabel: Fmt.money(_amount + fee),
      details: [
        ('Plan', scheme.name),
        ('Gold amount', Fmt.money(_amount)),
        ('Rate per gram', Fmt.money(locked.rate)),
        ('Estimated weight', Fmt.grams(_amount / locked.rate)),
        if (fee > 0) ('Convenience fee', Fmt.money(fee)),
      ],
      successNote: 'Gold is credited to your account at the confirmed rate. It can take a few minutes to appear '
          'in your holdings.',
      invalidateOnPaid: [holdingsProvider],
    );
    if (!mounted) return;

    if (exit == PaymentExit.backToReview) {
      setState(() {
        _order = null;
        _submitting = false;
        _acknowledged = false;
        _step = _Step.review;
      });
    } else {
      // Closes the flow; `true` tells the opener the payment was confirmed.
      Navigator.of(context).pop(exit == PaymentExit.paid);
    }
  }

  void _failPay(String message) {
    setState(() {
      _submitting = false;
      _payError = message;
      _phase = PayPhase.failed;
    });
  }

  void _back() {
    if (_submitting) {
      showAppSnack(context, 'Please wait while your payment is set up.');
      return;
    }
    setState(() {
      _step = switch (_step) {
        _Step.pay => _Step.review,
        _Step.review || _Step.amount => _Step.amount,
      };
    });
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final schemeAsync = ref.watch(digiGoldSchemeProvider);
    final ratesAsync = ref.watch(ratesProvider);

    return PopScope(
      canPop: _step == _Step.amount && !_submitting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        resizeToAvoidBottomInset: true,
        appBar: AppBar(title: const Text('Buy gold')),
        body: schemeAsync.when(
          skipLoadingOnRefresh: true,
          skipLoadingOnReload: true,
          loading: () => const _AmountSkeleton(),
          error: (e, _) => Center(
            child: SingleChildScrollView(
              child: ErrorView(error: e, onRetry: () => ref.invalidate(digiGoldSchemeProvider)),
            ),
          ),
          data: (scheme) {
            if (scheme == null || !scheme.active) {
              return const Center(
                child: SingleChildScrollView(
                  child: EmptyView(
                    icon: Icons.toll_outlined,
                    title: 'Digital gold is not available right now',
                    message: 'Purchases will open here when the jeweller makes digital gold available. '
                        'Please check again later.',
                  ),
                ),
              );
            }
            return _flow(scheme, ratesAsync);
          },
        ),
      ),
    );
  }

  Widget _flow(SchemeDetail scheme, AsyncValue<RateBoard> ratesAsync) {
    final rate = _rateFor(ratesAsync.valueOrNull, scheme);

    final (Widget body, Widget action, Widget? note) = switch (_step) {
      _Step.amount => (
          _amountStep(scheme, ratesAsync, rate),
          PrimaryButton(label: 'Continue', onPressed: rate == null ? null : () => _continue(scheme, rate)),
          null,
        ),
      _Step.review => _reviewStep(scheme, rate),
      _Step.pay => _payStep(scheme),
    };

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xs, Space.gutter, Space.md),
        child: StepIndicator(current: _step.index, labels: _labels),
      ),
      Expanded(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.xl),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: KeyedSubtree(key: ValueKey(_step), child: body),
          ),
        ),
      ),
      BottomActionBar(note: note, child: action),
    ]);
  }

  // Step 1 — Amount

  Widget _amountStep(SchemeDetail scheme, AsyncValue<RateBoard> ratesAsync, MetalRate? rate) {
    final amount = _entered(rate);
    final typed = _byGrams ? _gramsCtrl.text.isNotEmpty : _amountCtrl.text.isNotEmpty;
    final problem = _problem(amount, scheme);
    // Above-maximum is worth saying straight away; everything else waits for Continue.
    final showError = problem != null && (_showErrors || (typed && amount != null && amount > _max(scheme)));
    final limits = 'Min ${Fmt.money(_min(scheme), compact: true)} · Max ${Fmt.money(_max(scheme), compact: true)} '
        'per purchase';

    final Widget rateSection;
    if (rate != null) {
      final board = ratesAsync.valueOrNull;
      rateSection = _RateCard(
        label: _metalLabel(scheme, rate),
        rate: rate,
        updatedAt: rate.updatedAt ?? board?.updatedAt,
      );
    } else if (ratesAsync.isLoading) {
      rateSection = const SkeletonCard(lines: 1);
    } else if (ratesAsync.hasError) {
      rateSection = ErrorView(
        error: ratesAsync.error!,
        compact: true,
        onRetry: () => ref.invalidate(ratesProvider),
      );
    } else {
      rateSection = Notice(
        tone: Tone.negative,
        title: 'Rate not available',
        message: 'Today’s ${_metalLabel(scheme, null).toLowerCase()} rate has not been published yet, so purchases '
            'are paused. Please try again later.',
        action: TextButton(onPressed: () => ref.invalidate(ratesProvider), child: const Text('Check again')),
      );
    }

    final quick = _quickAmounts.where((v) => v >= _min(scheme) && v <= _max(scheme)).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('How much would you like to buy?', style: AppText.heading),
      const SizedBox(height: Space.xxs),
      Text(scheme.name, style: AppText.small),
      const SizedBox(height: Space.md),
      rateSection,
      const SizedBox(height: Space.lg),
      SizedBox(
        width: double.infinity,
        child: SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('Buy in ₹')),
            ButtonSegment(value: true, label: Text('Buy in grams')),
          ],
          selected: {_byGrams},
          showSelectedIcon: false,
          onSelectionChanged: rate == null ? null : (s) => _switchMode(s.first, rate),
          style: SegmentedButton.styleFrom(
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.inkSecondary,
            selectedBackgroundColor: AppColors.ink,
            selectedForegroundColor: AppColors.inkInverse,
            side: const BorderSide(color: AppColors.line),
            textStyle: AppText.smallStrong,
          ),
        ),
      ),
      const SizedBox(height: Space.md),
      if (_byGrams)
        AmountField(
          key: const ValueKey('grams'),
          controller: _gramsCtrl,
          label: 'Weight',
          suffix: 'g',
          decimals: 3,
          enabled: rate != null,
          helper: limits,
          error: showError ? problem : null,
          onChanged: (_) => setState(() {}),
          onSubmitted: rate == null ? null : (_) => _continue(scheme, rate),
        )
      else ...[
        AmountField(
          key: const ValueKey('rupees'),
          controller: _amountCtrl,
          label: 'Amount',
          prefix: '₹',
          enabled: rate != null,
          helper: limits,
          error: showError ? problem : null,
          onChanged: (_) => setState(() {}),
          onSubmitted: rate == null ? null : (_) => _continue(scheme, rate),
        ),
        if (quick.isNotEmpty) ...[
          const SizedBox(height: Space.sm),
          Wrap(spacing: Space.xs, runSpacing: Space.xs, children: [
            for (final v in quick)
              ChoiceChip(
                label: Text(Fmt.money(v, compact: true)),
                selected: amount == v,
                onSelected: rate == null ? null : (_) => _setQuickAmount(v),
              ),
          ]),
        ],
      ],
      const SizedBox(height: Space.lg),
      if (rate != null)
        _EstimateCard(
          byGrams: _byGrams,
          amount: amount,
          rate: rate,
          valid: problem == null,
          feePercent: scheme.convenienceFeePercent,
        ),
    ]);
  }

  // Step 2 — Review

  (Widget, Widget, Widget?) _reviewStep(SchemeDetail scheme, MetalRate? current) {
    final locked = _locked!;
    final fee = scheme.convenienceFeeFor(_amount);
    final total = _round2(_amount + fee);
    final moved = current != null && _rateMoved(current, locked);
    final feeText = fee > 0 && scheme.convenienceFeePercent > 0
        ? '${Fmt.money(fee)} (${_percent(scheme.convenienceFeePercent)})'
        : feeLabel(fee);

    final body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (moved) ...[
        Notice(
          title: 'The gold rate has changed',
          message: 'Today’s rate moved from ${Fmt.money(locked.rate)} to ${Fmt.money(current.rate)} per gram. '
              'Review the updated figures and confirm again.',
          action: TextButton(
            onPressed: () => _acceptRate(scheme, current),
            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(48, 40)),
            child: const Text('Use updated rate'),
          ),
        ),
        const SizedBox(height: Space.md),
      ],
      Text('Review your purchase', style: AppText.heading),
      const SizedBox(height: Space.sm),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          DetailRow('Plan', scheme.name),
          DetailRow('Metal & purity', _metalLabel(scheme, locked)),
          DetailRow('Rate per gram', Fmt.money(locked.rate)),
          DetailRow('Gold amount', Fmt.money(_amount)),
          DetailRow('Estimated weight', Fmt.grams(_amount / locked.rate)),
          DetailRow('Convenience fee', feeText),
          const Padding(padding: EdgeInsets.symmetric(vertical: Space.xs), child: Divider()),
          DetailRow('Total payable', Fmt.money(total), emphasize: true),
        ]),
      ),
      const SizedBox(height: Space.xs),
      Text('Rate locked at ${Fmt.time(_lockedAt)} for this review.', style: AppText.caption),
      if (scheme.terms.trim().isNotEmpty) ...[
        const SizedBox(height: Space.md),
        _TermsCard(terms: scheme.terms.trim()),
      ],
      const SizedBox(height: Space.md),
      CheckboxListTile(
        value: _acknowledged,
        onChanged: moved ? null : (v) => setState(() => _acknowledged = v ?? false),
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: EdgeInsets.zero,
        dense: false,
        activeColor: AppColors.ink,
        title: Text(
          'I understand gold is credited at the confirmed rate after the payment succeeds.',
          style: AppText.small.copyWith(color: AppColors.ink),
        ),
      ),
    ]);

    final action = PrimaryButton(
      label: 'Pay ${Fmt.money(total)}',
      onPressed: _acknowledged && !moved && !_submitting ? () => _pay(scheme) : null,
    );
    final note = Text('You will complete the payment on a secure payment page.',
        style: AppText.caption, textAlign: TextAlign.center);
    return (body, action, note);
  }

  // Step 3 — Pay

  (Widget, Widget, Widget?) _payStep(SchemeDetail scheme) {
    final locked = _locked!;
    final fee = scheme.convenienceFeeFor(_amount);
    final total = _round2(_amount + fee);

    final body = PayStepView(
      title: scheme.name,
      totalLabel: Fmt.money(total),
      phase: _payError != null ? PayPhase.failed : _phase,
      error: _payError,
      rows: [
        DetailRow('Gold amount', Fmt.money(_amount)),
        DetailRow('Estimated weight', Fmt.grams(_amount / locked.rate)),
        DetailRow('Rate per gram', Fmt.money(locked.rate)),
      ],
    );

    final Widget action = _submitting || _payError == null
        ? PrimaryButton(label: 'Pay ${Fmt.money(total)}', loading: true, onPressed: null)
        : Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            PrimaryButton(label: 'Try again', icon: Icons.refresh_rounded, onPressed: () => _pay(scheme)),
            const SizedBox(height: Space.xs),
            SecondaryButton(label: 'Back to review', onPressed: _back),
          ]);
    return (body, action, null);
  }

}

/// 1.5 → "1.5%", 2 → "2%".
String _percent(double p) {
  final fixed = p.toStringAsFixed(2);
  final trimmed = fixed.contains('.') ? fixed.replaceFirst(RegExp(r'\.?0+$'), '') : fixed;
  return '$trimmed%';
}

class _RateCard extends StatelessWidget {
  const _RateCard({required this.label, required this.rate, required this.updatedAt});

  final String label;
  final MetalRate rate;
  final DateTime? updatedAt;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('TODAY’S RATE · ${label.toUpperCase()}', style: AppText.overline),
            const SizedBox(height: Space.xxs),
            Text.rich(
              TextSpan(children: [
                TextSpan(text: Fmt.money(rate.rate), style: AppText.amountL),
                TextSpan(text: '  per gram', style: AppText.small),
              ]),
            ),
            const SizedBox(height: Space.xxs),
            Text('Updated ${Fmt.relativeDateTime(updatedAt)}', style: AppText.caption),
          ]),
        ),
        const IconTile(Icons.toll_outlined, size: 40, background: AppColors.goldWash, color: AppColors.goldDeep),
      ]),
    );
  }
}

class _EstimateCard extends StatelessWidget {
  const _EstimateCard({
    required this.byGrams,
    required this.amount,
    required this.rate,
    required this.valid,
    required this.feePercent,
  });

  final bool byGrams;
  final double? amount;
  final MetalRate rate;
  final bool valid;
  final double feePercent;

  @override
  Widget build(BuildContext context) {
    final has = amount != null && amount! > 0;
    final label = byGrams ? 'Gold amount' : 'Estimated weight';
    final value = !has ? '—' : (byGrams ? Fmt.money(amount) : Fmt.grams(amount! / rate.rate));
    return AppCard(
      color: AppColors.surfaceSunken,
      borderColor: AppColors.surfaceSunken,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text(label, style: AppText.smallStrong)),
          Text(value, style: AppText.amountM.copyWith(color: has && valid ? AppColors.ink : AppColors.inkTertiary)),
        ]),
        const SizedBox(height: Space.xxs),
        Text(
          'Estimated at today’s rate of ${Fmt.money(rate.rate)} per gram.'
          '${feePercent > 0 ? ' A ${_percent(feePercent)} convenience fee is added at review.' : ''}',
          style: AppText.caption,
        ),
      ]),
    );
  }
}

class _TermsCard extends StatelessWidget {
  const _TermsCard({required this.terms});

  final String terms;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          shape: const Border(),
          collapsedShape: const Border(),
          tilePadding: const EdgeInsets.symmetric(horizontal: Space.md),
          childrenPadding: const EdgeInsets.fromLTRB(Space.md, 0, Space.md, Space.md),
          iconColor: AppColors.inkSecondary,
          collapsedIconColor: AppColors.inkSecondary,
          title: Text('Plan terms', style: AppText.smallStrong),
          children: [
            Align(alignment: Alignment.centerLeft, child: Text(terms, style: AppText.small)),
          ],
        ),
      ),
    );
  }
}

class _AmountSkeleton extends StatelessWidget {
  const _AmountSkeleton();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      physics: NeverScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(Space.gutter, Space.xs, Space.gutter, Space.xl),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Skeleton(width: 160, height: 11),
        SizedBox(height: Space.xs),
        Skeleton(height: 4),
        SizedBox(height: Space.lg),
        Skeleton(width: 220, height: 16),
        SizedBox(height: Space.md),
        SkeletonCard(lines: 1),
        SizedBox(height: Space.lg),
        Skeleton(height: 44, radius: Radii.pill),
        SizedBox(height: Space.md),
        Skeleton(height: 60, radius: Radii.md),
        SizedBox(height: Space.sm),
        Row(children: [
          Skeleton(width: 64, height: 32, radius: Radii.pill),
          SizedBox(width: Space.xs),
          Skeleton(width: 72, height: 32, radius: Radii.pill),
          SizedBox(width: Space.xs),
          Skeleton(width: 72, height: 32, radius: Radii.pill),
        ]),
      ]),
    );
  }
}
