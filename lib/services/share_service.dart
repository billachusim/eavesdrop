import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';

class ShareService {
  static const String appStoreUrl = 'https://apps.apple.com/ng/app/eavesdrop-live-conversations/id6759225893';
  static const String playStoreUrl = 'https://play.google.com/store/apps/details?id=com.socialfaculty.eavesdrop&hl=en';

  static Future<void> shareApp({Rect? sharePositionOrigin}) async {
    const String message = 'Check out Eavesdrop - Live conversations worth listening to!\n\n'
        'Download on iOS: $appStoreUrl\n\n'
        'Download on Android: $playStoreUrl';
    
    await Share.share(
      message,
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  static Future<void> shareCallWithImage({
    required String title,
    required String hostName,
    required Uint8List imageBytes,
    required String callId,
    Rect? sharePositionOrigin,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final file = await File('${tempDir.path}/call_share.png').create();
    await file.writeAsBytes(imageBytes);

    final String message = 'Join me on Eavesdrop to listen to: "$title" with $hostName\n'
        'https://eavesdrop.app/call/$callId';

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'image/png')],
      text: message,
      sharePositionOrigin: sharePositionOrigin,
    );
  }
}
