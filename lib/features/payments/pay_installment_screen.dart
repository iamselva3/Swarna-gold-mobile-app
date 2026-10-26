import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/data/models.dart';
import '../../core/data/providers.dart';
import '../../core/ui/ui.dart';
import 'checkout.dart';
import 'widgets.dart';

/// Pays one instalment on a savings plan.
///
/// With [account] the flow starts at Review; without it the customer first
/// picks one of their open, non-digital plans.
class PayInstallmentScreen extends ConsumerStatefulWidget {
  const PayInstallmentScreen({super.key, this.account});

  final SchemeAccount? account;

  @override
  ConsumerState<PayInstallmentScreen> createState() => _PayInstallmentScreenState();
}

enum _Stage { plan, review, pay }

class _PayInstallmentScreenState extends ConsumerState<PayInstallmentScreen> {
  final _amountCtrl = TextEditingController();

  late _Stage _stage = widget.account == null ? _Stage.plan : _Stage.review;
  SchemeAccount? _selected;
  bool _showErrors = false;

  // Pay step.
  bool _submitting = false;
  PayPhase _phase = PayPhase.creatingOrder;
  String? _payError;
  double _payAmount = 0;

  /// The order for the current attempt; cleared only when the customer goes
  /// back to Review after a failed attempt.
  PaymentOrder? _order;

  /// The account changes are not allowed once an order exists, so this is
  /// stable for the whole Pay step.
  SchemeAccount? get _account => widget.account ?? _selected;

  bool get _hasPlanStep => widget.account == null;

  List<String> get _labels => _hasPlanStep ? const ['Plan', 'Review', 'Pay'] : const ['Review', 'Pay'];

  int get _indicator => _hasPlanStep ? _stage.index : _stage.index - 1;

  _Stage get _firstStage => _hasPlanStep ? _Stage.plan : _Stage.review;

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  // ── Rules ──────────────────────────────────────────────────────────────────

  bool _isFixed(SchemeAccount a) => a.monthlyPayable > 0;

  bool _isComplete(SchemeAccount a) => a.totalInstallments > 0 && a.paidInstallments >= a.totalInstallments;

  double? _amountFor(SchemeAccount a) => _isFixed(a) ? a.monthlyPayable : double.tryParse(_amountCtrl.text);

  String? _problem(SchemeAccount a, double? amount) {
    if (_isFixed(a)) return null;
    if (amount == null || amount <= 0) return 'Enter the amount you want to pay';
    if (a.minAmount > 0 && amount < a.minAmount) {
      return 'The minimum for this plan is ${Fmt.money(a.minAmount, compact: true)}';
    }
    if (a.maxAmount > 0 && amount > a.maxAmount) {
      return 'The maximum for this plan is ${Fmt.money(a.maxAmount, compact: true)}';
    }
    return null;
  }

  String _limitsHelper(SchemeAccount a) {
    final min = a.minAmount > 0 ? Fmt.money(a.minAmount, compact: true) : null;
    final max = a.maxAmount > 0 ? Fmt.money(a.maxAmount, compact: true) : null;
    if (min != null && max != null) return 'Between $min and $max';
    if (min != null) return 'Minimum $min';
    if (max != null) return 'Up to $max';
    return 'Enter the amount for this instalment';
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  void _toReview() {
    if (_selected == null) return;
    _amountCtrl.clear();
    setState(() {
      _showErrors = false;
      _stage = _Stage.review;
    });
  }

  void _tryPay(SchemeAccount account) {
    final amount = _amountFor(account);
    if (_problem(account, amount) != null) {
      setState(() => _showErrors = true);
      return;
    }
    _pay(account, amount!);
  }

  Future<void> _pay(SchemeAccount account, double amount) async {
    if (_submitting) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _payError = null;
      _phase = PayPhase.creatingOrder;
      _payAmount = amount;
      _stage = _Stage.pay;
    });

    final PaymentOrder order;
    try {
      order = _order ??= await ref.read(repositoryProvider).createInstallmentOrder(
            accountId: account.id,
            amount: amount,
            convenienceFee: 0,
          );
    } catch (e) {
      if (mounted) _failPay(orderNotCreatedMessage(e));
      return;
    }
    if (!mounted) return;

