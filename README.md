# Ứng dụng Quản lý Chi tiêu và Thu nhập Cá nhân

> **"Tiền đi đâu — Bạn biết đó!"**

Nền tảng quản lý tài chính cá nhân dành cho sinh viên Việt Nam.

---

## Vấn đề

Sinh viên thường hết tiền trước cuối tháng nhưng không biết tiền đã đi đâu. Các khoản chi nhỏ hàng ngày (ăn uống, trà sữa, đi lại) không được ghi lại nên không thể kiểm soát. Khi nhận ra vấn đề thì đã quá muộn để điều chỉnh.

Ba nguyên nhân gốc rễ:

| Nguyên nhân | Biểu hiện |
|---|---|
| **Thiếu công cụ** | App hiện có yêu cầu quá nhiều thao tác để ghi một khoản chi |
| **Thiếu kiến thức** | Sinh viên không được trang bị kỹ năng quản lý tài chính |
| **Sai đối tượng** | Money Lover, Misa, Spendee thiết kế cho người đi làm — quá phức tạp với sinh viên |

Điểm quan trọng: **app ngân hàng (VCB, TPBank, Momo) đã có thống kê chi tiêu tự động**, nhưng mỗi ngân hàng chỉ thấy một phần. Sinh viên dùng tiền mặt + Momo + nhiều thẻ ngân hàng → không app nào thấy toàn cảnh.

---

## Giải pháp

Ứng dụng di động (iOS + Android) giúp sinh viên ghi nhận thu chi trong **dưới 5 giây**, tự động phân loại, và quan trọng nhất: **biết hôm nay còn được tiêu bao nhiêu**.

### Ba trụ cột khác biệt

1. **Ma sát thấp** — ghi một khoản chi dưới 5 giây, hỗ trợ nhập nhanh bằng cú pháp (`com 35k`) và chụp hóa đơn
2. **Ngưỡng hiểu thấp** — không dùng thuật ngữ kế toán, mọi con số hiển thị dạng "còn được tiêu bao nhiêu"
3. **Cảnh báo chủ động** — thông báo ở mức 70% / 90% / 100% hạn mức, biết trước khi hết tiền

### Tính năng cốt lõi

| Nhóm | Chức năng chính |
|---|---|
| **A. Ghi nhận** | Ghi thu/chi, đa ví (tiền mặt, Momo, ngân hàng), nhập nhanh cú pháp, hoạt động offline |
| **B. Phân tích** | Biểu đồ cơ cấu, xu hướng theo ngày, so sánh kỳ trước, lọc và tìm kiếm |
| **C. Kiểm soát** | Chỉ số "hôm nay được tiêu", ngân sách theo danh mục, cảnh báo nhiều mức, mục tiêu tiết kiệm |
| **D. AI & nâng cao** | Đọc hóa đơn, trợ lý hỏi đáp, nhận xét thói quen, đồng bộ đa thiết bị |
| **E. Hỗ trợ** | Onboarding, trợ giúp trong app, kênh phản hồi |

### Chỉ số trung tâm

```
Ngân sách tháng:   3.000.000 đ
Đã chi:            1.850.000 đ
Còn lại:           1.150.000 đ
Còn 12 ngày   →   Hôm nay tối đa: 95.800 đ
```

Đây là màn hình chính, cũng là lý do người dùng mở app mỗi ngày.

---

## Năng lực AI

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

---

## Giữ chân người dùng

Rủi ro lớn nhất của thể loại app này: **người dùng bỏ sau 2 tuần**. Trung bình ngành D30 chỉ 10–15%.

Chiến lược: **kéo giá trị về ngày đầu tiên**, không phải gửi thông báo nhắc nhở.

| Cơ chế | Nội dung |
|---|---|
| Onboarding 3 bước | Không bắt đăng ký, nạp sẵn dữ liệu mẫu, thấy giá trị ngay phút đầu |
| Chỉ số hôm nay + widget | Con số hiển thị ngoài màn hình chính, không cần mở app |
| Thông báo có số liệu | 1 tin/ngày, luôn chứa thông tin, không nhắc suông |
| Đếm ngày ghi trong tháng | Không dùng streak liên tiếp (dễ gây bỏ app) |
| Win-back 2 bước | Sau 7 và 14 ngày, rồi dừng hẳn |

**Mục tiêu:** D1 > 55%, D7 > 30%, D30 > 20% (gấp đôi trung bình ngành).

---

## Mô hình kinh doanh

**Freemium** — bản miễn phí đủ dùng, gói Pro mở khóa tính năng sâu.

| Gói | Giá | Quyền lợi chính |
|---|---|---|
| Miễn phí | 0đ | Toàn bộ nhóm A, B, C. 10 lượt AI/tháng. Có quảng cáo |
| Pro tháng | 29.000đ/tháng | Toàn bộ nhóm D. 300 lượt AI/tháng. Không quảng cáo |
| Pro năm | 249.000đ/năm | Tiết kiệm ~28% |
| Pro sinh viên | 199.000đ/năm | Xác thực bằng email trường |

**Lưu ý:** doanh thu thực nhận sau khi trừ hoa hồng Google/Apple (15–30%) chỉ còn **20.300–24.650đ** cho gói 29.000đ.

