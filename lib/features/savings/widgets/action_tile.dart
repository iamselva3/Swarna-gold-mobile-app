import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';

/// A tappable card with an icon tile and a short label, used for shortcuts.
class ActionTile extends StatelessWidget {
  const ActionTile({super.key, required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: Space.sm),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(children: [
          IconTile(icon, size: 40, background: AppColors.goldWash, color: AppColors.goldDeep),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Text(label, style: AppText.smallStrong.copyWith(fontSize: 14), maxLines: 2),
          ),
        ]),
      ),
    );
  }
}

/// Two-column grid of [ActionTile]s; tiles in a row share the taller height so
/// a wrapped label never leaves a ragged edge.
class ActionGrid extends StatelessWidget {
  const ActionGrid({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      for (var i = 0; i < children.length; i += 2) ...[
        if (i > 0) const SizedBox(height: Space.sm),
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: children[i]),
            const SizedBox(width: Space.sm),
            Expanded(child: i + 1 < children.length ? children[i + 1] : const SizedBox.shrink()),
          ]),
        ),
      ],
    ]);
  }
}
