import 'package:flutter/material.dart';

import '../../core/constants/brand_config.dart';
import '../../core/ui/ui.dart';
import 'contact_actions.dart';

/// Support contacts and answers to common questions. The answers describe
/// how the app works; they make no promises beyond that.
class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  static const _faqs = <({String question, String answer})>[
    (
      question: 'When is my payment confirmed?',
      answer: 'A payment is marked as paid only after the bank or payment gateway confirms it to '
          '${BrandConfig.brandDisplayName}. Until then it shows as pending, and your savings are '
          'updated only once it is confirmed.',
    ),
    (
      question: 'Money was debited but the payment shows pending',
      answer: 'Confirmation from the bank can take some time. Please don’t pay the same instalment again '
          'straight away — check back later and pull down to refresh the account. If it still shows '
          'pending, contact support with the payment date, the amount and the reference number from '
          'your bank or UPI app so the payment can be traced.',
    ),
    (
      question: 'How do I redeem my gold or rewards?',
      answer: 'Redemption happens in store. Visit your branch with your registered mobile number; staff '
          'verify your account and complete the redemption against a bill. It appears in the app after '
          'it has been processed. The app cannot redeem on its own.',
    ),
    (
      question: 'How do I join a new plan?',
      answer: 'Open the Plans tab, choose a plan and follow the steps. Some plans, such as weight-based '
          'plans, can only be opened at your branch.',
    ),
    (
      question: 'How do I reset my password?',
      answer: 'On the sign-in screen, tap “Forgot password?”, enter your registered mobile number and the '
          'OTP sent to it by SMS, then choose a new password.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help & support')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          Space.gutter,
          Space.xs,
          Space.gutter,
          Space.xl + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          Semantics(header: true, child: Text('How can we help?', style: AppText.title)),
          const SizedBox(height: Space.xs),
          Text('Reach ${BrandConfig.brandDisplayName} directly, or find a quick answer below.',
              style: AppText.bodySecondary),
          const SectionHeader('Contact us', padding: EdgeInsets.only(top: Space.xl, bottom: Space.sm)),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              _ContactRow(
                icon: Icons.call_outlined,
                label: 'Call',
                value: BrandConfig.supportPhone,
                onTap: () => ContactActions.callSupport(context),
              ),
              const Divider(indent: 72),
              _ContactRow(
                icon: Icons.mail_outline_rounded,
                label: 'Email',
                value: BrandConfig.supportEmail,
                onTap: () => ContactActions.emailSupport(context),
              ),
              const Divider(indent: 72),
              _ContactRow(
                icon: Icons.language_rounded,
                label: 'Website',
                value: ContactActions.websiteLabel,
                onTap: () => ContactActions.openWebsite(context),
              ),
            ]),
          ),
          const SectionHeader('Common questions', padding: EdgeInsets.only(top: Space.xl, bottom: Space.sm)),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              for (var i = 0; i < _faqs.length; i++) ...[
                if (i > 0) const Divider(indent: Space.md, endIndent: Space.md),
                _FaqTile(question: _faqs[i].question, answer: _faqs[i].answer),
              ],
            ]),
          ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.icon, required this.label, required this.value, required this.onTap});

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
            child: Row(children: [
              IconTile(icon, background: AppColors.goldWash, color: AppColors.goldDeep),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(label, style: AppText.caption),
                  const SizedBox(height: 2),
                  Text(value, style: AppText.tabular(AppText.smallStrong).copyWith(fontSize: 15)),
                ]),
              ),
              const SizedBox(width: Space.xs),
              const Icon(Icons.open_in_new_rounded, size: 18, color: AppColors.inkTertiary),
            ]),
          ),
        ),
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.question, required this.answer});

  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: Text(question, style: AppText.body.copyWith(fontWeight: FontWeight.w600)),
      tilePadding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.xxs),
      childrenPadding: const EdgeInsets.fromLTRB(Space.md, 0, Space.md, Space.md),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      expandedAlignment: Alignment.centerLeft,
      shape: const Border(),
      collapsedShape: const Border(),
      backgroundColor: Colors.transparent,
      collapsedBackgroundColor: Colors.transparent,
      iconColor: AppColors.goldDeep,
      collapsedIconColor: AppColors.inkTertiary,
      textColor: AppColors.ink,
      collapsedTextColor: AppColors.ink,
      children: [Text(answer, style: AppText.bodySecondary)],
    );
  }
}
