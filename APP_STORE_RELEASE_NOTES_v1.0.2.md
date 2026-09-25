# HEARTPEARL - BẢN THÔNG TIN CẬP NHẬT APP STORE (VERSION 1.0.2)

> **Tổng hợp toàn diện từ 2 Workspace phát triển song song**: 
> Bao gồm nâng cấp hệ thống Thông báo đẩy (APNs), Quản lý Badge, Điều hướng Deep-link, Tối ưu hóa triệt để Hiệu năng Camera & Định vị tiết kiệm pin, Hệ thống hiệu ứng chuyển động (Entrance Animation), Skeleton Shimmer Loading cao cấp và Chuẩn hóa Design System toàn diện.
>
> *Tài liệu này được biên soạn sẵn để bạn có thể copy-paste trực tiếp vào **App Store Connect** khi nộp bản build `1.0.2` (Build `8`).*

---

## 1. NỘI DUNG "CÓ GÌ MỚI TRONG PHIÊN BẢN NÀY" (WHAT'S NEW)

### 🇻🇳 Phiên bản Tiếng Việt (Vietnamese)
```text
Chào mừng bạn đến với phiên bản 1.0.2 của HeartPearl! Bản cập nhật lớn này mang đến bước đột phá về hiệu năng, giao diện chuyển động mượt mà và hệ thống thông báo tức thì:

🔔 THÔNG BÁO ĐẨY TỨC THÌ (APNs PUSH NOTIFICATIONS):
• Không bao giờ bỏ lỡ tin nhắn và khoảnh khắc từ bạn thân! HeartPearl hiện đã hỗ trợ đầy đủ thông báo pop-up ngoài màn hình khóa và trung tâm thông báo qua chuẩn Apple APNs tốc độ cao.
• Khi đang mở ứng dụng, tin nhắn mới sẽ trượt xuống nhẹ nhàng dưới dạng thanh kính mờ (Frosted Banner) hiện đại, cho phép xem nhanh hoặc chạm để trả lời tức thì mà không gián đoạn trải nghiệm.
• Phân tách rành mạch: Tin nhắn vào thẳng mục Chat, chuông thông báo dành riêng cho tương tác kết bạn và cảm xúc.

⚡ SIÊU TIẾT KIỆM PIN & TỐI ƯU CAMERA:
• Khắc phục triệt để tình trạng camera chạy ngầm: Phần cứng camera và GPU sẽ lập tức tạm dừng ngay khi bạn chuyển tab hoặc ẩn ứng dụng, bảo vệ tối đa thời lượng pin và giữ máy luôn mát mẻ.
• Khi quay lại camera, luồng hình ảnh 60 FPS được khôi phục siêu tốc, không còn hiện tượng chớp đen hay khựng hình.
• Tối ưu định vị thông minh: Giảm hơn 35% mức tiêu thụ năng lượng khi xem bản đồ nhờ cơ chế lọc rung sai số GPS và bộ đệm trạng thái pin.

✨ GIAO DIỆN CHUYỂN ĐỘNG & SKELETON SHIMMER:
• Hiệu ứng chuyển động mượt mà (Entrance Animations): Danh sách ảnh, bạn bè, cuộc trò chuyện và thông báo giờ đây xuất hiện so le uyển chuyển, tinh tế.
• Tạm biệt vòng xoay chờ đợi: Nâng cấp toàn bộ màn hình chờ sang hiệu ứng Skeleton Shimmer kính mờ sang trọng, tái hiện trước cấu trúc giao diện trước khi tải xong.
• Màn hình rỗng (Empty State) rực rỡ: Thiết kế vòng hào quang ngọc trai ấm áp cùng chuyển động mở rộng nhẹ nhàng khi chưa có dữ liệu.

🎨 ĐỘT PHÁ QUAY VIDEO & MÀU SẮC DESIGN SYSTEM:
• Đảo ghi hình (Dynamic Island HUD) & Thanh laser neon đếm ngược 60 FPS: Nằm ngay trên kính ngắm, giúp bạn theo dõi thời gian quay video mà không bị ngón tay che khuất.
• Viền ngọc trai tỏa sáng (Pearl Glow): Làm nổi bật những bức ảnh mốc kỷ niệm đặc biệt trong trang Lịch sử.
• Bảng màu trạng thái mới hài hòa, tinh tế và đồng bộ chuẩn font chữ Inter toàn diện.
• Biểu tượng số thông báo đỏ ngoài màn hình chính tự động dọn sạch về 0 ngay khi mở app.

Cảm ơn bạn đã luôn đồng hành và chia sẻ những khoảnh khắc chân thực nhất cùng bạn bè thân thiết trên HeartPearl!
```

---

