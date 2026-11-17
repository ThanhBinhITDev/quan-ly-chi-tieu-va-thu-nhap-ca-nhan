# Student Finance — Ứng dụng Quản lý Chi tiêu và Thu nhập Cá nhân

> **"Tiền đi đâu — Bạn biết đó!"**

Nền tảng quản lý tài chính cá nhân dành cho sinh viên Việt Nam. Ghi một khoản chi dưới 5 giây, và luôn biết **hôm nay còn được tiêu bao nhiêu**.

---

## Cấu trúc repository

```
quan-ly-chi-tieu-va-thu-nhap-ca-nhan/
├── apps/                           # Ứng dụng cho người dùng cuối — 3 nền tảng
│   ├── ios/                        # iPhone: SwiftUI native (chưa có mã)
│   ├── android/                    # Android: Flutter
│   └── web/                        # Web: Next.js, React, TypeScript
├── assets/brand/                   # Logo gốc: SVG, PDF, PNG các kích thước
├── packages/                       # Mã dùng chung
│   └── shared-types/               # DTO + openapi.yaml, sinh client Dart và Swift
├── services/                       # Backend — chạy trên máy chủ, không có giao diện
│   ├── api/                        # NestJS: nhận request HTTP từ app
│   └── worker/                     # NestJS: 12 job định kỳ + hàng đợi đồng bộ
├── infra/                          # Hạ tầng
│   └── migrations/                 # 2 migration đã áp dụng: 12 bảng, RLS, 25 index
├── docs/                           # Tài liệu
│   ├── 01-tong-quan.md             # Định vị, vấn đề, giải pháp
│   ├── 02-san-pham.md              # Tính năng, AI, giữ chân người dùng
│   ├── 03-ky-thuat.md              # Kiến trúc, công nghệ, nguyên tắc
│   ├── 04-kinh-doanh.md            # Gói giá, doanh thu thực nhận, chi phí
│   ├── 05-lo-trinh.md              # Mốc thời gian, phạm vi MVP
│   ├── TODO.md                     # Việc còn lại
│   ├── *.docx                      # Thuyết minh gốc và chiến lược giữ chân
│   └── system-design/              # Thiết kế kỹ thuật chi tiết, 11 tài liệu 00–10
└── .gitignore
```

**Trạng thái:** các thư mục đã có khung và `README.md`, đã có migration SQL khởi tạo schema. Mã nguồn ứng dụng bắt đầu từ tuần 1 ([lộ trình](docs/05-lo-trinh.md)).

**Quy tắc:** ba app không import mã của nhau. Chia sẻ qua hợp đồng API trong `packages/shared-types/` và đặc tả [08-api-principles](docs/system-design/08-api-principles.md).

---

## Đọc gì trước

| File | Nội dung |
|---|---|
| [docs/01-tong-quan.md](docs/01-tong-quan.md) | Định vị, vấn đề, giải pháp, ranh giới sản phẩm |
| [docs/02-san-pham.md](docs/02-san-pham.md) | Tính năng, AI, giữ chân người dùng |
| [docs/03-ky-thuat.md](docs/03-ky-thuat.md) | Kiến trúc, công nghệ, nguyên tắc kỹ thuật |
| [docs/04-kinh-doanh.md](docs/04-kinh-doanh.md) | Gói giá, doanh thu thực nhận, chi phí |
| [docs/05-lo-trinh.md](docs/05-lo-trinh.md) | Mốc thời gian, phạm vi MVP, thứ tự cắt |
| [docs/system-design/00-architecture.md](docs/system-design/00-architecture.md) | Kiến trúc hệ thống đầy đủ — bắt đầu từ đây nếu là người kỹ thuật |

---

## Điểm khác biệt cốt lõi

| Điểm | Ý nghĩa |
|---|---|
| **Ma sát thấp** | Ghi một khoản chi dưới 5 giây — nhập nhanh `com 35k`, chụp hóa đơn, hoặc widget một chạm |
| **Ngưỡng hiểu thấp** | Không thuật ngữ kế toán. Mọi con số hiển thị dạng "còn được tiêu bao nhiêu" |
| **Cảnh báo chủ động** | Thông báo ở 70% / 90% / 100% hạn mức — biết trước khi hết tiền |

