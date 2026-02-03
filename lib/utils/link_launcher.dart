import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../pages/webview_page.dart';
import '../providers/preferences_provider.dart';

Future<void> launchExternalLink(BuildContext context, String url) async {
  if (url.isEmpty) return;
  final uri = Uri.tryParse(url);
  if (uri == null) return;

  final prefs =
      ProviderScope.containerOf(context, listen: false).read(preferencesProvider);
  final preferInApp = prefs.openExternalLinksInAppBrowser;

  if (preferInApp && (uri.scheme == 'http' || uri.scheme == 'https')) {
    WebViewPage.open(context, url);
    return;
  }

  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
