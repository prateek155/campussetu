import 'package:flutter_web_plugins/url_strategy.dart';
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

/// Enables clean HTML5 path URLs on Flutter Web without hashes (#/route)
/// and normalizes any legacy hash URLs into clean path URLs.
void configureUrlStrategy() {
  try {
    final loc = html.window.location;
    final hash = loc.hash;
    // 1. If someone accessed a URL with an unintended trailing hash, e.g. /events?code=EVT-XXX#/home
    if (loc.pathname != null && loc.pathname != '/' && hash.isNotEmpty) {
      final cleanUrl = '${loc.pathname}${loc.search ?? ''}';
      html.window.history.replaceState(null, '', cleanUrl);
    }
    // 2. If someone accessed an old legacy hash route on root, e.g. /#/events?code=EVT-XXX
    else if ((loc.pathname == null || loc.pathname == '/' || loc.pathname == '') && hash.startsWith('#/')) {
      final target = hash.substring(1);
      html.window.history.replaceState(null, '', target);
    }
  } catch (_) {}

  usePathUrlStrategy();
}
