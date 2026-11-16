# 09 — Chi tiết kỹ thuật

**Phiên bản:** 2.0 · **Ngày:** 2026-11-16

Tài liệu này chứa chi tiết triển khai của hệ thống: phân tầng backend, luồng dữ liệu, quan hệ dữ liệu, quy trình tự động, yêu cầu phi chức năng, chi phí và rủi ro.

Tài liệu tổng quan hệ thống (mục tiêu, sơ đồ C4, cấu trúc repo, bảo mật, lộ trình) nằm ở [00-architecture.md](00-architecture.md).

---

## 1. Phân tầng backend

```
Request → Controller → Service → Repository → Postgres
              ↓           ↓           ↓
            DTO        Domain       Entity
                       logic
```

| Tầng | Trách nhiệm | Ví dụ |
|---|---|---|
| **Controller** | Nhận request, kiểm tra định dạng, gọi service, trả response | `TransactionsController.create()` |
| **Service** | Nghiệp vụ, giao dịch, gọi nhiều repository | `TransactionsService.create()` kiểm tra ví tồn tại, chặn số âm, chống trùng |
| **Repository** | Truy vấn dữ liệu, không chứa nghiệp vụ | `TransactionsRepository.findByMonth()` |
| **DTO** | Hình dạng dữ liệu vào/ra, có validate | `CreateTransactionDto` |
| **Guard** | Chặn trước khi vào controller | `JwtAuthGuard`, `SubscriptionGuard` |
| **Filter** | Bắt lỗi, đổi thành mã lỗi chuẩn | `ApiExceptionFilter` |
| **Interceptor** | Ghi log, đo thời gian, gắn mã truy vết | `LoggingInterceptor` |

### Quy tắc bắt buộc

| Quy tắc | Lý do |
|---|---|
| Controller không gọi thẳng Repository | Nếu không, nghiệp vụ phân tán, không test được |
| Repository không ném lỗi nghiệp vụ | Repo chỉ biết dữ liệu; lỗi nghiệp vụ do Service quyết |
| Service không biết `Request`/`Response` của HTTP | Để dùng lại được cho worker và cron |
| Mọi mã lỗi nằm trong một enum dùng chung | Client map theo mã, không đọc câu chữ |
| Không trả `message` của server cho người dùng cuối | Câu chữ thay đổi được; mã lỗi thì không |

---

## 2. Yêu cầu phi chức năng

Mỗi con số dưới đây là ràng buộc có thể kiểm tra, không phải mong muốn chung chung.

| # | Yêu cầu | Con số đo được | Khi nào kiểm tra |
|---|---|---|---|
| NF1 | Mở app tới thấy số | Dưới 2 giây trên Android 4GB RAM | Máy thật chạy bằng 40 người |
| NF2 | Ghi một khoản chi khi có mạng | Dưới 1 giây kể từ bấm Lưu | Đo bằng timestamp local |
| NF3 | Ghi khi không có mạng | Luôn được; bản ghi hiện trong danh sách kèm dấu "chờ đồng bộ" | Rút mạng, thử 20 khoản |
| NF4 | Độ chính xác số | Tròn từng đồng; lệch 0đ sau 1.000 giao dịch so với tính tay | Test tự động |
| NF5 | Dung lượng DB trên máy | Dưới 1 MB cho 1 năm dữ liệu của 1 người | Đếm byte file SQLite |
| NF6 | Kích thước app Android | Dưới 40 MB | File build phát hành |
| NF7 | Dung lượng app iOS | Dưới 40 MB | File build phát hành |
| NF8 | Pin khi ghi 100 khoản | Ít hơn 2% | Đo qua 1 ngày thật |
| NF9 | Đồng bộ 1.000 giao dịch | Dưới 30 giây khi có mạng 4G | Test tải |
| NF10 | API p95 | Dưới 500 ms cho endpoint tổng hợp | Giám sát trong 4 tuần |
| NF11 | Tỷ lệ lỗi đồng bộ | Dưới 0,1% gói tin sau 4 tuần chạy thật | Giám sát |
| NF12 | Phục hồi khi mất DB | Dưới 1 giờ từ backup | Diễn tập 1 lần/tháng |

---


## 3. Chi phí hạ tầng theo quy mô

Giả định: gói miễn phí ở mức thấp nhất, tính theo hoá đơn thực tế.

| Quy mô người dùng | DB | Auth | Storage | API + Worker | Redis | AI | FCM | Tổng ước tính/tháng |
|---|---|---|---|---|---|---|---|---|
| 100 | 0 | 0 | 0 | 0 | 0 | ~44.000 | 0 | **~44.000** |
| 1.000 | 0 | 0 | 0 | 0 | 0 | ~440.000 | 0 | **~440.000** |
| 10.000 | 0–500.000 | 0–500.000 | 500.000 | 500.000 | 500.000 | ~4.400.000 | 0 | **~7.500.000** |
| 50.000 | 2.000.000 | 1.500.000 | 2.000.000 | 2.000.000 | 1.000.000 | ~22.000.000 | 0 | **~30.500.000** |

Lý do chi phí AI tăng nhanh hơn các thành phần khác: mỗi lượt gọi là một chi phí biến đổi theo người dùng, không phải theo máy chủ. Cầu dao chi phí (job 9) tồn tại để chặn trường hợp chi phí AI vượt doanh thu.

**Lưu ý:** con số AI dựa trên tỷ lệ user thực sự dùng AI, giả định khoảng 10% người dùng miễn phí dùng hết hạn mức. Cần đo thật trong 4 tuần đầu.

---

## 4. Rủi ro kỹ thuật

| Rủi ro | Xác suất | Tác động | Giảm thiểu |
|---|---|---|---|
| Hai codebase client lệch nhau | Cao | Cao | Một thư viện hợp đồng chia sẻ; kiểm thử đối chiếu số giữa ba nền |
| Liquid Glass không dùng được khi hạ mục tiêu iOS | Trung bình | Thấp | Fallback sang hiệu ứng kính mờ thường, không ảnh hưởng logic |
| 1 dev không kham nổi 3 nền trong 10 tuần | Cao | Cao | Cắt web trước; giữ iOS + Android; web để giai đoạn 2 |
| Supabase thay đổi chính sách giá | Thấp | Trung bình | Dữ liệu nằm trong Postgres chuẩn, không khoá chặt |
| Gemini đổi API hoặc giá | Trung bình | Thấp | Gọi qua một lớp trừu tượng; đổi cấu hình là đủ |
| RLS được tắt sai thao tác | Thấp | Rất cao | Test tự động kiểm tra RLS bật trên mọi bảng trong CI |
| Cron chạy trùng gây dữ liệu lặp | Trung bình | Cao | Khoá idempotent theo composite key; test job phải chạy lại được |
| Đồng bộ gây lệch số giữa thiết bị | Trung bình | Cao | Mỗi thiết bị giữ checkpoint; đối chiếu checksum theo tuần |

---
