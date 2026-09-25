# HEARTPEARL - TÀI LIỆU HƯỚNG DẪN KIỂM THỬ NỘI BỘ (TESTER NOTES)
## PHIÊN BẢN 1.0.4 (BUILD 10)

Tài liệu này dành riêng cho đội ngũ **QA / Testers** và kiểm thử viên trên **Apple TestFlight**, tập trung vào các tính năng mới và các trường hợp lỗi đã được xử lý trong bản cập nhật 1.0.4.

---

## 1. THÔNG TIN BẢN BUILD
* **Phiên bản (Version):** `1.0.4`
* **Số hiệu bản dựng (Build Number):** `10`
* **Bundle ID:** `com.heartpearl.heartpearl`
* **Môi trường Firebase:** Production (`tamchau-865f3`)
* **Tài khoản kiểm thử nhanh (Demo Test Accounts):**
  * **Tester A:** `+84988888888` | OTP: `123456`
  * **Tester B:** `+84988888889` | OTP: `123456`

---

## 2. KỊCH BẢN THỬ NGHIỆM TRỌNG TÂM

### Kịch bản 1: Ghim địa điểm & Đo thời gian ở lại (Zenly Dwell Time)
1. **Thêm địa điểm:**
   * Mở tab Bản đồ (icon chính giữa thanh điều hướng đáy).
   * Bấm nút **Ghim địa điểm** (nút trên cùng trong cụm 4 nút nổi bên phải).
   * Hoặc **nhấn giữ bất kỳ điểm nào** trên bản đồ.
   * Chọn loại địa điểm: 🏠 Nhà, 🏢 Cơ quan, 🏫 Trường học, hoặc 📍 Điểm khác $\rightarrow$ Điền tên $\rightarrow$ Bấm Lưu.
2. **Kiểm tra nhận diện & Dwell Time:**
   * Di chuyển vào trong bán kính $\le 80\text{m}$ của địa điểm.
   * Avatar hiển thị **Floating Pill** với icon và thời gian ở lại: `"Vừa đến"`, `"X phút"`.
   * Ở trong nhà/văn phòng trong bán kính $\le 120\text{m}$ (thuật toán chống rung Hysteresis), trạng thái địa điểm được giữ nguyên liên tục mà không bị nhảy chớp tắt.
3. **Thoát khỏi địa điểm:**
   * Di chuyển xa hơn $120\text{m}$ hoặc di chuyển với vận tốc $> 15\text{ km/h}$.
   * Trạng thái địa điểm được giải phóng, chuyển sang hiển thị vận tốc di chuyển (nếu có).

---

### Kịch bản 2: Khôi phục GPS sau khi tắt/mở lại app (Resume Live Sharing)
1. Bấm nút Chia sẻ vị trí $\rightarrow$ Chọn thời hạn chia sẻ (ví dụ: `1 giờ` hoặc `Đến hết ngày`).
2. Xác nhận vị trí đang được chia sẻ trực tiếp (có icon sóng phát sóng màu xanh).
3. **Tắt hoàn toàn ứng dụng:** Vuốt app lên trong App Switcher của iOS để Kill app.
4. Chờ 15 – 30 giây rồi mở lại app.
5. **Kết quả mong đợi:** 
   * App tự động kiểm tra phiên chia sẻ cũ còn hạn trong Firebase.
   * Tự động mở lại GPS Stream phần cứng và gửi vị trí mới mà người dùng không cần phải bấm nút chia sẻ lại từ đầu.

---

### Kịch bản 3: Kiểm tra đồng hồ đếm ngược phiên chia sẻ
1. Bật chia sẻ vị trí với thời hạn `1 giờ`.
2. Quan sát dòng chữ hiển thị thời gian còn lại:
   * Sau 2 phút, kiểm tra thấy thời gian giảm dần: `"Hết hạn sau 58 phút"`, `"Hết hạn sau 55 phút"`,...
   * Đồng hồ đếm lùi chính xác chứ không bị cố định ở mốc `"1 giờ"`.

---

### Kịch bản 4: Sử dụng công cụ giả lập di chuyển trên Terminal
Nếu bạn kiểm thử trên máy ảo iOS Simulator:
* **Đi bộ Nguyễn Huệ:** `./scripts/simulate_movement.sh walk` (~4 km/h)
* **Lái xe qua Cầu Ba Son:** `./scripts/simulate_movement.sh drive` (~36 km/h)
* **Chạy bộ Apple:** `./scripts/simulate_movement.sh city_run`
* **Dừng giả lập:** `./scripts/simulate_movement.sh stop`

---

## 3. CHECKLIST KIỂM THỬ XÁC NHẬN (SIGN-OFF)
- [ ] Ghim và xóa địa điểm thành công không bị giật lag.
- [ ] Thời gian ở lại (Dwell Time) hiển thị đúng định dạng.
- [ ] Tắt và mở lại app vẫn duy trì chia sẻ vị trí (nếu phiên chưa hết hạn).
- [ ] Đồng hồ đếm ngược giảm dần đúng từng phút.
- [ ] Bản đồ hiển thị tràn viền mượt mà với 3 chế độ (Sáng, Tối, Vệ tinh).
- [ ] Không có thông báo lỗi Crash hay Permission Denied trong quá trình thao tác.
