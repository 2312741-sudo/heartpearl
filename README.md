# HeartPearl (Flutter Edition)

Ứng dụng chia sẻ khoảnh khắc widget thời gian thực phong cách Locket dành cho bạn bè và người thân yêu, được xây dựng hoàn toàn bằng **Flutter** & **Dart**.

---

## ✨ Điểm nổi bật & Tính năng chính

- **Camera & Quay Video 2-trong-1 siêu mượt**:
  - Chạm 1 lần để chụp ảnh tức thì.
  - Nhấn giữ để quay video ngắn 15s với vòng tròn tiến trình neon phát sáng.
  - Hỗ trợ cử chỉ Pinch-to-zoom (1.0x - 4.0x), lật camera trước/sau, bật/tắt đèn flash.
  - **Bộ lọc làm đẹp (Beauty Filters)** thời gian thực: Gốc (Normal), Soft Glow, Pearl Skin, Rosy Blush.
- **Hộp thư (Inbox Feed)**:
  - Lưới ảnh 2 cột dạng thẻ bo góc sang trọng.
  - Huy hiệu "MỚI" gradient neon cho khoảnh khắc chưa xem.
  - Tối ưu bộ nhớ cache và tải ảnh tức thì với `cached_network_image`.
- **Trình xem chi tiết (Photo Viewer) & Tương tác kép**:
  - Phát video looping hoặc xem ảnh full-screen.
  - **📸 Selfie Reaction**: Mở nhanh camera trước để chụp ảnh biểu cảm phản hồi.
  - **💬 Text Reaction**: Phản hồi nhanh bằng emoji (❤️, 😍, 🔥, ...) hoặc tin nhắn văn bản.
  - Tự động đồng bộ phản hồi vào phòng chat 1-on-1.
- **Nhắn tin Trực tiếp (Real-time Chat)**:
  - Khung chat thời gian thực với bạn bè, hiển thị ảnh reaction selfie và tin nhắn.
  - Huy hiệu số tin nhắn chưa đọc cập nhật trực tiếp tại màn hình chính.
- **Quản lý bạn bè & Khoảnh khắc**:
  - 3 Tab tiện lợi: Bạn bè, Lời mời kết bạn và Tìm kiếm bạn theo `@username`.
  - Dòng thời gian lịch sử ảnh đã gửi nhóm theo từng ngày.
- **Hồ sơ & Tuỳ chỉnh**:
  - Thẻ thông tin cá nhân kèm thống kê số bạn bè, số ảnh đã gửi, số reactions.
  - Đổi ảnh đại diện, tên hiển thị, `@username`.
  - Chuyển đổi giao diện Sáng / Tối (Dark / Light Mode) tức thì.
  - Đa ngôn ngữ: Tiếng Việt và English.
- **Home Screen Widget**:
  - Tích hợp `home_widget` hỗ trợ cập nhật ảnh mới nhất trực tiếp ra Widget màn hình chính cho cả iOS (WidgetKit) và Android (AppWidget).

---

## 🛠️ Kiến trúc Dự án (Clean Architecture)

```
lib/
├── core/
│   ├── constants/       # AppColors, AppTypography, AppDimens
│   ├── theme/           # Dark & Light ThemeData
│   ├── l10n/            # AppStrings (Tiếng Việt & English)
│   └── utils/           # BeautyFilter, HapticHelper, DateHelper
├── models/              # UserModel, PhotoModel, ChatModel, NotificationModel
├── services/            # AuthService, PhotoService, FriendService, ChatService, WidgetService, NotificationService
├── providers/           # Riverpod State Management (Auth, Feed, Friends, Chat, Settings)
├── ui/
│   ├── common/          # GradientButton, FrostedContainer, UserAvatar, AppTextField, AppBadge
│   ├── auth/            # WelcomeScreen, LoginScreen, CreateProfileScreen
│   └── main/
│       ├── main_scaffold.dart
│       ├── home/        # CameraScreen, PreviewScreen
│       ├── inbox/       # InboxScreen
│       ├── viewer/      # PhotoViewerScreen
│       ├── chat/        # ChatListScreen, ChatRoomScreen
│       ├── friends/     # FriendsScreen
│       ├── history/     # HistoryScreen
│       ├── notifications/ # NotificationsScreen
│       └── profile/     # ProfileScreen, EditProfileSheet
└── main.dart            # Root application entry
```

---

## 🚀 Hướng dẫn Chạy ứng dụng

1. **Cài đặt thư viện phụ thuộc**:
   ```bash
   flutter pub get
   ```

2. **Chạy kiểm tra mã nguồn**:
   ```bash
   dart analyze lib
   flutter test
   ```

3. **Chạy ứng dụng**:
   ```bash
   # Chạy trên thiết bị hoặc máy ảo
   flutter run
   ```