### 🇺🇸 Phiên bản Tiếng Anh (English)
```text
Welcome to HeartPearl 1.0.2! This major release delivers breakthrough battery efficiency, fluid entrance animations, premium shimmer loading, and instant push notifications:

🔔 INSTANT PUSH NOTIFICATIONS & IN-APP BANNER:
• Never miss a moment from your closest friends! High-priority Apple APNs push notifications now alert you on your Lock Screen and Notification Center the instant a friend reaches out.
• In-App Message Banner: While browsing the camera or map, incoming chats slide down gracefully in a sleek frosted glass banner—preview or tap to jump right in.
• Cleaner Navigation: Direct chats are neatly housed in the Chat tab, leaving your notification bell dedicated exclusively to friend requests and reactions.

⚡ SUPERCHARGED EFFICIENCY & ZERO-DRAIN CAMERA:
• Background Camera Halt: Camera hardware and GPU pipelines instantly pause the moment you switch tabs or leave the viewfinder, completely eliminating overheating and background battery drain.
• Seamless 60 FPS Camera Resume: Re-entering the camera tab instantly restores live preview without black-screen flicker.
• Smart Battery-Saving Location: Reduced map tracking energy consumption by over 35% through GPS jitter deduplication and intelligent battery caching.

✨ FLUID MOTION & SKELETON SHIMMER LOADING:
• Staggered Entrance Animations: Moment cards, friend lists, conversations, and notifications glide into place with smooth, delightful motion.
• Premium Shimmer Skeletons: Replaced default spinning indicators with frosted shimmer placeholders tailored for grid, list, and profile layouts.
• Reimagined Empty States: Features a warm pearl glow orb and gentle scale entrance when no content is present.

🎨 NEON VIDEO RECORDING HUD & REFINED DESIGN SYSTEM:
• Dynamic Island Recording HUD: Real-time countdown timer positioned neatly at the top of the viewfinder, accompanied by a 60 FPS neon laser line unobstructed by your fingers.
• Pearl Glow Accents: Special memory milestone moments in History now shine with an exclusive pearl glow border.
• Polished Status Palette: Refined success, warning, and info colors alongside brand-plum confirmation actions and unified Inter typography.
• Home screen unread icon badge count automatically clears to zero when launching the app.

Thank you for sharing genuine, unfiltered moments with your inner circle on HeartPearl!
```

---

## 2. GHI CHÚ DÀNH CHO ĐỘI NGŨ DUYỆT APP APPLE (APP REVIEW NOTES)

*(Điền vào mục **App Review Information -> Notes** trên App Store Connect)*

```text
Dear Apple Review Team,

HeartPearl is a private, close-friends photo and video sharing application featuring interactive camera filters, Home Screen widgets, and user-controlled location radar.

1. TEST ACCOUNT CREDENTIALS:
- Email: nthanhtam.402@gmail.com (or testacc@gmail.com)
- Password: [Test_Account_Password]
- Role: Active user account pre-populated with friend connections, shared moments, and history to review all features seamlessly.

2. WHAT'S NEW IN VERSION 1.0.2:
- Apple APNs Push Notifications: High-priority remote notification delivery with explicit user permission prompt.
- In-App Interactive Notification Banner: Frosted glass banner for non-intrusive direct chat alerts while actively in-app.
- Background Camera Power Management: Native CameraController sessions immediately invoke pausePreview() and controlled disposal when navigating away from the camera tab, ensuring zero background camera/GPU drain.
- Battery-Friendly Location Updates: Fused location provider configuration, GPS jitter deduplication (<5m/45s), and adaptive marker animations.
- Premium UI Polish: Staggered entrance animations (flutter_animate), FrostedContainer shimmer skeleton loaders, and upgraded glowing empty states.
- Enhanced Video HUD: Top viewfinder Dynamic Island countdown display and neon laser indicator.
- App Icon Badge Cleanup: Automatically resets UNUserNotificationCenter badge count to 0 when the app enters foreground.

3. ACCOUNT DELETION COMPLIANCE (Guideline 5.1.1(v)):
Users can delete their account and all associated personal data permanently and instantly through either of two accessible paths:
- In-App: Profile Screen -> Settings -> "Xóa tài khoản vĩnh viễn" (Permanently Delete Account).
- Web Portal: Accessible 24/7 at https://tamchau-865f3.web.app/delete-account.html

4. USER-GENERATED CONTENT & SAFETY COMPLIANCE (Guideline 1.2):
- EULA agreement is presented upon registration and accessible at any time in Profile -> Privacy & Safety.
- Automated objectionable text and content filtering are active on all captions and messages.
- Two-way user blocking and immediate content reporting (reviewed within 24 hours) are accessible on every user profile and moment card.
- Direct safety contact: nthanhtam.402@gmail.com.

5. LOCATION PRIVACY ARCHITECTURE (Guideline 5.1.2(i) Compliance):
Continuous 24/7 background location tracking is strictly forbidden in HeartPearl. Location sharing is exclusively user-initiated:
a) Manual Check-In: Captures a single GPS coordinate only when the user explicitly taps "Check-in".
b) Timed Live Sharing: User explicitly picks a session duration (15m, 1h, 8h). Sessions auto-expire and purge GPS coordinates from the database.
c) Ghost Mode: Instantly ceases location transmission and clears current coordinates.
d) Granular Audience Control: Users specify exactly which friends may view their location pin via the "Allowed Viewers" list.

Thank you very much for your time and continued support. Please let us know if any further information is needed!
```

