import { Platform } from 'react-native';

/**
 * Cập nhật Widget trên màn hình chính cho cả iOS và Android
 * @param latestPhotoUrl Đường dẫn ảnh mới nhất cần hiển thị
 */
export const updateWidgets = async (latestPhotoUrl: string) => {
  if (!latestPhotoUrl) return;

  try {
    // 1. Lưu vào AsyncStorage để Android Task Handler có thể đọc lại khi hệ thống yêu cầu reload
    const AsyncStorage = require('@react-native-async-storage/async-storage').default;
    await AsyncStorage.setItem('latestPhotoUrl', latestPhotoUrl);

    // 2. Cập nhật nền tảng iOS
    if (Platform.OS === 'ios') {
      try {
        const { ExtensionStorage } = require('@bacons/apple-targets');
        const storage = new ExtensionStorage('group.com.tamchau.app');
        storage.set('latestPhotoUrl', latestPhotoUrl);
        ExtensionStorage.reloadWidget();
        console.log('[WidgetService] Đã cập nhật iOS Widget với URL:', latestPhotoUrl);
      } catch (iosError) {
        console.warn('[WidgetService] Lỗi khi cập nhật iOS Widget (Bỏ qua nếu đang chạy Android/Expo Go):', iosError);
      }
    }

    // 3. Cập nhật nền tảng Android
    if (Platform.OS === 'android') {
      try {
        const { requestWidgetUpdate } = require('react-native-android-widget');
        const { TamChauWidget } = require('../widgets/androidWidget');

        requestWidgetUpdate({
          widgetName: 'TamChauWidget',
          renderWidget: () => TamChauWidget({ imageUrl: latestPhotoUrl }),
        });
        console.log('[WidgetService] Đã cập nhật Android Widget với URL:', latestPhotoUrl);
      } catch (androidError) {
        console.warn('[WidgetService] Lỗi khi cập nhật Android Widget (Bỏ qua nếu đang chạy iOS/Expo Go):', androidError);
      }
    }
  } catch (error) {
    console.warn('[WidgetService] Lỗi không xác định khi cập nhật Widget:', error);
  }
};
