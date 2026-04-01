import 'package:url_launcher/url_launcher.dart';

void openUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri != null) launchUrl(uri, mode: LaunchMode.externalApplication);
}

void openLocationInMaps(String location) {
  final url = 'geo:0,0?q=${Uri.encodeComponent(location)}';
  final uri = Uri.tryParse(url);
  if (uri != null) launchUrl(uri, mode: LaunchMode.externalApplication);
}
