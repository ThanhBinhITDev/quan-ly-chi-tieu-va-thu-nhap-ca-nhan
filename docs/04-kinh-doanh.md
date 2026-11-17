# 04 — Kinh doanh

**Cập nhật:** 2026-11-16

---

## 1. Mô hình

**Freemium** — bản miễn phí đủ dùng, gói Pro mở khóa tính năng sâu.

| Gói | Giá | Quyền lợi chính |
|---|---|---|
| Miễn phí | 0đ | Toàn bộ nhóm A, B, C. 10 lượt AI/tháng. Có quảng cáo |
| Pro tháng | 29.000đ/tháng | Toàn bộ nhóm D. 300 lượt AI/tháng. Không quảng cáo |
| Pro năm | 249.000đ/năm | Tiết kiệm ~28% |
| Pro sinh viên | 199.000đ/năm | Xác thực bằng email trường |

---

## 2. Doanh thu thực nhận

Đây là con số quan trọng nhất và hay bị bỏ sót trong bảng kế hoạch:

| Gói | Giá niêm yết | Hoa hồng store | **Thực nhận** |
|---|---|---|---|
| Pro tháng | 29.000đ | 15–30% | **20.300 – 24.650đ** |
| Pro năm | 249.000đ | 15–30% | **174.300 – 211.650đ** |
| Pro sinh viên | 199.000đ | 15–30% | **139.300 – 169.150đ** |

> Mọi bảng doanh thu phải dùng cột "thực nhận", không dùng giá niêm yết. Dùng nhầm sẽ thổi phồng doanh thu 15–30%.

**Lưu ý về hoa hồng:** mức 15% áp dụng cho doanh thu năm đầu của gói đăng ký dài hạn (chương trình Small Business của Apple). Mức 30% là mặc định. Với Google Play, mức thấp là 15% cho 1 triệu USD đầu tiên mỗi năm.

---

## 3. Cơ cấu chi phí (đề xuất điều chỉnh)

| Nhóm | Tỷ trọng | Tính chất |
|---|---|---|
| Hạ tầng cố định | 8–10% | Server, domain, tài khoản store |
| Dịch vụ AI | 3–5% (tối đa 25% doanh thu) | Biến đổi theo số user |
| Nhân sự | 25–30% | Cố định theo tháng |
| Marketing | 20–25% | Linh hoạt |
| Dự phòng | 10–15% | Nâng cấp, rủi ro |

---

## 4. Chi phí hạ tầng theo quy mô

Bốn mốc, dùng free tier Supabase + VPS:

| Mốc | Người dùng | Chi phí/tháng (ước tính) |
|---|---|---|
| 1 | 0 – 100 | ~44.000đ (chỉ domain + VPS nhỏ) |
| 2 | 100 – 1.000 | ~600.000đ |
| 3 | 1.000 – 10.000 | ~5.000.000đ |
| 4 | 10.000 – 50.000 | ~30.500.000đ |

**Chưa gồm:** hoa hồng store (tính riêng ở mục 2), chi phí AI (tính riêng theo lượt), nhân sự.

**Điểm cần kiểm chứng:** khi vượt free tier Supabase, có mua Redis trả phí không (D2 trong [system-design/00](system-design/00-architecture.md) mục 12). BullMQ cần Redis; free tier 25MB thường đủ cho MVP nhưng không đủ khi có hàng chục nghìn người.

---

## 5. Điểm chưa xác định

| # | Việc | Vì sao quan trọng |
|---|---|---|
| 1 | Bảng tài chính 3 năm có con số cụ thể | Giám khảo/đối tác hỏi ngay; chưa có thì kế hoạch chưa đứng được |
| 2 | Khảo sát 150–200 sinh viên về thói hạn chi tiêu | Mọi con số "sinh viên chi trung bình X/tháng" cần nguồn thật |
| 3 | Phân tích đối thủ (Money Lover, Misa, Spendee, app ngân hàng) | Phải có bảng so sánh, không nói chung chung |

---

## 6. Tài liệu liên quan

| File | Nội dung |
|---|---|
| [01 — Tổng quan](01-tong-quan.md) | Định vị, phân khúc |
| [02 — Sản phẩm](02-san-pham.md) | Tính năng, AI |
| [05 — Lộ trình](05-lo-trinh.md) | Mốc thời gian |
