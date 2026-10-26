import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/constants/brand_config.dart';
import '../../core/data/models.dart';
import '../../core/data/providers.dart';
import '../../core/ui/ui.dart';
import '../buy_gold/buy_gold_screen.dart';
import '../profile/contact_actions.dart';
import 'enrol_screen.dart';
import 'plan_format.dart';

/// Everything the backend says about one plan, with the action that fits it:
/// buy (digital gold), join in the app (instalment plans) or join at the
/// branch (weight-based plans).
class PlanDetailScreen extends ConsumerWidget {
  const PlanDetailScreen({super.key, required this.schemeId});

  final String schemeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(schemeDetailProvider(schemeId));

    return Scaffold(
      appBar: AppBar(title: const Text('Plan details')),
      body: detail.when(
        skipLoadingOnRefresh: true,
        skipLoadingOnReload: true,
        loading: () => const _DetailSkeleton(),
        error: (e, _) => Center(
          child: SingleChildScrollView(
            child: ErrorView(error: e, onRetry: () => ref.invalidate(schemeDetailProvider(schemeId))),
          ),
        ),
        data: (scheme) => Column(children: [
          Expanded(
            child: RefreshIndicator(
              color: AppColors.goldDeep,
              backgroundColor: AppColors.surface,
              onRefresh: () async {
                ref.invalidate(schemeDetailProvider(schemeId));
                try {
                  await ref.read(schemeDetailProvider(schemeId).future);
                } catch (_) {
                  // The error state offers a retry.
                }
              },
              child: _PlanContent(scheme: scheme),
            ),
          ),
          _PlanAction(scheme: scheme),
        ]),
      ),
    );
  }
}

class _PlanContent extends StatelessWidget {
  const _PlanContent({required this.scheme});

  final SchemeDetail scheme;

  @override
  Widget build(BuildContext context) {
    final s = scheme;
    final glance = <Widget>[
      DetailRow('Plan type', s.classificationName.isEmpty ? '—' : s.classificationName),
      DetailRow('Metal & purity', s.metalLabel),
      if (!s.isDigital) DetailRow('Frequency', s.frequencyLabel),
      if (!s.isDigital || s.totalInstallments > 0)
        DetailRow('Instalments', s.totalInstallments > 0 ? '${s.totalInstallments}' : '—'),
      if (s.maturityLabel != null) DetailRow('Maturity period', s.maturityLabel!),
    ];

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xs, Space.gutter, Space.xl),
      children: [
        if (s.imageUrl != null) _PlanImage(url: s.imageUrl!),
        Wrap(spacing: Space.xs, runSpacing: Space.xs, children: [
          if (s.isDigital) StatusBadge(s.isDigitalSilver ? 'Digital silver' : 'Digital gold', tone: Tone.gold),
          if (s.isWeightBased) const StatusBadge('Weight-based'),
          if (!s.active) const StatusBadge('Not open for enrolment', tone: Tone.caution),
        ]),
        if (s.isDigital || s.isWeightBased || !s.active) const SizedBox(height: Space.sm),
        Semantics(header: true, child: Text(s.name, style: AppText.title)),
        if (s.code.isNotEmpty) ...[
          const SizedBox(height: Space.xxs),
          Text('Plan code ${s.code}', style: AppText.caption),
        ],
        if (s.description.isNotEmpty) ...[
          const SizedBox(height: Space.md),
          Text(s.description, style: AppText.bodySecondary),
        ],
        const SectionHeader('At a glance', padding: EdgeInsets.only(top: Space.xl, bottom: Space.sm)),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.xs),
          child: Column(children: glance),
        ),
        ..._amountSection(s),
        if (s.terms.isNotEmpty) ...[
          const SectionHeader('Terms & conditions', padding: EdgeInsets.only(top: Space.xl, bottom: Space.sm)),
          AppCard(child: Text(s.terms, style: AppText.small)),
        ],
      ],
    );
  }

  List<Widget> _amountSection(SchemeDetail s) {
    const header = EdgeInsets.only(top: Space.xl, bottom: Space.sm);
    final fee = s.convenienceFeePercent > 0
        ? DetailRow('Convenience fee', '${s.feeLabel} of each online payment')
        : null;

    // Digital plans: show purchase limits only when the jeweller set them.
    if (s.isDigital) {
      final range = s.amountRange;
      if (range == null && fee == null) return const [];
      return [
        const SectionHeader('Purchase limits', padding: header),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.xs),
          child: Column(children: [
            if (range != null) DetailRow('Amount per purchase', range),
            if (fee != null) fee,
          ]),
        ),
      ];
    }

    // Weight-based plans: the fixed values are weights in grams.
    if (s.isWeightBased) {
      final range = s.weightRange;
      return [
        const SectionHeader('Weight per instalment', padding: header),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (s.fixedAmounts.isNotEmpty) ...[
              Text('Choose one of these weights at the branch', style: AppText.small),
              const SizedBox(height: Space.sm),
              _ValueChips(values: [for (final w in s.fixedAmounts) Fmt.grams(w)]),
            ] else
              DetailRow('Weight range', range ?? '—'),
            if (fee != null) ...[const SizedBox(height: Space.xs), fee],
          ]),
        ),
      ];
    }

    final range = s.amountRange;
    final Widget body;
    if (s.commitsToAmount && s.fixedAmounts.isNotEmpty) {
      body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Choose one of these amounts when you join. It becomes your amount for each instalment.',
            style: AppText.small),
        const SizedBox(height: Space.sm),
        _ValueChips(values: [for (final a in s.fixedAmounts) Fmt.money(a, compact: true)]),
      ]);
    } else if (s.commitsToAmount) {
      body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('You choose your instalment amount when you join, and pay the same amount each time.',
            style: AppText.small),
        const SizedBox(height: Space.xs),
        DetailRow('Allowed amount', range ?? '—'),
      ]);
    } else {
      body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          range == null
              ? 'No fixed commitment. You decide how much to pay each instalment.'
              : 'No fixed commitment. Pay any amount within this range each instalment.',
          style: AppText.small,
        ),
        if (range != null) ...[
          const SizedBox(height: Space.xs),
          DetailRow('Per instalment', range),
        ],
      ]);
    }

    return [
      const SectionHeader('Amount per instalment', padding: header),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          body,
          if (fee != null) ...[const SizedBox(height: Space.xs), fee],
        ]),
      ),
    ];
  }
}

