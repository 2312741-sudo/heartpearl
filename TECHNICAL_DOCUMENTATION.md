# TÀI LIỆU KỸ THUẬT DỰ ÁN HEARTPEARL (TECHNICAL DOCUMENTATION)

> **Phiên bản:** 1.0.0  
> **Nền tảng:** iOS (ưu tiên số 1), Android  
> **Công nghệ lõi:** Flutter (3.x), Riverpod, Firebase Suite, Swift (WidgetKit & AVFoundation), Clean Architecture  

---

## 1. TỔNG QUAN HỆ THỐNG (SYSTEM OVERVIEW)

HeartPearl là ứng dụng mạng xã hội chia sẻ khoảnh khắc ảnh/video nhanh và vị trí thời gian thực dành cho bạn bè thân thiết, tích hợp sâu với hệ sinh thái iOS WidgetKit để đưa những khoảnh khắc và vị trí trực tiếp lên màn hình chính (Home Screen) của iPhone.

### Kiến trúc phân tầng (Clean Architecture)
```
lib/
├── core/                  # Tiện ích dùng chung, bảng màu, typography, kích thước, bộ lọc
│   ├── constants/         # AppColors, AppDimens, AppTypography, AppStrings
│   ├── theme/             # AppTheme (Dark/Light mode)
│   └── utils/             # CameraFilters, HapticHelper, MediaHelper, ProfanityFilter
├── models/                # Thực thể dữ liệu (UserModel, PhotoModel, LocationModel, ...)
├── providers/             # Quản lý trạng thái Riverpod (Auth, Feed, Location, Chat, ...)
├── services/              # Tầng dịch vụ (Auth, Photo, Location, Widget, Notification, ...)
└── ui/                    # Giao diện người dùng
    ├── auth/              # Đăng nhập, chào mừng, tạo hồ sơ, EULA modal
    ├── common/            # Widget tái sử dụng (FrostedContainer, CameraEffectLayer, AppBadge, ...)
    └── main/              # Các màn hình chính
        ├── home/          # CameraScreen (GPU Preview, bộ lọc, chụp/quay, preview)
        ├── inbox/         # Bảng tin khoảnh khắc từ bạn bè
        ├── map/           # Bản đồ bạn bè trực tiếp, ghim lên widget
        ├── history/       # Lịch sử khoảnh khắc
        ├── profile/       # Hồ sơ cá nhân, cài đặt, xóa tài khoản vĩnh viễn
        ├── chat/          # Nhắn tin tức thì & phản hồi khoảnh khắc
        ├── friends/       # Danh sách & lời mời kết bạn
        └── notifications/ # Trung tâm thông báo
```

---

## 2. CAMERA & COMPUTER VISION PIPELINE

### 2.1. Kiến trúc xem trước GPU thời gian thực (Real-time GPU Preview)
- Sử dụng `CameraEffectLayer` (`lib/ui/common/camera_effect_layer.dart`) bọc trực tiếp quanh `CameraPreview`.
- **25 Bộ lọc màu sắc & sắc đẹp đa thể loại** chia thành 8 danh mục (`lib/core/utils/camera_filters.dart`):
  - *Natural, Aesthetic, Cinematic, Korean, Vintage, Cyberpunk, Monochrome, Creative*.
- Sử dụng ma trận biến đổi màu `ColorFilter.matrix` xử lý trực tiếp trên chip đồ họa (GPU Impeller / Metal), đạt chuẩn 60 FPS không gây nghẽn UI Thread.

### 2.2. Xử lý ảnh cao cấp bằng Dart Isolate
- Khi người dùng chụp ảnh, ảnh gốc được chuyển sang **Isolate riêng biệt** (`lib/services/camera_effects_service.dart`) để:
  - Phân tích màu sắc & làm mịn da theo thuật toán thông minh không làm mờ chi tiết mắt, môi và tóc.
  - Áp dụng bộ lọc chính xác theo cấu hình người dùng chọn.
  - Xuất ảnh chất lượng cao mà không gây giật lag giao diện người dùng.

