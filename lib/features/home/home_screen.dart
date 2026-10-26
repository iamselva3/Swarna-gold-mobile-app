import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/app_tab.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/auth/session.dart';
import '../../core/data/models.dart';
import '../../core/data/providers.dart';
import '../../core/ui/ui.dart';
import '../buy_gold/buy_gold_screen.dart';
import '../payments/pay_installment_screen.dart';
import '../rates/rates_screen.dart';
import '../rates/widgets/rate_change.dart';
import '../redeem/redeem_screen.dart';
import '../savings/account_detail_screen.dart';
import '../savings/widgets/account_card.dart';
import '../savings/widgets/action_tile.dart';
import '../savings/widgets/holdings_panel.dart';

/// Home tab: greeting, gold balance, today's rate, shortcuts and open plans.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, required this.onOpenTab});

  final void Function(AppTab tab) onOpenTab;

  Future<void> _refresh(WidgetRef ref) async {
    ref
      ..invalidate(holdingsProvider)
      ..invalidate(ratesProvider);
    try {
      await Future.wait([ref.read(holdingsProvider.future), ref.read(ratesProvider.future)]);
    } catch (_) {
      // Each section shows its own error with a retry.
    }
  }

  void _push(BuildContext context, Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final holdings = ref.watch(holdingsProvider);
    final rates = ref.watch(ratesProvider);
    final goldRate = rates.valueOrNull?.primaryGold;

    return TabPage(
      brandHeader: Row(
        children: [
          const BrandHeaderLogo(size: 34),
          const Spacer(),
          _ProfileButton(session: session, onTap: () => onOpenTab(AppTab.profile)),
        ],
      ),
      title: _greeting(DateTime.now(), session),
      subtitle: DateFormat('EEEE, d MMMM').format(DateTime.now()),
      onRefresh: () => _refresh(ref),
      slivers: [
        SliverToBoxAdapter(
          child: Gutter(
            top: Space.md,
            child: holdings.when(
              skipLoadingOnRefresh: true,
              skipLoadingOnReload: true,
              loading: () => const HoldingsPanelSkeleton(),
              error: (e, _) => ErrorView(error: e, compact: true, onRetry: () => ref.invalidate(holdingsProvider)),
              data: (h) => HoldingsPanel(holdings: h, goldRate: goldRate, onTap: () => onOpenTab(AppTab.savings)),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SectionHeader('Today’s rate',
              actionLabel: 'All rates', onAction: () => _push(context, const RatesScreen())),
        ),
        SliverToBoxAdapter(
          child: Gutter(
            child: AsyncView<RateBoard>(
              value: rates,
              compactError: true,
              onRetry: () => ref.invalidate(ratesProvider),
              loading: const _RateCardSkeleton(),
              data: (board) => _RateCard(board: board, onOpen: () => _push(context, const RatesScreen())),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SectionHeader('Quick actions')),
        SliverToBoxAdapter(
          child: Gutter(
            child: ActionGrid(children: [
              ActionTile(
                icon: Icons.shopping_bag_outlined,
                label: 'Buy gold',
                onTap: () => _push(context, const BuyGoldScreen()),
              ),
              ActionTile(
                icon: Icons.payments_outlined,
                label: 'Pay instalment',
                onTap: () => _push(context, const PayInstallmentScreen()),
              ),
              ActionTile(
                icon: Icons.storefront_outlined,
                label: 'Redeem',
                onTap: () => _push(context, const RedeemScreen()),
              ),
              ActionTile(
                icon: Icons.event_note_outlined,
                label: 'Join a plan',
                onTap: () => onOpenTab(AppTab.plans),
              ),
            ]),
          ),
        ),
        SliverToBoxAdapter(
          child: _PlansSection(
            holdings: holdings,
            onSeeAll: () => onOpenTab(AppTab.savings),
            onJoin: () => onOpenTab(AppTab.plans),
            onOpenAccount: (a) => _push(context, AccountDetailScreen(account: a)),
          ),
        ),
      ],
    );
  }
}

String _greeting(DateTime now, Session? session) {
  final h = now.hour;
  final part = h < 12 ? 'Good morning' : (h < 17 ? 'Good afternoon' : 'Good evening');
  final name = _displayName(session?.firstName ?? '');
  return name.isEmpty ? part : '$part, $name';
}

/// Title-cases names stored all upper- or lower-case ("RAVI" → "Ravi");
/// mixed-case names are left exactly as entered.
String _displayName(String raw) {
  final s = raw.trim();
  if (s.isEmpty || (s != s.toUpperCase() && s != s.toLowerCase())) return s;
  return s
      .split(RegExp(r'\s+'))
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
      .join(' ');
}

/// Initials in a hairline gold ring; opens the Profile tab.
class _ProfileButton extends StatelessWidget {
  const _ProfileButton({required this.session, required this.onTap});

  final Session? session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final first = session?.firstName.trim() ?? '';
    final last = session?.lastName.trim() ?? '';
    final initials = '${first.isEmpty ? '' : first[0]}${last.isEmpty ? '' : last[0]}'.toUpperCase();

    return Tooltip(
      message: 'Profile',
      child: Semantics(
        button: true,
        label: 'Open profile',
        excludeSemantics: true,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 48,
              height: 48,
              child: Center(
                child: Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.gold, width: 1.2),
                  ),
                  child: initials.isEmpty
                      ? const Icon(Icons.person_outline_rounded, size: 22, color: AppColors.goldDeep)
                      : Text(initials,
                          style: AppText.smallStrong.copyWith(color: AppColors.goldDeep, letterSpacing: 0.5)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Today's primary gold rate with its movement, plus a short list of the
/// branch's other published rates.
class _RateCard extends StatelessWidget {
  const _RateCard({required this.board, required this.onOpen});

  final RateBoard board;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    if (board.isEmpty) {
      return AppCard(
        child: Row(children: [
          const IconTile(Icons.schedule_rounded),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Text('Today’s rates haven’t been published for your branch yet. Pull down to check again.',
                style: AppText.small),
          ),
        ]),
      );
    }

    final primary = board.primaryGold ?? board.rates.first;
    final others = board.rates.where((r) => !identical(r, primary)).take(3).toList();
    final updated = primary.updatedAt ?? board.updatedAt;

    return AppCard(
      onTap: onOpen,
      padding: const EdgeInsets.fromLTRB(Space.md, Space.md, Space.md, Space.xs),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${primary.label.trim().toUpperCase()}  ·  PER GRAM', style: AppText.overline),
              const SizedBox(height: Space.xs),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(Fmt.money(primary.rate), style: AppText.amountL),
              ),
              const SizedBox(height: Space.xxs),
              RateChange(primary, suffix: '  vs previous'),
            ]),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.inkTertiary),
        ]),
        if (updated != null) ...[
          const SizedBox(height: Space.sm),
          Text('Updated ${Fmt.relativeDateTime(updated)}', style: AppText.caption),
        ],
        if (others.isNotEmpty) ...[
          const SizedBox(height: Space.md),
          const Divider(),
          for (final r in others) _RateLine(r),
        ] else
          const SizedBox(height: Space.sm),
      ]),
    );
  }
}

