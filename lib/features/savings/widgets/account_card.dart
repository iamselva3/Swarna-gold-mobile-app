import 'package:flutter/material.dart';

import '../../../core/data/models.dart';
import '../../../core/ui/ui.dart';

/// Display helpers shared by the account card and the account detail screen.
extension AccountDisplay on SchemeAccount {
  /// The backend reports "Pending" until staff assign an account number.
  String get numberLabel =>
      accountNumber.isEmpty || accountNumber == 'Pending' ? 'Account number pending' : 'A/c $accountNumber';

  Tone get statusTone => isOpen ? Tone.positive : Tone.neutral;

  /// Plans without a fixed schedule (e.g. digital gold) have no instalment count.
  bool get hasSchedule => totalInstallments > 0;

  bool get isFlexible => monthlyPayable <= 0 && (minAmount > 0 || maxAmount > 0);

  /// The committed instalment, or the flexible range; null when neither is known.
  String? get commitmentLabel {
    if (monthlyPayable > 0) return Fmt.money(monthlyPayable, compact: true);
    if (minAmount > 0 && maxAmount > 0) {
      return '${Fmt.money(minAmount, compact: true)} – ${Fmt.money(maxAmount, compact: true)}';
    }
    if (minAmount > 0) return 'From ${Fmt.money(minAmount, compact: true)}';
    if (maxAmount > 0) return 'Up to ${Fmt.money(maxAmount, compact: true)}';
    return null;
  }

  /// Short form for the next-due line: the fixed amount, or the minimum.
  String? get dueAmountLabel {
    if (monthlyPayable > 0) return Fmt.money(monthlyPayable, compact: true);
    if (minAmount > 0) return 'from ${Fmt.money(minAmount, compact: true)}';
    return null;
  }

  // The backend counts the current period's unpaid instalment here too, so
  // "due" is accurate where "overdue" would alarm a customer who just joined.
  String get overdueLabel => '$overdueInstallments due';
}

/// A savings plan in a list. [compact] is the Home summary; the full form is
/// used on the Savings tab.
class AccountCard extends StatelessWidget {
  const AccountCard({super.key, required this.account, required this.onTap, this.compact = false});

  final SchemeAccount account;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) => compact ? _compact() : _full();

  /// Name, number and badges; badges wrap under the number so long names and
  /// large text never collide.
  Widget _title({required bool showStatus, bool chevron = false}) {
    final a = account;
    final badges = [
      if (showStatus) StatusBadge(a.statusLabel, tone: a.statusTone),
      if (a.overdueInstallments > 0) StatusBadge(a.overdueLabel, tone: Tone.caution),
    ];
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(a.schemeName, style: AppText.heading, maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(a.numberLabel, style: AppText.tabular(AppText.caption)),
          if (badges.isNotEmpty) ...[
            const SizedBox(height: Space.xs),
            Wrap(spacing: Space.xs, runSpacing: Space.xxs, children: badges),
          ],
        ]),
      ),
      if (chevron) ...[
        const SizedBox(width: Space.xs),
        const Icon(Icons.chevron_right_rounded, color: AppColors.inkTertiary),
      ],
    ]);
  }

  Widget _compact() {
    final a = account;
    final due = a.isOpen ? a.nextDueDate : null;
    final dueAmount = a.dueAmountLabel;
    return AppCard(
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _title(showStatus: false, chevron: true),
        const SizedBox(height: Space.md),
        _ProgressBlock(account: a, trailing: '${Fmt.money(a.totalPaidAmount)} paid'),
        if (due != null) ...[
          const SizedBox(height: Space.sm),
          const Divider(),
          const SizedBox(height: Space.sm),
          MergeSemantics(
            child: Row(children: [
              const Icon(Icons.event_outlined, size: 16, color: AppColors.inkTertiary),
              const SizedBox(width: Space.xs),
              Expanded(child: Text('Next due ${Fmt.date(due)}', style: AppText.small)),
              if (dueAmount != null) ...[
                const SizedBox(width: Space.sm),
                Text(dueAmount, style: AppText.tabular(AppText.smallStrong)),
              ],
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _full() {
    final a = account;
    return AppCard(
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _title(showStatus: true),
        const SizedBox(height: Space.md),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: _Figure('Amount paid', Fmt.money(a.totalPaidAmount))),
          const SizedBox(width: Space.md),
          Expanded(child: _Figure('Gold saved', Fmt.grams(a.totalPaidWeight))),
        ]),
        const SizedBox(height: Space.md),
        _ProgressBlock(
          account: a,
          trailing: a.hasSchedule
              ? (a.remainingInstallments == 0 ? 'Completed' : '${a.remainingInstallments} remaining')
              : null,
        ),
        const SizedBox(height: Space.sm),
        const Divider(),
        const SizedBox(height: Space.sm),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: _Figure('Next due', a.isOpen ? Fmt.date(a.nextDueDate) : '—', small: true),
          ),
          const SizedBox(width: Space.md),
          Expanded(child: _Figure('Matures', Fmt.date(a.maturityDate), small: true)),
        ]),
      ]),
    );
  }
}

/// Instalment progress, or the payment count for unscheduled plans.
class _ProgressBlock extends StatelessWidget {
  const _ProgressBlock({required this.account, this.trailing});

  final SchemeAccount account;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final a = account;
    if (!a.hasSchedule) {
      final count = a.paidInstallments;
      return MergeSemantics(
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(child: Text('$count payment${count == 1 ? '' : 's'}', style: AppText.small)),
          const SizedBox(width: Space.sm),
          Flexible(
            child: Text(Fmt.grams(a.totalPaidWeight),
                textAlign: TextAlign.right, style: AppText.tabular(AppText.smallStrong)),
          ),
        ]),
      );
    }
    final summary = '${a.paidInstallments} of ${a.totalInstallments} instalments';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Semantics(label: '$summary paid', child: ExcludeSemantics(child: ProgressBar(a.progress))),
      const SizedBox(height: Space.xs),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Expanded(child: Text(summary, style: AppText.tabular(AppText.caption))),
        if (trailing != null) ...[
          const SizedBox(width: Space.sm),
          Flexible(
            child: Text(trailing!,
                textAlign: TextAlign.right,
                style: AppText.tabular(AppText.caption).copyWith(color: AppColors.inkSecondary)),
          ),
        ],
      ]),
    ]);
  }
}

class _Figure extends StatelessWidget {
  const _Figure(this.label, this.value, {this.small = false});

  final String label;
  final String value;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: AppText.caption),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: small ? AppText.tabular(AppText.smallStrong) : AppText.amountM),
        ),
      ]),
    );
  }
}

/// Mirrors [AccountCard] while holdings load.
class AccountCardSkeleton extends StatelessWidget {
  const AccountCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      child: const AppCard(
        child: ExcludeSemantics(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Skeleton(width: 170, height: 16),
            SizedBox(height: Space.xs),
            Skeleton(width: 90, height: 11),
            SizedBox(height: Space.xs),
            Skeleton(width: 56, height: 20, radius: Radii.pill),
            SizedBox(height: Space.lg),
            Skeleton(height: 6, radius: Radii.pill),
            SizedBox(height: Space.sm),
            Row(children: [
              Skeleton(width: 120, height: 11),
              Spacer(),
              Skeleton(width: 70, height: 11),
            ]),
          ]),
        ),
      ),
    );
  }
}
