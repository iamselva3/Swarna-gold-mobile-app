import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/brand_config.dart';
import '../../core/data/models.dart';
import '../../core/data/providers.dart';
import '../../core/ui/ui.dart';
import '../profile/contact_actions.dart';

/// In-store redemption guide.
///
/// Redemption is a staff-only action in the backend (it needs a bill number),
/// so this screen only explains the process and shows what the customer holds.
/// It never submits anything or reports a redemption.
class RedeemScreen extends ConsumerWidget {
  const RedeemScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref
      ..invalidate(holdingsProvider)
      ..invalidate(walletProvider)
      ..invalidate(profileProvider);
    try {
      await Future.wait([
        ref.read(holdingsProvider.future),
        ref.read(walletProvider.future),
        ref.read(profileProvider.future),
      ]);
    } catch (_) {
      // Each section shows its own error with a retry.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Redeem in store')),
      body: RefreshIndicator(
        color: AppColors.goldDeep,
        backgroundColor: AppColors.surface,
        onRefresh: () => _refresh(ref),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            Space.gutter,
            Space.xs,
            Space.gutter,
            Space.xl + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            Semantics(header: true, child: Text('Redeem at your branch', style: AppText.title)),
            const SizedBox(height: Space.xs),
            Text(
              'Your gold savings and rewards are redeemed in person. Staff at your branch check your account '
              'and complete the redemption against a bill. The app cannot redeem on its own.',
              style: AppText.bodySecondary,
            ),
            const _Header('What you hold'),
            const _HoldingsCard(),
            const SizedBox(height: Space.sm),
            const _WalletCard(),
            const _Header('How it works'),
            AppCard(
              padding: const EdgeInsets.fromLTRB(Space.md, Space.md, Space.md, Space.xs),
              child: Column(children: [
                _Step(
                  number: 1,
                  title: 'Visit your branch',
                  body: profile?.branchName == null
                      ? 'Go to the branch your account is registered with.'
                      : 'Go to ${profile!.branchName}, where your account is registered.',
                ),
                _Step(
                  number: 2,
                  title: 'Show this screen or your registered mobile number',
                  body: profile == null || profile.mobile.isEmpty
                      ? 'Staff find your account with the mobile number you registered.'
                      : 'Staff find your account with your registered mobile number '
                          '(+91 ${Fmt.maskedMobile(profile.mobile)}).',
                ),
                const _Step(
                  number: 3,
                  title: 'Choose your jewellery',
                  body: 'Staff verify your account, then close or redeem it against your purchase.',
                ),
                const _Step(
                  number: 4,
                  title: 'Receive your bill',
                  body: 'You get a bill for the redemption. It appears in the app after it has been processed.',
                  last: true,
                ),
              ]),
            ),
            const SizedBox(height: Space.md),
            const _PolicyNotice(),
            const _Header('Your branch'),
            const _BranchCard(),
            const SizedBox(height: Space.xl),
            SecondaryButton(
              label: 'Call support',
              icon: Icons.call_outlined,
              onPressed: () => ContactActions.callSupport(context),
            ),
            const SizedBox(height: Space.sm),
            PrimaryButton(label: 'Done', onPressed: () => Navigator.of(context).maybePop()),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.title);

  final String title;

  @override
  Widget build(BuildContext context) =>
      SectionHeader(title, padding: const EdgeInsets.only(top: Space.xl, bottom: Space.sm));
}

class _HoldingsCard extends ConsumerWidget {
  const _HoldingsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncView<Holdings>(
      value: ref.watch(holdingsProvider),
      onRetry: () => ref.invalidate(holdingsProvider),
      compactError: true,
      loading: const _FiguresSkeleton(),
      data: (h) {
        if (h.accounts.isEmpty) {
          return AppCard(
            child: Text('You don’t have any savings accounts yet.', style: AppText.small),
          );
        }
        final count = h.accounts.length;
        return AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Expanded(child: _Figure(label: 'Gold accumulated', value: Fmt.grams(h.totalWeight))),
                const VerticalDivider(width: Space.xl, thickness: 1, color: AppColors.line),
                Expanded(child: _Figure(label: 'Total paid', value: Fmt.money(h.totalPaid))),
              ]),
            ),
            const SizedBox(height: Space.sm),
            Text('Across $count ${count == 1 ? 'account' : 'accounts'}', style: AppText.caption),
          ]),
        );
      },
    );
  }
}

