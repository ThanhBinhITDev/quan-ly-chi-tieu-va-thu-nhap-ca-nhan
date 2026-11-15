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

## 2. MVP — mười tuần, hai codebase

Cùng một tuần, hai nền chạy song song từ tuần 1 đến tuần 2, sau đó tách hẳn.

| Tuần | iOS (SwiftUI) | Flutter (Android + Web) | Mốc chung |
|---|---|---|---|
| 1 | `Core/`, SwiftData + seed, kiểm chứng hiệu năng query | `core/`, drift + seed | Cả hai: mở app thấy danh mục mặc định |
| 2 | Onboarding + QuickEntry + Trang chủ | Onboarding + nhập nhanh + Trang chủ | Ghi được giao dịch |
| 3 | `DailyLimitCalculator` + 40 test + **Widget** | `DailyLimitCalculator` + 40 test + **Web chạy được** | Chỉ số hôm nay đúng trên cả hai nền |
| 4 | Ngân sách, danh sách, ví, sửa/xóa | ngân sách, danh sách, ví | Dùng offline hoàn toàn |
| 5 | Swift Charts: biểu đồ tròn + cột | fl_chart: biểu đồ tròn + cột | Có biểu đồ |
| 6 | Auth + đồng bộ + **App Intents** | Auth + đồng bộ + PWA | Dữ liệu không mất khi đổi thiết bị |
| 7–8 | AI-1 + AI-2 + cổng hạn mức | AI-1 + AI-2 + cổng hạn mức | Đọc được hóa đơn |
| 9 | Thông báo đẩy (APNs), cài đặt | Thông báo đẩy (FCM), cài đặt | Nhắc cuối ngày hoạt động |
| 10 | Kiểm thử, sửa lỗi, TestFlight | Kiểm thử, sửa lỗi, closed testing | Bản nộp |

**MVP xong ở tuần 6** (chưa có AI, chưa có thông báo). Đây là mốc cần cho bản dự thi.

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
| 1 | **Web** | Ít người dùng nhất ở MVP; Android + iOS đã đủ demo |
| 2 | Đồng bộ đa thiết bị (tuần 6) | Offline-first vẫn dùng được một máy |
| 3 | Thông báo đẩy (tuần 9) | Không phải tính năng cốt lõi |
| 4 | AI-3 hỏi đáp | AI-1 đọc hóa đơn đã đủ gây ấn tượng |
| — | **Không cắt iOS** | Liquid Glass là điểm khác biệt của bản demo |

---

## 5. Điểm chờ quyết

Bốn điểm trong [system-design/00](system-design/00-architecture.md) mục 16 ảnh hưởng trực tiếp tới lộ trình:

| Mã | Câu hỏi | Ảnh hưởng |
|---|---|---|
| D1 | Web cắt hẳn ở MVP hay giữ ưu tiên thấp | Nếu cắt, tiết kiệm ~1,5 tuần |
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
