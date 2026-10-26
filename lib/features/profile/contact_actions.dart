import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/brand_config.dart';
import '../../core/ui/ui.dart';

/// Opens the dialler, mail app or browser for the jeweller's support
/// contacts. A failed launch is reported with a snack bar, never silently.
class ContactActions {
  ContactActions._();

  static Uri get phoneUri => Uri(scheme: 'tel', path: BrandConfig.supportPhone.replaceAll(RegExp(r'[^\d+]'), ''));

  static Uri get emailUri => Uri(scheme: 'mailto', path: BrandConfig.supportEmail);

  static Uri get websiteUri => Uri.parse(BrandConfig.officialWebsite);

  /// "swarnagold.com" for display.
  static String get websiteLabel {
    final host = websiteUri.host;
    return host.isEmpty ? BrandConfig.officialWebsite : host.replaceFirst(RegExp(r'^www\.'), '');
  }

  static Future<void> callSupport(BuildContext context) =>
      open(context, phoneUri, 'Couldn’t open the phone app. Call ${BrandConfig.supportPhone}.');

  static Future<void> emailSupport(BuildContext context) =>
      open(context, emailUri, 'Couldn’t open an email app. Write to ${BrandConfig.supportEmail}.');

  static Future<void> openWebsite(BuildContext context) =>
      open(context, websiteUri, 'Couldn’t open the browser. Visit $websiteLabel.');

  static Future<void> open(BuildContext context, Uri uri, String failureMessage) async {
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (!opened && context.mounted) showAppSnack(context, failureMessage, error: true);
  }
}
