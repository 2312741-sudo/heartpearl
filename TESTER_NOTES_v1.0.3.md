# HEARTPEARL - BẢN HƯỚNG DẪN TESTER CHI TIẾT (VERSION 1.0.3 - BUILD 9)

**Ngày cập nhật:** 25/09/2026  
**Phiên bản mục tiêu:** `1.0.3` (Build `9`)  
**Mục tiêu chính:** Kiểm thử tính năng Ghim vị trí thủ công (Nhà, Cơ quan, Trường học), Đo thời gian ở lại (Zenly Dwell Time), Tái thiết kế Bản đồ tràn viền, Khắc phục lỗi cắt ảnh đại diện, và Đồng bộ vị trí Realtime.

---

## 📋 DANH SÁCH CÁC HẠNG MỤC CẦN KIỂM THỬ (TEST CHECKLIST)

### 1. Kiểm thử Ghim Địa Điểm Thủ Công (Nhà 🏠, Cơ quan 🏢, Trường học 🏫, Tùy chỉnh 📍)
- **Kịch bản 1 (Ghim qua nút trên thanh công cụ)**:
  - Mở app -> Vào tab **Bản đồ**.
  - Bấm vào icon **Ghim địa điểm** (icon chiếc ghim có dấu cộng trên thanh công cụ nổi bên phải).
  - *Kỳ vọng:* Bảng `AddPlaceSheet` trượt lên từ đáy màn hình, tọa độ GPS hiện tại được tự động điền sẵn.
  - Chọn loại địa điểm: **Nhà (🏠)** hoặc **Nơi làm việc (🏢)**, nhập tên nhãn gợi nhớ (ví dụ: "Nhà riêng", "Văn phòng").
  - Bấm **"Lưu địa điểm"**.
  - *Kỳ vọng:* Báo thành công, danh sách địa điểm cập nhật ngay lập tức.
- **Kịch bản 2 (Ghim bằng thao tác Nhấn giữ trên Bản đồ - Long Press)**:
  - Trên màn hình bản đồ, dùng ngón tay **nhấn giữ 1 giây** vào bất kỳ vị trí nào trên bản đồ.
  - *Kỳ vọng:* Máy rung phản hồi nhẹ (Haptic), Bottom Sheet ghim địa điểm mở lên với tọa độ tại chính điểm bạn vừa bấm.
- **Kịch bản 3 (Quản lý và Xóa địa điểm đã ghim)**:
  - Mở bảng Ghim địa điểm, cuộn xuống mục "Địa điểm đã lưu".
  - Bấm icon thùng rác bên cạnh một địa điểm để xóa.
  - *Kỳ vọng:* Địa điểm được xóa ngay lập tức khỏi bộ nhớ và Firestore.

---

### 2. Kiểm thử Hiển thị Dwell Time (Thời gian ở lại phong cách Zenly)
- **Kịch bản**:
  - Khi bạn đang đứng trong phạm vi địa điểm đã ghim (bán kính $\le 80\text{m}$):
  - *Kỳ vọng trên Marker của bạn và bạn bè*:
    - Xuất hiện **viên thuốc nổi (Floating Pill)** phía trên avatar hiển thị biểu tượng địa điểm và thời gian: `🏠 Ở Nhà · Vừa đến` hoặc `🏠 Ở Nhà · 25 phút`.
    - Ở góc dưới bên phải avatar tròn có gắn **Mini Emoji Badge** tương ứng (🏠, 🏢, 🏫, 📍).
  - Bấm vào Avatar để mở thẻ chi tiết:
    - *Kỳ vọng:* Xuất hiện Card lớn phong cách Zenly hiển thị icon to rõ, tên địa điểm, thời gian đã ở đó, vận tốc và % pin.
  - **Kiểm tra Hysteresis Geofencing (Chống nhảy GPS)**:
    - Khi di chuyển nhẹ trong nhà/văn phòng (trong phạm vi $80\text{m} - 120\text{m}$): Trạng thái địa điểm và thời gian vẫn được duy trì, không bị reset.
    - Khi đi ra xa ($> 120\text{m}$) hoặc đi xe ($> 15\text{ km/h}$): Trạng thái địa điểm tự động biến mất và chuyển sang hiển thị tốc độ di chuyển (ví dụ: `🚗 35 km/h`).

---

### 3. Kiểm thử Giao diện Bản đồ Tràn Viền Tinh Giản
- **Kịch bản 1 (Kiểm tra bố cục mới)**:
  - Bản đồ hiển thị tràn viền (Edge-to-Edge) sắc nét.
  - Hai nút zoom `+` và `-` tĩnh đã được gỡ bỏ hoàn toàn; thao tác pinch-to-zoom bằng 2 ngón tay hoạt động mượt mà.
  - Cụm nút nổi bên phải gồm 4 nút:
    - 📍 Ghim địa điểm (`mapPinPlus`).
    - 🎯 Đưa về vị trí của tôi (`locateFixed`) với hiệu ứng lướt mượt mà.
    - 🗺️ Đổi kiểu bản đồ (`layers`): Chuyển giữa Tối, Đường phố, Vệ tinh — kiểm tra app tự nhớ kiểu này khi mở lại app.
    - 🛡️ Cài đặt quyền riêng tư vị trí (`shieldCheck`).
- **Kịch bản 2 (Băng chuyền bạn bè ở đáy màn hình)**:
  - Cuộn ngang danh sách bạn bè ở đáy màn hình.
  - Mỗi thẻ hiển thị Avatar tròn, Tên, % Pin 🔋, và Badge địa điểm/trạng thái. Bấm vào thẻ để bản đồ tự động lia tới vị trí bạn bè đó.

---

### 4. Kiểm thử Cắt Ảnh Avatar & Đăng Ảnh từ Thư Viện (Sửa lỗi hoàn toàn)
- **Kịch bản 1 (Đổi ảnh đại diện)**:
  - Vào tab **Hồ sơ** -> Bấm **Chỉnh sửa** -> Chạm vào ảnh đại diện để chọn ảnh từ thư viện.
  - *Kỳ vọng:* Màn hình Cắt ảnh (`ImageCropScreen`) mở lên mượt mà. Dùng 2 ngón tay thu phóng, xoay ảnh, căn chỉnh trong khung tròn. Bấm dấu tích xác nhận.
  - *Kỳ vọng:* Ảnh được cắt tức thì, **HOÀN TOÀN KHÔNG BÁO LỖI**, ảnh đại diện mới được lưu và hiển thị sắc nét.
- **Kịch bản 2 (Đăng ảnh từ Thư viện qua Camera)**:
  - Vào tab Camera -> Bấm icon thư viện ảnh ở góc dưới bên trái -> Chọn ảnh -> Căn chỉnh trong khung chữ nhật 3:4 -> Gửi thành công cho bạn bè.

---

### 5. Kiểm thử Chế độ Riêng tư (Ghost Mode) & Chia sẻ Live
- Bật **Chế độ tàng hình (Ghost Mode)**: Vị trí của bạn lập tức biến mất khỏi bản đồ bạn bè, không còn gửi GPS ngầm.
- Bật **Chia sẻ trực tiếp (Live 1 giờ)**: Vị trí được đồng bộ tức thời với độ trễ dưới 1 giây qua Firebase Realtime Database.

---

### 6. Kiểm tra Thông tin Phiên bản
- Vào tab **Hồ sơ** -> Bấm mục **"Quyền riêng tư & Thông tin ứng dụng"**.
- Xác nhận:
  - **Version:** `1.0.3`
  - **Build:** `9`
  - **Bundle ID:** `com.heartpearl.heartpearl`
