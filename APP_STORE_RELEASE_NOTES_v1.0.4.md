# HEARTPEARL - BẢN THÔNG TIN CẬP NHẬT APP STORE & APPLE REVIEW NOTES
## (VERSION 1.0.4 - BUILD 10)

> **Tài liệu hoàn chỉnh chuẩn bị nộp App Store Connect cho phiên bản 1.0.4**:
> Bao gồm báo cáo chi tiết mọi cải tiến tính năng và sửa lỗi từ bản 1.0.2 đến nay, bản ghi chú phát hành (What's New) song ngữ Việt - Anh, kịch bản thử nghiệm từng bước (Step-by-Step Review Guide), cam kết tuân thủ các quy định nghiêm ngặt của Apple (Guideline 5.1.2(i), 1.2, 5.1.1(v)) và siêu dữ liệu ASO.
>
> *Bạn có thể sao chép trực tiếp các phần tương ứng vào **App Store Connect** để Apple duyệt bản cập nhật thuận lợi và sớm nhất.*

---

## MỤC LỤC
1. [TỔNG HỢP TOÀN BỘ THAY ĐỔI & CẢI TIẾN TÍNH TỪ BẢN 1.0.2](#1-tổng-hợp-toàn-bộ-thay-đổi--cải-tiến-tính-từ-bản-102)
2. [NỘI DUNG "CÓ GÌ MỚI TRONG PHIÊN BẢN NÀY" (WHAT'S NEW)](#2-nội-dung-có-gì-mới-trong-phiên-bản-này-whats-new)
3. [GHI CHÚ DÀNH CHO APPLE REVIEW TEAM (APP REVIEW NOTES)](#3-ghi-chú-dành-cho-apple-review-team-app-review-notes)
4. [SIÊU DỮ LIỆU APP STORE CONNECT (METADATA)](#4-siêu-dữ-liệu-app-store-connect-metadata)
5. [CHECKLIST TRƯỚC KHI BẤM "SUBMIT FOR REVIEW"](#5-checklist-trước-khi-bấm-submit-for-review)

---

## 1. TỔNG HỢP TOÀN BỘ THAY ĐỔI & CẢI TIẾN TÍNH TỪ BẢN 1.0.2

Phiên bản **1.0.4 (Build 10)** là bản cập nhật quan trọng, mang đến những cải tiến vượt trội về trải nghiệm bản đồ thời gian thực, độ tin cậy của dịch vụ định vị GPS ngầm, bảo mật dữ liệu và khắc phục các vấn đề phát sinh:

### 📍 1.1. Ghim Địa Điểm Thủ Công & Dwell Time (Phong cách Zenly)
* **Ghim địa điểm thủ công**: Người dùng chủ động ghim và đặt tên các địa điểm thân thuộc:
  * 🏠 **Nhà** (Home)
  * 🏢 **Nơi làm việc** (Work)
  * 🏫 **Trường học** (School)
  * 📍 **Địa điểm yêu thích / Tùy chỉnh** (Custom Place)
* **Thao tác nhanh gọn & tiện lợi**:
  * Ghim nhanh tọa độ hiện tại qua nút **Ghim địa điểm** trên thanh công cụ nổi.
  * Hoặc **Nhấn giữ (Long Press)** bất kỳ điểm nào trên bản đồ để ghim chính xác vị trí đó.
  * Quản lý, đổi tên, đổi icon hoặc xóa địa điểm trực quan trong bảng điều khiển.
* **Thời gian ở lại (Zenly Dwell Time)**:
  * Tự động nhận diện khi người dùng bước vào địa điểm và bắt đầu đếm thời gian: `"Vừa đến"`, `"15 phút"`, `"2 giờ"`, `"1g 30p"`, `"3 ngày"`.
  * Hiển thị **Floating Pill** bo tròn ngay trên Avatar của bạn bè trên bản đồ.
  * Đính kèm biểu tượng mini emoji (🏠, 🏢, 🏫, 📍) ở góc Avatar.
* **Thuật toán Geofencing Hysteresis (Chống rung GPS)**:
  * Bán kính bước vào: $\le 80\text{m}$.
  * Bán kính duy trì (Hysteresis): $\le 120\text{m}$ (ngăn chặn GPS jitter khiến trạng thái nhảy liên tục khi ở trong nhà).
  * Tự động giải phóng trạng thái khi tốc độ di chuyển $> 15\text{ km/h}$ hoặc vượt ngoài $120\text{m}$.
  * Mốc thời gian đến (`arrivedAt`) được bảo lưu liên tục khi còn trong địa điểm, không bị reset khi GPS cập nhật điểm mới.

---

### 🗺️ 1.2. Thiết Kế Lại Toàn Diện Giao Diện Bản Đồ (MapScreen Redesign)
* **Bản đồ tràn viền (Edge-to-Edge)**:
  * Bỏ các nút zoom `+` và `-` tĩnh dư thừa (thay bằng thao tác cử chỉ pinch-to-zoom 2 ngón tay mượt mà chuẩn iOS).
  * Cảm giác thoáng đãng, hiện đại, tối ưu không gian hiển thị.
* **Cụm điều khiển nổi (Floating Stack) bên phải**:
  * 📍 **Ghim địa điểm** (`mapPinPlus`): Mở bảng thêm và quản lý địa điểm.
  * 🎯 **Định vị tôi** (`locateFixed`): Đưa bản đồ về vị trí của mình với hiệu ứng animate nhẹ nhàng.
  * 🗺️ **Kiểu bản đồ** (`layers`): Chuyển đổi linh hoạt giữa Bản đồ tối (Dark Mode), Đường phố (Street), và Ảnh vệ tinh (Satellite) — tự động lưu lựa chọn.
  * 🛡️ **Quyền riêng tư** (`shieldCheck`): Mở cài đặt Ghost Mode, Đóng băng vị trí, và danh sách người được xem.
* **Băng chuyền bạn bè ở đáy màn hình (Bottom Friend Carousel)**:
  * Thẻ bo góc hiển thị Avatar tròn, Tên, Phần trăm pin 🔋 %, Trạng thái online, và Badge địa điểm `🏠 Nhà · 2 giờ`.
  * Vuốt ngang chọn bạn bè, chạm vào để camera bản đồ tự động bay tới vị trí người đó.
* **Thẻ chi tiết bạn bè (Friend Details Sheet)**:
  * Hiển thị Card địa điểm lớn phong cách Zenly với icon to rõ, tên nơi ở, thời gian đã ở đó, tốc độ di chuyển và các nút tắt chỉ đường / nhắn tin nhanh.

---

### 🔄 1.3. Khôi Phục Tự Động GPS Chia Sẻ Sau Khi Tắt/Mở App (Part A)
* **Khắc phục triệt để lỗi mất GPS sau khi khởi động lại app**:
  * Trước đây khi đóng app và mở lại, hệ thống chỉ khôi phục trạng thái hiển thị nhưng không kích hoạt lại luồng GPS (`getPositionStream`) thật sự.
  * Đã tách lõi luồng định vị thành `_beginLiveStream()` và xây dựng cơ chế `resumeLiveSharingIfNeeded()`.
  * Khi mở app, hệ thống tự động kiểm tra phiên chia sẻ còn hạn từ Realtime Database / Firestore, khôi phục lại GPS stream phần cứng, kết nối WebSocket và thiết lập lại timer heartbeat 45 giây.

---

### ⏱️ 1.4. Sửa Lỗi Đồng Hồ Đếm Ngược Phiên Chia Sẻ Vị Trí (Part B)
* **Sửa lỗi không bao giờ đếm lùi**:
  * Trước đây hàm `countdownLabel` tự động tính lại mốc hết hạn bằng "thời điểm hiện tại + 1 giờ" mỗi lần giao diện render, khiến đồng hồ luôn bị reset và không bao giờ đếm lùi.
  * Đã cập nhật phương thức nhận tham số cố định `fixedExpiresAt: _currentExpiresAt` lưu từ thời điểm bắt đầu phiên, giúp thời gian đếm ngược chính xác tuyệt đối từng phút (`"Hết hạn sau 45 phút"`).

---

### 🛡️ 1.5. Cập Nhật Bộ Quy Tắc Bảo Mật Firebase Toàn Diện (Parts C & D)
* **Firestore Security Rules (`firestore.rules`)**:
  * Mở rộng `validLocationDocument` từ 9 trường lên đủ 18 trường (`lat`, `lng`, `isOnline`, `liveSessionActive`, `shareExpiresAt`, `shareDurationLabel`, `currentPlaceType`, `currentPlaceLabel`, `arrivedAt`), loại bỏ hoàn toàn lỗi `permission-denied` khi đồng bộ vị trí.
* **Realtime Database Security Rules (`database.rules.json`)**:
  * Thiết lập và triển khai bộ quy tắc bảo mật mới cho đường dẫn `locations/$uid`: chỉ chủ sở hữu mới có quyền ghi; chỉ bạn bè trong danh sách `allowedViewers` mới có quyền đọc khi `isSharing == true`.

---

### ⚙️ 1.6. Tối Ưu Hệ Thống Biên Dịch iOS & Khắc Phục Lỗi Xây Dựng (Xcode & CocoaPods)
* **Cập nhật Scheme & Build Order (`Runner.xcscheme`)**:
  * Bổ sung mục `Pods-Runner` vào danh sách bắt buộc biên dịch trước `Runner.app`.
  * Tắt `parallelizeBuildables` trong scheme để loại bỏ hiện tượng race-condition khi liên kết thư viện.
  * Chuyển cấu hình `LaunchAction` về `Debug` khi chạy trên máy ảo hoặc thiết bị kiểm thử.
* **Khắc phục đường dẫn cấu hình CocoaPods**:
  * Bổ sung đường dẫn nạp `#include? "../Pods/Target Support Files/..."` chuẩn xác trong `Debug.xcconfig` và `Release.xcconfig`.
* **Vô hiệu hóa sinh mã tài nguyên không tương thích**:
  * Đặt `ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = NO` và `STRING_CATALOG_GENERATE_SYMBOLS = NO` nhằm ngăn chặn các cảnh báo lỗi file sinh mã tạm thời trong Xcode 15/16.

---

## 2. NỘI DUNG "CÓ GÌ MỚI TRONG PHIÊN BẢN NÀY" (WHAT'S NEW)

*(Sao chép vào ô **What's New in This Version** trên App Store Connect)*

### 🇻🇳 Tiếng Việt (Bản Tiếng Việt - Tối đa 4000 ký tự)

```text
Phiên bản 1.0.4 mang đến trải nghiệm bản đồ thời gian thực hoàn toàn mới và nâng cao độ tin cậy vượt bậc:

📍 GHIM ĐỊA ĐIỂM & ĐO THỜI GIAN Ở LẠI (DWELL TIME)
- Tự do ghim và đặt tên các địa điểm thân thuộc: Nhà, Nơi làm việc, Trường học hoặc Địa điểm tùy chỉnh yêu thích.
- Thao tác ghim cực nhanh qua nút trên bản đồ hoặc chỉ cần nhấn giữ bất kỳ điểm nào.
- Tự động nhận diện khi bạn hoặc bạn bè ghé thăm địa điểm và hiển thị thời gian đã ở đó ("Vừa đến", "25 phút", "2 giờ",...).

🗺️ GIAO DIỆN BẢN ĐỒ MỚI TINH GỌN & HIỆN ĐẠI
- Bản đồ tràn viền Edge-to-Edge mang lại tầm nhìn thoáng đãng và rộng rãi.
- Cụm điều khiển nổi thông minh: Ghim địa điểm, Định vị tôi, Chuyển đổi lớp bản đồ (Sáng, Tối, Vệ tinh), và Cài đặt quyền riêng tư nhanh chóng.
- Băng chuyền bạn bè ở đáy màn hình giúp bạn dễ dàng theo dõi vị trí, mức pin và trạng thái của người thân chỉ bằng một cái chạm nhẹ.

⚡ NÂNG CAO ĐỘ TIN CẬY & SỬA LỖI
- Luồng GPS chia sẻ vị trí trực tiếp luôn hoạt động ổn định và tự động kết nối lại mượt mà sau khi mở lại ứng dụng.
- Sửa lỗi đồng hồ đếm ngược phiên chia sẻ vị trí giúp thời gian hiển thị chính xác từng phút.
- Tối ưu hóa hiệu năng, giảm tiêu hao năng lượng pin và nâng cao khả năng bảo mật dữ liệu riêng tư.

Cảm ơn bạn đã luôn tin tưởng và đồng hành cùng HeartPearl!
```

---

### 🇺🇸 English (Bản Tiếng Anh - Tối đa 4000 ký tự)

```text
Version 1.0.4 brings a completely redesigned live map experience and major improvements to location tracking reliability:

📍 PINNED PLACES & DWELL TIME (ZENLY-STYLE)
- Easily pin and name your meaningful places: Home, Work, School, or Favorite Spots.
- Quickly pin via the on-screen tool or simply long-press anywhere on the map.
- Automatic place visit detection showing how long your friends have stayed ("Just arrived", "25m", "2h",...).

🗺️ FRESH & INTUITIVE MAP INTERFACE
- Edge-to-edge map design maximizing your view and visual clarity.
- Floating control stack: Pin Place, Center on Me, Map Style Switcher (Street, Dark, Satellite), and Quick Privacy Settings.
- Bottom friends carousel allowing you to easily browse friends, battery levels, and places with smooth camera focus.

⚡ RELIABILITY IMPROVEMENTS & BUG FIXES
- Live location sharing now seamlessly resumes GPS streaming after app restarts.
- Fixed countdown timer display for timed sharing sessions to ensure minute-accurate remaining time.
- Enhanced battery efficiency, smoother map rendering, and hardened data privacy.

Thank you for choosing HeartPearl!
```

---

## 3. GHI CHÚ DÀNH CHO APPLE REVIEW TEAM (APP REVIEW NOTES)

*(Sao chép vào ô **App Review Information -> Notes** trên App Store Connect)*

```text
Dear Apple App Review Team,

Thank you for reviewing HeartPearl (Version 1.0.4, Build 10). Below is the comprehensive testing guide and compliance details for this submission.

==================================================
1. DEMO TEST ACCOUNTS
==================================================
The app features SMS OTP authentication via Firebase Phone Auth with pre-registered test phone numbers:

• Account 1 (Primary Test User):
  - Phone Number: +84988888888
  - Verification Code (OTP): 123456
  - Display Name: Tâm Châu

• Account 2 (Friend Account for Map & Sharing Testing):
  - Phone Number: +84988888889
  - Verification Code (OTP): 123456
  - Display Name: HeartPearl Friend

==================================================
2. KEY NEW FEATURES TO TEST IN VERSION 1.0.4
==================================================

A. PIN PLACES & DWELL TIME (Zenly-style):
1. Sign in with Account 1.
2. Navigate to the Map tab (center bottom bar icon).
3. Tap the "Pin Place" button (top button of the floating control stack on the right), or simply LONG-PRESS anywhere on the map.
4. Select place type (Home 🏠, Work 🏢, School 🏫, Custom 📍), enter a custom label, and save.
5. Notice that when the user enters within 80m of the place, the place badge and dwell time pill ("Just arrived", "15m", etc.) appear above the avatar. An advanced hysteresis buffer (120m) prevents GPS jitter when indoors.

B. MAP SCREEN REDESIGN:
1. Experience the edge-to-edge map layout with intuitive pinch-to-zoom gestures.
2. Use the floating control stack on the right:
   - Top button: Pin Place
   - Second button: Center on Me (animates camera back to user location)
   - Third button: Map Style Switcher (toggle Dark, Street, Satellite)
   - Bottom button: Location Privacy Settings (Ghost Mode / Frozen / Allowed Viewers)
3. Swipe horizontally on the bottom carousel to browse friends, inspect battery percentage, and tap any card to smoothly focus the map on that friend.

C. LIVE SHARING RESUME & COUNTDOWN FIX:
1. Tap the Privacy/Sharing button on the map and choose "Share for 1 hour".
2. Notice the live countdown timer displays the accurate remaining duration.
3. Completely terminate the app from iOS App Switcher and reopen: the app detects the ongoing active session and resumes live GPS streaming automatically.

==================================================
3. COMPLIANCE & PRIVACY SAFEGUARDS
==================================================

• Guideline 5.1.2(i) (Location Privacy & Strict User Control):
- Location sharing is 100% OPT-IN and strictly user-initiated.
- HeartPearl defaults to private; location is NEVER shared without explicit permission.
- Users can choose duration limits (1 hour, until end of day, unlimited) or stop sharing with a single tap at any time.
- Ghost Mode and Frozen Location options give users granular privacy control over who can see their location.

• Guideline 1.2 (User Generated Content Safeguards):
- All shared photos, videos, and comments include immediate Report and Block features.
- Automated client-side content moderation filters objectionable words before submission.
- Blocked users are immediately hidden from feed, chats, and location viewing.
- EULA terms are required during account setup.

• Guideline 5.1.1(v) (Account Deletion):
- Users can permanently delete their account and all associated data inside the app: Profile -> Settings -> Delete Account.
- Web-based deletion portal is also available at:
  https://tamchau-865f3.web.app/delete-account.html

==================================================
4. SUPPORT & CONTACT INFORMATION
==================================================
If you have any questions or require additional information, please contact:
- Support Email: nthanhtam.402@gmail.com
- Web Portal: https://tamchau-865f3.web.app
- Privacy Policy: https://tamchau-865f3.web.app/privacy-policy.html
- Terms of Service / EULA: https://tamchau-865f3.web.app/eula.html

Thank you for your time and assistance in reviewing HeartPearl!
```

---

## 4. SIÊU DỮ LIỆU APP STORE CONNECT (METADATA)

### 4.1. Tiêu đề & Phụ đề (Title & Subtitle - 30 ký tự)

| Ngôn ngữ | App Name (Tối đa 30 ký tự) | Subtitle (Tối đa 30 ký tự) |
|---|---|---|
| **Tiếng Việt** | `HeartPearl` | `Chia sẻ khoảnh khắc & vị trí` |
| **English** | `HeartPearl` | `Live Moments & Friend Radar` |

*(Cả 2 subtitle đều nằm trong giới hạn 30 ký tự nghiêm ngặt của Apple)*.

### 4.2. Từ khóa tìm kiếm (Keywords - Tối đa 100 ký tự)

* **Tiếng Việt:**  
  `vi tri,ban do,chia se anh,ban be,khoanh khac,zenly,dinh vi,radar,chat rieng tu,heartpearl`
* **English:**  
  `live map,friend radar,photo sharing,zenly,location,moments,private social,dwell time,map pin`

### 4.3. Văn bản quảng cáo (Promotional Text - Tối đa 170 ký tự)

* **Tiếng Việt:**  
  `Trải nghiệm bản đồ bạn bè thời gian thực với tính năng ghim địa điểm, đo thời gian ở lại phong cách Zenly và chia sẻ khoảnh khắc thân mật cùng người thân yêu!`
* **English:**  
  `Explore the all-new live friend map with pinned places, Zenly-style dwell time, and close-circle moment sharing with your loved ones!`

### 4.4. Địa chỉ liên kết bắt buộc (URLs)
* **Support URL:** `https://tamchau-865f3.web.app`
* **Marketing URL:** `https://tamchau-865f3.web.app`
* **Privacy Policy URL:** `https://tamchau-865f3.web.app/privacy-policy.html`
* **EULA URL:** `https://tamchau-865f3.web.app/eula.html`
* **Account Deletion URL:** `https://tamchau-865f3.web.app/delete-account.html`

---

## 5. CHECKLIST TRƯỚC KHI BẤM "SUBMIT FOR REVIEW"

- [x] Đã cập nhật `pubspec.yaml` lên phiên bản `1.0.4+10`.
- [x] Đã đồng bộ `AppInfo.appVersion = '1.0.4'` và `buildNumber = '10'`.
- [x] Bộ kiểm thử tự động đạt kết quả tuyệt đối: `38/38 All tests passed!`.
- [x] Kiểm tra phân tích mã nguồn đạt chuẩn: `dart analyze` $\rightarrow$ **0 issues found**.
- [x] Đã triển khai bộ quy tắc bảo mật `firestore.rules` và `database.rules.json` lên Firebase Production (`tamchau-865f3`).
- [x] Đã cấu hình thứ tự biên dịch Xcode Scheme `Pods-Runner` trước `Runner.app`.
- [x] Đã kiểm tra tính năng khôi phục GPS sau khi tắt/mở app và sửa lỗi đồng hồ đếm ngược.
- [x] Tài khoản demo (+84988888888 / OTP: 123456) sẵn sàng cho Apple Review Team đăng nhập thử nghiệm.
