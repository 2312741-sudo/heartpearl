# HEARTPEARL - BẢN THÔNG TIN CẬP NHẬT APP STORE (VERSION 1.0.1)

> Tài liệu này được biên soạn sẵn để bạn có thể copy-paste trực tiếp vào **App Store Connect** khi nộp bản build `1.0.1` (Build `7`).

---

## 1. NỘI DUNG "CÓ GÌ MỚI TRONG PHIÊN BẢN NÀY" (WHAT'S NEW)

### 🇻🇳 Phiên bản Tiếng Việt (Vietnamese)
```text
Chào mừng bạn đến với phiên bản 1.0.1 của HeartPearl! Trong bản cập nhật này:

• TẢI ẢNH & VIDEO VỀ MÁY: Giờ đây bạn có thể dễ dàng lưu lại mọi khoảnh khắc đáng nhớ trực tiếp vào Thư viện ảnh của điện thoại (hỗ trợ cả ảnh vừa chụp lẫn ảnh trong lịch sử).
• CHIA SẺ VỊ TRÍ AN TOÀN & TIẾT KIỆM PIN: Cải tiến toàn diện cơ chế vị trí sang Check-in chủ động và phiên chia sẻ có thời hạn tự động kết thúc, tôn trọng tối đa quyền riêng tư và tối ưu thời lượng pin.
• TỐI ƯU CÔNG THÁI HỌC CAMERA: Cụm nút chụp ảnh được tinh chỉnh hạ thấp giúp thao tác chụp một tay cực kỳ thuận tiện.
• THANH CƯỜNG ĐỘ BỘ LỌC MỚI: Thanh điều chỉnh độ đậm nhạt của bộ lọc được đặt ngay trên nút chụp, giúp khung hình camera cố định 100% mượt mà, không còn hiện tượng giật màn hình.
• CẢI TIẾN WIDGET & BẢN ĐỒ: Khắc phục triệt để lỗi khi mở ứng dụng từ Home Widget, mang lại trải nghiệm xem vị trí bạn bè mượt mà và tức thì.
• LIÊN KẾT & HỖ TRỢ TRỰC TIẾP: Tất cả các đường link chính sách, thỏa thuận người dùng và cổng hỗ trợ kỹ thuật hiện đã có thể bấm mở trực tiếp trên trình duyệt.

Cảm ơn bạn đã luôn đồng hành và chia sẻ những khoảnh khắc chân thực nhất cùng bạn bè thân thiết trên HeartPearl!
```

---

### 🇺🇸 Phiên bản Tiếng Anh (English)
```text
Welcome to HeartPearl 1.0.1! Here is what's new:

• SAVE PHOTOS & VIDEOS TO DEVICE: Easily save your live moments and memorable memories directly to your Photo Library (supported for both freshly taken shots and past history moments).
• PRIVACY-FIRST LOCATION SHARING: Upgraded to explicit user-initiated check-ins and time-limited live sharing sessions with automatic expiry, maximizing battery life and location privacy.
• OPTIMIZED CAMERA CONTROLS: Refined shutter and action buttons positioned closer to your thumb for effortless one-handed shooting.
• ENHANCED FILTER INTENSITY SLIDER: Seamlessly adjust filter intensity right above the shutter button with a zero-jitter, full-preview camera experience.
• IMPROVED WIDGET & MAP NAVIGATION: Resolved widget deep link navigation for smooth, single-instance map viewing when tapping your Home Widget.
• INTERACTIVE LINKS & SUPPORT: Quick direct access to support, privacy policy, and account management portals directly in your browser.

Thank you for sharing genuine moments with your closest circle on HeartPearl!
```

---

## 2. GHI CHÚ DÀNH CHO ĐỘI NGŨ DUYỆT APP APPLE (APP REVIEW NOTES)

*(Điền vào mục **App Review Information -> Notes** trên App Store Connect)*

```text
Dear Apple Review Team,

HeartPearl is a close-friends live photo and video sharing app with live widgets and location radar.

1. Test Account Information:
- Email: review_test@heartpearl.com (or test phone number configured in Firebase Auth)
- Password: [Password_Here]
- Role: Active user with sample friends and moments to review all features.

2. Account Deletion Compliance (Guideline 5.1.1(v)):
Users can delete their account and all associated personal data instantly and permanently in two ways:
- In-App: Profile -> Settings -> Delete Account permanently.
- Web Portal: Accessible at https://tamchau-865f3.web.app/delete-account.html

3. User Generated Content & Safety Compliance (Guideline 1.2):
- EULA agreement is presented upon registration and accessible anytime in Profile.
- Automated objectionable text and content filtering are active.
- Two-way user blocking and immediate 24h content reporting mechanism are fully implemented.
- Technical support and reporting contact: nthanhtam.402@gmail.com.

4. Location Privacy Architecture (Guideline 5.1.2(i) Compliance):
- Automatic continuous 24/7 background location tracking is never used.
- Location sharing operates strictly via explicit user-initiated mechanisms:
  a) Manual Check-In: Captures a single GPS fix only when the user explicitly taps "Check-in" (foreground-only).
  b) User-Initiated Timed Live Sharing: The user explicitly selects a session duration (1h, until end of day, unlimited). During an active live session, background updates are delivered with a prominent system indicator (showsBackgroundLocationIndicator=true / Dynamic Island blue pill) so the user's close circle can see their live journey while the phone is locked or in a pocket. The session automatically terminates upon expiry or when the user taps "Stop Live".
  c) Ghost Mode: Instantly erases all location coordinates and stops sharing immediately.
  d) Granular Audience Control: Users select specifically which friends can see their pin via Allowed Viewers list.

5. Version 1.0.1 Improvements:
- Added in-app photo & video downloading feature to local Photo Library (requires NSPhotoLibraryAddUsageDescription).
- Camera UI layout enhancement for better ergonomics.
- Fix Home Widget navigation flow.
- Direct external link launching for user safety & transparency.

Please let us know if any further information is needed. Thank you for your review!
```

---

## 3. THÔNG TIN HỖ TRỢ & BẢN QUYỀN (SUPPORT & COPYRIGHT)

- **Support URL:** `https://tamchau-865f3.web.app`
- **Marketing URL:** `https://tamchau-865f3.web.app`
- **Privacy Policy URL:** `https://tamchau-865f3.web.app/privacy-policy.html`
- **Support Contact Email:** `nthanhtam.402@gmail.com`
- **Copyright:** `© 2026 HeartPearl. All rights reserved.`
