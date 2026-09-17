import 'package:url_launcher/url_launcher.dart';

Future<void> openExternalUrl(String url) async {
  try {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  } catch (_) {}
}