class _RateLine extends StatelessWidget {
  const _RateLine(this.rate);

  final MetalRate rate;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.sm),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(child: Text(rate.label.trim(), style: AppText.small)),
          const SizedBox(width: Space.sm),
          Flexible(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: Fmt.money(rate.rate), style: AppText.tabular(AppText.smallStrong)),
                TextSpan(text: ' /g', style: AppText.caption),
              ]),
              textAlign: TextAlign.right,
            ),
          ),
        ]),
      ),
    );
  }
}

class _RateCardSkeleton extends StatelessWidget {
  const _RateCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading today’s rate',
      child: const AppCard(
        child: ExcludeSemantics(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Skeleton(width: 140, height: 11),
            SizedBox(height: Space.sm),
            Skeleton(width: 150, height: 24),
            SizedBox(height: Space.sm),
            Skeleton(width: 120, height: 12),
            SizedBox(height: Space.lg),
            Skeleton(height: 12),
            SizedBox(height: Space.sm),
            Skeleton(width: 200, height: 12),
          ]),
        ),
      ),
    );
  }
}

/// Up to three open plans, overdue and soonest-due first.
class _PlansSection extends StatelessWidget {
  const _PlansSection({
    required this.holdings,
    required this.onSeeAll,
    required this.onJoin,
    required this.onOpenAccount,
  });

  final AsyncValue<Holdings> holdings;
  final VoidCallback onSeeAll;
  final VoidCallback onJoin;
  final void Function(SchemeAccount account) onOpenAccount;

  static int _byUrgency(SchemeAccount a, SchemeAccount b) {
    final overdue = b.overdueInstallments.compareTo(a.overdueInstallments);
    if (overdue != 0) return overdue;
    final da = a.nextDueDate, db = b.nextDueDate;
    if (da == null && db == null) return 0;
    if (da == null) return 1;
    if (db == null) return -1;
    return da.compareTo(db);
  }

  @override
  Widget build(BuildContext context) {
    return holdings.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      // The holdings panel above already shows the error and retry.
      error: (_, __) => const SizedBox.shrink(),
      loading: () => const Column(children: [
        SectionHeader('Your plans'),
        Gutter(child: AccountCardSkeleton()),
        SizedBox(height: Space.sm),
        Gutter(child: AccountCardSkeleton()),
      ]),
      data: (h) {
        final open = [...h.openAccounts]..sort(_byUrgency);
        if (open.isEmpty) {
          return Column(children: [
            const SectionHeader('Your plans'),
            Gutter(
              child: AppCard(
                padding: EdgeInsets.zero,
                child: EmptyView(
                  icon: Icons.savings_outlined,
                  title: 'No active plans',
                  message: 'Plans you join appear here with your instalments and the gold you have saved.',
                  action: SizedBox(
                    width: 220,
                    child: SecondaryButton(label: 'Join a plan', onPressed: onJoin),
                  ),
                ),
              ),
            ),
          ]);
        }
        return Column(children: [
          SectionHeader('Your plans', actionLabel: 'See all', onAction: onSeeAll),
          for (final a in open.take(3))
            Gutter(
              bottom: Space.sm,
              child: AccountCard(account: a, compact: true, onTap: () => onOpenAccount(a)),
            ),
        ]);
      },
    );
  }
}
