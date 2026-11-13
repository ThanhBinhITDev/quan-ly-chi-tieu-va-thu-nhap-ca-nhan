# Thiết kế hệ thống

Bộ tài liệu thiết kế kỹ thuật cho ứng dụng Quản lý Chi tiêu và Thu nhập Cá nhân.

| # | Tài liệu | Nội dung |
|---|---|---|
| 01 | [Cơ sở dữ liệu](01-database-schema.md) | Bảng, quan hệ, index, quy ước, RLS, truy vấn then chốt, dung lượng |
| 02 | [Hợp đồng API](02-api-contract.md) | Endpoint, request/response, mã lỗi, giới hạn tải, công thức dùng chung |
| 03 | [Đồng bộ dữ liệu](03-sync-strategy.md) | Local-first, hàng đợi, chống trùng, xử lý xung đột, toàn vẹn |
| 04 | [Màn hình](04-wireframes.md) | 5 màn hình chính, khối, trạng thái, màu, thông báo |
| 05 | [Cấu trúc Flutter](05-flutter-structure.md) | Thư mục, phân lớp, Riverpod, kiểm thử, CI |

---

## Phạm vi

Thiết kế phục vụ **MVP**: ghi chi tiêu, đa ví, chỉ số hôm nay, ngân sách, biểu đồ tròn. Chưa bao gồm AI — nhưng schema, API và cấu trúc mã đã chừa sẵn chỗ (bảng `receipt_url`, `ai_confidence`, endpoint `/ai/*`, thư mục `services/`) để giai đoạn 2 không phải migrate lại.

## Ba quyết định nền tảng

| Quyết định | Chọn |
|---|---|
| Nguồn dữ liệu chính | SQLite trên máy, đồng bộ lên Supabase |
| Khóa chính | UUID sinh trên thiết bị |
| Công thức "hôm nay được tiêu" | Một công thức duy nhất, dùng chung Dart và SQL, có test đối chiếu |

## Công nghệ

| Lớp | Công nghệ |
|---|---|
| Ứng dụng | Flutter 3.24+, Riverpod 2, go_router, drift |
| Backend | Supabase (PostgreSQL, Auth, Storage, Realtime) |
| Biểu đồ | fl_chart |
| Thông báo | Firebase Cloud Messaging |
| Thanh toán | Google Play Billing / StoreKit |

## Trạng thái

Bản nháp 1.0 — chờ duyệt. Mỗi tài liệu có mục "Điểm cần bạn quyết" ở cuối, liệt kê các điểm chưa chốt kèm đề xuất.