### 2.3. Cơ chế Snapshot đóng băng khung hình (Zero Gray-Screen Transition)
- **Vấn đề đã xử lý:** Trước đây khi chuyển đổi giữa ống kính 0.5x và 1x hoặc lật camera trước/sau, việc hủy Native Metal Texture trên iOS khiến Impeller vẽ màu xám mặc định `(0.5, 0.5, 0.5)` trong tích tắc.
- **Giải pháp:**
  1. Trước khi hủy controller cũ, `RenderRepaintBoundary.toImage()` lập tức chụp lại khung hình hiện tại thành `ui.Image` (`_frozenFrame`) trên GPU.
  2. Gỡ bỏ ngay `CameraPreview` cũ (`_controller = null`) và đặt `RawImage(_frozenFrame)` làm lớp nền thay thế.
  3. Áp dụng hiệu ứng mờ quang học `BackdropFilter(sigma: 12px)` khi chuyển ống kính `.5x ⇄ 1x` hoặc xoay thẻ 3D khi lật camera.
  4. Sau khi camera mới truyền khung hình đầu tiên, `_frozenFrame` được giải phóng an toàn khỏi bộ nhớ.

### 2.4. Đồng bộ vòng đời chống lag từ Widget
- Tích hợp cờ `isActive` và `cameraTrigger` giữa `MainScaffold` và `CameraScreen`.
- Khi vào app từ widget (`heartpearl://camera`) hoặc chuyển tab, app tự động hủy pipeline camera bị iOS tiết lưu xung nhịp (throttle) và khởi tạo phiên `AVCaptureSession` 60 FPS mới tinh sạch, triệt tiêu hoàn toàn hiện tượng khựng khung hình.

---

## 3. HỆ THỐNG TIỆN ÍCH MÀN HÌNH CHÍNH (IOS WIDGETKIT)

### 3.1. Cấu trúc chia sẻ App Group
- **App Group ID:** `group.com.tamchau.app`
- Đồng bộ dữ liệu 2 chiều giữa Flutter và tiện ích Swift WidgetKit thông qua `UserDefaults(suiteName: appGroupId)` và container tệp dùng chung của hệ thống iOS.

### 3.2. Đa dạng kích thước & Bố cục chia đôi (Dual-Panel Large Widget)
Widget hỗ trợ 3 kích thước:
- **Small (`.systemSmall`)**: Hiển thị ảnh khoảnh khắc mới nhất hoặc bản đồ radar thu nhỏ.
- **Medium (`.systemMedium`)**: Hiển thị ảnh kèm chú thích hoặc radar vị trí bạn bè kèm khoảng cách.
- **Large (`.systemLarge`)**: **Giao diện chia đôi độc quyền (Dual-Panel)**:
  - **Nửa trái:** Ảnh khoảnh khắc mới nhất từ bạn bè, hiệu ứng chuyển màu gradient bóng mờ và tên người gửi.
  - **Đường phân cách:** Dải sáng neon hồng mờ `(255, 74, 110)` tạo điểm nhấn phong cách HeartPearl.
  - **Nửa phải:** Bản đồ radar vị trí trực tiếp của bạn bè, hiển thị khoảng cách di chuyển và thời gian cập nhật.

### 3.3. Tải và lưu trữ ảnh cục bộ bền vững
- Để tránh lỗi liên kết ảnh Firebase Storage hết hạn xác thực (token expiration) khiến widget bị trắng ảnh, phương thức `WidgetService.updateLatestPhoto()` tự động tải dữ liệu nhị phân ảnh và lưu tệp `latestPhoto.jpg` trực tiếp vào App Group Shared Directory. Swift Widget đọc trực tiếp từ ổ đĩa nội bộ, hiển thị tức thì không phụ thuộc mạng.

### 3.4. Bộ sinh ảnh Radar Vector độc lập (`dart:ui Canvas`)
- Khi không có token Mapbox trực tuyến, app tự động kích hoạt bộ vẽ vector đồ họa trên thiết bị (`WidgetService.generateRadarMapImage`):
  - Nền obsidian siêu tối với lưới tọa độ.
  - Các vòng đồng tâm radar màu hồng ngọc.
  - Điểm đánh dấu vị trí Bạn (Xanh dương) và Bạn bè (Hồng neon) kèm đường nối khoảng cách (Haversine Distance).
  - Xuất ảnh chuẩn PNG ghi vào App Group để widget nạp ngay lập tức.

---

## 4. BẬT CẬP NHẬT THỜI GIAN THỰC QUA CLOUD FUNCTIONS (SILENT PUSH)

