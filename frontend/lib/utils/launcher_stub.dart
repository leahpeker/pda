import 'package:url_launcher/url_launcher.dart';

void openUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri != null) launchUrl(uri, mode: LaunchMode.externalApplication);
}

void openLocationInMaps(
  String location, {
  double? latitude,
  double? longitude,
}) {
  final String url;
  if (latitude != null && longitude != null) {
    url = 'geo:$latitude,$longitude?q=${Uri.encodeComponent(location)}';
  } else {
    url = 'geo:0,0?q=${Uri.encodeComponent(location)}';
  }
  final uri = Uri.tryParse(url);
  if (uri != null) launchUrl(uri, mode: LaunchMode.externalApplication);
}
