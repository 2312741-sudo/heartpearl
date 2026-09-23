# HEARTPEARL - BẢN THÔNG TIN CẬP NHẬT APP STORE (VERSION 1.0.2 - BUILD 8)

> Tài liệu này được biên soạn sẵn để bạn có thể copy-paste trực tiếp vào **App Store Connect** khi nộp bản build `1.0.2` (Build `8`).

---

## 1. NỘI DUNG "CÓ GÌ MỚI TRONG PHIÊN BẢN NÀY" (WHAT'S NEW)

### 🇻🇳 Phiên bản Tiếng Việt (Vietnamese)
```text
Chào mừng bạn đến với phiên bản 1.0.2 của HeartPearl! Trong bản cập nhật này:

• THÔNG BÁO ĐẨY TỨC THÌ (PUSH NOTIFICATIONS): Không bao giờ bỏ lỡ tin nhắn và khoảnh khắc từ bạn thân! HeartPearl hiện đã hỗ trợ đầy đủ thông báo pop-up ngoài màn hình khóa và trung tâm thông báo qua chuẩn Apple APNs tốc độ cao.
• BANNER THÔNG BÁO TIN NHẮN TRONG APP: Khi đang lướt camera hay xem bản đồ, tin nhắn mới sẽ trượt xuống nhẹ nhàng dưới dạng thanh kính mờ hiện đại, cho phép xem nhanh hoặc chạm để vào trò chuyện tức thì.
• PHÂN TÁCH HỘP THƯ TIN NHẮN RÕ RÀNG: Tin nhắn trò chuyện giờ đây nằm riêng biệt trong mục Chat, trả lại chuông thông báo cho các sự kiện kết bạn và tương tác khoảnh khắc.
• THANH ĐẾM NGƯỢC VIDEO NEON ĐỘC ĐÁO: Đột phá trải nghiệm quay video với thanh laser neon chạy mượt 60 FPS cùng Đảo ghi hình (Dynamic Island HUD) trên kính ngắm, hiển thị số giây đếm ngược rõ ràng mà không bị ngón tay che khuất.
• TỰ ĐỘNG LÀM SẠCH BIỂU TƯỢNG APP: Số thông báo đỏ trên biểu tượng app ngoài màn hình chính sẽ tự động được dọn sạch về 0 ngay khi bạn mở ứng dụng.
• TỐI ƯU HIỆU NĂNG & ĐỘ ỔN ĐỊNH: Nâng cao tốc độ khởi động, đồng bộ hóa kết nối và giảm thiểu tối đa độ trễ tin nhắn.

Cảm ơn bạn đã luôn đồng hành và chia sẻ những khoảnh khắc chân thực nhất cùng bạn bè thân thiết trên HeartPearl!
```

---

### 🇺🇸 Phiên bản Tiếng Anh (English)
```text
Welcome to HeartPearl 1.0.2! Here is what's new in this release:

• INSTANT PUSH NOTIFICATIONS: Never miss a beat from your best friends! Fully integrated Apple APNs remote push notifications now alert you on your Lock Screen and Notification Center the moment you receive a message or moment.
• IN-APP MESSAGE POPUP BANNER: Stay engaged without interruption. Incoming messages slide down smoothly in a frosted glass banner while browsing, letting you preview or tap to jump straight into the chat room.
• STREAMLINED NOTIFICATION INBOX: Direct messages are now neatly organized inside the Chat tab, keeping your notification bell dedicated exclusively to friend requests and social reactions.
• ALL-NEW NEON RECORDING HUD: Reimagined video recording experience featuring a smooth 60 FPS neon laser countdown line and an Island Recording HUD at the top of the viewfinder—keeping countdown timers easily visible and completely unobstructed by your thumb.
• SMART APP ICON BADGE RESET: The red unread badge counter on your home screen app icon now automatically clears to zero whenever you launch or return to the app.
• PERFORMANCE & STABILITY POLISH: Optimized cold-start times, refined real-time socket connections, and minimized message delivery latency.

Thank you for sharing genuine moments with your closest circle on HeartPearl!
```

---

## 2. GHI CHÚ DÀNH CHO ĐỘI NGŨ DUYỆT APP APPLE (APP REVIEW NOTES)

*(Điền vào mục **App Review Information -> Notes** trên App Store Connect)*

```text
Dear Apple Review Team,

HeartPearl is a close-friends live photo and video sharing app with live widgets, interactive camera filters, and private location radar.

1. Test Account Information:
- Email: nthanhtam.402@gmail.com (or testacc@gmail.com)
- Password: [Test_Account_Password]
- Role: Active user account pre-populated with friend connections and moment history to review all features seamlessly.

2. Push Notifications & APNs Integration:
- HeartPearl utilizes Apple Push Notification service (APNs) for high-priority direct message delivery and social friend interactions.
- Remote notifications entitlement (Push Notifications capability) and Background Modes (remote-notification) are fully configured.
- Push permissions are requested with explicit user consent upon launch, and notification presentation options are handled cleanly.
- Icon badge management utilizes UNUserNotificationCenter.setBadgeCount(0) on app active state.

3. Account Deletion Compliance (Guideline 5.1.1(v)):
Users can delete their account and all associated personal data instantly and permanently in two ways:
- In-App: Profile -> Settings -> Delete Account permanently.
- Web Portal: Accessible at https://tamchau-865f3.web.app/delete-account.html

4. User Generated Content & Safety Compliance (Guideline 1.2):
- EULA agreement is presented upon registration and accessible anytime in Profile.
- Automated objectionable text and content filtering are active.
- Two-way user blocking and immediate 24h content reporting mechanism are fully implemented.
- Technical support and reporting contact: nthanhtam.402@gmail.com.

5. Location Privacy Architecture (Guideline 5.1.2(i) Compliance):
- Automatic continuous 24/7 background location tracking is strictly prohibited in HeartPearl.
- Location sharing operates strictly via explicit user-initiated mechanisms:
  a) Manual Check-In: Captures a single GPS fix only when the user explicitly taps "Check-in".
  b) Timed Live Sharing: The user explicitly selects a session duration (15m, 1h, 8h). Sessions automatically expire and clean up GPS coordinates from Firestore.
  c) Ghost Mode: Instantly erases all location coordinates and stops sharing immediately.
  d) Granular Audience Control: Users select specifically which friends can see their pin via Allowed Viewers list.

6. Version 1.0.2 Improvements:
- Full Apple APNs remote push notification delivery for outside-app alerts.
- In-app interactive message popup banner for non-intrusive chat notifications.
- Re-architected camera countdown UI: top neon laser progress bar + Dynamic Island recording HUD.
- Separation of chat messages from general notifications.
- Automatic app icon badge reset on active state.

Please let us know if any further information is needed. Thank you for your review!
```

---

## 3. THÔNG TIN HỖ TRỢ & BẢN QUYỀN (SUPPORT & COPYRIGHT)

- **Version:** `1.0.2`
- **Build Number:** `8`
- **Bundle ID:** `com.heartpearl.heartpearl`
- **Support URL:** `https://tamchau-865f3.web.app`
- **Marketing URL:** `https://tamchau-865f3.web.app`
- **Privacy Policy URL:** `https://tamchau-865f3.web.app/privacy-policy.html`
- **EULA URL:** `https://tamchau-865f3.web.app/eula.html`
- **Account Deletion URL:** `https://tamchau-865f3.web.app/delete-account.html`
- **Support Contact Email:** `nthanhtam.402@gmail.com`
- **Copyright:** `© 2026 HeartPearl. All rights reserved.`