### 4.1. Kiến trúc Cloud Functions v2
- **Tệp nguồn:** `functions/src/locationWidgetPush.ts`
- **Bộ kích hoạt:** `onDocumentUpdated('userLocations/{uid}')`
- **Thuật toán xử lý:**
  1. So sánh tọa độ `geo` trước và sau cập nhật bằng công thức lượng giác cầu Haversine.
  2. Nếu quãng đường di chuyển $\ge 100\text{ m}$:
     - Tra cứu danh sách người được phép xem vị trí (`allowedViewers` hoặc toàn bộ danh sách bạn bè).
     - Truy vấn danh sách mã thông báo FCM (`fcmToken`) của các thiết bị này.
     - Phát thông báo ngầm dữ liệu thuần (**Silent Push Notification**):
       - APNs header: `apns-push-type: background`, `apns-priority: 5`.
       - APNs payload: `content-available: 1`.
       - Data: `{ type: 'location_widget_update', uid: '...' }`.

### 4.2. Xử lý đánh thức nền trên iOS
- **Tại `AppDelegate.swift`**:
  - Hàm `application(_:didReceiveRemoteNotification:fetchCompletionHandler:)` nhận gói tin `location_widget_update` ngầm ngay cả khi app đang đóng.
  - Gọi ngay `WidgetCenter.shared.reloadAllTimelines()` để WidgetKit cập nhật vị trí bạn bè trong vòng vài giây mà không cần người dùng mở app.
- **Tại Flutter `NotificationService`**:
  - Đăng ký hàm nhận ngầm cấp cao nhất `_firebaseMessagingBackgroundHandler()` trước khi `runApp()` thực thi để đồng bộ dữ liệu vào `WidgetService`.

---

## 5. BẢO VỆ NGƯỜI DÙNG & TUÂN THỦ NGUYÊN TẮC APPLE (UGC COMPLIANCE)

HeartPearl được thiết kế đáp ứng 100% các tiêu chuẩn nghiêm ngặt của Apple App Store:
1. **Guideline 1.2 (An toàn nội dung UGC)**:
   - Thỏa thuận EULA bắt buộc tại màn hình Chào mừng và Đăng nhập, khẳng định rõ chính sách **Không khoan nhượng (Zero Tolerance)** với nội dung phản cảm và cam kết xử lý trong 24 giờ.
   - Bộ lọc ngôn từ phản cảm tự động `ContentFilterService` kiểm duyệt 2 ngôn ngữ (Việt - Anh) trên mọi trường văn bản (chú thích ảnh, tin nhắn, hồ sơ).
   - Cơ chế báo cáo vi phạm (`ReportContentSheet`) và nút chặn người dùng (`FriendService.blockUser`) tức thì gửi bản ghi về Firestore `reports` để nhà phát triển can thiệp.
2. **Guideline 5.1.1(v) (Xóa tài khoản vĩnh viễn)**:
   - Cung cấp nút bấm độc lập màu đỏ nổi bật trong Hồ sơ: **Xóa tài khoản vĩnh viễn**.
   - Quy trình xóa toàn diện: Xóa sạch dữ liệu ảnh/video trên Firebase Storage, bản ghi tài khoản trên Firestore và vô hiệu hóa Firebase Authentication.
   - Cung cấp cổng trực tuyến xóa tài khoản tại `https://tamchau-865f3.web.app/delete-account.html`.

---

## 6. HƯỚNG DẪN BIÊN DỊCH & TRIỂN KHAI (DEPLOYMENT GUIDE)

### 6.1. Kiểm tra chất lượng mã nguồn
```bash
# Phân tích tĩnh toàn bộ mã Dart
dart analyze lib

# Chạy toàn bộ 21 bộ kiểm thử tự động
flutter test test/widget_test.dart test/location_test.dart
```

### 6.2. Triển khai Cloud Functions (Firebase Blaze)
```bash
cd functions
npm install
npm run build
firebase deploy --only functions --project tamchau-865f3
```

### 6.3. Đóng gói & Ký bản phát hành iOS (iOS Release Build)
1. Mở dự án trong Xcode:
   ```bash
   open ios/Runner.xcworkspace
   ```
2. Kiểm tra mục **Signing & Capabilities**:
   - Target `Runner`: Chọn đúng Signing Team, Bundle ID `com.heartpearl.heartpearl`, App Group `group.com.tamchau.app`.
   - Target `HeartPearlWidgetExtension`: Bundle ID `com.heartpearl.heartpearl.HeartPearlWidget`, App Group `group.com.tamchau.app`.
3. Biên dịch bản release:
   ```bash
   flutter build ipa --release
   ```
4. Đẩy bản build lên TestFlight thông qua Xcode Organizer hoặc Transporter.