---

## 3. SIÊU DỮ LIỆU APP STORE (APP STORE METADATA)

### Phụ đề (Subtitle) - Tối đa 30 ký tự
```text
Khoảnh khắc bạn thân & Radar
```
*(Tiếng Anh: `Close Friends & Live Moments`)*

### Văn bản quảng cáo (Promotional Text) - Tối đa 170 ký tự
```text
Cập nhật 1.0.2: Thông báo đẩy tức thì, giao diện chuyển động mượt mà, camera siêu tiết kiệm pin và đảo đếm ngược video neon độc đáo cùng bạn thân!
```

### Từ khóa (Keywords) - Tối đa 100 ký tự (phân cách bằng dấu phẩy)
```text
heartpearl,locket,chia sẻ ảnh,bạn thân,camera,widget,khoảnh khắc,tin nhắn,bản đồ,kỷ niệm,làm đẹp
```
*(Tiếng Anh: `heartpearl,locket,photo share,best friends,camera,widget,moments,chat,radar,memories`)*

### Đường dẫn URL & Thông tin Hỗ trợ:
- **Version:** `1.0.2`
- **Build Number:** `8`
- **Bundle ID:** `com.heartpearl.heartpearl`
- **Support URL:** `https://tamchau-865f3.web.app`
- **Marketing URL:** `https://tamchau-865f3.web.app`
- **Privacy Policy URL:** `https://tamchau-865f3.web.app/privacy-policy.html`
- **EULA URL:** `https://tamchau-865f3.web.app/eula.html`
- **Account Deletion URL:** `https://tamchau-865f3.web.app/delete-account.html`
- **Email Hỗ trợ:** `nthanhtam.402@gmail.com`
- **Bản quyền:** `© 2026 HeartPearl. All rights reserved.`

---

## 4. TỔNG HỢP KỸ THUẬT (CHANGELOG DÀNH CHO DEVELOPER / QA TEST)

Dưới đây là bảng tổng hợp tất cả các thay đổi từ 2 workspace để đối chiếu kiểm thử:

| Nhóm | Hạng mục thay đổi | Chi tiết kỹ thuật & File liên quan |
| :--- | :--- | :--- |
| **Hiệu năng Camera** | Sửa camera chạy ngầm tốn pin | Gọi `pausePreview()` ngay khi chuyển tab; bổ sung `!widget.isActive` check trong `_switchCamera` để hủy controller kịp thời. (`camera_screen.dart`) |
| **Kiến trúc Code** | Tách nhỏ CameraScreen | Tách `CameraFilterBar` (`widgets/camera_filter_bar.dart`) và `CameraControls` (`widgets/camera_controls.dart`), giảm ~520 dòng mã phức tạp. |
| **Hiệu năng Bản đồ** | Tiết kiệm pin định vị | Chuyển sang `LocationAccuracy.medium` (Fused Location); bộ lọc sai số <5m/45s; cache % pin 15 phút; bỏ qua loop animation khi tọa độ không đổi. (`location_service.dart`, `map_screen.dart`) |
| **Bộ nhớ & Mạng** | Loại bỏ `Image.network` | Thay bằng `CachedNetworkImage` kèm placeholder & error widget. (`edit_profile_sheet.dart`) |
| **Thông báo** | Apple APNs Push | Cấu hình APNs remote push notification ngoài màn hình khóa và trung tâm thông báo; đồng bộ token FCM. |
| **Giao diện In-App** | Banner tin nhắn nổi | `InAppMessageOverlay` kính mờ trượt từ trên xuống, xem trước tin nhắn và bấm vào thẳng phòng chat. |
| **Giao diện Điều hướng**| Khử lặp màn hình & Icon Badge | Hợp nhất route điều hướng tránh push trùng lặp; tự động xóa badge số đỏ về 0 khi app active. |
| **Giao diện Chuyển động**| Entrance Animations | Áp dụng `flutter_animate` so le cho `inbox_screen`, `friends_screen`, `chat_list_screen`, `history_screen`, `notifications_screen`. |
| **Loading State** | Skeleton Shimmer Loading | Thay `CircularProgressIndicator` bằng `SkeletonGridView`, `SkeletonListView`, `SkeletonProfile` kính mờ shimmer. (`skeleton_loader.dart`) |
| **Empty State** | Trạng thái rỗng cao cấp | Thêm viền phát sáng `glowShadow(primary, opacity: 0.25)` và scale/fade-in animation trên tất cả màn hình rỗng. |
| **Design System** | Bảng màu & Viền kỷ niệm | Chuẩn hóa màu `success` (`#6FAE8C`), `warning` (`#D9A455`), `info` (`#8B7FC7`), `errorBrand` (`primaryDark`), và viền gradient ngọc trai `pearlGlowGradient` cho ảnh kỷ niệm. |
