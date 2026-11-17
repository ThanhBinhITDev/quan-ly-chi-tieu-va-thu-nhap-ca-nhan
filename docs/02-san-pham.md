<p align="center">
  <img src="../assets/brand/student-finance-logo-192.png" alt="Student Finance" width="96" />
</p>

# 02 — Sản phẩm

**Cập nhật:** 2026-11-16

---

## 1. Năng lực AI

AI là **lớp hỗ trợ, không phải nguồn dữ liệu gốc**. Nguyên tắc bất di bất dịch:

> **Mọi con số tài chính do database tính bằng công thức xác định. Mô hình ngôn ngữ tuyệt đối không sinh ra con số.**

| Mã | Chức năng | Chạy ở đâu | Chi phí/lượt |
|---|---|---|---|
| AI-1 | Đọc hóa đơn | ML Kit (máy) + mô hình đọc hiểu | ~8đ |
| AI-2 | Phân loại giao dịch | Trên máy, miễn phí | 0đ |
| AI-3 | Trợ lý hỏi đáp | Máy chủ | ~13đ |
| AI-4 | Nhận xét thói quen tháng | Máy chủ, 1 lần/tháng | ~18đ |

**Chi phí thực tế:** user free dùng hết hạn mức ≈ 220đ/tháng. Ở quy mô có doanh thu, chi phí AI chiếm ~11% doanh thu.

Kiểm soát bằng 4 lớp: hạn mức theo gói → cache kết quả → xử lý trên thiết bị trước → cầu dao chi phí tự động.

**Cách cưỡng chế nguyên tắc "không sinh số":** mọi đầu ra của mô hình được kiểm tra — nếu chứa con số không khớp dữ liệu thật trong database, kết quả bị huỷ và ghi log. Xem [system-design/07](system-design/07-cron-jobs.md) mục 2.7.

---

## 2. Giữ chân người dùng

Rủi ro lớn nhất của thể loại app này: **người dùng bỏ sau 2 tuần**. Trung bình ngành D30 chỉ 10–15%.

Chiến lược: **kéo giá trị về ngày đầu tiên**, không phải gửi thông báo nhắc nhở.

| Cơ chế | Nội dung |
|---|---|
| Onboarding 3 bước | Không bắt đăng ký, nạp sẵn dữ liệu mẫu, thấy giá trị ngay phút đầu |
| Chỉ số hôm nay + widget | Con số hiển thị ngoài màn hình chính, không cần mở app |
| Thông báo có số liệu | 1 tin/ngày, luôn chứa thông tin, không nhắc suông |
| Đếm ngày ghi trong tháng | Không dùng streak liên tiếp (dễ gây bỏ app) |
| Win-back 2 bước | Sau 7 và 14 ngày, rồi dừng hẳn |

Chi tiết đầy đủ trong `Chien_luoc_giu_chan_nguoi_dung.docx`.

---

## 3. Ma sát ghi chép — giới hạn đã biết

Không có cách nào tự động 100% với tiền mặt. **MVP chỉ nhập tay**, có nhập nhanh bằng cú pháp (`com 35k`) và widget 1 chạm. Các cách tự động dưới đây là giai đoạn sau, chưa cam kết:

| Giai đoạn | Cách làm | Ma sát | Chi phí |
|---|---|---|---|
| MVP | Nhập tay + nhập nhanh `com 35k` | Trung bình | 0đ |
| MVP | Widget 1 chạm | Thấp | 0đ |
| Sau MVP | Sao kê ngân hàng — nhập một lần, phân loại hàng loạt (foreground) | Thấp, 1 lần/tháng | 0đ |
| Sau MVP | Share sheet từ app khác vào app | Thấp | 0đ |

**Đã loại bỏ:** đọc thông báo bằng `NotificationListenerService`. Lý do: không đáng tin — ROM Trung Quốc giết dịch vụ nền, người dùng sẽ thấy app "lúc được lúc không", tệ hơn là không có tính năng.

**Chưa kiểm chứng** (phải thử trước khi đưa vào lộ trình giai đoạn sau):
- VCB/TPBank/MB có xuất được CSV/Excel hay chỉ PDF
- MoMo share ra text hay chỉ ảnh
- Có app Việt nào đang làm và còn sống trên Play Store

---

## 4. Ngoài phạm vi

| Thứ | Lý do loại |
|---|---|
| Giữ tiền, nạp/rút, liên kết ngân hàng | App chỉ ghi chép; tránh phạm vi luật tổ chức tín dụng |
| Đọc thông báo tự động | Không đáng tin trên ROM Trung Quốc |
| Đồng bộ realtime | Không cần cho MVP; đồng bộ theo lượt đủ dùng |
| Xuất Excel/PDF | Giai đoạn 2 |
| Báo cáo 6 tháng | Giai đoạn 2 |

---

## 5. Tài liệu liên quan

| File | Nội dung |
|---|---|
| [01 — Tổng quan](01-tong-quan.md) | Định vị, vấn đề, giải pháp |
| [03 — Kỹ thuật](03-ky-thuat.md) | Kiến trúc, công nghệ |
| [04 — Kinh doanh](04-kinh-doanh.md) | Gói giá, doanh thu |
| [05 — Lộ trình](05-lo-trinh.md) | Mốc thời gian |