    setState(() => _phase = PayPhase.inGateway);
    final exit = await checkoutAndVerify(
      context,
      order: order,
      title: 'Instalment payment',
      amountLabel: Fmt.money(amount),
      details: [
        ('Plan', account.schemeName),
        ('Account', account.accountNumber),
        ('Instalment', instalmentLabel(account.paidInstallments + 1, account.totalInstallments)),
      ],
      successNote: 'Your account will reflect this payment shortly. The receipt appears in the plan’s payment '
          'history once it is recorded.',
      invalidateOnPaid: [holdingsProvider, paymentsProvider(account.id)],
    );
    if (!mounted) return;

    if (exit == PaymentExit.backToReview) {
      setState(() {
        _order = null;
        _submitting = false;
        _stage = _Stage.review;
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
      _stage = switch (_stage) {
        _Stage.pay => _Stage.review,
        _Stage.review || _Stage.plan => _firstStage,
      };
    });
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final (Widget body, Widget? action) = switch (_stage) {
      _Stage.plan => _planStage(),
      _Stage.review => _reviewStage(_account!),
      _Stage.pay => _payStage(_account!),
    };

    return PopScope(
      canPop: _stage == _firstStage && !_submitting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        resizeToAvoidBottomInset: true,
        appBar: AppBar(title: const Text('Pay instalment')),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xs, Space.gutter, Space.md),
            child: StepIndicator(current: _indicator, labels: _labels),
          ),
          Expanded(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.xl),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: KeyedSubtree(key: ValueKey(_stage), child: body),
              ),
            ),
          ),
          if (action != null) BottomActionBar(child: action),
        ]),
      ),
    );
  }

  // Plan

  (Widget, Widget?) _planStage() {
    final holdings = ref.watch(holdingsProvider);
    final eligible = holdings.valueOrNull?.openAccounts.where((a) => !a.isDigital).toList();

    final body = AsyncView<Holdings>(
      value: holdings,
      onRetry: () => ref.invalidate(holdingsProvider),
      loading: const Column(children: [
        SkeletonCard(lines: 2),
        SizedBox(height: Space.sm),
        SkeletonCard(lines: 2),
        SizedBox(height: Space.sm),
        SkeletonCard(lines: 2),
      ]),
      data: (_) {
        final accounts = eligible ?? const <SchemeAccount>[];
        if (accounts.isEmpty) {
          return const EmptyView(
            icon: Icons.event_available_outlined,
            title: 'No plans awaiting payment',
            message: 'You have no open savings plans that take instalments right now.',
          );
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Which plan are you paying for?', style: AppText.heading),
          const SizedBox(height: Space.md),
          for (final a in accounts) ...[
            _AccountOption(
              account: a,
              selected: _selected?.id == a.id,
              onTap: () => setState(() => _selected = a),
            ),
            const SizedBox(height: Space.sm),
          ],
        ]);
      },
    );

    final action = (eligible == null || eligible.isEmpty)
        ? null
        : PrimaryButton(label: 'Continue', onPressed: _selected == null ? null : _toReview);
    return (body, action);
  }

  // Review

  (Widget, Widget?) _reviewStage(SchemeAccount account) {
    final fixed = _isFixed(account);
    final amount = _amountFor(account);
    final problem = _problem(account, amount);
    final typed = _amountCtrl.text.isNotEmpty;
    final overMax = !fixed && typed && amount != null && account.maxAmount > 0 && amount > account.maxAmount;
    final showError = problem != null && (_showErrors || overMax);
    final complete = _isComplete(account);
    final valid = problem == null && amount != null;
    final instalment = instalmentLabel(account.paidInstallments + 1, account.totalInstallments);

    final body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _AccountSummary(account: account),
      if (account.overdueInstallments > 0) ...[
        const SizedBox(height: Space.md),
        Notice(
          title: account.overdueInstallments == 1
              ? '1 instalment is due'
              : '${account.overdueInstallments} instalments are due',
          message: 'You can pay one instalment at a time here. For questions about pending instalments, '
              'please contact your branch.',
        ),
      ],
      if (complete) ...[
        const SizedBox(height: Space.md),
        const Notice(
          tone: Tone.neutral,
          title: 'All instalments are paid',
          message: 'There is nothing left to pay on this plan.',
        ),
      ],
      const SizedBox(height: Space.lg),
      Text('Amount', style: AppText.heading),
      const SizedBox(height: Space.sm),
      if (fixed)
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('INSTALMENT AMOUNT', style: AppText.overline),
            const SizedBox(height: Space.xxs),
            Text(Fmt.money(account.monthlyPayable), style: AppText.amountL),
            const SizedBox(height: Space.xxs),
            Text('Your committed instalment. It is fixed for this plan.', style: AppText.caption),
          ]),
        )
      else
        AmountField(
          controller: _amountCtrl,
          label: 'Instalment amount',
          prefix: '₹',
          enabled: !complete,
          helper: _limitsHelper(account),
          error: showError ? problem : null,
          onChanged: (_) => setState(() {}),
          onSubmitted: complete ? null : (_) => _tryPay(account),
        ),
      const SizedBox(height: Space.lg),
      Text('Review', style: AppText.heading),
      const SizedBox(height: Space.sm),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          DetailRow('Plan', account.schemeName),
          DetailRow('Account', account.accountNumber),
          DetailRow('Instalment', instalment),
          DetailRow('Amount', valid ? Fmt.money(amount) : '—'),
          DetailRow('Convenience fee', feeLabel(0)),
          const Padding(padding: EdgeInsets.symmetric(vertical: Space.xs), child: Divider()),
          DetailRow('Total payable', valid ? Fmt.money(amount) : '—', emphasize: true),
        ]),
      ),
      const SizedBox(height: Space.sm),
      Text('You will complete the payment on a secure payment page.', style: AppText.caption),
    ]);

    final action = PrimaryButton(
      label: valid ? 'Pay ${Fmt.money(amount)}' : 'Pay',
      onPressed: complete || _submitting ? null : () => _tryPay(account),
    );
    return (body, action);
  }

  // Pay

  (Widget, Widget?) _payStage(SchemeAccount account) {
    final body = PayStepView(
      title: account.schemeName,
      totalLabel: Fmt.money(_payAmount),
      phase: _payError != null ? PayPhase.failed : _phase,
      error: _payError,
      rows: [
        DetailRow('Account', account.accountNumber),
        DetailRow('Instalment', instalmentLabel(account.paidInstallments + 1, account.totalInstallments)),
      ],
    );

    final Widget action = _submitting || _payError == null
        ? PrimaryButton(label: 'Pay ${Fmt.money(_payAmount)}', loading: true, onPressed: null)
        : Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            PrimaryButton(
              label: 'Try again',
              icon: Icons.refresh_rounded,
              onPressed: () => _pay(account, _payAmount),
            ),
            const SizedBox(height: Space.xs),
            SecondaryButton(label: 'Back to review', onPressed: _back),
          ]);
    return (body, action);
  }
}

