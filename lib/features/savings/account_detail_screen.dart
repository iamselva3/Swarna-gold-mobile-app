import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/models.dart';
import '../../core/data/providers.dart';
import '../../core/ui/ui.dart';
import '../payments/pay_installment_screen.dart';
import 'widgets/account_card.dart';

/// One savings plan: key figures, schedule, and the passbook of payments.
class AccountDetailScreen extends ConsumerStatefulWidget {
  const AccountDetailScreen({super.key, required this.account});

  final SchemeAccount account;

  @override
  ConsumerState<AccountDetailScreen> createState() => _AccountDetailScreenState();
}

class _AccountDetailScreenState extends ConsumerState<AccountDetailScreen> {
  bool _opening = false;

  String get _id => widget.account.id;

  /// The latest copy of this account from holdings, so figures update after a
  /// payment or refresh; falls back to the snapshot the screen was opened with.
  SchemeAccount _current(Holdings? holdings) {
    if (holdings != null) {
      for (final a in holdings.accounts) {
        if (a.id == _id) return a;
      }
    }
    return widget.account;
  }

  Future<void> _refresh() async {
    ref
      ..invalidate(holdingsProvider)
      ..invalidate(paymentsProvider(_id));
    try {
      await Future.wait([ref.read(paymentsProvider(_id).future), ref.read(holdingsProvider.future)]);
    } catch (_) {
      // Sections show their own error with a retry.
    }
  }

  Future<void> _pay(SchemeAccount account) async {
    if (_opening) return;
    _opening = true;
    try {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => PayInstallmentScreen(account: account)));
    } finally {
      _opening = false;
    }
    if (!mounted) return;
    ref
      ..invalidate(holdingsProvider)
      ..invalidate(paymentsProvider(_id));
  }

  @override
  Widget build(BuildContext context) {
    final account = _current(ref.watch(holdingsProvider).valueOrNull);
    final payments = ref.watch(paymentsProvider(_id));

    return Scaffold(
      appBar: AppBar(title: const Text('Plan details')),
      bottomNavigationBar: account.isOpen
          ? BottomActionBar(
              child: PrimaryButton(
                label: 'Pay instalment',
                icon: Icons.arrow_forward_rounded,
                onPressed: () => _pay(account),
              ),
            )
          : null,
      body: RefreshIndicator(
        color: AppColors.goldDeep,
        backgroundColor: AppColors.surface,
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            SliverToBoxAdapter(child: Gutter(top: Space.xs, child: _Header(account))),
            SliverToBoxAdapter(child: Gutter(top: Space.lg, child: _Figures(account))),
            SliverToBoxAdapter(child: Gutter(top: Space.sm, child: _Schedule(account))),
            const SliverToBoxAdapter(child: SectionHeader('Passbook')),
            SliverToBoxAdapter(
              child: Gutter(
                child: AsyncView<List<PaymentRecord>>(
                  value: payments,
                  compactError: true,
                  onRetry: () => ref.invalidate(paymentsProvider(_id)),
                  loading: const _PassbookSkeleton(),
                  data: (list) => list.isEmpty ? const _PassbookEmpty() : _Passbook(list),
                ),
              ),
            ),
            const SliverSafeArea(
              top: false,
              sliver: SliverToBoxAdapter(child: SizedBox(height: Space.xxl)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.account);

  final SchemeAccount account;

  @override
  Widget build(BuildContext context) {
    final a = account;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Semantics(header: true, child: Text(a.schemeName, style: AppText.title)),
      const SizedBox(height: Space.xxs),
      Text(a.numberLabel, style: AppText.tabular(AppText.small)),
      const SizedBox(height: Space.sm),
      Wrap(spacing: Space.xs, runSpacing: Space.xs, children: [
        StatusBadge(a.statusLabel, tone: a.statusTone),
        if (a.overdueInstallments > 0)
          StatusBadge(
            '${a.overdueInstallments} instalment${a.overdueInstallments == 1 ? '' : 's'} due',
            tone: Tone.caution,
          ),
      ]),
    ]);
  }
}

/// Gold saved, amount paid and instalment progress.
class _Figures extends StatelessWidget {
  const _Figures(this.account);

  final SchemeAccount account;

  @override
  Widget build(BuildContext context) {
    final a = account;
    return AppCard(
      padding: const EdgeInsets.all(Space.lg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: _KeyFigure('Gold saved', Fmt.grams(a.totalPaidWeight))),
          const SizedBox(width: Space.md),
          Expanded(child: _KeyFigure('Amount paid', Fmt.money(a.totalPaidAmount))),
        ]),
        if (a.averageRate > 0) ...[
          const SizedBox(height: Space.sm),
          Text('Average rate ${Fmt.money(a.averageRate)} per gram', style: AppText.tabular(AppText.caption)),
        ],
        const SizedBox(height: Space.lg),
        const Divider(),
        const SizedBox(height: Space.lg),
        if (a.hasSchedule) ...[
          MergeSemantics(
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Expanded(child: Text('Instalments', style: AppText.smallStrong)),
              const SizedBox(width: Space.sm),
              Flexible(
                child: Text('${a.paidInstallments} of ${a.totalInstallments} paid',
                    textAlign: TextAlign.right, style: AppText.tabular(AppText.smallStrong)),
              ),
            ]),
          ),
          const SizedBox(height: Space.sm),
          ExcludeSemantics(child: ProgressBar(a.progress)),
          const SizedBox(height: Space.xs),
          Text(
            a.remainingInstallments == 0
                ? 'All instalments paid'
                : '${a.remainingInstallments} instalment${a.remainingInstallments == 1 ? '' : 's'} remaining',
            style: AppText.caption,
          ),
        ] else
          MergeSemantics(
            child: Row(children: [
              Expanded(child: Text('Payments made', style: AppText.smallStrong)),
              const SizedBox(width: Space.sm),
              Text('${a.paidInstallments}', style: AppText.tabular(AppText.smallStrong)),
            ]),
          ),
      ]),
    );
  }
}

