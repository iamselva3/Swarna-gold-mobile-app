import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/brand_config.dart';
import '../../core/data/models.dart';
import '../../core/data/providers.dart';
import '../../core/ui/ui.dart';
import '../redeem/redeem_screen.dart';

/// Rewards tab: the rewards wallet the jeweller credits (referrals and other
/// benefits) and its store redemptions.
class RewardsScreen extends ConsumerWidget {
  const RewardsScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(walletProvider);
    try {
      await ref.read(walletProvider.future);
    } catch (_) {
      // The error state below offers a retry.
    }
  }

  void _openRedeem(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RedeemScreen()));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(walletProvider);

    return TabPage(
      title: 'Rewards',
      subtitle: 'Your rewards wallet with ${BrandConfig.brandDisplayName}',
      onRefresh: () => _refresh(ref),
      slivers: overview.when(
        skipLoadingOnRefresh: true,
        skipLoadingOnReload: true,
        loading: () => const [SliverToBoxAdapter(child: _RewardsSkeleton())],
        error: (e, _) => [
          SliverToBoxAdapter(child: ErrorView(error: e, onRetry: () => ref.invalidate(walletProvider))),
        ],
        data: (data) {
          final wallet = data.wallet;
          if (wallet == null) {
            return [
              SliverToBoxAdapter(
                child: EmptyView(
                  icon: Icons.card_giftcard_outlined,
                  title: 'No rewards yet',
                  message: 'Rewards such as referral benefits are credited to your rewards wallet by '
                      '${BrandConfig.brandDisplayName}. Once they are, your balance and history appear here.',
                  action: TextButton(
                    onPressed: () => _openRedeem(context),
                    child: const Text('How redemption works'),
                  ),
                ),
              ),
            ];
          }

          final rate = data.rate;
          final showRate = rate != null && rate.rupeesPerPoint > 0;
          return [
            SliverToBoxAdapter(
              child: Gutter(
                top: Space.lg,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  _BalanceCard(wallet: wallet),
                  if (showRate) ...[
                    const SizedBox(height: Space.sm),
                    _RateNote(rate: rate),
                  ],
                  const SizedBox(height: Space.sm),
                  AppCard(
                    onTap: () => _openRedeem(context),
                    child: Row(children: [
                      const IconTile(Icons.storefront_outlined),
                      const SizedBox(width: Space.md),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('How to redeem', style: AppText.smallStrong),
                          const SizedBox(height: 2),
                          Text('Rewards are redeemed at your branch against a bill.', style: AppText.small),
                        ]),
                      ),
                      const SizedBox(width: Space.xs),
                      const Icon(Icons.chevron_right_rounded, color: AppColors.inkTertiary),
                    ]),
                  ),
                ]),
              ),
            ),
            const SliverToBoxAdapter(child: SectionHeader('History')),
            SliverToBoxAdapter(
              child: Gutter(
                child: data.history.isEmpty
                    ? AppCard(
                        child: Row(children: [
                          const Icon(Icons.receipt_long_outlined, color: AppColors.inkTertiary, size: 22),
                          const SizedBox(width: Space.sm),
                          Expanded(
                            child: Text('No activity yet. Redemptions made at the store will appear here.',
                                style: AppText.small),
                          ),
                        ]),
                      )
                    : _HistoryList(entries: data.history),
              ),
            ),
          ];
        },
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.wallet});

  final Wallet wallet;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(Space.lg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: MergeSemantics(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('AVAILABLE BALANCE', style: AppText.overline),
                const SizedBox(height: Space.xs),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(Fmt.money(wallet.balance), style: AppText.amountXL),
                ),
              ]),
            ),
          ),
          const IconTile(Icons.card_giftcard_outlined, background: AppColors.goldWash, color: AppColors.goldDeep),
        ]),
        const SizedBox(height: Space.lg),
        const Divider(),
        const SizedBox(height: Space.md),
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: _Figure(label: 'Earned', value: Fmt.money(wallet.earned))),
            const VerticalDivider(width: Space.xl, thickness: 1, color: AppColors.line),
            Expanded(child: _Figure(label: 'Redeemed', value: Fmt.money(wallet.redeemed))),
          ]),
        ),
      ]),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: AppText.small),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: AppText.amountM),
        ),
      ]),
    );
  }
}

class _RateNote extends StatelessWidget {
  const _RateNote({required this.rate});

  final WalletRate rate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
      decoration: BoxDecoration(color: AppColors.surfaceSunken, borderRadius: BorderRadius.circular(Radii.md)),
      child: Row(children: [
        const Icon(Icons.swap_horiz_rounded, size: 20, color: AppColors.goldDeep),
        const SizedBox(width: Space.sm),
        Expanded(
          child: Text.rich(
            TextSpan(children: [
              TextSpan(text: 'Points value  ', style: AppText.small),
              TextSpan(
                text: '1 point = ${Fmt.money(rate.rupeesPerPoint, compact: true)}',
                style: AppText.tabular(AppText.smallStrong),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({required this.entries});

  final List<WalletEntry> entries;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(children: [
        for (var i = 0; i < entries.length; i++) ...[
          if (i > 0) const Divider(indent: Space.md, endIndent: Space.md),
          _HistoryRow(entry: entries[i]),
        ],
      ]),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry});

  final WalletEntry entry;

  @override
  Widget build(BuildContext context) {
    final meta = [
      Fmt.date(entry.date),
      if (entry.billNo != null) 'Bill ${entry.billNo}',
    ].join('  ·  ');
    final credit = entry.isCredit;
    final amount = '${credit ? '+' : '−'}${Fmt.money(entry.amount.abs())}';

    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm + 2),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(entry.description, style: AppText.smallStrong, maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(meta, style: AppText.caption),
            ]),
          ),
          const SizedBox(width: Space.md),
          Text(
            amount,
            style: AppText.amountM.copyWith(color: credit ? AppColors.positive : AppColors.negative),
            semanticsLabel: '${credit ? 'Credited' : 'Redeemed'} ${Fmt.money(entry.amount.abs())}',
          ),
        ]),
      ),
    );
  }
}

class _RewardsSkeleton extends StatelessWidget {
  const _RewardsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      child: Gutter(
        top: Space.lg,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.all(Space.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(Radii.lg),
              border: Border.all(color: AppColors.line),
            ),
            child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Skeleton(width: 120, height: 11),
              SizedBox(height: Space.xs),
              Skeleton(width: 190, height: 32),
              SizedBox(height: Space.lg),
              Divider(),
              SizedBox(height: Space.md),
              Row(children: [
                Expanded(child: Skeleton(width: 100, height: 30)),
                SizedBox(width: Space.xl),
                Expanded(child: Skeleton(width: 100, height: 30)),
              ]),
            ]),
          ),
          const SizedBox(height: Space.sm),
          const Skeleton(height: 64, radius: Radii.lg),
          const SizedBox(height: Space.xl),
          const Skeleton(width: 90, height: 16),
          const SizedBox(height: Space.sm),
          const SkeletonCard(lines: 2),
        ]),
      ),
    );
  }
}
