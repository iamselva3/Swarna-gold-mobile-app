import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/constants/brand_config.dart';
import '../../core/data/models.dart';
import '../../core/data/providers.dart';
import '../../core/network/api_client.dart';
import '../../core/ui/ui.dart';
import '../payments/pay_installment_screen.dart';
import 'plan_format.dart';

enum _AmountMode {
  /// Pick one of the plan's fixed amounts.
  choose,

  /// Enter one amount within the plan's limits.
  enter,

  /// No commitment; each instalment can differ within the range.
  flexible,
}

/// Joins an instalment plan: Amount → Review → Confirm. The account exists
/// only once the backend confirms it; nothing is charged here.
class EnrolScreen extends ConsumerStatefulWidget {
  const EnrolScreen({super.key, required this.scheme});

  final SchemeDetail scheme;

  @override
  ConsumerState<EnrolScreen> createState() => _EnrolScreenState();
}

class _EnrolScreenState extends ConsumerState<EnrolScreen> {
  static const _labels = ['Amount', 'Review', 'Confirm'];
  static const _noBranch =
      'Your account isn’t linked to a branch yet, so plans can’t be opened in the app. Please contact support.';

  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _name = TextEditingController();
  final _scroll = ScrollController();

  int _step = 0;
  double? _chosen;
  String? _chooseError;
  bool _nameEdited = false;
  bool _acceptedTerms = false;
  bool _submitting = false;
  String? _error;
  String? _successMessage;

  SchemeDetail get _s => widget.scheme;

  _AmountMode get _mode {
    if (!_s.commitsToAmount) return _AmountMode.flexible;
    return _s.fixedAmounts.isNotEmpty ? _AmountMode.choose : _AmountMode.enter;
  }

  double? get _committed => switch (_mode) {
        _AmountMode.choose => _chosen,
        _AmountMode.enter => double.tryParse(_amount.text.trim()),
        _AmountMode.flexible => null,
      };

  @override
  void initState() {
    super.initState();
    final profile = ref.read(profileProvider).valueOrNull;
    final fromProfile = profile?.fullName ?? '';
    _name.text = fromProfile.isNotEmpty ? fromProfile : (ref.read(sessionProvider)?.displayName ?? '');
  }