### Cơ cấu chi phí (đề xuất điều chỉnh)

| Nhóm | Tỷ trọng | Tính chất |
|---|---|---|
| Hạ tầng cố định | 8–10% | Server, domain, tài khoản store |
| Dịch vụ AI | 3–5% (tối đa 25% doanh thu) | Biến đổi theo số user |
| Nhân sự | 25–30% | Cố định theo tháng |
| Marketing | 20–25% | Linh hoạt |
| Dự phòng | 10–15% | Nâng cấp, rủi ro |

---

## Kiến trúc kỹ thuật

| Thành phần | Công nghệ | Lý do |
|---|---|---|
| Mobile | **Flutter** | 1 codebase cho iOS + Android |
| Local DB | SQLite (drift) | Offline-first, query thống kê nhanh |
| Backend | **Supabase** | Postgres + Auth + Storage, free tier đủ MVP |
| Sync | Supabase Realtime + queue cục bộ | Ghi local trước, đẩy lên sau |
| OCR | Google ML Kit (on-device) | Miễn phí, không gửi ảnh lên server |
| LLM | Mô hình cỡ nhỏ qua lớp trừu tượng | Đổi nhà cung cấp không sửa app |
| Chart | fl_chart | Nhẹ, đủ dùng |
| Push | FCM | Miễn phí |
| Payment | Google Play Billing / StoreKit | Bắt buộc cho gói kỹ thuật số |

**Chi phí hạ tầng giai đoạn đầu: gần 0đ** nhờ các gói miễn phí.

---

## Lộ trình

| Giai đoạn | Nội dung |
|---|---|
| **MVP (tuần 1–6)** | Ghi thu/chi, danh mục, ví, chỉ số hôm nay, ngân sách, biểu đồ, offline, auth |
| **Tuần 7–8** | AI-1 đọc hóa đơn, AI-2 phân loại, cổng hạn mức |
| **Tuần 9–10** | AI-3 hỏi đáp, đo chi phí thật, test với 20–30 sinh viên |
| **Giai đoạn 2** | AI-4 nhận xét tháng, đồng bộ đa thiết bị, xuất dữ liệu |

**Phạm vi MVP:** chỉ 3 thứ — ghi chi tiêu, chỉ số hạn mức hôm nay, biểu đồ tròn. Demo 3 cái này chạy thật mạnh hơn 10 tính năng trên slide.

---

## Cấu trúc repository

```
quan-ly-chi-tieu-sinh-vien/
├── README.md
├── docs/
│   ├── Mo_ta_ung_dung_Quan_ly_chi_tieu_va_thu_nhap.docx
│   └── Chien_luoc_giu_chan_nguoi_dung.docx
└── .gitignore
```

Tài liệu trong `docs/`:

- **Mo_ta_ung_dung...docx** — đặc tả sản phẩm 12 chương, 34 bảng: định vị, 38 chức năng, luồng sử dụng, mô hình dữ liệu, kiến trúc kỹ thuật, bảo mật, Chương 4 riêng về AI, lộ trình, KPI
- **Chien_luoc_giu_chan_nguoi_dung.docx** — chiến lược retention 11 chương, 10 bảng: 4 mốc rơi rụng, 6 cơ chế giữ chân, đo lường cohort, thứ tự triển khai

---

## Trạng thái dự án

**Giai đoạn: đặc tả sản phẩm hoàn tất, bắt đầu thiết kế hệ thống.**

Đã hoàn thành:
- [x] Thuyết minh ý tưởng và kế hoạch kinh doanh
- [x] Đặc tả sản phẩm và chức năng chi tiết
- [x] Chiến lược giữ chân người dùng
- [x] Mô hình chi phí AI
- [x] Kiến trúc kỹ thuật đề xuất

Chưa làm:
- [ ] Thiết kế hệ thống (schema, API, luồng dữ liệu) — **đang thực hiện**
- [ ] Khảo sát người dùng thực tế
- [ ] Bảng tài chính 3 năm
- [ ] Phân tích đối thủ chi tiết
- [ ] Mã nguồn MVP
- [ ] Bộ nhận diện thương hiệu (logo, màu sắc, typography)

---

## Đội ngũ

| Họ tên | Vai trò |
|---|---|
| Nguyễn Huyền Diệu | Trưởng nhóm, quản lý dự án, phát triển ý tưởng |
| Lê Thị Quỳnh Mai | Tài chính, kế hoạch tài chính |
| Nguyễn Công Danh | Thuyết trình, nghiên cứu thị trường |
| Lê Thanh Bình | Kỹ thuật, UI/UX, cơ sở dữ liệu, hạ tầng, bảo mật |
| Hà Văn Thương | Nghiên cứu thị trường, hậu cần |

---

## Bản quyền

© 2026 Ứng dụng Quản lý Chi tiêu và Thu nhập Cá nhân. Bảo lưu mọi quyền.

Mã nguồn, tài liệu thiết kế và bộ nhận diện thương hiệu thuộc quyền sở hữu của nhóm phát triển. Mọi hình thức sao chép, phân phối lại hoặc sử dụng thương mại cần có văn bản đồng ý.