class _WalletCard extends ConsumerWidget {
  const _WalletCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncView<WalletOverview>(
      value: ref.watch(walletProvider),
      onRetry: () => ref.invalidate(walletProvider),
      compactError: true,
      loading: const Skeleton(height: 64, radius: Radii.lg),
      data: (o) {
        final wallet = o.wallet;
        if (wallet == null) return const SizedBox.shrink();
        return AppCard(
          child: MergeSemantics(
            child: Row(children: [
              const IconTile(Icons.card_giftcard_outlined, background: AppColors.goldWash, color: AppColors.goldDeep),
              const SizedBox(width: Space.md),
              Expanded(child: Text('Rewards wallet balance', style: AppText.small)),
              const SizedBox(width: Space.sm),
              Text(Fmt.money(wallet.balance), style: AppText.amountM),
            ]),
          ),
        );
      },
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
          child: Text(value, style: AppText.amountL),
        ),
      ]),
    );
  }
}

class _FiguresSkeleton extends StatelessWidget {
  const _FiguresSkeleton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      child: Container(
        padding: const EdgeInsets.all(Space.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(Radii.lg),
          border: Border.all(color: AppColors.line),
        ),
        child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Skeleton(width: 110, height: 12),
                SizedBox(height: Space.xs),
                Skeleton(width: 120, height: 22),
              ]),
            ),
            SizedBox(width: Space.xl),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Skeleton(width: 80, height: 12),
                SizedBox(height: Space.xs),
                Skeleton(width: 120, height: 22),
              ]),
            ),
          ]),
          SizedBox(height: Space.sm),
          Skeleton(width: 100, height: 11),
        ]),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.title, required this.body, this.last = false});

  final int number;
  final String title;
  final String body;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Padding(
        padding: EdgeInsets.only(bottom: last ? Space.sm : Space.md),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.gold, width: 1.2),
            ),
            child: Text(
              '$number',
              style: AppText.tabular(AppText.smallStrong).copyWith(color: AppColors.goldDeep),
              semanticsLabel: 'Step $number.',
              textScaler: TextScaler.noScaling,
            ),
          ),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 3),
              Text(title, style: AppText.smallStrong),
              const SizedBox(height: 2),
              Text(body, style: AppText.small),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _PolicyNotice extends StatelessWidget {
  const _PolicyNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Space.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceSunken,
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.verified_outlined, size: 20, color: AppColors.goldDeep),
        const SizedBox(width: Space.sm),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('From ${BrandConfig.brandDisplayName}', style: AppText.smallStrong),
            const SizedBox(height: Space.xxs),
            Text(BrandConfig.inStoreRedemptionNotice, style: AppText.small),
          ]),
        ),
      ]),
    );
  }
}

class _BranchCard extends ConsumerWidget {
  const _BranchCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncView<CustomerProfile>(
      value: ref.watch(profileProvider),
      onRetry: () => ref.invalidate(profileProvider),
      compactError: true,
      loading: const SkeletonCard(lines: 0),
      data: (p) => AppCard(
        child: Row(children: [
          const IconTile(Icons.storefront_outlined),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.branchName ?? 'Branch not set', style: AppText.smallStrong),
              const SizedBox(height: 2),
              Text(
                p.branchName == null
                    ? 'Call support to find out which branch to visit.'
                    : 'Your account is registered here.',
                style: AppText.small,
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
