# 01 — Tổng quan

**Cập nhật:** 2026-11-16

---

## 1. Định vị

| Mục | Nội dung |
|---|---|
| Tên | **Student Finance** — Ứng dụng Quản lý Chi tiêu và Thu nhập Cá nhân |
| Slogan | *"Tiền đi đâu — Bạn biết đó!"* |
| Nền tảng | iOS (native SwiftUI), Android, Web |
| Mô hình | Freemium, gói Pro 29.000đ/tháng |

---

## 2. Phân khúc khách hàng

| Phân khúc | Vai trò |
|---|---|
| Sinh viên cao đẳng, đại học | **Khách hàng chính** — đặc biệt nhóm có thu nhập hạn chế từ gia đình, học bổng hoặc làm thêm |
| Học sinh THPT có nhu cầu quản lý tiền cá nhân | Phân khúc mở rộng |
| Người có thu nhập hạn chế, muốn kiểm soát chi tiêu và tiết kiệm | Phân khúc mở rộng |

Đối tượng khách hàng quan trọng nhất: sinh viên có thu nhập hạn chế. Sau khi hoạt động ổn định, dự án mở rộng đến học sinh THPT, người mới đi làm và các cá nhân có nhu cầu quản lý tài chính cá nhân.

---

## 3. Vấn đề

Sinh viên thường hết tiền trước cuối tháng nhưng không biết tiền đã đi đâu. Các khoản chi nhỏ hàng ngày (ăn uống, trà sữa, đi lại) không được ghi lại nên không thể kiểm soát. Khi nhận ra vấn đề thì đã quá muộn để điều chỉnh.

Ba nguyên nhân gốc rễ:

| Nguyên nhân | Biểu hiện |
|---|---|
| **Thiếu công cụ** | App hiện có yêu cầu quá nhiều thao tác để ghi một khoản chi |
| **Thiếu kiến thức** | Sinh viên không được trang bị kỹ năng quản lý tài chính |
| **Sai đối tượng** | Money Lover, Misa, Spendee thiết kế cho người đi làm — quá phức tạp với sinh viên |

Điểm quan trọng: **app ngân hàng (VCB, TPBank, Momo) đã có thống kê chi tiêu tự động**, nhưng mỗi ngân hàng chỉ thấy một phần. Sinh viên dùng tiền mặt + Momo + nhiều thẻ ngân hàng → không app nào thấy toàn cảnh.

---

## 4. Giải pháp

Ứng dụng giúp sinh viên ghi nhận thu chi trong **dưới 5 giây**, tự động phân loại, và quan trọng nhất: **biết hôm nay còn được tiêu bao nhiêu**.

### Ba trụ cột khác biệt

1. **Ma sát thấp** — ghi một khoản chi dưới 5 giây, hỗ trợ nhập nhanh bằng cú pháp (`com 35k`) và chụp hóa đơn
2. **Ngưỡng hiểu thấp** — không dùng thuật ngữ kế toán, mọi con số hiển thị dạng "còn được tiêu bao nhiêu"
3. **Cảnh báo chủ động** — thông báo ở mức 70% / 90% / 100% hạn mức, biết trước khi hết tiền

### Ranh giới sản phẩm

> **App không giữ tiền.** Không nạp, không rút, không liên kết tài khoản ngân hàng, không thực hiện giao dịch. App chỉ ghi chép lại những gì người dùng đã chi hoặc đã nhận.

Ranh giới này quan trọng: nó giữ app ngoài phạm vi quản lý của luật tổ chức tín dụng, đồng thời tránh mọi rủi ro bảo mật liên quan đến tiền thật.

---

## 5. Tính năng

| Nhóm | Chức năng chính |
|---|---|
| **A. Ghi nhận** | Ghi thu/chi, đa ví (tiền mặt, Momo, ngân hàng), nhập nhanh cú pháp, hoạt động offline |
| **B. Phân tích** | Biểu đồ cơ cấu, xu hướng theo ngày, so sánh kỳ trước, lọc và tìm kiếm |
| **C. Kiểm soát** | Chỉ số "hôm nay được tiêu", ngân sách theo danh mục, cảnh báo nhiều mức, mục tiêu tiết kiệm (nhập tay) |
| **D. AI & nâng cao** | Đọc hóa đơn, trợ lý hỏi đáp, nhận xét thói quen, đồng bộ đa thiết bị |
| **F. Chia tiền nhóm** | Tạo nhóm bằng mã mời, chia đều hoặc chia theo số tiền, xem ai nợ ai, đánh dấu đã trả |
| **E. Hỗ trợ** | Onboarding, trợ giúp trong app, kênh phản hồi |

---

## 6. Chỉ số trung tâm

```
Ngân sách tháng:   3.000.000 đ
Đã chi:            1.850.000 đ
Còn lại:           1.150.000 đ
Còn 12 ngày   →   Hôm nay tối đa: 95.800 đ
```

Đây là màn hình chính, cũng là lý do người dùng mở app mỗi ngày.

**Công thức bắt buộc:**

```
daily_limit = (budget_month - spent_month) / days_left
```

`days_left` **tính cả hôm nay**. Ví dụ: kỳ 1–30/11, hôm nay 13/11 → `days_left = 18`, không phải 17.

Mọi truy vấn tổng chi phải có `AND type = 'expense'` — chuyển ví không tính là chi.

---

## 7. Tài liệu liên quan

| File | Nội dung |
|---|---|
| [02 — Sản phẩm](02-san-pham.md) | AI, giữ chân người dùng, chỉ số chất lượng |
| [03 — Kỹ thuật](03-ky-thuat.md) | Kiến trúc, công nghệ, cấu trúc repository |
| [04 — Kinh doanh](04-kinh-doanh.md) | Gói giá, doanh thu, cơ cấu chi phí |
| [05 — Lộ trình](05-lo-trinh.md) | Các mốc thời gian, phạm vi MVP |
| [system-design/](system-design/README.md) | Thiết kế kỹ thuật chi tiết |
