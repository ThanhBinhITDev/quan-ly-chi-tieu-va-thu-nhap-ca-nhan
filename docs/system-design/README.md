# Thiết kế hệ thống

Bộ tài liệu thiết kế kỹ thuật cho ứng dụng Quản lý Chi tiêu và Thu nhập Cá nhân.

**Đọc theo thứ tự.** Tài liệu `00` là gốc; các tài liệu sau triển khai chi tiết nội dung của nó.

| # | Tài liệu | Nội dung | Trạng thái |
|---|---|---|---|
| 00 | [Kiến trúc hệ thống](00-architecture.md) | Mục tiêu, C4 hai mức, 3 nền tảng, luồng dữ liệu, 12 job cron, bảo mật, chi phí, ADR | 2.0 |
| 01 | [Cơ sở dữ liệu](01-database-schema.md) | 7 bảng, quan hệ, index, RLS, truy vấn then chốt, dung lượng | 2.0 |
| 02 | [Hợp đồng API](02-api-contract.md) | Endpoint, request/response, mã lỗi, giới hạn tải, công thức dùng chung | 2.0 |
| 03 | [Đồng bộ dữ liệu](03-sync-strategy.md) | Local-first, hàng đợi, chống trùng, xử lý xung đột, toàn vẹn | 2.0 |
| 04 | [Màn hình](04-wireframes.md) | 5 màn hình chính, khối, trạng thái, màu, thông báo | 2.0 |
| 05 | [Cấu trúc iOS (SwiftUI)](05-ios-structure.md) | Thư mục, phân lớp, SwiftData, async/await, kiểm thử | 2.0 (mới) |
| 06 | [Cấu trúc Flutter (Android + Web)](06-flutter-structure.md) | Thư mục, phân lớp, Riverpod, drift, kiểm thử | 2.0 (đổi tên) |
| 07 | [Công việc định kỳ](07-cron-jobs.md) | 12 job, lịch chạy, khoá chống trùng, xử lý lỗi, giám sát | 2.0 (mới) |

---

## Bốn quyết định nền tảng

| # | Quyết định | Chọn | Hệ quả |
|---|---|---|---|
| Q1 | Nguồn dữ liệu chính | Local DB trên máy (`SwiftData` cho iOS, `drift` cho Android/Web), đồng bộ lên Postgres | App ghi được khi không có mạng |
| Q3 | Chuyển ví không tính vào tổng chi | Mọi truy vấn tổng chi phải có `AND type = 'expense'` | Số liệu thống kê đúng |
| Q4 | Ba nền tảng, hai codebase | iOS dùng SwiftUI native; Android và Web dùng chung Flutter | Liquid Glass thật trên iOS, tiết kiệm nhân lực cho Android |
| Q5 | Backend tự viết | NestJS cho API và Worker; Supabase chỉ làm Postgres + Auth + Storage | Logic nghiệp vụ kiểm thử được, không khoá vào một nhà cung cấp |

## Công nghệ

| Lớp | Công nghệ | Ghi chú |
|---|---|---|
| iOS | SwiftUI, Swift 6, iOS 26+ | Liquid Glass dùng được thật; fallback khi không có |
| Android | Flutter 3.24+, Riverpod 2, drift | Một codebase với Web |
| Web | Flutter Web | Ưu tiên thấp ở MVP |
| Backend | NestJS (TypeScript) | Phân tầng controller → service → repository |
| Hàng đợi + cron | BullMQ + Redis | 12 job ở [07](07-cron-jobs.md) |
| Cơ sở dữ liệu | PostgreSQL 15 (Supabase) | RLS bật trên mọi bảng |
| Xác thực | Supabase Auth | JWT, refresh token |
| Lưu trữ tệp | Supabase Storage | Ảnh hoá đơn, signed URL |
| Biểu đồ | Swift Charts (iOS), fl_chart (Flutter) | Không dùng thư viện ngoài cho iOS |
| Thông báo | FCM (Android), APNs (iOS) | Miễn phí |
| Thanh toán | Google Play Billing / StoreKit | Bắt buộc cho gói số phẩm |
| AI | Gemini Flash (server) + ML Kit (máy) | AI không sinh con số tài chính |

## Đã loại bỏ

| Nội dung | Lý do | Ngày |
|---|---|---|
| Tính năng mục tiêu tiết kiệm (bảng `goals`) | Con số người dùng tự gõ, không kiểm chứng được, không gắn với tiền thật | 2026-11-16 |
| Q2 cũ ("mục tiêu tách khỏi ví") | Không còn đối tượng | 2026-11-16 |
| Supabase Realtime | Local-first đã đủ; kết nối thường trực tốn pin, khó test | 2026-11-16 |
| Supabase Edge Functions | Deno, khó debug, cold start | 2026-11-16 |
| pg_cron | Không retry, không dead-letter, không gọi API ngoài | 2026-11-16 |

## Trạng thái

Bản nháp 2.0 — đã chốt Q1, Q3–Q7; loại bỏ mục tiêu tiết kiệm. Bốn điểm còn chờ quyết ở [mục 16 của 00](00-architecture.md#16-điểm-cần-bạn-quyết).
