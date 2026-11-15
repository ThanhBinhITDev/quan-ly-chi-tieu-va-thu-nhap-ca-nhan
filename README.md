# Ứng dụng Quản lý Chi tiêu và Thu nhập Cá nhân

> **"Tiền đi đâu — Bạn biết đó!"**

Nền tảng quản lý tài chính cá nhân dành cho sinh viên Việt Nam. Ghi một khoản chi dưới 5 giây, và luôn biết **hôm nay còn được tiêu bao nhiêu**.

---

## Đọc gì trước

| File | Nội dung | Cho ai |
|---|---|---|
| [docs/01-tong-quan.md](docs/01-tong-quan.md) | Định vị, vấn đề, giải pháp, ranh giới sản phẩm | Mọi người |
| [docs/02-san-pham.md](docs/02-san-pham.md) | Tính năng, AI, giữ chân người dùng | Nhóm sản phẩm |
| [docs/03-ky-thuat.md](docs/03-ky-thuat.md) | Kiến trúc, công nghệ, cấu trúc repo | Nhóm kỹ thuật |
| [docs/04-kinh-doanh.md](docs/04-kinh-doanh.md) | Gói giá, doanh thu thực nhận, chi phí | Nhóm tài chính |
| [docs/05-lo-trinh.md](docs/05-lo-trinh.md) | Mốc thời gian, phạm vi MVP, thứ tự cắt | Nhóm trưởng |
| [docs/system-design/](docs/system-design/README.md) | Thiết kế kỹ thuật chi tiết (8 tài liệu) | Nhóm kỹ thuật |

---

## Điểm khác biệt cốt lõi

| | |
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

---

## Ranh giới sản phẩm

> **App không giữ tiền.** Không nạp, không rút, không liên kết tài khoản ngân hàng, không thực hiện giao dịch. App chỉ ghi chép lại những gì người dùng đã chi hoặc đã nhận.

---

## Công nghệ

| Nền tảng | Công nghệ |
|---|---|
| iOS | **SwiftUI native** (iOS 26, Liquid Glass, SwiftData, Swift Charts) |
| Android + Web | **Flutter** + Riverpod + drift |
| Backend | **NestJS** (API) + **NestJS Worker** + BullMQ + Redis |
| CSDL / Auth / Storage | **PostgreSQL 15 trên Supabase** |
| AI | ML Kit on-device + mô hình cỡ nhỏ qua lớp trừu tượng |

Chi tiết và lý do ở [docs/03-ky-thuat.md](docs/03-ky-thuat.md).

---

## Trạng thái

**Thiết kế hệ thống hoàn tất bản nháp 2.0 — chờ duyệt trước khi lập trình.**

Đã xong:
- [x] Thuyết minh ý tưởng và kế hoạch kinh doanh
- [x] Đặc tả sản phẩm và chức năng chi tiết
- [x] Chiến lược giữ chân người dùng
- [x] Mô hình chi phí AI
- [x] Thiết kế hệ thống: kiến trúc, schema DB, hợp đồng API, đồng bộ, wireframe, cấu trúc iOS, cấu trúc Flutter, 12 job định kỳ

Chưa làm:
- [ ] Khảo sát người dùng thực tế (150–200 sinh viên)
- [ ] Bảng tài chính 3 năm có con số cụ thể
- [ ] Phân tích đối thủ chi tiết
- [ ] Mã nguồn MVP
- [ ] Bộ nhận diện thương hiệu (logo, màu sắc, typography)

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

## Cấu trúc repository

```
quan-ly-chi-tieu-va-thu-nhap-ca-nhan/
├── README.md
├── apps/
│   ├── ios/                        # (tuần 1) SwiftUI
│   ├── android/                    # (tuần 1) Flutter — app shell mỏng
│   └── web/                        # (tuần 1) Flutter Web — app shell mỏng
├── packages/
│   ├── flutter_core/               # (tuần 1) Dart dùng chung Android + Web
│   └── shared-types/               # (tuần 1) DTO + OpenAPI
├── services/
│   ├── api/                        # (tuần 1) NestJS — HTTP
│   └── worker/                     # (tuần 1) NestJS — cron + queue
├── infra/
│   └── docker-compose.yml          # (tuần 1)
├── docs/
│   ├── 01-tong-quan.md
│   ├── 02-san-pham.md
│   ├── 03-ky-thuat.md
│   ├── 04-kinh-doanh.md
│   ├── 05-lo-trinh.md
│   ├── Mo_ta_ung_dung_Quan_ly_chi_tieu_va_thu_nhap.docx
│   ├── Chien_luoc_giu_chan_nguoi_dung.docx
│   ├── TODO.md
│   └── system-design/
│       ├── 00-architecture.md
│       ├── 01-database-schema.md
│       ├── 02-api-contract.md
│       ├── 03-sync-strategy.md
│       ├── 04-wireframes.md
│       ├── 05-ios-structure.md
│       ├── 06-flutter-structure.md
│       └── 07-cron-jobs.md
└── .gitignore
```

Mỗi thư mục trên có sẵn `README.md` mô tả nội dung và quy tắc; mã nguồn tạo ở tuần 1 của lộ trình.

---

## Bản quyền

© 2026 Ứng dụng Quản lý Chi tiêu và Thu nhập Cá nhân. Bảo lưu mọi quyền.

Mã nguồn, tài liệu thiết kế và bộ nhận diện thương hiệu thuộc quyền sở hữu của nhóm phát triển. Mọi hình thức sao chép, phân phối lại hoặc sử dụng thương mại cần có văn bản đồng ý.
