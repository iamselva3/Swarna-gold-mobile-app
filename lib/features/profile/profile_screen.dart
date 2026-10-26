import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/constants/brand_config.dart';
import '../../core/data/models.dart';
import '../../core/data/providers.dart';
import '../../core/ui/ui.dart';
import 'support_screen.dart';

/// Profile tab: the customer's details as held by the jeweller, help, about
/// and sign-out. The menu stays usable even if the profile fails to load.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(profileProvider);
    try {
      await ref.read(profileProvider.future);
    } catch (_) {
      // The error state below offers a retry.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);

    return TabPage(
      title: 'Profile',
      onRefresh: () => _refresh(ref),
      slivers: [
        SliverToBoxAdapter(
          child: Gutter(
            top: Space.lg,
            child: AsyncView<CustomerProfile>(
              value: profile,
              onRetry: () => ref.invalidate(profileProvider),
              compactError: true,
              loading: const _ProfileSkeleton(),
              data: (p) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _ProfileCard(profile: p),
                const SizedBox(height: Space.sm),
                Text('To change these details, contact your branch or ${BrandConfig.appName} support.',
                    style: AppText.caption),
              ]),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SectionHeader('Help & settings')),
        SliverToBoxAdapter(
          child: Gutter(
            child: AppCard(
              padding: EdgeInsets.zero,
              child: Column(children: [
                _MenuRow(
                  icon: Icons.support_agent_outlined,
                  title: 'Help & support',
                  subtitle: 'Contact us and common questions',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SupportScreen())),
                ),
                const Divider(indent: 72),
                _MenuRow(
                  icon: Icons.info_outline_rounded,
                  title: 'About',
                  subtitle: BrandConfig.appName,
                  onTap: () => _showAbout(context),
                ),
                const Divider(indent: 72),
                _MenuRow(
                  icon: Icons.logout_rounded,
                  title: 'Sign out',
                  destructive: true,
                  onTap: () => _confirmSignOut(context, ref),
                ),
              ]),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out of ${BrandConfig.appName}?'),
        content: const Text('You’ll need your mobile number and password to sign in again.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            style: TextButton.styleFrom(foregroundColor: AppColors.ink),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.negative),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await ref.read(authControllerProvider.notifier).signOut();
    }
  }

  void _showAbout(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.xl),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              const BrandMark(size: 48),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Semantics(header: true, child: Text(BrandConfig.appName, style: AppText.headline)),
                  Text(BrandConfig.brandDisplayName, style: AppText.small),
                ]),
              ),
            ]),
            const SizedBox(height: Space.lg),
            const Divider(),
            const SizedBox(height: Space.xs),
            const DetailRow('Operated by', BrandConfig.companyLegalName),
            const DetailRow('Gold standard', BrandConfig.goldStandard),
          ]),
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.profile});

  final CustomerProfile profile;

  @override
  Widget build(BuildContext context) {
    final p = profile;
    final place = [p.city, p.state].whereType<String>().where((s) => s.isNotEmpty).join(', ');
    final address = [p.address, p.pincode].whereType<String>().where((s) => s.isNotEmpty).join(' – ');

    return AppCard(
      padding: const EdgeInsets.all(Space.lg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          _Avatar(profile: p),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.fullName.isEmpty ? '—' : p.fullName,
                  style: AppText.heading.copyWith(fontSize: 18), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(
                p.mobile.isEmpty ? '—' : '+91 ${Fmt.maskedMobile(p.mobile)}',
                style: AppText.tabular(AppText.small),
                semanticsLabel: p.mobile.isEmpty ? null : 'Mobile ending ${_lastDigits(p.mobile)}',
              ),
            ]),
          ),
        ]),
        const SizedBox(height: Space.md),
        const Divider(),
        const SizedBox(height: Space.xs),
        if (p.email != null) DetailRow('Email', p.email!),
        DetailRow('Branch', p.branchName ?? '—'),
        if (place.isNotEmpty) DetailRow('City', place),
        if (address.isNotEmpty) DetailRow('Address', address),
      ]),
    );
  }

  static String _lastDigits(String mobile) =>
      mobile.length <= 4 ? mobile : mobile.substring(mobile.length - 4).split('').join(' ');
}

/// Customer photo, or initials while it loads, when it is missing or fails.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.profile});

  static const double _size = 60;

  final CustomerProfile profile;

  @override
  Widget build(BuildContext context) {
    final initials = Container(
      width: _size,
      height: _size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.goldWash,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
      ),
      child: Text(
        profile.initials,
        style: AppText.heading.copyWith(fontSize: 20, color: AppColors.goldDeep),
        textScaler: TextScaler.noScaling,
      ),
    );

    final url = profile.photoUrl;
    return ExcludeSemantics(
      child: url == null
          ? initials
          : ClipOval(
              child: CachedNetworkImage(
                imageUrl: url,
                width: _size,
                height: _size,
                fit: BoxFit.cover,
                memCacheWidth: (_size * MediaQuery.devicePixelRatioOf(context)).round(),
                fadeInDuration: const Duration(milliseconds: 150),
                placeholder: (_, __) => initials,
                errorWidget: (_, __, ___) => initials,
              ),
            ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.negative : AppColors.ink;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
            child: Row(children: [
              IconTile(
                icon,
                background: destructive ? AppColors.negativeWash : AppColors.surfaceSunken,
                color: color,
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(title, style: AppText.smallStrong.copyWith(color: color, fontSize: 15)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: AppText.caption),
                  ],
                ]),
              ),
              if (!destructive) const Icon(Icons.chevron_right_rounded, color: AppColors.inkTertiary),
            ]),
          ),
        ),
      ),
    );
  }
}

class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      child: Container(
        padding: const EdgeInsets.all(Space.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(Radii.lg),
          border: Border.all(color: AppColors.line),
        ),
        child: const Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Skeleton(width: 60, height: 60, radius: 30),
            SizedBox(width: Space.md),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Skeleton(width: 160, height: 18),
                SizedBox(height: Space.xs),
                Skeleton(width: 110, height: 12),
              ]),
            ),
          ]),
          SizedBox(height: Space.md),
          Divider(),
          SizedBox(height: Space.md),
          Skeleton(height: 12),
          SizedBox(height: Space.sm),
          Skeleton(height: 12),
          SizedBox(height: Space.sm),
          Skeleton(width: 200, height: 12),
        ]),
      ),
    );
  }
}