  @override
  void dispose() {
    _amount.dispose();
    _name.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _goTo(int step) {
    setState(() {
      _step = step;
      _error = null;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _continueFromAmount() {
    setState(() => _chooseError = null);
    final formOk = _formKey.currentState?.validate() ?? false;
    if (_mode == _AmountMode.choose && _chosen == null) {
      setState(() => _chooseError = 'Choose an instalment amount to continue');
    }
    if (!formOk || _chooseError != null) return;
    FocusScope.of(context).unfocus();
    _goTo(1);
  }

  String? _validateAmount(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Enter your instalment amount';
    final amount = double.tryParse(text);
    if (amount == null || amount <= 0) return 'Enter a valid amount';
    if (_s.minAmount > 0 && amount < _s.minAmount) return 'The minimum is ${Fmt.money(_s.minAmount, compact: true)}';
    if (_s.maxAmount > 0 && amount > _s.maxAmount) return 'The maximum is ${Fmt.money(_s.maxAmount, compact: true)}';
    return null;
  }

  String? _validateName(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter the account holder’s name';
    if (v.length < 2) return 'Enter the full name';
    return null;
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (_s.terms.isNotEmpty && !_acceptedTerms) {
      setState(() => _error = 'Please confirm that you have read the plan terms.');
      return;
    }
    final session = ref.read(sessionProvider);
    final branchId = session?.branchId;
    if (session == null || branchId == null || branchId.isEmpty) {
      setState(() => _error = _noBranch);
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final message = await ref.read(repositoryProvider).openAccount(
            scheme: _s,
            customerId: session.customerId,
            branchId: branchId,
            accountName: _name.text.trim(),
            committedAmount: _committed,
          );
      ref.invalidate(holdingsProvider);
      if (mounted) setState(() => _successMessage = message);
    } on ApiException catch (e) {
      if (e.kind == ApiFailure.timeout || e.kind == ApiFailure.server) {
        // The request may have reached the backend; a blind retry could open a
        // second account, so point the customer to Savings first.
        ref.invalidate(holdingsProvider);
        if (mounted) {
          setState(() => _error = 'We couldn’t confirm whether your account was opened. '
              'Check the Savings tab before trying again.');
        }
      } else if (mounted) {
        setState(() => _error = e.message);
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'We couldn’t open the account. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _finish({required bool payNow}) {
    final navigator = Navigator.of(context);
    navigator.popUntil((route) => route.isFirst);
    if (payNow) navigator.push(MaterialPageRoute(builder: (_) => const PayInstallmentScreen()));
  }

  @override
  Widget build(BuildContext context) {
    // Fill the holder name from the profile if it arrives after the screen opened.
    ref.listen<AsyncValue<CustomerProfile>>(profileProvider, (_, next) {
      final name = next.valueOrNull?.fullName ?? '';
      if (!_nameEdited && name.isNotEmpty && _name.text != name) _name.text = name;
    });

    final done = _successMessage != null;

    return PopScope(
      canPop: !_submitting && (_step == 0 || done),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _submitting || done || _step == 0) return;
        _goTo(_step - 1);
      },
      child: Scaffold(
        appBar: AppBar(title: Text(done ? 'Account opened' : 'Join plan')),
        body: done ? _buildSuccess() : _buildFlow(),
      ),
    );
  }

  Widget _buildFlow() {
    final Widget content = switch (_step) {
      0 => _amountStep(),
      1 => _reviewStep(),
      _ => _confirmStep(),
    };
    final Widget action = switch (_step) {
      0 => PrimaryButton(label: 'Continue', onPressed: _continueFromAmount),
      1 => PrimaryButton(label: 'Continue', onPressed: () => _goTo(2)),
      _ => PrimaryButton(label: 'Open account', loading: _submitting, onPressed: _submit),
    };

    return Column(children: [
      Expanded(
        child: SingleChildScrollView(
          controller: _scroll,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xs, Space.gutter, Space.xl),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            StepIndicator(current: _step, labels: _labels),
            const SizedBox(height: Space.lg),
            content,
          ]),
        ),
      ),
      BottomActionBar(
        note: _step == 2 ? Text('No payment is taken now.', style: AppText.caption, textAlign: TextAlign.center) : null,
        child: action,
      ),
    ]);
  }

  // ── Step 1: amount and holder name ─────────────────────────────────────────

  Widget _amountStep() {
    final range = _s.amountRange;

    final Widget amount = switch (_mode) {
      _AmountMode.choose => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Choose your instalment amount', style: AppText.smallStrong),
          const SizedBox(height: Space.xxs),
          Text('You pay this amount every instalment.', style: AppText.small),
          const SizedBox(height: Space.sm),
          Wrap(spacing: Space.xs, runSpacing: Space.xs, children: [
            for (final value in _s.fixedAmounts) _amountChip(value),
          ]),
          if (_chooseError != null) ...[
            const SizedBox(height: Space.xs),
            Semantics(
              liveRegion: true,
              child: Text(_chooseError!,
                  style: AppText.caption.copyWith(color: AppColors.negative, fontWeight: FontWeight.w600)),
            ),
          ],
        ]),
      _AmountMode.enter => TextFormField(
          controller: _amount,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(9)],
          style: AppText.tabular(AppText.body),
          decoration: InputDecoration(
            labelText: 'Instalment amount',
            helperText: range == null ? 'You pay this amount every instalment.' : 'Allowed: $range',
            helperStyle: AppText.caption,
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: Space.md, right: Space.xs),
              child: Text('₹', style: AppText.body.copyWith(color: AppColors.inkSecondary)),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
          ),
          validator: _validateAmount,
        ),
      _AmountMode.flexible => AppCard(
          color: AppColors.surfaceSunken,
          borderColor: AppColors.surfaceSunken,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.tune_rounded, size: 20, color: AppColors.goldDeep),
            const SizedBox(width: Space.sm),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Flexible amount', style: AppText.smallStrong),
                const SizedBox(height: Space.xxs),
                Text(
                  range == null
                      ? 'You don’t commit to an amount now. You decide how much to pay each instalment.'
                      : 'You don’t commit to an amount now. Each instalment can be any amount within $range.',
                  style: AppText.small,
                ),
              ]),
            ),
          ]),
        ),
    };

    return Form(
      key: _formKey,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Semantics(header: true, child: Text(_s.name, style: AppText.headline)),
        const SizedBox(height: Space.xxs),
        Text('${_s.frequencyLabel} plan'
            '${_s.totalInstallments > 0 ? ' · ${_s.totalInstallments} instalments' : ''}',
            style: AppText.small),
        const SizedBox(height: Space.xl),
        amount,
        const SizedBox(height: Space.xl),
        TextFormField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.name],
          inputFormatters: [LengthLimitingTextInputFormatter(60)],
          decoration: InputDecoration(
            labelText: 'Account holder name',
            helperText: 'The name the account is opened in.',
            helperStyle: AppText.caption,
          ),
          onChanged: (_) => _nameEdited = true,
          validator: _validateName,
          onFieldSubmitted: (_) => _continueFromAmount(),
        ),
      ]),
    );
  }

  Widget _amountChip(double value) {
    final selected = _chosen == value;
    return ChoiceChip(
      label: Text(Fmt.money(value, compact: true)),
      selected: selected,
      onSelected: (_) => setState(() {
        _chosen = value;
        _chooseError = null;
      }),
      labelStyle: AppText.tabular(AppText.smallStrong).copyWith(
        fontSize: 15,
        color: selected ? AppColors.inkInverse : AppColors.ink,
      ),
      labelPadding: const EdgeInsets.symmetric(horizontal: Space.xs, vertical: 2),
      backgroundColor: AppColors.surface,
      selectedColor: AppColors.ink,
      side: BorderSide(color: selected ? AppColors.ink : AppColors.lineStrong),
      showCheckmark: false,
    );
  }

  // ── Step 2: review ─────────────────────────────────────────────────────────

  String get _amountSummary {
    final committed = _committed;
    if (committed != null) return '${Fmt.money(committed, compact: true)} per instalment';
    final range = _s.amountRange;
    return range == null ? 'Flexible' : 'Flexible · $range';
  }

  String _branchLabel() {
    final profile = ref.watch(profileProvider);
    return profile.when(
      data: (p) => p.branchName ?? '—',
      loading: () => 'Loading…',
      error: (_, __) => '—',
    );
  }

  Widget _reviewStep() {
    final s = _s;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Semantics(header: true, child: Text('Review your plan', style: AppText.headline)),
      const SizedBox(height: Space.xxs),
      Text('Check the details before you continue.', style: AppText.small),
      const SizedBox(height: Space.lg),
      AppCard(
        padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.xs),
        child: Column(children: [
          DetailRow('Plan', s.name),
          DetailRow('Instalments', s.totalInstallments > 0 ? '${s.totalInstallments}' : '—'),
          DetailRow('Frequency', s.frequencyLabel),
          if (s.maturityLabel != null) DetailRow('Maturity period', s.maturityLabel!),
          DetailRow(_committed != null ? 'Committed amount' : 'Instalment amount', _amountSummary),
          DetailRow('Account holder', _name.text.trim()),
          DetailRow('Branch', _branchLabel()),
        ]),
      ),
      if (s.convenienceFeePercent > 0) ...[
        const SizedBox(height: Space.sm),
        Text('A ${s.feeLabel} convenience fee is added to each online payment.', style: AppText.caption),
      ],
      const SizedBox(height: Space.sm),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => _goTo(0),
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: const Text('Change details'),
        ),
      ),
    ]);
  }

  // ── Step 3: confirm ────────────────────────────────────────────────────────

  Widget _confirmStep() {
    final s = _s;
    final branch = ref.watch(profileProvider).valueOrNull?.branchName;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Semantics(header: true, child: Text('Confirm and open', style: AppText.headline)),
      const SizedBox(height: Space.xs),
      Text(
        'You’re opening ${s.name} in the name of ${_name.text.trim()}'
        '${branch == null ? '' : ' at $branch'}. Instalment: $_amountSummary.',
        style: AppText.bodySecondary,
      ),
      const SizedBox(height: Space.lg),
      if (s.terms.isNotEmpty)
        AppCard(
          padding: const EdgeInsets.fromLTRB(Space.md, Space.md, Space.md, Space.xs),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Plan terms', style: AppText.smallStrong),
            const SizedBox(height: Space.xs),
            Text(s.terms, style: AppText.small),
            const SizedBox(height: Space.xs),
            const Divider(),
            CheckboxListTile(
              value: _acceptedTerms,
              onChanged: _submitting
                  ? null
                  : (v) => setState(() {
                        _acceptedTerms = v ?? false;
                        if (_acceptedTerms) _error = null;
                      }),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              activeColor: AppColors.ink,
              checkColor: AppColors.inkInverse,
              title: Text('I have read and accept the plan terms', style: AppText.body),
            ),
          ]),
        )
      else
        AppCard(
          color: AppColors.surfaceSunken,
          borderColor: AppColors.surfaceSunken,
          child: Text(
            'Your account is opened with ${BrandConfig.brandDisplayName} under the rules shown on the plan page.',
            style: AppText.small,
          ),
        ),
      if (_error != null) ...[
        const SizedBox(height: Space.md),
        _ErrorBanner(message: _error!),
      ],
    ]);
  }

  // ── Result ─────────────────────────────────────────────────────────────────

  Widget _buildSuccess() {
    return Column(children: [
      Expanded(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: Space.xxl, vertical: Space.xl),
            child: Semantics(
              liveRegion: true,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const IconTile(
                  Icons.check_circle_outline_rounded,
                  size: 64,
                  background: AppColors.positiveWash,
                  color: AppColors.positive,
                ),
                const SizedBox(height: Space.lg),
                Text(_successMessage!, style: AppText.headline, textAlign: TextAlign.center),
                const SizedBox(height: Space.xs),
                Text(
                  'Your ${_s.name} account is in the Savings tab. '
                  'You can pay your first instalment now or later.',
                  style: AppText.bodySecondary,
                  textAlign: TextAlign.center,
                ),
              ]),
            ),
          ),
        ),
      ),
      BottomActionBar(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          PrimaryButton(label: 'Pay first instalment', onPressed: () => _finish(payNow: true)),
          const SizedBox(height: Space.sm),
          SecondaryButton(label: 'Done', onPressed: () => _finish(payNow: false)),
        ]),
      ),
    ]);
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
        decoration: BoxDecoration(color: AppColors.negativeWash, borderRadius: BorderRadius.circular(Radii.md)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.error_outline_rounded, size: 20, color: AppColors.negative),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Text(message,
                style: AppText.small.copyWith(color: AppColors.negative, fontWeight: FontWeight.w600)),
          ),
        ]),
      ),
    );
  }
}
