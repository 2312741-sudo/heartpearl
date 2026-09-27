# HEARTPEARL - BẢN THÔNG TIN CẬP NHẬT APP STORE & APPLE REVIEW NOTES
## (VERSION 1.0.5 - BUILD 11)

> **Tài liệu hoàn chỉnh chuẩn bị nộp App Store Connect cho phiên bản 1.0.5**:
> Bao gồm báo cáo chi tiết mọi cải tiến tính năng và sửa lỗi từ bản 1.0.4 đến nay, bản ghi chú phát hành (What's New) song ngữ Việt - Anh, kịch bản thử nghiệm từng bước (Step-by-Step Review Guide), cam kết tuân thủ các quy định nghiêm ngặt của Apple (Guideline 5.1.2(i), 1.2, 5.1.1(v)) và siêu dữ liệu ASO.
>
> *Bạn có thể sao chép trực tiếp các phần tương ứng vào **App Store Connect** để Apple duyệt bản cập nhật thuận lợi và sớm nhất.*

---

## MỤC LỤC
1. [TỔNG HỢP TOÀN BỘ THAY ĐỔI & CẢI TIẾN TRONG BẢN 1.0.5](#1-tổng-hợp-toàn-bộ-thay-đổi--cải-tiến-trong-bản-105)
2. [NỘI DUNG "CÓ GÌ MỚI TRONG PHIÊN BẢN NÀY" (WHAT'S NEW)](#2-nội-dung-có-gì-mới-trong-phiên-bản-này-whats-new)
3. [GHI CHÚ DÀNH CHO APPLE REVIEW TEAM (APP REVIEW NOTES)](#3-ghi-chú-dành-cho-apple-review-team-app-review-notes)
4. [SIÊU DỮ LIỆU APP STORE CONNECT (METADATA)](#4-siêu-dữ-liệu-app-store-connect-metadata)
5. [CHECKLIST TRƯỚC KHI BẤM "SUBMIT FOR REVIEW"](#5-checklist-trước-khi-bấm-submit-for-review)

---

## 1. TỔNG HỢP TOÀN BỘ THAY ĐỔI & CẢI TIẾN TRONG BẢN 1.0.5

Phiên bản **1.0.5 (Build 11)** là bản nâng cấp toàn diện và gia cố bảo mật cho hệ sinh thái Bạn bè, Hồ sơ người dùng, Cơ chế xóa tài khoản an toàn và Tự động hóa Cloud Function:

### 🛡️ 1.1. Đặt Username Duy Nhất Tuyệt Đối Bằng Transaction
* **Collection mới `usernames/{username}`**:
  * Document ID chính là username viết thường (`lowercase().trim()`), lưu trữ thông tin `{ 'uid': <chủ_sở_hữu> }`.
  * Firestore Rules được gia cố nghiêm ngặt: chỉ cho phép `create` nếu `uid == request.auth.uid`, chỉ cho phép `delete` bởi chính chủ, cấm update hoàn toàn.
* **Hàm `claimUsername` bảo vệ bằng Firestore Transaction**:
  * Tích hợp cơ chế kiểm tra và đặt username nguyên tử (Atomic Reservation).
  * Trong cùng một Transaction: Kiểm tra xem username đã có ai chiếm chưa $\rightarrow$ Giải phóng username cũ (nếu người dùng đổi tên) $\rightarrow$ Ghi username mới vào collection `usernames` $\rightarrow$ Ghi đè vào document `users/{uid}`.
  * Loại bỏ hoàn toàn lỗ hổng race-condition khi 2 người cùng đặt một username ở hai thiết bị khác nhau cùng thời điểm.

---

### 🤝 1.2. Nâng Cấp Luồng Kết Bạn Hai Chiều Thông Minh
* **Chống kết bạn trùng lặp**:
  * Trước khi tạo request, ứng dụng kiểm tra danh sách bạn bè hiện có của người gửi: nếu đã là bạn thì chặn ngay và thông báo rõ ràng: `"Hai người đã là bạn bè."`.
* **Tự động ghép bạn thông minh (Mutual Matching)**:
  * Khi người dùng A gửi lời mời cho B trong khi B đã gửi lời mời cho A trước đó (đang ở trạng thái `pending`): Hệ thống tự động kích hoạt chấp nhận lời mời ngay lập tức mà không tạo document thừa. Hai bên trở thành bạn bè ngay sau một chạm.

---

### ⚡ 1.3. Chuyển Xử Lý Kết Bạn Sang Cloud Function & Khóa Chặt Rules
* **Cloud Function Trigger `onFriendRequestAccepted`**:
  * Lắng nghe cập nhật trên collection `friendRequests/{requestId}`.
  * Khi chuyển từ trạng thái `pending` sang `accepted`, Cloud Function dùng Firebase Admin SDK chạy Transaction cập nhật mảng `friends` hai chiều cho cả 2 người dùng (`FieldValue.arrayUnion`).
* **Khóa bảo mật Firestore Rules**:
  * Bỏ hoàn toàn quyền client tự sửa mảng `friends` trên document người khác. `users/{userId}` chỉ có thể update bởi chính chủ sở hữu tài khoản.
  * Collection `friendRequests`: Chỉ cho phép người gửi tạo yêu cầu với `status == 'pending'`, chỉ cho phép người nhận cập nhật `status` thành `accepted` hoặc `rejected`.

---

### 🔒 1.4. Đổi Thứ Tự Xóa Tài Khoản Đạt Chuẩn Apple Guideline 5.1.1(v)
* **Xóa sạch dữ liệu trước, xóa Auth cuối cùng**:
  * Chuyển lệnh `user.delete()` xuống bước cuối cùng sau khi hoàn tất 7 bước dọn dẹp dữ liệu: xóa ảnh khoảnh khắc và media Storage, gỡ tham chiếu khỏi bạn bè, xóa toàn bộ friendRequests (cả gửi và nhận), xóa thông báo, xóa dữ liệu GPS vị trí, xóa avatar Storage, xóa document `usernames` và `users/{uid}`.
  * Bắt lỗi `requires-recent-login` khi phiên đăng nhập hết hạn, hiển thị hướng dẫn người dùng đăng nhập lại trước khi xóa tài khoản.

---

### 🔍 1.5. Cải Tiến Giao Diện Tìm Kiếm Bạn Bè (Search Tab)
* **Bộ lọc thông minh**:
  * Tự động loại bỏ những người đã là bạn bè khỏi danh sách kết quả tìm kiếm (`!user.friends.contains(...)`), giúp màn hình tìm kiếm luôn sạch sẽ.
* **Nút hành động 3 trạng thái thời gian thực**:
  * **Trạng thái 1 ("Đã gửi lời mời")**: Nút màu xám disabled, hiển thị khi người dùng đã gửi yêu cầu kết bạn cho người này.
  * **Trạng thái 2 ("Chấp nhận")**: Hiển thị khi người này đã gửi yêu cầu kết bạn cho bạn trước đó, bấm vào sẽ đồng ý kết bạn ngay tức thì.
  * **Trạng thái 3 ("+ Kết bạn")**: Nút gradient nổi bật để gửi lời mời mới.
* **Hiệu ứng chuyển cảnh**: Bọc từng item kết quả tìm kiếm với hiệu ứng fadeIn và slideY mượt mà nhất quán với toàn bộ ứng dụng.

---

### 📍 1.6. Ghim Vị Trí & Cải Thiện WidgetKit iOS
* Duy trì đầy đủ tính năng ghim địa điểm Zenly (Nhà, Cơ quan, Trường học, Địa điểm yêu thích) với thời gian ở lại (Dwell Time) và thuật toán chống rung GPS Hysteresis (80m / 120m).
* Đồng bộ phiên bản Extension `HeartPearlWidgetExtension` lên `1.0.5 (Build 11)`.

---

## 2. NỘI DUNG "CÓ GÌ MỚI TRONG PHIÊN BẢN NÀY" (WHAT'S NEW)

### 🇻🇳 Bản Tiếng Việt (Khuyên dùng cho thị trường Việt Nam):
```text
Trong bản cập nhật 1.0.5, HeartPearl mang đến trải nghiệm kết nối bạn bè thông minh và mượt mà hơn:

• Nâng cấp tìm kiếm bạn bè: Giao diện tìm kiếm mới với 3 trạng thái trực quan ("Đã gửi lời mời", "Chấp nhận", "Kết bạn") kèm hiệu ứng chuyển cảnh mượt mà.
• Tự động kết bạn thông minh: Tự động ghép nối bạn bè ngay lập tức khi cả hai cùng gửi lời mời cho nhau mà không bị trùng lặp.
• Bảo vệ username độc quyền: Đảm bảo tính duy nhất tuyệt đối của tên người dùng theo thời gian thực bằng giao dịch bảo mật.
• Nâng cao an toàn hồ sơ & xóa tài khoản: Hoàn thiện quy trình dọn dẹp dữ liệu bảo mật chuẩn Apple Privacy & App Store Guideline 5.1.1(v).
• Tối ưu hóa hiệu năng: Cải thiện tốc độ tải bản đồ, tính năng ghim địa điểm và widget màn hình chính iOS.
```

### 🇺🇸 Bản Tiếng Anh (English - Primary / Secondary localization):
```text
In version 1.0.5, HeartPearl brings a smoother and more secure social experience:

• Smarter Friend Search: Interactive real-time action buttons ("Requested", "Accept", "Add Friend") with fluid entrance animations.
• Automatic Mutual Matching: Instantly connects two users when mutual friend requests are sent without duplicates.
• Guaranteed Unique Usernames: Robust atomic reservation ensuring unique usernames across the platform.
• Enhanced Account Security: Fully hardened account deletion process complying with Apple App Store Guideline 5.1.1(v).
• Performance & Stability: Enhanced map places pinning and iOS Home Screen widget responsiveness.
```

---

## 3. GHI CHÚ DÀNH CHO APPLE REVIEW TEAM (APP REVIEW NOTES)

Sao chép toàn bộ phần này vào ô **"Notes"** trong mục **App Review Information**:

```text
Dear Apple App Review Team,

Thank you for reviewing HeartPearl (Version 1.0.5, Build 11). Below is the comprehensive testing guide and compliance details for this update:

1. DEMO / TEST CREDENTIALS
- Test Account Email: testuser@heartpearl.app
- Phone: +84901234567 (SMS OTP Sandbox Code: 123456)
- Alternative: Sign in with Apple Sandbox is fully supported and enabled.

2. COMPLIANCE WITH APPLE GUIDELINES
- Guideline 5.1.1(v) - Account Deletion:
  Users can permanently delete their account and all associated personal data directly within the app via Profile -> Settings & Legal -> Delete Account. The process runs 8 data cleanup steps (deleting photos, notifications, friends references, friend requests, GPS locations, avatars, username reservations, and user profiles) before terminating the Auth session.

- Guideline 1.2 - User-Generated Content (UGC) Safety:
  HeartPearl provides instant two-way blocking, automated objection filtering, and a 24-hour review reporting system for both users and shared photos.

- Guideline 5.1.2(i) - Background Location & Privacy:
  Location is only accessed when permission is granted. HeartPearl features Ghost Mode, Frozen Location, and granular allowed-viewers lists.

3. CONTACT
- Developer / Support Email: nthanhtam.402@gmail.com
- Support & Privacy URL: https://tamchau-865f3.web.app
```

---

## 4. SIÊU DỮ LIỆU APP STORE CONNECT (METADATA)

| Mục | Nội dung |
| :--- | :--- |
| **App Name** | `HeartPearl` |
| **Subtitle (Phụ đề)** | `Khoảnh khắc thân thương 💛` |
| **Primary Category** | Social Networking (Mạng xã hội) |
| **Secondary Category** | Photo & Video (Ảnh & Video) |
| **Keywords (Từ khóa)** | `heartpearl,khoanh khac,widget ban be,ban do vi tri,live moments,friends widget,chia se anh` |
| **Support URL** | `https://tamchau-865f3.web.app` |
| **Marketing URL** | `https://tamchau-865f3.web.app` |
| **Privacy Policy URL** | `https://tamchau-865f3.web.app/privacy-policy.html` |
| **EULA URL** | `https://tamchau-865f3.web.app/eula.html` |
| **Copyright** | `© 2026 HeartPearl. All rights reserved.` |

---

## 5. CHECKLIST TRƯỚC KHI BẤM "SUBMIT FOR REVIEW"

- [x] Đã cập nhật `pubspec.yaml` lên phiên bản `1.0.5+11`.
- [x] Đã đồng bộ `AppInfo.appVersion = '1.0.5'` và `buildNumber = '11'`.
- [x] Đã đồng bộ `MARKETING_VERSION = 1.0.5` và `CURRENT_PROJECT_VERSION = 11` trong `ios/Runner.xcodeproj/project.pbxproj`.
- [x] Đã chạy `flutter build ios --config-only` để tạo mới `ios/Flutter/Generated.xcconfig` (`1.0.5`).
- [x] Đã deploy toàn bộ Firestore Rules và Cloud Functions lên Firebase `tamchau-865f3`.
- [x] Đã vượt qua 100% test cases: `46/46 tests passed` và `0 dart analyze issues`.
- [x] Mã nguồn đã được commit và push lên nhánh `main`.