/// Plan artwork at its natural proportions; collapses if it fails to load.
class _PlanImage extends StatelessWidget {
  const _PlanImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    Widget frame(Widget child) => Padding(
          padding: const EdgeInsets.only(bottom: Space.lg),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(Radii.lg),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.line),
                borderRadius: BorderRadius.circular(Radii.lg),
              ),
              child: AspectRatio(aspectRatio: 16 / 9, child: child),
            ),
          ),
        );

    return ExcludeSemantics(
      child: CachedNetworkImage(
        imageUrl: url,
        fadeInDuration: const Duration(milliseconds: 150),
        imageBuilder: (_, image) => frame(Image(image: image, fit: BoxFit.contain)),
        placeholder: (_, __) => frame(const ColoredBox(color: AppColors.surfaceSunken)),
        errorWidget: (_, __, ___) => const SizedBox.shrink(),
      ),
    );
  }
}

/// Read-only pills listing a plan's fixed amounts or weights.
class _ValueChips extends StatelessWidget {
  const _ValueChips({required this.values});

  final List<String> values;

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: Space.xs, runSpacing: Space.xs, children: [
      for (final v in values)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surfaceSunken,
            borderRadius: BorderRadius.circular(Radii.pill),
          ),
          child: Text(v, style: AppText.tabular(AppText.smallStrong)),
        ),
    ]);
  }
}

/// Bottom action that matches the kind of plan and the customer's account.
class _PlanAction extends ConsumerWidget {
  const _PlanAction({required this.scheme});

  final SchemeDetail scheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = scheme;
    final branchId = ref.watch(sessionProvider)?.branchId;
    final callSupport = SecondaryButton(
      label: 'Call support',
      icon: Icons.call_outlined,
      onPressed: () => ContactActions.callSupport(context),
    );

    if (s.isDigital && !s.isDigitalSilver) {
      return BottomActionBar(
        child: PrimaryButton(
          label: 'Buy digital gold',
          icon: Icons.arrow_forward_rounded,
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BuyGoldScreen())),
        ),
      );
    }
    if (s.isDigitalSilver) {
      return BottomActionBar(
        note: const _ActionNote('Digital silver can’t be bought in the app yet. '
            'Contact ${BrandConfig.brandDisplayName} to buy it at the branch.'),
        child: callSupport,
      );
    }
    if (s.isWeightBased) {
      return BottomActionBar(
        note: const _ActionNote('This plan is opened at your branch, where staff record your weight commitment. '
            'It can’t be joined in the app.'),
        child: callSupport,
      );
    }
    if (!s.active) {
      return BottomActionBar(
        note: const _ActionNote('This plan is not open for new enrolments right now.'),
        child: callSupport,
      );
    }
    if (branchId == null || branchId.isEmpty) {
      return BottomActionBar(
        note: const _ActionNote('Your account isn’t linked to a branch yet, so plans can’t be opened in the app. '
            'Please contact support.'),
        child: callSupport,
      );
    }
    return BottomActionBar(
      child: PrimaryButton(
        label: 'Join this plan',
        icon: Icons.arrow_forward_rounded,
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => EnrolScreen(scheme: s))),
      ),
    );
  }
}

class _ActionNote extends StatelessWidget {
  const _ActionNote(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(
        padding: EdgeInsets.only(top: 1),
        child: Icon(Icons.info_outline_rounded, size: 18, color: AppColors.goldDeep),
      ),
      const SizedBox(width: Space.xs),
      Expanded(child: Text(message, style: AppText.small)),
    ]);
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xs, Space.gutter, Space.xl),
      children: const [
        AspectRatio(aspectRatio: 16 / 9, child: Skeleton(radius: Radii.lg)),
        SizedBox(height: Space.lg),
        Skeleton(width: 220, height: 26),
        SizedBox(height: Space.xs),
        Skeleton(width: 120, height: 12),
        SizedBox(height: Space.md),
        Skeleton(height: 14),
        SizedBox(height: Space.xs),
        Skeleton(width: 240, height: 14),
        SizedBox(height: Space.xl),
        SkeletonCard(lines: 3),
        SizedBox(height: Space.md),
        SkeletonCard(lines: 1),
      ],
    );
  }
}
