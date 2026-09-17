// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;

Future<void> openExternalUrl(String url) async {
  try {
    html.window.open(url, '_blank');
  } catch (_) {}
}
