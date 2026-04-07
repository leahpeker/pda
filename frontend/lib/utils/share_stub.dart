import 'package:share_plus/share_plus.dart';

void shareUrl(String url, {String? subject}) {
  SharePlus.instance.share(ShareParams(text: url, subject: subject));
}
