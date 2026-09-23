# HEARTPEARL v1.0.2 (Build 8) - TÀI LIỆU HƯỚNG DẪN KIỂM THỬ (QA / TESTER NOTES)

> **Phiên bản:** `1.0.2+8`  
> **Nền tảng kiểm thử:** iOS (TestFlight / Thiết bị thật iPhone) & Android  
> **Ngôn ngữ hỗ trợ:** Tiếng Việt & English  
> **Giao diện:** Tối (Dark) & Sáng (Light)  
> **Email hỗ trợ kỹ thuật:** `nthanhtam.402@gmail.com`

---

## MỤC LỤC
1. [Tổng quan mục tiêu phiên bản 1.0.2](#1-tổng-quan-mục-tiêu-phiên-bản-102)
2. [Checklist kiểm thử chi tiết theo từng tính năng](#2-checklist-kiểm-thử-chi-tiết-theo-từng-tính-năng)
   - [A. Thông báo đẩy ngoài app qua Apple APNs (Mới)](#a-thông-báo-đẩy-ngoài-app-qua-apple-apns-mới)
   - [B. Banner Thông báo Tin nhắn trong app (In-App Popup) (Mới)](#b-banner-thông-báo-tin-nhắn-trong-app-in-app-popup-mới)
   - [C. Phân tách Tin nhắn khỏi Chuông thông báo (Mới)](#c-phân-tách-tin-nhắn-khỏi-chuông-thông-báo-mới)
   - [D. Giao diện Ghi hình Video: Laser Neon & Đảo Đếm Ngược (Mới)](#d-giao-diện-ghi-hình-video-laser-neon--đảo-đếm-ngược-mới)
   - [E. Tự động Xóa Số Đỏ (Badge) trên Icon App (Mới)](#e-tự-động-xóa-số-đỏ-badge-trên-icon-app-mới)
   - [F. Hồi quy các chức năng v1.0.1 (Tải ảnh/video, Check-in vị trí, Widget)](#f-hồi-quy-các-chức-năng-v101)
3. [Các kịch bản kiểm thử ngoại lệ & Biên (Edge Cases)](#3-các-kịch-bản-kiểm-thử-ngoại-lệ--biên-edge-cases)
4. [Mẫu báo cáo lỗi (Bug Report Template)](#4-mẫu-báo-cáo-lỗi-bug-report-template)

---

## 1. TỔNG QUAN MỤC TIÊU PHIÊN BẢN 1.0.2

Phiên bản 1.0.2 là bản cập nhật mang tính hoàn thiện trải nghiệm giao tiếp và tương tác thời gian thực:
1. **Thông báo đẩy ngoài app (APNs Remote Push)**: Hoàn tất cấu hình Apple Push Notification service. Khi app tắt hoặc chạy ngầm, tin nhắn và tương tác từ bạn bè sẽ hiển thị pop-up banner ngoài màn hình khóa/trung tâm thông báo ngay lập tức.
2. **Banner tin nhắn trong app (In-App Frosted Banner)**: Khi đang ở các màn hình khác (Camera, Bản đồ, Profile), tin nhắn mới trượt xuống dưới dạng banner kính mờ sang trọng, vuốt lên để ẩn hoặc chạm vào để mở phòng chat.
3. **Phân tách luồng thông báo**: Tin nhắn được gom trọn vẹn vào tab Chat. Chuông thông báo chỉ hiển thị tương tác xã hội (kết bạn, thả tim, gửi ảnh).
4. **Đổi mới giao diện đếm ngược quay video**: Thay vì hiển thị số đếm trong nút chụp (bị ngón tay cái che khuất), camera có thanh laser neon 60 FPS chạy mượt mà trên đỉnh kính ngắm cùng Đảo ghi hình (Dynamic Island HUD) với chấm đỏ REC nhấp nháy.
5. **Tự động làm sạch số đỏ Icon App**: Tự động reset số đỏ `badge` về 0 mỗi khi người dùng mở lại ứng dụng.

---

## 2. CHECKLIST KIỂM THỬ CHI TIẾT THEO TỪNG TÍNH NĂNG

### A. Thông báo đẩy ngoài app qua Apple APNs (Mới)

| STT | Luồng kiểm thử | Thao tác thực hiện | Kết quả mong đợi | Đánh giá |
|:---:|:---|:---|:---|:---:|
| **A1** | Xin cấp quyền Thông báo lần đầu | Mở app trên máy mới cài đặt bản 1.0.2 build 8. | Hiển thị hộp thoại hệ thống: *"HeartPearl muốn gửi thông báo cho bạn"*. Bấm **Cho phép**. Token được ghi nhận thành công lên Firestore. | [ ] Pass |
| **A2** | Nhận thông báo tin nhắn khi khóa màn hình | 1. Khóa màn hình iPhone.<br>2. Dùng tài khoản B gửi tin nhắn văn bản sang tài khoản A. | Màn hình sáng lên, xuất hiện banner thông báo: **[Tên bạn B]** cùng nội dung tin nhắn và âm thanh chuông mặc định. | [ ] Pass |
| **A3** | Nhận thông báo tin nhắn ảnh | 1. Thoát app ra Home screen.<br>2. Bạn B gửi một hình ảnh sang phòng chat. | Banner hiện: **[Tên bạn B]** kèm `📷 [Hình ảnh]`. | [ ] Pass |
| **A4** | Chạm thông báo để Deep-link vào phòng Chat | Khi có banner thông báo tin nhắn mới ngoài màn hình khóa, chạm vào thông báo. | Ứng dụng tự động khởi động và **mở thẳng vào phòng chat** với người gửi đó. Không bị dừng ở màn hình chính. | [ ] Pass |
| **A5** | Nhận thông báo Lời mời kết bạn | Người khác gửi lời mời kết bạn khi app đang đóng. | Hiển thị thông báo kết bạn. Chạm vào mở thẳng màn hình Bạn bè (tab Lời mời). | [ ] Pass |

---

### B. Banner Thông báo Tin nhắn trong app (In-App Popup) (Mới)

| STT | Luồng kiểm thử | Thao tác thực hiện | Kết quả mong đợi | Đánh giá |
|:---:|:---|:---|:---|:---:|
| **B1** | Tin nhắn đến khi đang ở Camera / Bản đồ | 1. Đang mở màn hình Camera hoặc Bản đồ.<br>2. Bạn bè gửi tin nhắn đến. | Banner kính mờ trượt từ trên đỉnh màn hình xuống (380ms mượt mà): có Avatar, Tên bạn bè, nhãn "Tin nhắn mới", nội dung tin và nút [X]. | [ ] Pass |
| **B2** | Tự động biến mất (Auto-dismiss) | Không chạm vào banner khi nó xuất hiện. | Sau 4.5 giây, banner tự động trượt ngược lên trên và biến mất êm dịu. | [ ] Pass |
| **B3** | Thao tác vuốt lên để ẩn nhanh | Vuốt ngón tay từ dưới lên trên bề mặt banner. | Banner trượt lên và ẩn ngay lập tức, không gây cản trở thao tác chụp ảnh hay xem bản đồ. | [ ] Pass |
| **B4** | Chạm vào banner để mở Chat | Chạm vào giữa banner khi nó đang hiển thị. | Chuyển cảnh mở thẳng màn hình `ChatRoomScreen` với người bạn đó. | [ ] Pass |
| **B5** | Không hiển thị khi đang trong chính phòng chat đó | Đang nhắn tin trực tiếp với bạn B trong phòng chat của B $\rightarrow$ bạn B gửi thêm tin. | **Không hiện banner** (tránh làm phiền vì người dùng đang đọc tin nhắn trực tiếp). | [ ] Pass |

---

### C. Phân tách Tin nhắn khỏi Chuông thông báo (Mới)

| STT | Luồng kiểm thử | Thao tác thực hiện | Kết quả mong đợi | Đánh giá |
|:---:|:---|:---|:---|:---:|
| **C1** | Kiểm tra biểu tượng chuông trên Camera | Nhận 3 tin nhắn chat mới từ bạn bè. | Số đỏ trên chuông thông báo (góc phải trên màn hình Camera) **không tăng**. Số đỏ chỉ tăng trên biểu tượng Tin nhắn (góc dưới phải). | [ ] Pass |
| **C2** | Kiểm tra danh sách trong màn hình Thông báo | Mở màn hình Thông báo (bấm vào icon chuông). | Danh sách thông báo chỉ gồm: Lời mời kết bạn, Tương tác cảm xúc, Khoảnh khắc mới. **Không có tin nhắn chat lẫn vào**. | [ ] Pass |

---

### D. Giao diện Ghi hình Video: Laser Neon & Đảo Đếm Ngược (Mới)

| STT | Luồng kiểm thử | Thao tác thực hiện | Kết quả mong đợi | Đánh giá |
|:---:|:---|:---|:---|:---:|
| **D1** | Khởi động quay video | Nhấn giữ nút chụp ảnh lớn màu hồng ở giữa. | - Nút chụp chuyển sang icon hình vuông bo góc trắng (Stop icon).<br>- Vòng tròn viền ngoài quay mượt mà 60 FPS theo tiến độ. | [ ] Pass |
| **D2** | Thanh Laser Neon trên đỉnh kính ngắm | Quan sát mép trên kính ngắm khi đang quay. | Thanh neon màu hồng ngọc phát sáng thu ngắn dần từ trái qua phải cực kỳ mượt mà. 3 giây cuối chuyển sang ánh đỏ cảnh báo sắp hết giờ. | [ ] Pass |
| **D3** | Đảo ghi hình (Dynamic Island HUD) | Quan sát viên nang kính mờ ở giữa phía trên. | - Chấm đỏ **REC** nhấp nháy theo nhịp thở (750ms).<br>- Số giây đếm ngược (15s $\rightarrow$ 0s) hiển thị rõ ràng, không bị ngón tay che khuất. | [ ] Pass |
| **D4** | Kết thúc quay video | Thả tay ra hoặc quay hết 15 giây. | Máy tự động dừng quay và chuyển sang màn hình Preview xem lại video vừa quay, âm thanh rõ nét. | [ ] Pass |

---

### E. Tự động Xóa Số Đỏ (Badge) trên Icon App (Mới)

| STT | Luồng kiểm thử | Thao tác thực hiện | Kết quả mong đợi | Đánh giá |
|:---:|:---|:---|:---|:---:|
| **E1** | Xóa số đỏ khi mở app | 1. Nhận thông báo làm icon app ngoài Home Screen có số 1 đỏ.<br>2. Chạm vào biểu tượng HeartPearl để mở app. | Số 1 màu đỏ trên biểu tượng app ngoài màn hình chính **tự động biến mất về 0 ngay lập tức**. | [ ] Pass |
| **E2** | Xóa số đỏ khi đọc hết thông báo | Mở màn hình Thông báo $\rightarrow$ bấm "Đánh dấu tất cả đã đọc". | Lệnh reset badge được kích hoạt, đảm bảo icon app luôn sạch sẽ. | [ ] Pass |

---

### F. Hồi quy các chức năng v1.0.1

| STT | Hạng mục kiểm tra | Thao tác kiểm thử | Kết quả mong đợi | Đánh giá |
|:---:|:---|:---|:---|:---:|
| **F1** | Tải ảnh & video về Thư viện | Bấm icon Tải về ở màn hình Preview hoặc Photo Viewer. | Ảnh/video lưu thành công vào album ảnh máy kèm bộ lọc màu chính xác. | [ ] Pass |
| **F2** | Check-in Vị trí thủ công | Vào tab Bản đồ $\rightarrow$ Bấm Cập nhật vị trí / Check-in. | Vị trí cập nhật 1 lần duy nhất, không chạy ngầm hao pin. | [ ] Pass |
| **F3** | Chạm Widget mở Bản đồ | Chạm Home Widget khi app đang đóng hoặc chạy ngầm. | Chuyển thẳng vào tab Bản đồ một cách mượt mà. | [ ] Pass |
| **F4** | Mở liên kết Web & Email | Vào Cài đặt $\rightarrow$ Liên hệ & Hỗ trợ $\rightarrow$ Bấm Email / Cổng web. | Mở đúng ứng dụng Mail hoặc trình duyệt Safari ngoài. | [ ] Pass |
| **F5** | Hiển thị phiên bản | Cuộn xuống đáy màn hình Cài đặt Hồ sơ. | Hiển thị chính xác: **Version 1.0.2 (Build 8)**. | [ ] Pass |

---

## 3. CÁC KỊCH BẢN KIỂM THỬ NGOẠI LỆ & BIÊN (EDGE CASES)

1. **Người dùng tắt quyền Thông báo trong Settings iPhone**:
   - Vào Settings máy $\rightarrow$ Notifications $\rightarrow$ HeartPearl $\rightarrow$ Tắt cho phép.
   - App vẫn hoạt động bình thường, không crash khi gửi/nhận tin nhắn trong app.
2. **Nhận nhiều tin nhắn liên tiếp khi đang ở màn hình khác**:
   - Khi nhận 3 tin nhắn liên tục, banner sẽ cập nhật nội dung tin nhắn mới nhất và làm mới bộ đếm 4.5 giây, không bị giật hay xếp chồng lỗi giao diện.
3. **Mạng chập chờn khi đang quay video**:
   - Bộ đếm thời gian neon trên camera chạy dựa trên đồng hồ cục bộ của thiết bị nên hoàn toàn độc lập với kết nối mạng, đảm bảo không bao giờ bị đứng hình hay trôi giây.

---

## 4. MẪU BÁO CÁO LỖI (BUG REPORT TEMPLATE)

Nếu phát hiện lỗi trong quá trình chạy thử, vui lòng báo cáo theo mẫu sau:
- **Tiêu đề lỗi:** `[v1.0.2][Push/Camera/UI] Mô tả ngắn gọn lỗi`
- **Thiết bị & Phiên bản iOS:** Ví dụ: `iPhone 14 Pro, iOS 17.6.1`
- **Tài khoản test:** Email tài khoản thực hiện
- **Các bước tái hiện (Steps to Reproduce):**
  1. ...
  2. ...
- **Kết quả thực tế (Actual Result):** ...
- **Kết quả mong đợi (Expected Result):** ...
- **Ảnh / Video đính kèm:** ...
