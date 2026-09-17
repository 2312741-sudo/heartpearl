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
  static Future<void> updateLatestPhoto(String imageUrl) async {
    if (imageUrl.isEmpty) return;

    try {
      // Save data for widgets
      await HomeWidget.saveWidgetData<String>('latestPhotoUrl', imageUrl);

      // Trigger widget update for iOS & Android
      await HomeWidget.updateWidget(
        name: androidWidgetName,
        iOSName: iOSWidgetName,
      );
    } catch (e) {
      // Non-critical, ignore on environments without widget configured
    }
  }
}
