# HEARTPEARL v1.0.1 (Build 7) - TÀI LIỆU HƯỚNG DẪN KIỂM THỬ (QA / TESTER NOTES)

> **Phiên bản:** `1.0.1+7`  
> **Nền tảng kiểm thử:** iOS (TestFlight / Simulator / Thiết bị thật) & Android  
> **Ngôn ngữ hỗ trợ:** Tiếng Việt & English  
> **Giao diện:** Tối (Dark) & Sáng (Light)  
> **Email hỗ trợ kỹ thuật:** `nthanhtam.402@gmail.com`

---

## MỤC LỤC
1. [Tổng quan mục tiêu phiên bản 1.0.1](#1-tổng-quan-mục-tiêu-phiên-bản-101)
2. [Checklist kiểm thử chi tiết theo từng tính năng](#2-checklist-kiểm-thử-chi-tiết-theo-từng-tính-năng)
   - [A. Chức năng Tải ảnh & Video về máy (Mới)](#a-chức-năng-tải-ảnh--video-về-máy-mới)
   - [B. Giao diện Camera & Điều khiển Bộ lọc](#b-giao-diện-camera--điều-khiển-bộ-lọc)
   - [C. Mở ứng dụng từ Home Widget & Tab Bản đồ](#c-mở-ứng-dụng-từ-home-widget--tab-bản-đồ)
   - [D. Thay đổi Cơ chế Lấy Vị Trí (Check-in thủ công & Live Sharing có thời hạn)](#d-thay-đổi-cơ-chế-lấy-vị-trí-check-in-thủ-công--live-sharing-có-thời-hạn)
   - [E. Mở liên kết Web & Ứng dụng Email](#e-mở-liên-kết-web--ứng-dụng-email)
   - [F. Cập nhật Thông tin Hỗ trợ Kỹ thuật & Bản quyền](#f-cập-nhật-thông-tin-hỗ-trợ-kỹ-thuật--bản-quyền)
3. [Các trường hợp ngoại lệ & Biên (Edge Cases)](#3-các-trường-hợp-ngoại-lệ--biên-edge-cases)
4. [Mẫu báo cáo lỗi (Bug Report Template)](#4-mẫu-báo-cáo-lỗi-bug-report-template)

---

## 1. TỔNG QUAN MỤC TIÊU PHIÊN BẢN 1.0.1
Phiên bản 1.0.1 tập trung vào 5 nhóm cải tiến trọng tâm:
1. **Thay đổi hình thức lấy vị trí (Quan trọng)**: Chuyển hoàn toàn từ cơ chế *theo dõi ngầm liên tục* sang **Check-in thủ công (Manual Check-in)** và **Live Sharing có thời hạn người dùng tự chọn** (nhằm tiết kiệm pin tối đa và tuân thủ nghiêm ngặt chính sách Quyền riêng tư của Apple - **Guideline 5.1.2(i)**).
2. **Bổ sung tính năng Tải ảnh/video về máy**: Lưu khoảnh khắc (ảnh/video) trực tiếp vào album máy cho cả ảnh vừa chụp lẫn ảnh trong lịch sử.
3. **Cải tiến công thái học (Ergonomics) cho Camera**: Hạ cụm nút chụp thuận tiện thao tác 1 tay; đưa thanh cường độ bộ lọc lên trên nút chụp; cố định khung hình 100% chống giật màn hình.
4. **Khắc phục triệt để lỗi Widget điều hướng**: Không còn hiện tượng nhân bản hoặc mở nhiều tab Bản đồ xếp chồng nhau khi chạm vào Home Widget.
5. **Tương tác hóa 100% các liên kết**: Bấm vào mở trực tiếp Safari/Chrome hoặc mở ứng dụng Email mặc định; cập nhật email hỗ trợ chính thức `nthanhtam.402@gmail.com`.

---

## 2. CHECKLIST KIỂM THỬ CHI TIẾT THEO TỪNG TÍNH NĂNG

### A. Chức năng Tải ảnh & Video về máy (Mới)

| STT | Luồng kiểm thử | Thao tác thực hiện | Kết quả mong đợi | Đánh giá |
|:---:|:---|:---|:---|:---:|
| **A1** | Xin quyền truy cập Thư viện ảnh | Lần đầu tiên bấm tải ảnh về trên thiết bị mới cài app. | Hệ thống hiển thị hộp thoại xin cấp quyền Photos / Thư viện ảnh rõ ràng, không crash. | [ ] Pass |
| **A2** | Tải ảnh vừa chụp (Không filter) | 1. Chụp 1 bức ảnh mới.<br>2. Ở màn hình Preview, bấm nút **Tải về** (icon mũi tên tải xuống ở góc phải trên). | - Hiển thị toast thông báo *"Đã lưu ảnh vào Thư viện" (hoặc "Saved to Photos")*.<br>- Ảnh xuất hiện trong album máy và trong album riêng tên **HeartPearl**. | [ ] Pass |
| **A3** | Tải ảnh vừa chụp (Có Filter màu / Làm đẹp) | 1. Chọn 1 filter (VD: Cổ điển, Rực rỡ, hoặc Mịn da 80%).<br>2. Chụp ảnh.<br>3. Bấm nút Tải về ở Preview. | Ảnh được lưu vào Thư viện với **hiệu ứng filter được nung (bake) chuẩn xác**, không bị mất màu hay mất hiệu ứng. | [ ] Pass |
| **A4** | Tải video vừa quay | 1. Nhấn giữ nút chụp để quay video ngắn.<br>2. Ở màn hình Preview, bấm nút Tải về. | Video kèm âm thanh được lưu thành công vào Thư viện máy. | [ ] Pass |
| **A5** | Tải ảnh từ màn hình Xem chi tiết (Photo Viewer) | 1. Mở xem chi tiết bất kỳ khoảnh khắc nào (của mình hoặc bạn bè).<br>2. Bấm nút Tải về ở góc trên bên phải hoặc nút Tải về ở thanh đáy. | Ảnh tải về máy thành công, độ phân giải sắc nét, có toast xác nhận. | [ ] Pass |
| **A6** | Tải ảnh nhanh trong Lịch sử (History) | 1. Vào tab **Lịch sử**.<br>2. **Nhấn giữ (Long-press)** vào một bức ảnh bất kỳ trong lưới.<br>3. Chọn **Tải ảnh về máy** từ menu hiện lên. | Menu phản hồi rung nhẹ, ảnh được lưu ngay vào thư viện máy và có thông báo thành công. | [ ] Pass |

---

### B. Giao diện Camera & Điều khiển Bộ lọc

| STT | Luồng kiểm thử | Thao tác thực hiện | Kết quả mong đợi | Đánh giá |
|:---:|:---|:---|:---|:---:|
| **B1** | Vị trí cụm nút Camera | Mở màn hình Camera chính. | Cụm nút (Thư viện - Nút chụp - Lật Camera) nằm hạ thấp xuống dưới (~22px thấp hơn bản cũ), gần ngón tay cái, bấm dễ dàng bằng một tay. | [ ] Pass |
| **B2** | Vị trí thanh điều chỉnh Cường độ | 1. Chọn một bộ lọc màu (VD: Ấm áp, Điện ảnh,...).<br>2. Quan sát vị trí slider cường độ. | Thanh cường độ dạng viên thuốc kính mờ (Frosted pill) nằm **ngay phía trên nút chụp ảnh**, căn giữa cân đối, không che khuất các nút khác. | [ ] Pass |
| **B3** | Kiểm tra ổn định khung hình (Không giật/thu nhỏ) | 1. Chọn lần lượt giữa "Bình thường" (Không filter) và các bộ lọc màu khác.<br>2. Kéo thanh trượt cường độ từ 0% đến 100%. | **Khung hình camera giữ nguyên 100% tỷ lệ**, hoàn toàn không bị co giật, không bị thu nhỏ màn hình xem trước. | [ ] Pass |
| **B4** | Danh mục & Tùy chọn bộ lọc | Chuyển qua các tab phân loại: Tất cả, Làm đẹp, Màu sắc, Sáng tạo. | Các tùy chọn bộ lọc hiển thị đầy đủ, cuộn ngang mượt mà, bấm chọn áp dụng tức thì. | [ ] Pass |

---

### C. Mở ứng dụng từ Home Widget & Tab Bản đồ

| STT | Luồng kiểm thử | Thao tác thực hiện | Kết quả mong đợi | Đánh giá |
|:---:|:---|:---|:---|:---:|
| **C1** | Chạm Widget khi app đang đóng (Cold start) | Thêm Widget HeartPearl lên màn hình chính điện thoại, sau đó chạm vào Widget. | App khởi động và chuyển ngay đến tab Bản đồ định vị bạn bè. Không bị mở 2 lần hay nhấp nháy màn hình. | [ ] Pass |
| **C2** | Chạm Widget khi app đang chạy nền (Background) | Mở app, chuyển sang tab Cá nhân, nhấn Home về màn hình chính, chạm vào Widget. | App thức dậy và chuyển thẳng đến tab Bản đồ. Không tạo thêm layer/tab Bản đồ xếp chồng lên nhau. | [ ] Pass |
| **C3** | Chạm Widget khi đang mở Modal / Dialog con | Đang mở modal EULA hoặc màn hình Cài đặt, gạt mở từ Widget. | Ứng dụng tự động đóng toàn bộ modal đang đè phía trên (Pop to root) và hiển thị tab Bản đồ một cách mượt mà. | [ ] Pass |

---

### D. Thay đổi Cơ chế Lấy Vị Trí (Check-in thủ công & Live Sharing có thời hạn)

> **Mục tiêu thay đổi:** Loại bỏ hoàn toàn việc ứng dụng tự ý quét GPS ngầm liên tục chạy ngầm 24/7 (vốn gây hao pin và vi phạm Apple Guideline 5.1.2(i)). Thay vào đó, **chỉ chia sẻ vị trí khi người dùng chủ động cho phép**.

| STT | Luồng kiểm thử | Thao tác thực hiện | Kết quả mong đợi | Đánh giá |
|:---:|:---|:---|:---|:---:|
| **D1** | Check-in Vị trí thủ công (Manual Check-in) | 1. Vào tab **Bản đồ**.<br>2. Bấm nút **Check-in / Cập nhật vị trí** của tôi. | - Ứng dụng lấy tọa độ GPS hiện tại một lần duy nhất (`single GPS fix`).<br>- Ghim vị trí của bạn hiển thị trên bản đồ bạn bè.<br>- **Không duy trì dịch vụ quét GPS ngầm**, tiết kiệm pin. | [ ] Pass |
| **D2** | Live Sharing có thời hạn (Timed Session) | 1. Bấm **Bắt đầu chia sẻ vị trí**.<br>2. Chọn một khoảng thời gian: **15 phút**, **1 giờ**, hoặc **8 giờ**.<br>3. Theo dõi bộ đếm thời gian. | - Vị trí trực tiếp được cập nhật theo thời gian thực khi đang mở app.<br>- Hiển thị thời gian còn lại của phiên chia sẻ.<br>- Khi hết giờ: Tọa độ tự động hủy và xóa khỏi bản đồ. | [ ] Pass |
| **D3** | Chế độ Ẩn danh (Ghost Mode) | Đang bật chia sẻ vị trí -> Bật **Chế độ ẩn danh (Ghost Mode)**. | - Vị trí của người dùng bị ẩn ngay lập tức đối với tất cả bạn bè.<br>- Tọa độ GPS trên máy chủ bị xóa ngay lập tức. | [ ] Pass |
| **D4** | Tùy chọn Bạn bè được xem (Allowed Viewers) | Vào Cài đặt quyền riêng tư vị trí -> Chọn chỉ 1-2 bạn bè nhất định được xem. | Chỉ những bạn bè được tích chọn mới thấy chấm vị trí trên bản đồ; những bạn bè khác không thấy. | [ ] Pass |
| **D5** | Không tiêu hao pin ngầm | Chạy app một lúc, sau đó đưa app xuống nền hoặc khóa màn hình trong 30 phút. | Ứng dụng không duy trì GPS ngầm liên tục, biểu tượng định vị GPS của iOS tắt khi không dùng, máy mát, không sụt pin. | [ ] Pass |

---

### E. Mở liên kết Web & Ứng dụng Email

| STT | Luồng kiểm thử | Thao tác thực hiện | Kết quả mong đợi | Đánh giá |
|:---:|:---|:---|:---|:---:|
| **E1** | Mở Email hỗ trợ kỹ thuật | 1. Vào tab Hồ sơ -> Cài đặt -> **Liên hệ & Hỗ trợ**.<br>2. Bấm vào ô **Email hỗ trợ kỹ thuật** (`nthanhtam.402@gmail.com`). | Ứng dụng Mail mặc định trên thiết bị được mở ra, trường Người nhận điền sẵn `nthanhtam.402@gmail.com`, Tiêu đề điền sẵn `[HeartPearl] Yêu cầu hỗ trợ kỹ thuật`. | [ ] Pass |
| **E2** | Mở Cổng thông tin Web | Trong hộp thoại **Liên hệ & Hỗ trợ**, bấm vào ô **Cổng web & Xóa tài khoản** (`https://tamchau-865f3.web.app`). | Trình duyệt Safari (trên iOS) hoặc Chrome (trên Android) được kích hoạt và mở đúng trang chủ. | [ ] Pass |
| **E3** | Mở link Xóa tài khoản trong Cài đặt | 1. Vào tab Hồ sơ -> Cài đặt -> **Xóa tài khoản vĩnh viễn**.<br>2. Bấm vào dòng liên kết web `https://tamchau-865f3.web.app/delete-account.html`. | Mở trình duyệt web ngoài dẫn thẳng tới trang hỗ trợ xóa tài khoản trực tuyến theo chuẩn Apple. | [ ] Pass |
| **E4** | Mở các liên kết Pháp lý & Quyền riêng tư | 1. Vào Cài đặt -> **Chính sách & Điều khoản**.<br>2. Thử bấm lần lượt vào 3 mục:<br>   - *Trang chính sách trực tuyến*<br>   - *Thỏa thuận người dùng (EULA)*<br>   - *Yêu cầu xóa dữ liệu trực tuyến* | Cả 3 liên kết đều mở đúng trang tương ứng trên trình duyệt web. Có hiệu ứng chạm và icon liên kết ngoài rõ ràng. | [ ] Pass |
| **E5** | Mở liên kết trong Modal EULA | Mở xem modal EULA -> cuộn xuống mục **5. Quyền Xóa Tài khoản & Dữ liệu** -> bấm vào link. | Mở trình duyệt web ngoài đến trang xóa tài khoản trực tuyến. | [ ] Pass |

---

### F. Cập nhật Thông tin Hỗ trợ Kỹ thuật & Bản quyền

| STT | Vị trí kiểm tra | Nội dung cần hiển thị chính xác | Kết quả mong đợi | Đánh giá |
|:---:|:---|:---|:---|:---:|
| **F1** | Menu Trợ giúp & Hỗ trợ (Hồ sơ) | Phụ đề: `Phản hồi trong 24h • nthanhtam.402@gmail.com` | Hiển thị đúng email `nthanhtam.402@gmail.com`, không còn email cũ. | [ ] Pass |
| **F2** | Hộp thoại Hỗ trợ | Tiêu đề & Nội dung phản hồi cam kết giải quyết trong 24 giờ. | Hiển thị giao diện sạch đẹp, hỗ trợ cả Dark/Light Mode. | [ ] Pass |
| **F3** | Phiên bản ứng dụng | Footer dưới cùng của màn hình Cài đặt Hồ sơ. | Hiển thị: **Version 1.0.1 (Build 7)**. | [ ] Pass |

---

## 3. CÁC TRƯỜNG HỢP NGOẠI LỆ & BIÊN (EDGE CASES)
1. **Thiết bị không có mạng Internet khi tải ảnh từ xa**:
   - Thử mở ảnh cũ trên máy không có mạng -> Bấm tải về -> App hiển thị thông báo lỗi mạng một cách lịch sự, không bị đơ hoặc crash.
2. **Từ chối quyền Ảnh (Deny Photos Permission)**:
   - Vào Cài đặt máy -> Thu hồi quyền Photos của HeartPearl -> Quay lại app bấm Tải về -> App xử lý an toàn và hướng dẫn người dùng cấp quyền.
3. **Từ chối quyền Vị trí (Deny Location Permission)**:
   - Khi bấm Check-in vị trí mà từ chối cấp quyền -> App hiển thị nhắc nhở mở Cài đặt thân thiện, không crash.
4. **Thiết bị chưa cấu hình tài khoản Email**:
   - Nếu máy chưa cài app Mail hoặc chưa đăng nhập hòm thư, việc bấm vào link email không làm crash app.

---

## 4. MẪU BÁO CÁO LỖI (BUG REPORT TEMPLATE)
Nếu phát hiện lỗi trong quá trình kiểm thử, vui lòng tạo issue hoặc gửi phản hồi theo định dạng sau:
- **Tiêu đề lỗi:** `[v1.0.1][Feature] Mô tả ngắn gọn lỗi`
- **Thiết bị & OS:** Ví dụ: `iPhone 15 Pro, iOS 17.5` hoặc `Pixel 7, Android 14`
- **Các bước tái hiện (Steps to Reproduce):**
  1. ...
  2. ...
- **Kết quả thực tế (Actual Result):** ...
- **Kết quả mong đợi (Expected Result):** ...
- **Ảnh / Video đính kèm:** ...
