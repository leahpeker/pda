import 'package:logging/logging.dart';
import 'package:web/web.dart' as web;

final _log = Logger('openUrl');

const _safeSchemes = {'http', 'https', 'tel', 'mailto', 'sms', 'whatsapp'};

void openUrl(String url) {
  // Prepend https:// if no scheme is present (e.g. "cash.app/pdanyc").
  final normalized =
      url.contains('://') ? url : 'https://$url';
  final uri = Uri.tryParse(normalized);
  if (uri == null || !_safeSchemes.contains(uri.scheme)) {
    _log.warning('Refusing to open URL with unsafe scheme: $url');
    return;
  }
  web.window.open(normalized, '_blank');
}
