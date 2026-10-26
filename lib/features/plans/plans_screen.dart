import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/brand_config.dart';
import '../../core/data/models.dart';
import '../../core/data/providers.dart';
import '../../core/ui/ui.dart';
import 'plan_detail_screen.dart';

/// Plans tab: every savings plan the jeweller currently offers.
class PlansScreen extends ConsumerWidget {
  const PlansScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(schemesProvider);
    try {
      await ref.read(schemesProvider.future);
    } catch (_) {
      // The error state below offers a retry.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schemes = ref.watch(schemesProvider);

    return TabPage(
      title: 'Plans',
      subtitle: 'Savings plans offered by ${BrandConfig.brandDisplayName}',
      trailing: const BrandMark(size: 36),
      onRefresh: () => _refresh(ref),
      slivers: schemes.when(
        skipLoadingOnRefresh: true,
        skipLoadingOnReload: true,
        loading: () => [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(Space.gutter, Space.lg, Space.gutter, 0),
            sliver: SliverList.separated(
              itemCount: 4,
              itemBuilder: (_, __) => const _PlanCardSkeleton(),
              separatorBuilder: (_, __) => const SizedBox(height: Space.sm),
            ),
          ),
        ],
        error: (e, _) => [
          SliverToBoxAdapter(child: ErrorView(error: e, onRetry: () => ref.invalidate(schemesProvider))),
        ],
        data: (list) {
          if (list.isEmpty) {
            return const [
              SliverToBoxAdapter(
                child: EmptyView(
                  icon: Icons.event_note_outlined,
                  title: 'No plans available right now',
                  message: 'When ${BrandConfig.brandDisplayName} publishes savings plans, they will appear here. '
                      'Pull down to check again.',
                ),
              ),
            ];
          }
          final digital = list.where((s) => s.isDigital).toList();
          final instalment = list.where((s) => !s.isDigital).toList();
          // Group only when both kinds exist; a single heading over one group adds nothing.
          final grouped = digital.isNotEmpty && instalment.isNotEmpty;
          return [
            if (grouped) ...[
              const SliverToBoxAdapter(child: SectionHeader('Digital gold')),
              _PlanList(plans: digital),
              const SliverToBoxAdapter(child: SectionHeader('Instalment plans')),
              _PlanList(plans: instalment),
            ] else ...[
              const SliverToBoxAdapter(child: SizedBox(height: Space.lg)),
              _PlanList(plans: list),
            ],
          ];
        },
      ),
    );
  }
}

class _PlanList extends StatelessWidget {
  const _PlanList({required this.plans});

  final List<SchemeSummary> plans;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
      sliver: SliverList.separated(
        itemCount: plans.length,
        itemBuilder: (_, i) => _PlanCard(plan: plans[i]),
        separatorBuilder: (_, __) => const SizedBox(height: Space.sm),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan});

  final SchemeSummary plan;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PlanDetailScreen(schemeId: plan.id)),
      ),
      child: Row(children: [
        _PlanLogo(url: plan.logoUrl, digital: plan.isDigital),
        const SizedBox(width: Space.md),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(plan.name, style: AppText.heading, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: Space.xxs + 2),
            if (plan.isDigital)
              StatusBadge(plan.schemeType == 14 ? 'Digital silver' : 'Digital gold', tone: Tone.gold)
            else
              Text('Instalment savings plan', style: AppText.small),
          ]),
        ),
        const SizedBox(width: Space.xs),
        const Icon(Icons.chevron_right_rounded, color: AppColors.inkTertiary),
      ]),
    );
  }
}

/// Plan artwork, or a neutral icon tile while it loads or when it is missing.
class _PlanLogo extends StatelessWidget {
  const _PlanLogo({required this.url, required this.digital});

  static const double _size = 56;

  final String? url;
  final bool digital;

  @override
  Widget build(BuildContext context) {
    final fallback = IconTile(
      digital ? Icons.toll_outlined : Icons.savings_outlined,
      size: _size,
      color: AppColors.inkSecondary,
    );
    if (url == null) return fallback;

    final cacheSize = (_size * MediaQuery.devicePixelRatioOf(context)).round();
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Radii.md),
        child: CachedNetworkImage(
          imageUrl: url!,
          width: _size,
          height: _size,
          fit: BoxFit.cover,
          memCacheWidth: cacheSize,
          fadeInDuration: const Duration(milliseconds: 150),
          placeholder: (_, __) => const ColoredBox(
            color: AppColors.surfaceSunken,
            child: SizedBox(width: _size, height: _size),
          ),
          errorWidget: (_, __, ___) => fallback,
        ),
      ),
    );
  }
}

class _PlanCardSkeleton extends StatelessWidget {
  const _PlanCardSkeleton();

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
        child: const Row(children: [
          Skeleton(width: 56, height: 56, radius: Radii.md),
          SizedBox(width: Space.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Skeleton(width: 180, height: 16),
              SizedBox(height: Space.xs),
              Skeleton(width: 110, height: 12),
            ]),
          ),
        ]),
      ),
    );
  }
}
