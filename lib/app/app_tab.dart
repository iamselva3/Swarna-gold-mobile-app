import 'package:flutter/material.dart';

enum AppTab {
  home('Home', Icons.home_outlined, Icons.home_rounded),
  savings('Savings', Icons.account_balance_wallet_outlined, Icons.account_balance_wallet_rounded),
  plans('Plans', Icons.event_note_outlined, Icons.event_note_rounded),
  rewards('Rewards', Icons.card_giftcard_outlined, Icons.card_giftcard_rounded),
  profile('Profile', Icons.person_outline_rounded, Icons.person_rounded);

  const AppTab(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