class _AccountOption extends StatelessWidget {
  const _AccountOption({required this.account, required this.selected, required this.onTap});

  final SchemeAccount account;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final amount = account.monthlyPayable > 0
        ? '${Fmt.money(account.monthlyPayable, compact: true)} per instalment'
        : 'Flexible amount';
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      child: AppCard(
        onTap: onTap,
        borderColor: selected ? AppColors.ink : AppColors.line,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
              size: 22,
              color: selected ? AppColors.ink : AppColors.inkTertiary,
            ),
          ),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Text(account.schemeName, style: AppText.heading)),
                if (account.overdueInstallments > 0) ...[
                  const SizedBox(width: Space.xs),
                  const StatusBadge('Due', tone: Tone.caution),
                ],
              ]),
              const SizedBox(height: 2),
              Text('Account ${account.accountNumber}', style: AppText.tabular(AppText.small)),
              const SizedBox(height: Space.sm),
              ProgressBar(account.progress),
              const SizedBox(height: Space.xs),
              Text(
                [
                  'Paid ${instalmentLabel(account.paidInstallments, account.totalInstallments)}',
                  if (account.nextDueDate != null) 'Next due ${Fmt.date(account.nextDueDate)}',
                ].join('  ·  '),
                style: AppText.caption,
              ),
              const SizedBox(height: 2),
              Text(amount, style: AppText.caption),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _AccountSummary extends StatelessWidget {
  const _AccountSummary({required this.account});

  final SchemeAccount account;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(account.schemeName, style: AppText.heading),
              const SizedBox(height: 2),
              Text('Account ${account.accountNumber}', style: AppText.tabular(AppText.small)),
            ]),
          ),
          const SizedBox(width: Space.xs),
          StatusBadge(account.statusLabel, tone: account.isOpen ? Tone.positive : Tone.neutral),
        ]),
        const SizedBox(height: Space.md),
        ProgressBar(account.progress),
        const SizedBox(height: Space.xs),
        Row(children: [
          Expanded(
            child: Text(
              'Paid ${instalmentLabel(account.paidInstallments, account.totalInstallments)}',
              style: AppText.caption,
            ),
          ),
          if (account.nextDueDate != null) Text('Next due ${Fmt.date(account.nextDueDate)}', style: AppText.caption),
        ]),
      ]),
    );
  }
}