Chỉ số trung tâm, cũng là lý do người dùng mở app mỗi ngày:

```
Ngân sách tháng:   3.000.000 đ
Đã chi:            1.850.000 đ
Còn lại:           1.150.000 đ
Còn 12 ngày   →   Hôm nay tối đa: 95.800 đ
```

Ghi chú: 12 ngày còn lại tính cả hôm nay.

---

## Ranh giới sản phẩm

> **App không giữ tiền.** Không nạp, không rút, không liên kết tài khoản ngân hàng, không thực hiện giao dịch. App chỉ ghi chép lại những gì người dùng đã chi hoặc đã nhận.

---

## Công nghệ

| Thành phần | Công nghệ |
|---|---|
| iPhone (`apps/ios`) | SwiftUI native, SwiftData, Swift Charts. Hiệu ứng Liquid Glass trên iOS 26 |
| Android (`apps/android`) | Flutter, Riverpod, drift |
| Web (`apps/web`) | Next.js, React, TypeScript |
| Backend (`services/`) | NestJS (API) + NestJS Worker, BullMQ, Redis |
| CSDL, đăng nhập, lưu trữ file | PostgreSQL 15 trên Supabase (chỉ dùng Postgres + Auth + Storage) |
| AI (giai đoạn sau MVP) | ML Kit chạy trên máy + mô hình cỡ nhỏ qua lớp trừu tượng |

Lý do chọn và đánh đổi: [docs/03-ky-thuat.md](docs/03-ky-thuat.md) và [docs/system-design/00-architecture.md](docs/system-design/00-architecture.md).

---

## Trạng thái

**Thiết kế hệ thống đang ở bản nháp 2.0, chờ duyệt. Chưa có mã nguồn ứng dụng; schema đã được áp dụng lên Supabase project `ebbqcnnwqeasozmcqigu`.**

Đã xong:
- [x] Thuyết minh ý tưởng và kế hoạch kinh doanh
- [x] Đặc tả sản phẩm và chức năng chi tiết
- [x] Chiến lược giữ chân người dùng
- [x] Mô hình chi phí AI
- [x] Thiết kế hệ thống: kiến trúc, schema DB, hợp đồng API, đồng bộ, wireframe, cấu trúc iOS và Flutter, 12 job định kỳ
- [x] Khung thư mục ba nền tảng và hai package dùng chung
- [x] Migration SQL khởi tạo 12 bảng + RLS (đã áp dụng và xác minh lên Supabase)
- [x] File logo gốc và các bản export SVG, PDF, PNG, favicon, PWA icon

Chưa làm:
- [ ] Khảo sát người dùng thực tế (150–200 sinh viên)
- [ ] Bảng tài chính 3 năm có con số cụ thể
- [ ] Phân tích đối thủ chi tiết
- [ ] Mã nguồn (ios, android, web, api, worker)
- [ ] Hoàn thiện bộ nhận diện thương hiệu: chữ trên logo còn ghi "SMARTFIN", cần quyết có đổi sang "Student Finance" không; chưa chốt typography

Danh sách việc đầy đủ: [docs/TODO.md](docs/TODO.md).

---

## Đội ngũ

| Họ tên | Chuyên ngành | Vai trò |
|---|---|---|
| Nguyễn Huyền Diệu | Kế toán K20 | Trưởng nhóm, quản lý dự án, phát triển ý tưởng |
| Lê Thị Quỳnh Mai | Kế toán K20 | Tài chính, kế hoạch tài chính |
| Nguyễn Công Danh | Kế toán K20 | Thuyết trình, nghiên cứu thị trường |
| Lê Thanh Bình | Thiết kế Đồ họa K19 | Kỹ thuật, UI/UX, cơ sở dữ liệu, hạ tầng, bảo mật |
| Hà Văn Thương | Kế toán K20 | Chưa xác định |

> Vai trò của Hà Văn Thương chưa được chốt trong tài liệu gốc — chờ nhóm trưởng xác nhận.

---

## Bản quyền

© 2026 Student Finance. Bảo lưu mọi quyền.

Mã nguồn, tài liệu thiết kế và bộ nhận diện thương hiệu thuộc quyền sở hữu của nhóm phát triển. Mọi hình thức sao chép, phân phối lại hoặc sử dụng thương mại cần có văn bản đồng ý.
