# 03 — Kỹ thuật

**Cập nhật:** 2026-11-16 · **Phiên bản:** 2.0

---

## 1. Quyết định nền tảng

Toàn bộ chi tiết và lý do ở [system-design/00-architecture.md](system-design/00-architecture.md). Bốn quyết định định hình mọi thứ còn lại:

| Mã | Quyết định | Hệ quả |
|---|---|---|
| **Q4** | iOS dùng **SwiftUI native** (iOS 26, Liquid Glass); **Android + Web dùng chung một codebase Flutter** | 2 codebase, 2 lần sửa lỗi/test/phát hành. Đổi lại: iOS có giao diện Liquid Glass thật, Flutter chỉ giả được `BackdropFilter` |
| **Q5** | Backend **tự viết bằng NestJS**; Supabase chỉ còn Postgres + Auth + Storage | Không dùng Realtime, không dùng Edge Functions, không dùng PostgREST tự động |
| **Q6** | Cron chạy trong **Worker NestJS + BullMQ + Redis** | Không dùng `pg_cron`; 12 job ở [system-design/07](system-design/07-cron-jobs.md) |
| **Q7** | **Loại bỏ mục tiêu tiết kiệm** | Bảng `goals` không tạo; Q2 cũ bị huỷ |

**Đánh đổi đã ghi rõ:** 2 codebase = gấp đôi công sửa lỗi và phát hành. Nếu thời gian eo hẹp, **cắt Web trước** — không cắt iOS, vì Liquid Glass là điểm khác biệt của bản demo.

---

## 2. Bảng công nghệ

| Thành phần | Công nghệ | Lý do |
|---|---|---|
| iOS | **SwiftUI + SwiftData + Swift Charts** | Liquid Glass thật, widget, App Intents |
| Android + Web | **Flutter + Riverpod + drift** | 1 codebase cho 2 nền |
| Backend API | **NestJS (TypeScript)** | Tách module rõ, test được, một ngôn ngữ với web |
| Backend Worker | **NestJS + BullMQ + Redis** | 12 job định kỳ + hàng đợi đồng bộ |
| CSDL | **PostgreSQL 15** trên Supabase | 7 bảng, RLS bật |
| Xác thực | **Supabase Auth** | JWT, refresh token, xác thực email |
| Lưu trữ | **Supabase Storage** | Ảnh hóa đơn (giai đoạn 2) |
| OCR | **ML Kit (on-device)** | Miễn phí, không gửi ảnh lên server |
| LLM | Mô hình cỡ nhỏ qua lớp trừu tượng | Đổi nhà cung cấp không sửa app |
| Push | **FCM** (Android) + **APNs** (iOS) | Miễn phí |
| Payment | Google Play Billing / StoreKit | Bắt buộc cho gói kỹ thuật số |
| Hạ tầng | Docker Compose trên VPS | Rẻ hơn PaaS khi có traffic thật |

**Chi phí hạ tầng giai đoạn đầu: gần 0đ** nhờ free tier Supabase + VPS nhỏ.

---

## 3. Cấu trúc repository

```
quan-ly-chi-tieu-va-thu-nhap-ca-nhan/
├── apps/
│   ├── ios/                        # SwiftUI, Xcode project
│   ├── flutter/                    # Android + Web
│   │   ├── lib/
│   │   ├── android/
│   │   └── web/
│   └── web-admin/                  # (giai đoạn 3, chưa làm)
├── services/
│   ├── api/                        # NestJS — HTTP
│   └── worker/                     # NestJS — cron + queue
├── packages/
│   └── shared-types/               # DTO dùng chung api ↔ web
├── infra/
│   ├── docker-compose.yml
│   └── migrations/
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
└── README.md
```

---

## 4. Nguyên tắc kỹ thuật bắt buộc

| # | Nguyên tắc | Lý do |
|---|---|---|
| 1 | Không lưu `balance` trong `wallets` | Số dư luôn tính từ `initial_balance` + tổng giao dịch. Một nguồn sự thật, không lệch |
| 2 | Mọi truy vấn tổng chi phải có `AND type = 'expense'` | Chuyển ví không phải chi tiêu (Q3) |
| 3 | Mô hình ngôn ngữ không sinh ra con số tài chính | Kiểm tra đầu ra, huỷ nếu lệch |
| 4 | Mọi job cron phải chạy lại được | Có khoá idempotent, không tạo dữ liệu trùng |
| 5 | Trigger trong Postgres chỉ bảo vệ toàn vẹn, không chứa nghiệp vụ | Nghiệp vụ nằm ở NestJS, dễ test và sửa |
| 6 | App không giữ tiền, không liên kết ngân hàng | Ngoài phạm vi luật tổ chức tín dụng |

---

## 5. Bảo mật

| Lớp | Biện pháp |
|---|---|
| Xác thực | Supabase Auth, JWT ngắn hạn + refresh token |
| Phân quyền dữ liệu | RLS trên mọi bảng, lọc theo `user_id` |
| Truyền tải | HTTPS bắt buộc, HSTS |
| Lưu trữ local | iOS: Keychain cho token; Flutter: `flutter_secure_storage` |
| Ảnh hóa đơn | Không gửi lên server ở MVP (ML Kit chạy trên máy) |
| Dữ liệu xoá | Xoá mềm 30 ngày, sau đó xoá cứng bằng job |
| Tuổi tối thiểu | 16 |

---

## 6. Tài liệu liên quan

| File | Nội dung |
|---|---|
| [system-design/00](system-design/00-architecture.md) | Kiến trúc đầy đủ, 18 mục, ADR, chi phí, rủi ro |
| [system-design/01](system-design/01-database-schema.md) | 7 bảng, index, RLS |
| [system-design/02](system-design/02-api-contract.md) | Hợp đồng API NestJS |
| [system-design/05](system-design/05-ios-structure.md) | Cấu trúc SwiftUI |
| [system-design/06](system-design/06-flutter-structure.md) | Cấu trúc Flutter |
| [system-design/07](system-design/07-cron-jobs.md) | 12 job định kỳ |
