# HEARTPEARL - TÀI LIỆU HƯỚNG DẪN KIỂM THỬ NỘI BỘ (TESTER NOTES)
## PHIÊN BẢN 1.0.5 (BUILD 11)

Tài liệu này dành riêng cho đội ngũ **QA / Testers** và kiểm thử viên trên **Apple TestFlight**, tập trung vào các tính năng mới và các trường hợp xử lý nâng cao trong bản cập nhật **1.0.5 (Build 11)**.

---

## 1. THÔNG TIN BẢN BUILD
* **Phiên bản (Version):** `1.0.5`
* **Số hiệu bản dựng (Build Number):** `11`
* **Bundle ID:** `com.heartpearl.heartpearl`
* **Widget Extension ID:** `com.heartpearl.heartpearl.HeartPearlWidget`
* **Môi trường Firebase:** Production (`tamchau-865f3`)
* **Tài khoản kiểm thử nhanh (Demo Test Accounts):**
  * **Tester A:** `+84988888888` | OTP: `123456`
  * **Tester B:** `+84988888889` | OTP: `123456`

---

## 2. KỊCH BẢN THỬ NGHIỆM TRỌNG TÂM

### 👤 Kịch bản 1: Đặt Username Duy Nhất & Đổi Username (Transaction)
1. **Thử trùng username:**
   * Dùng Tester A đặt username `pearlqueen`.
   * Dùng Tester B mở màn hình Đổi hồ sơ và cố tình gõ `pearlqueen` $\rightarrow$ Bấm Lưu.
   * **Kết quả mong đợi:** Ứng dụng báo lỗi `"Username này đã có người sử dụng!"` hoặc `"Username này đã được sử dụng. Vui lòng chọn tên khác!"`.
2. **Đổi username và kiểm tra giải phóng tên cũ:**
   * Dùng Tester A đổi username từ `pearlqueen` sang `pearlking` $\rightarrow$ Bấm Lưu thành công.
   * Dùng Tester B gõ lại `pearlqueen` $\rightarrow$ Bấm Lưu.
   * **Kết quả mong đợi:** Tester B đăng ký thành công `pearlqueen` do hệ thống đã tự động thu hồi và giải phóng tên cũ của Tester A trong cùng một transaction.

---

### 🔍 Kịch bản 2: Tìm Kiếm Bạn Bè Thông Minh & 3 Trạng Thái Nút
1. **Lọc người đã là bạn bè:**
   * Kết bạn giữa Tester A và Tester B.
   * Vào tab Bạn bè $\rightarrow$ Chọn tab Tìm kiếm $\rightarrow$ Gõ username của Tester B.
   * **Kết quả mong đợi:** Tester B **không xuất hiện** trong kết quả tìm kiếm (đã được tự động lọc bỏ vì đã là bạn).
2. **Trạng thái "Đã gửi lời mời":**
   * Dùng Tester A tìm một người chưa kết bạn (Tester C) $\rightarrow$ Bấm "+ Kết bạn".
   * **Kết quả mong đợi:** Nút lập tức chuyển sang màu xám disabled với nhãn `"Đã gửi lời mời"`.
3. **Trạng thái "Chấp nhận":**
   * Dùng Tester C vào tab Tìm kiếm $\rightarrow$ Gõ tìm Tester A.
   * **Kết quả mong đợi:** Nút tương ứng bên cạnh Tester A hiển thị `"Chấp nhận"` (thay vì nút "+ Kết bạn" thông thường). Chạm vào `"Chấp nhận"` sẽ đồng ý kết bạn ngay tức thì.

---

### ⚡ Kịch bản 3: Tự Động Ghép Bạn Hai Chiều (Mutual Matching)
1. Tester A gửi lời mời kết bạn cho Tester B (đang ở trạng thái `pending`).
2. Trước khi Tester B mở mục Lời mời, Tester B vô tình vào mục Tìm kiếm và gửi lời mời kết bạn cho Tester A.
3. **Kết quả mong đợi:**
   * Hệ thống tự động nhận diện Tester A đã gửi trước đó $\rightarrow$ Không tạo thêm request trùng lặp.
   * Tự động hoàn tất kết bạn cho cả hai bên ngay lập tức.
   * Cả 2 tài khoản xuất hiện trong danh sách bạn bè của nhau.

---

### ☁️ Kịch bản 4: Cloud Function Cập Nhật Danh Sách Bạn Bè
1. Tester A gửi lời mời cho Tester B.
2. Tester B vào tab "Lời mời" $\rightarrow$ Bấm dấu tích xanh "Đồng ý".
3. **Kết quả mong đợi:**
   * Yêu cầu biến mất khỏi tab Lời mời.
   * Cloud Function `onFriendRequestAccepted` tự động chạy ngầm trên Firebase Admin SDK, thêm Tester A vào mảng `friends` của Tester B và ngược lại.
   * Cả 2 bên mở tab "Bạn bè" đều thấy nhau mà không gặp lỗi permission Firestore.

---

### 🗑️ Kịch bản 5: Xóa Tài Khoản An Toàn Đạt Chuẩn Apple Guideline 5.1.1(v)
1. Dùng một tài khoản phụ (ví dụ: `+84988888887` | OTP: `123456`).
2. Tải lên một ảnh khoảnh khắc, ghim 1 địa điểm, kết bạn với Tester A.
3. Vào Hồ sơ $\rightarrow$ Cài đặt & Pháp lý $\rightarrow$ Xóa tài khoản vĩnh viễn $\rightarrow$ Xác nhận.
4. **Kết quả mong đợi:**
   * Ứng dụng dọn dẹp sạch sẽ toàn bộ: ảnh khoảnh khắc trên Storage, vị trí GPS, thông báo, bạn bè (bên Tester A tự động mất liên kết bạn bè), document người dùng và reservation username.
   * Phiên đăng nhập Auth bị xóa sau cùng.
   * Nếu phiên đăng nhập bị cũ/hết hạn, ứng dụng hiển thị thông báo: `"Vui lòng đăng nhập lại để xác nhận xóa tài khoản"`.

---

### 📍 Kịch bản 6: Ghim Địa Điểm Zenly & Widgetkit
1. Vào tab Bản đồ $\rightarrow$ Bấm icon Ghim địa điểm hoặc nhấn giữ bản đồ để tạo địa điểm Nhà / Công ty.
2. Kiểm tra hiển thị Pill `🏠 Nhà · Vừa đến` trên Avatar khi ở trong bán kính.
3. Thêm Widget HeartPearl ra màn hình chính iOS $\rightarrow$ Kiểm tra hiển thị widget mượt mà, đồng bộ phiên bản 1.0.5 (Build 11).
