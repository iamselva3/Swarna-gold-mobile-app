import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/models.dart';
import '../../core/data/providers.dart';
import '../../core/ui/ui.dart';
import '../payments/pay_installment_screen.dart';
import '../redeem/redeem_screen.dart';
import 'account_detail_screen.dart';
import 'widgets/account_card.dart';
import 'widgets/action_tile.dart';
import 'widgets/holdings_panel.dart';

enum _Filter {
  all('All'),
  active('Active'),
  closed('Closed');

  const _Filter(this.label);

  final String label;

  bool matches(SchemeAccount a) => switch (this) {
        _Filter.all => true,
        _Filter.active => a.isOpen,
        _Filter.closed => !a.isOpen,
      };
}

/// Savings tab: balance across plans, shortcuts and every plan the customer
/// holds, filterable by status.
class SavingsScreen extends ConsumerStatefulWidget {
  const SavingsScreen({super.key});

  @override
  ConsumerState<SavingsScreen> createState() => _SavingsScreenState();
}

class _SavingsScreenState extends ConsumerState<SavingsScreen> {
  _Filter _filter = _Filter.all;

  Future<void> _refresh() async {
    ref
      ..invalidate(holdingsProvider)
      ..invalidate(ratesProvider);
    try {
      await ref.read(holdingsProvider.future);
    } catch (_) {
      // The page shows the error with a retry.
    }
  }

  void _push(Widget screen) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final holdings = ref.watch(holdingsProvider);
    final goldRate = ref.watch(ratesProvider).valueOrNull?.primaryGold;

    return TabPage(
      title: 'Savings',
      subtitle: 'Your accumulated gold holdings and savings accounts',
      trailing: const BrandMark(size: 36),
      onRefresh: _refresh,
      slivers: holdings.when(
        skipLoadingOnRefresh: true,
        skipLoadingOnReload: true,
        loading: _loading,
        error: (e, _) => [
          SliverToBoxAdapter(child: ErrorView(error: e, onRetry: () => ref.invalidate(holdingsProvider))),
        ],
        data: (h) => _content(h, goldRate),
      ),
    );
  }

  List<Widget> _loading() => const [
        SliverToBoxAdapter(child: Gutter(top: Space.md, child: HoldingsPanelSkeleton(detailed: true))),
        SliverToBoxAdapter(child: Gutter(top: Space.xl, child: AccountCardSkeleton())),
        SliverToBoxAdapter(child: Gutter(top: Space.sm, child: AccountCardSkeleton())),
      ];

  List<Widget> _content(Holdings h, MetalRate? goldRate) {
    if (h.accounts.isEmpty) {
      return const [
        SliverToBoxAdapter(
          child: EmptyView(
            icon: Icons.savings_outlined,
            title: 'No savings plans yet',
            message: 'When you join a plan from the Plans tab, its instalments, passbook and the gold '
                'you have saved will appear here.',
          ),
        ),
      ];
    }

    final hasOpen = h.openAccounts.isNotEmpty;
    final visible = h.accounts.where(_filter.matches).toList();

    return [
      SliverToBoxAdapter(
        child: Gutter(top: Space.md, child: HoldingsPanel(holdings: h, goldRate: goldRate, detailed: true)),
      ),
      SliverToBoxAdapter(
        child: Gutter(
          top: Space.md,
          child: ActionGrid(children: [
            if (hasOpen)
              ActionTile(
                icon: Icons.payments_outlined,
                label: 'Pay instalment',
                onTap: () => _push(const PayInstallmentScreen()),
              ),
            ActionTile(
              icon: Icons.storefront_outlined,
              label: 'Redeem',
              onTap: () => _push(const RedeemScreen()),
            ),
          ]),
        ),
      ),
      const SliverToBoxAdapter(
        child: SectionHeader('Your plans', padding: EdgeInsets.fromLTRB(Space.gutter, Space.xl, Space.gutter, 0)),
      ),
      SliverToBoxAdapter(child: _FilterBar(accounts: h.accounts, selected: _filter, onSelected: _select)),
      if (visible.isEmpty)
        SliverToBoxAdapter(
          child: EmptyView(
            icon: Icons.filter_list_rounded,
            title: _filter == _Filter.active ? 'No active plans' : 'No closed plans',
            message: _filter == _Filter.active
                ? 'All of your plans are closed. Your passbooks remain available under All.'
                : 'Plans appear here once they mature or are closed.',
          ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, 0),
          sliver: SliverList.separated(
            itemCount: visible.length,
            separatorBuilder: (_, __) => const SizedBox(height: Space.sm),
            itemBuilder: (context, i) {
              final a = visible[i];
              return AccountCard(account: a, onTap: () => _push(AccountDetailScreen(account: a)));
            },
          ),
        ),
    ];
  }

  void _select(_Filter f) {
    if (f != _filter) setState(() => _filter = f);
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.accounts, required this.selected, required this.onSelected});

  final List<SchemeAccount> accounts;
  final _Filter selected;
  final ValueChanged<_Filter> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter, vertical: Space.xs),
      child: Row(children: [
        for (final f in _Filter.values) ...[
          if (f.index > 0) const SizedBox(width: Space.xs),
          _chip(f, accounts.where(f.matches).length),
        ],
      ]),
    );
  }

  Widget _chip(_Filter f, int count) {
    final isSelected = f == selected;
    return ChoiceChip(
      label: Text('${f.label}  $count'),
      selected: isSelected,
      showCheckmark: false,
      selectedColor: AppColors.ink,
      backgroundColor: AppColors.surface,
      side: BorderSide(color: isSelected ? AppColors.ink : AppColors.line),
      labelStyle: AppText.tabular(AppText.small).copyWith(
        fontWeight: FontWeight.w700,
        color: isSelected ? AppColors.inkInverse : AppColors.ink,
      ),
      onSelected: (_) => onSelected(f),
    );
  }
}
