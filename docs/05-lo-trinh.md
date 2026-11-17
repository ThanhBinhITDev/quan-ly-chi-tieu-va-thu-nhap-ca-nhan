# 05 — Lộ trình

**Cập nhật:** 2026-11-16 · **Phiên bản:** 2.0 (2 codebase)

---

## 1. Mốc tổng thể

| Giai đoạn | Tuần | Nội dung |
|---|---|---|
| **MVP** | 1–6 | Ghi thu/chi, danh mục, ví, chỉ số hôm nay, ngân sách, biểu đồ, offline, auth |
| **AI cơ bản** | 7–8 | AI-1 đọc hóa đơn, AI-2 phân loại, cổng hạn mức |
| **Hoàn thiện** | 9–10 | AI-3 hỏi đáp, đo chi phí thật, test với 20–30 sinh viên |
| **Giai đoạn 2** | sau | AI-4 nhận xét tháng, đồng bộ đa thiết bị, xuất dữ liệu |

---

## 2. MVP — mười tuần, ba nền tảng

Ba nền chạy song song. Tuần 1–2 cả ba cùng dựng khung; từ tuần 3 tách hẳn theo đặc thù từng nền.

| Tuần | iOS (SwiftUI) | Android (Flutter) | Web (Next.js) | Mốc chung |
|---|---|---|---|---|
| 1 | `Core/`, SwiftData + seed, kiểm chứng hiệu năng query | `core/`, drift + seed | Dựng Next.js, landing tĩnh | Mở app thấy danh mục mặc định |
| 2 | Onboarding + QuickEntry + Trang chủ | Onboarding + nhập nhanh + Trang chủ | Trang đăng ký, đăng nhập | Ghi được giao dịch (iOS + Android) |
| 3 | `DailyLimitCalculator` + 40 test + **Widget** | `DailyLimitCalculator` + 40 test | Báo cáo tháng (chỉ đọc) | Chỉ số hôm nay đúng trên iOS và Android |
| 4 | Ngân sách, danh sách, ví, sửa/xoá, **mục tiêu tiết kiệm** | Ngân sách, danh sách, ví, **mục tiêu** | — | Dùng offline hoàn toàn |
| 5 | Swift Charts: biểu đồ + **Chia tiền nhóm** (màn) | fl_chart + **Chia tiền nhóm** | Biểu đồ trên web | Có biểu đồ ở cả ba nơi |
| 6 | Auth + đồng bộ + **App Intents** + **RLS chia tiền** | Auth + đồng bộ + RLS | Auth + đọc dữ liệu thật | Chia được hoá đơn 4 người, số liệu cá nhân vẫn đúng |
| 7–8 | AI-1 + AI-2 + cổng hạn mức | AI-1 + AI-2 | — | Đọc được hoá đơn (giai đoạn sau MVP) |
| 9 | Thông báo đẩy (APNs), cài đặt | Thông báo đẩy (FCM), cài đặt | — | Nhắc cuối ngày hoạt động |
| 10 | Kiểm thử, sửa lỗi, TestFlight | Kiểm thử, sửa lỗi, closed testing | Kiểm thử, deploy | Bản nộp |

**MVP xong ở tuần 6** (chỉ nhập tay; chưa có AI, chưa có thông báo, chưa có nhập tự động). Đây là mốc cần cho bản dự thi.

**Lưu ý:** Chia tiền nhóm chen vào tuần 5–6 làm hai tuần này dày hơn trước. Nếu chậm, cắt Split Bill trước — nó không nằm trong ba thứ demo (mục 3).

---

## 3. Phạm vi MVP — chỉ ba thứ

1. Ghi chi tiêu
2. Chỉ số hạn mức hôm nay
3. Biểu đồ tròn

Demo ba cái này chạy thật mạnh hơn mười tính năng trên slide.

---

## 4. Thứ tự cắt khi thiếu thời gian

Nếu không kịp, cắt theo đúng thứ tự này:

| Thứ tự | Cắt gì | Vì sao cắt được |
|---|---|---|
| 1 | Ghi giao dịch + ví trên Web | Người dùng chính dùng điện thoại; giữ landing + đăng ký + báo cáo đọc |
| 1b | **Chia tiền nhóm (Split Bill)** | Thêm 4 bảng + RLS nhiều người dùng; không nằm trong ba thứ demo cốt lõi |
| 2 | Đồng bộ đa thiết bị (tuần 6) | Offline-first vẫn dùng được một máy |
| 3 | Thông báo đẩy (tuần 9) | Không phải tính năng cốt lõi |
| 4 | AI-3 hỏi đáp | AI-1 đọc hóa đơn đã đủ gây ấn tượng |
| — | **Không cắt iOS** | Liquid Glass là điểm khác biệt của bản demo |

---

## 5. Điểm chờ quyết

Ba điểm còn mở (D2–D4) trong [system-design/00](system-design/00-architecture.md) mục 12 ảnh hưởng trực tiếp tới lộ trình; D1 đã chốt:

| Mã | Câu hỏi | Ảnh hưởng |
|---|---|---|
| D1 | ~~Web cắt hẳn hay giữ ưu tiên thấp~~ — **đã chốt 2026-11-16:** Web tách khỏi Flutter, dùng Next.js, phạm vi MVP chỉ landing + đăng ký + báo cáo đọc | — |
| D2 | Có mua Redis trả phí khi vượt free tier không | Chặn việc chạy 12 job ở môi trường thật |
| D3 | Gói AI miễn phí 10 lượt có đủ demo không | Nếu không, phải nâng trước ngày demo |
| D4 | Máy demo chạy bản iOS hay Android | Quyết định tuần cuối dồn sức vào nền nào |

---

## 6. Tài liệu liên quan

| File | Nội dung |
|---|---|
| [01 — Tổng quan](01-tong-quan.md) | Định vị |
| [03 — Kỹ thuật](03-ky-thuat.md) | Kiến trúc, nguyên tắc |
| [system-design/07](system-design/07-cron-jobs.md) | Thứ tự triển khai job |
| [TODO.md](TODO.md) | Việc còn lại chi tiết |