class _KeyFigure extends StatelessWidget {
  const _KeyFigure(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: AppText.caption),
        const SizedBox(height: Space.xxs),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: AppText.amountL),
        ),
      ]),
    );
  }
}

/// Commitment and dates.
class _Schedule extends StatelessWidget {
  const _Schedule(this.account);

  final SchemeAccount account;

  @override
  Widget build(BuildContext context) {
    final a = account;
    final commitment = a.commitmentLabel;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
      child: Column(children: [
        if (commitment != null) DetailRow(a.isFlexible ? 'Instalment range' : 'Instalment amount', commitment),
        if (a.accountName.isNotEmpty) DetailRow('Account name', a.accountName),
        DetailRow('Started', Fmt.date(a.startDate)),
        DetailRow('Matures', Fmt.date(a.maturityDate)),
        if (a.isOpen)
          DetailRow('Next due', Fmt.date(a.nextDueDate)),
      ]),
    );
  }
}

class _Passbook extends StatelessWidget {
  const _Passbook(this.payments);

  final List<PaymentRecord> payments;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: Space.md),
      child: Column(children: [
        for (var i = 0; i < payments.length; i++) ...[
          if (i > 0) const Divider(),
          _PassbookRow(payments[i]),
        ],
      ]),
    );
  }
}

class _PassbookRow extends StatelessWidget {
  const _PassbookRow(this.payment);

  final PaymentRecord payment;

  static (String, Tone) _status(PaymentState s) => switch (s) {
        PaymentState.paid => ('Paid', Tone.positive),
        PaymentState.pending => ('Awaiting confirmation', Tone.caution),
        PaymentState.failed => ('Failed', Tone.negative),
        PaymentState.other => ('Unconfirmed', Tone.neutral),
      };

  @override
  Widget build(BuildContext context) {
    final p = payment;
    final (statusLabel, tone) = _status(p.state);
    final meta = [
      if (p.installment > 0) 'Instalment ${p.installment}',
      if (p.mode.isNotEmpty) p.mode,
    ].join('  ·  ');

    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(Fmt.date(p.date), style: AppText.smallStrong),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(meta, style: AppText.caption),
                ],
                if (p.receipt.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text('Receipt ${p.receipt}', style: AppText.tabular(AppText.caption)),
                ],
              ]),
            ),
            const SizedBox(width: Space.md),
            Flexible(
              child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(Fmt.money(p.amount), style: AppText.amountM),
                ),
                const SizedBox(height: 2),
                Text(p.weight > 0 ? Fmt.grams(p.weight) : '—',
                    textAlign: TextAlign.right, style: AppText.tabular(AppText.caption)),
              ]),
            ),
          ]),
          const SizedBox(height: Space.sm),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: Space.sm,
            runSpacing: Space.xxs,
            children: [
              StatusBadge(statusLabel, tone: tone),
              if (p.metalRate > 0)
                Text('Rate ${Fmt.money(p.metalRate)}/g', style: AppText.tabular(AppText.caption)),
            ],
          ),
        ]),
      ),
    );
  }
}

class _PassbookEmpty extends StatelessWidget {
  const _PassbookEmpty();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      padding: EdgeInsets.zero,
      child: EmptyView(
        icon: Icons.receipt_long_outlined,
        title: 'No payments yet',
        message: 'Payments towards this plan appear here once they are recorded.',
      ),
    );
  }
}

class _PassbookSkeleton extends StatelessWidget {
  const _PassbookSkeleton();

  @override
  Widget build(BuildContext context) {
    const row = Padding(
      padding: EdgeInsets.symmetric(vertical: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Skeleton(width: 96, height: 13),
              SizedBox(height: Space.xs),
              Skeleton(width: 140, height: 11),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Skeleton(width: 88, height: 16),
            SizedBox(height: Space.xs),
            Skeleton(width: 56, height: 11),
          ]),
        ]),
        SizedBox(height: Space.sm),
        Row(children: [
          Skeleton(width: 52, height: 20, radius: Radii.pill),
          Spacer(),
          Skeleton(width: 100, height: 11),
        ]),
      ]),
    );
    return Semantics(
      label: 'Loading passbook',
      child: const AppCard(
        padding: EdgeInsets.symmetric(horizontal: Space.md),
        child: ExcludeSemantics(
          child: Column(children: [row, Divider(), row, Divider(), row]),
        ),
      ),
    );
  }
}
