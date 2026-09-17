import 'dart:io';
import 'package:home_widget/home_widget.dart';

class WidgetService {
  static const String appGroupId = 'group.com.tamchau.app';
  static const String androidWidgetName = 'TamChauWidget';
  static const String iOSWidgetName = 'widget';

  /// Initialize HomeWidget App Group for iOS
  static Future<void> initialize() async {
    try {
      if (Platform.isIOS) {
        await HomeWidget.setAppGroupId(appGroupId);
      }
    } catch (e) {
      // Ignored if platform doesn't support
    }
  }

  /// Update home screen widget with latest received/sent photo
  static Future<void> updateLatestPhoto(
    String imageUrl, {
    File? localFile,
    String? senderName,
    String? caption,
    bool isMirrored = false,
  }) async {
    if (imageUrl.isEmpty && localFile == null) return;

    try {
      if (imageUrl.isNotEmpty) {
        await HomeWidget.saveWidgetData<String>('latestPhotoUrl', imageUrl);
      }
      if (senderName != null && senderName.isNotEmpty) {
        await HomeWidget.saveWidgetData<String>('senderName', senderName);
      }
      if (caption != null && caption.isNotEmpty) {
        await HomeWidget.saveWidgetData<String>('caption', caption);
      }
      await HomeWidget.saveWidgetData<bool>('isMirrored', isMirrored);
      await HomeWidget.saveWidgetData<int>(
        'updatedAt',
        DateTime.now().millisecondsSinceEpoch,
      );

      // Save local file directly into App Group Shared Container if available
      if (localFile != null && await localFile.exists()) {
        try {
          final bytes = await localFile.readAsBytes();
          await HomeWidget.saveFile('latestPhoto', bytes, extension: 'jpg');
        } catch (_) {}
      }

      // Trigger widget update for iOS & Android
      await HomeWidget.updateWidget(
        name: androidWidgetName,
        iOSName: iOSWidgetName,
      );
    } catch (_) {}
  }

  /// Clear widget so it never shows old/own photos when no friends photos are present
  static Future<void> clearWidget() async {
    try {
      await HomeWidget.saveWidgetData<String>('latestPhotoUrl', '');
      await HomeWidget.saveWidgetData<String>('latestPhoto', '');
      await HomeWidget.saveWidgetData<String>('senderName', 'HeartPearl');
      await HomeWidget.saveWidgetData<String>('caption', '');
      await HomeWidget.saveWidgetData<int>('updatedAt', 0);
      await HomeWidget.updateWidget(
        name: androidWidgetName,
        iOSName: iOSWidgetName,
      );
    } catch (_) {}
  }
}
