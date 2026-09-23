# HƯỚNG DẪN & MẪU ĐƠN XIN DUYỆT GẤP APPLE (EXPEDITED APP REVIEW)

## 1. ĐƯỜNG LINK CHÍNH THỨC
👉 **Link form xin duyệt gấp của Apple:**  
**[https://developer.apple.com/contact/app-store/?topic=expedite](https://developer.apple.com/contact/app-store/?topic=expedite)**

*(Lưu ý: Bạn cần đăng nhập bằng Apple ID của tài khoản Developer sở hữu ứng dụng).*

---

## 2. CÁC BƯỚC THỰC HIỆN
1. **Bước 1: Submit bản build lên App Store Connect trước**
   - Vào [App Store Connect](https://appstoreconnect.apple.com/apps).
   - Chọn app **Heartpearl**, chọn bản build `1.0.1 (7)`.
   - Bấm **Submit for Review** (hoặc *Add for Review* rồi *Submit to App Review*).
   - Đảm bảo trạng thái của phiên bản đang là **Waiting for Review** (Đang chờ duyệt).
2. **Bước 2: Mở Form xin duyệt gấp**
   - Truy cập: [https://developer.apple.com/contact/app-store/?topic=expedite](https://developer.apple.com/contact/app-store/?topic=expedite)
3. **Bước 3: Điền các thông tin trong form**
   - **Contact Information:** Tên, Email, Số điện thoại của bạn.
   - **App Name:** `Heartpearl`
   - **Apple ID / App ID:** (Dãy 9 hoặc 10 chữ số trong mục *App Information / General Information* trên App Store Connect).
   - **Platform:** `iOS`
   - **Reason for Request:** Chọn **Critical Bug Fix** (Sửa lỗi nghiêm trọng) hoặc **Time-Sensitive Event**.

---

## 3. MẪU NỘI DUNG GIẢI TRÌNH TIẾNG ANH (EXPLANATION)
*(Copy-paste toàn bộ đoạn bên dưới vào ô **Description / Explanation** trên form)*

```text
Dear Apple App Review Team,

We are requesting an Expedited App Review for Heartpearl (Version 1.0.1, Build 7) under the "Critical Bug Fix" category due to critical user experience and privacy issues in the current live build.

Key Issues Resolved in this Update:

1. Critical Widget Deep Link Navigation Glitch:
In the current release, opening the app via the Home Widget creates duplicate stacked Map tabs, causing navigation lockups and freezing for users tapping on their friends' widgets. Version 1.0.1 completely resolves this with route debouncing and automatic root navigation.

2. Critical Location Privacy & Battery Fix (Guideline 5.1.2(i)):
We have completely overhauled the location architecture to eliminate background GPS tracking that was causing severe battery drain and unnecessary location queries for active users. The app now uses strictly user-initiated single-fix Manual Check-Ins and user-timed Live Sharing sessions with automatic expiry, strictly aligning with Apple Guideline 5.1.2(i).

3. Critical Account Deletion & Support Links (Guideline 5.1.1(v) & 1.2):
Interactive web browser links for online account deletion and direct technical support email routing (nthanhtam.402@gmail.com) have been fully activated to ensure users have immediate access to 24-hour safety and data deletion requests.

Because this update resolves active navigation lockups, battery drain, and critical compliance items for our live users, we kindly request an expedited review so this fix can reach our users as quickly as possible.

Thank you very much for your understanding and continuous support!
```

---

## 4. THỜI GIAN PHẢN HỒI CỦA APPLE
- Sau khi gửi form, Apple thường phản hồi qua email của bạn trong vòng ** vài giờ đến 24 giờ**.
- Nếu được chấp thuận (*Expedited Review Approved*), bản build sẽ được chuyển sang trạng thái **In Review** và duyệt rất nhanh (thường trong 1-2 tiếng sau đó).
