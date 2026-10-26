import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/models.dart';
import '../../core/data/providers.dart';
import '../../core/ui/ui.dart';
import 'widgets/rate_change.dart';

/// Today's full rate board for the customer's branch, grouped by metal, with
/// a weight-to-value calculator.
class RatesScreen extends ConsumerStatefulWidget {
  const RatesScreen({super.key});

  @override
  ConsumerState<RatesScreen> createState() => _RatesScreenState();
}

class _RatesScreenState extends ConsumerState<RatesScreen> {
  final _weight = TextEditingController();

  @override
  void dispose() {
    _weight.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(ratesProvider);
    try {
      await ref.read(ratesProvider.future);
    } catch (_) {
      // The board shows the error with a retry.
    }
  }

  @override
  Widget build(BuildContext context) {
    final rates = ref.watch(ratesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Today’s rates'),
        actions: [
          IconButton(
            tooltip: 'Refresh rates',
            onPressed: rates.isLoading ? null : _refresh,
            icon: rates.isLoading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: Space.xs),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.goldDeep,
        backgroundColor: AppColors.surface,
        onRefresh: _refresh,
        child: rates.when(
          skipLoadingOnRefresh: true,
          skipLoadingOnReload: true,
          loading: () => _scroll(const [_BoardSkeleton()]),
          error: (e, _) => _scroll([ErrorView(error: e, onRetry: () => ref.invalidate(ratesProvider))]),
          data: (board) => board.isEmpty
              ? _scroll(const [
                  EmptyView(
                    icon: Icons.schedule_rounded,
                    title: 'Rates not published yet',
                    message: 'Today’s rates for your branch haven’t been published. Pull down to check again.',
                  ),
                ])
              : _scroll([
                  _BoardHeader(board),
                  for (final group in groupRatesByMetal(board)) ...[
                    SectionHeader(group.metal, padding: const EdgeInsets.fromLTRB(0, Space.xl, 0, Space.sm)),
                    _RateGroupCard(rates: group.rates, boardUpdatedAt: board.updatedAt),
                  ],
                  const SectionHeader('Value calculator', padding: EdgeInsets.fromLTRB(0, Space.xxl, 0, Space.sm)),
                  _Calculator(board: board, controller: _weight),
                ]),
        ),
      ),
    );
  }

  Widget _scroll(List<Widget> children) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(Space.gutter, Space.xs, Space.gutter, Space.xxl + bottom),
      children: children,
    );
  }
}

class _BoardHeader extends StatelessWidget {
  const _BoardHeader(this.board);

  final RateBoard board;

  @override
  Widget build(BuildContext context) {
    final updated = board.updatedAt;
    return Text(
      updated == null
          ? 'Per gram, published by your branch.'
          : 'Per gram, published by your branch. Updated ${Fmt.relativeDateTime(updated)}.',
      style: AppText.small,
    );
  }
}

class _RateGroupCard extends StatelessWidget {
  const _RateGroupCard({required this.rates, required this.boardUpdatedAt});

  final List<MetalRate> rates;
  final DateTime? boardUpdatedAt;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: Space.md),
      child: Column(children: [
        for (var i = 0; i < rates.length; i++) ...[
          if (i > 0) const Divider(),
          _RateRow(rate: rates[i], boardUpdatedAt: boardUpdatedAt),
        ],
      ]),
    );
  }
}

class _RateRow extends StatelessWidget {
  const _RateRow({required this.rate, required this.boardUpdatedAt});

  final MetalRate rate;
  final DateTime? boardUpdatedAt;

  @override
  Widget build(BuildContext context) {
    final previous = rate.previousRate;
    final updated = rate.updatedAt;
    // Only call out a row's own time when it differs from the board's.
    final showUpdated = updated != null &&
        (boardUpdatedAt == null || boardUpdatedAt!.difference(updated).inMinutes.abs() >= 1);

    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(rate.purity.isEmpty ? rate.metal : rate.purity, style: AppText.heading),
              const SizedBox(height: 2),
              Text(previous == null ? 'No previous rate' : 'Previous ${Fmt.money(previous)}',
                  style: AppText.tabular(AppText.caption)),
              if (showUpdated)
                Text('Updated ${Fmt.relativeDateTime(updated)}', style: AppText.caption),
            ]),
          ),
          const SizedBox(width: Space.md),
          Flexible(
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text.rich(TextSpan(children: [
                  TextSpan(text: Fmt.money(rate.rate), style: AppText.amountM),
                  TextSpan(text: ' /g', style: AppText.caption),
                ])),
              ),
              if (previous != null) ...[
                const SizedBox(height: 2),
                RateChange(rate),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Weight × rate for every published rate. Client-side and indicative only.
class _Calculator extends StatelessWidget {
  const _Calculator({required this.board, required this.controller});

  final RateBoard board;
  final TextEditingController controller;

  static final _pattern = RegExp(r'^\d{0,4}(\.\d{0,3})?$');

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.done,
          inputFormatters: [
            TextInputFormatter.withFunction((old, next) => _pattern.hasMatch(next.text) ? next : old),
          ],
          style: AppText.tabular(AppText.body),
          decoration: const InputDecoration(
            labelText: 'Weight',
            hintText: '0.000',
            suffixText: 'grams',
            prefixIcon: Icon(Icons.scale_outlined),
          ),
        ),
        const SizedBox(height: Space.sm),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            final grams = double.tryParse(value.text);
            final valid = grams != null && grams > 0;
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (final r in board.rates)
                DetailRow(r.label.trim(), valid ? Fmt.money(grams * r.rate) : '—'),
            ]);
          },
        ),
        const SizedBox(height: Space.sm),
        const Divider(),
        const SizedBox(height: Space.sm),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.inkTertiary),
          const SizedBox(width: Space.xs),
          Expanded(
            child: Text(
              'Indicative value of the metal at today’s rates. Excludes making charges and GST; '
              'the final price is confirmed at billing.',
              style: AppText.caption,
            ),
          ),
        ]),
      ]),
    );
  }
}

class _BoardSkeleton extends StatelessWidget {
  const _BoardSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget row() => const Padding(
          padding: EdgeInsets.symmetric(vertical: 14),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Skeleton(width: 56, height: 16),
                SizedBox(height: Space.xs),
                Skeleton(width: 120, height: 11),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Skeleton(width: 96, height: 16),
              SizedBox(height: Space.xs),
              Skeleton(width: 72, height: 11),
            ]),
          ]),
        );

    Widget group(int rows) => AppCard(
          padding: const EdgeInsets.symmetric(horizontal: Space.md),
          child: Column(children: [
            for (var i = 0; i < rows; i++) ...[if (i > 0) const Divider(), row()],
          ]),
        );

    return Semantics(
      label: 'Loading rates',
      child: ExcludeSemantics(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Skeleton(width: 240, height: 12),
          const SizedBox(height: Space.xl),
          const Skeleton(width: 48, height: 16),
          const SizedBox(height: Space.sm),
          group(2),
          const SizedBox(height: Space.xl),
          const Skeleton(width: 56, height: 16),
          const SizedBox(height: Space.sm),
          group(1),
        ]),
      ),
    );
  }
}
