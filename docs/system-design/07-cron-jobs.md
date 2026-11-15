# 07 — Công việc định kỳ

**Phiên bản:** 1.0 · **Ngày:** 2026-11-16 · **Trạng thái:** bản nháp đầu

Công việc chạy tự động trên Worker NestJS + BullMQ. Không dùng `pg_cron`, không dùng Edge Functions. Lý do: xem [00 mục 9.3](00-architecture.md#93-vì-sao-không-dùng-pg_cron).

Toàn bộ chạy múi giờ `Asia/Ho_Chi_Minh` (UTC+7). Ngoại lệ ghi rõ ở từng job.

---

## 1. Nguyên tắc bắt buộc

| # | Nguyên tắc | Lý do |
|---|---|---|
| 1 | Mọi job phải **chạy lại được** mà không tạo dữ liệu trùng | Job có thể chạy quá giờ, chạy 2 lần, hoặc bị kill giữa chừng |
| 2 | Mọi job phải **có khoá idempotent** | Không có khoá thì retry sinh dữ liệu rác |
| 3 | Job không được đọc rồi ghi trong cùng một transaction dài | Giữ khoá DB quá lâu, chặn request của người dùng |
| 4 | Xử lý theo lô, mỗi lô tối đa 500 bản ghi | Tránh tràn bộ nhớ khi số người dùng tăng |
| 5 | Lỗi thì ghi log có `jobName`, `runId`, `userId`, sau đó ném lại để BullMQ retry | Không nuốt lỗi |
| 6 | Job đọc chỉ số thì không được ghi vào bảng nghiệp vụ | `integrity-check` chỉ đọc |
| 7 | Không dùng `setInterval` — luôn dùng lịch của BullMQ | `setInterval` không sống qua khởi động lại |

---

## 2. Mười hai job

### 2.1. `recurring-generate` — sinh giao dịch định kỳ

| Trường | Nội dung |
|---|---|
| Lịch | `05 0 * * *` (00:05 hằng ngày) |
| Việc làm | Tìm `recurring_rules` có `next_run_on <= today` và `is_active = true`; sinh giao dịch tương ứng; cập nhật `next_run_on` và `last_run_at` |
| Khoá idempotent | UNIQUE `(rule_id, occurrence_date)` trên bảng `transactions` |
| Số lần thử | 3, cách nhau 5 phút |
| Nếu chạy lại | Bản ghi đã sinh bị `ON CONFLICT DO NOTHING`; `next_run_on` chỉ tiến, không lùi |

**Quy tắc tính `next_run_on`:**

| Tần suất | Cách tính |
|---|---|
| `daily` | `+1 ngày` |
| `weekly` | `+7 ngày` |
| `monthly` | cùng ngày tháng sau; nếu tháng sau không có ngày đó thì lấy ngày cuối tháng |
| `yearly` | cùng ngày tháng năm sau; 29/02 thì lấy 28/02 |

**Trường hợp biên phải xử lý:**

- Rule tạo ngày 31, tháng 2 không có ngày 31 → sinh ngày 28 (hoặc 29 nếu nhuận)
- Máy chủ tắt 3 ngày → hôm sau chạy phải sinh bù đủ 3 giao dịch, không chỉ 1
- Người dùng xoá ví trước khi rule tới hạn → bỏ qua rule, đánh dấu `is_active = false`
- Người dùng sửa số tiền rule hôm nay → chỉ áp dụng từ lần sinh tiếp theo

### 2.2. `budget-close` — chốt ngân sách tháng

| Trường | Nội dung |
|---|---|
| Lịch | `10 0 1 * *` (00:10 ngày 1 hằng tháng) |
| Việc làm | Tính tổng chi tháng vừa rồi cho từng ngân sách; lưu vào bảng tổng hợp; tạo khung ngân sách tháng mới cho người dùng đã đặt |
| Khoá idempotent | UNIQUE `(user_id, category_id, month)` trên bảng tổng hợp |
| Số lần thử | 3, cách 10 phút |

**Không chặn người dùng:** nếu người dùng chưa đặt ngân sách, không tạo dòng nào. Không tự đặt hộ.

### 2.3. `aggregate-refresh` — tính lại tổng hợp

| Trường | Nội dung |
|---|---|
| Lịch | `30 0 * * *` |
| Việc làm | Tính lại bảng tổng hợp theo `(user, month, category)` và `(user, month, day)`; ghi vào bảng tổng hợp; xoá cache Redis liên quan |
| Khoá idempotent | Ghi đè theo khoá chính, không cộng dồn |
| Số lần thử | 3, cách 10 phút |

**Vì sao cần job này khi đã có truy vấn trực tiếp:** báo cáo tháng cần quét toàn bộ giao dịch, với người dùng 3 năm dữ liệu (~3.000 dòng) mất 200–400 ms. Tính sẵn thì còn 20 ms.

### 2.4. `budget-alert` — cảnh báo ngưỡng ngân sách

| Trường | Nội dung |
|---|---|
| Lịch | `*/15 * * * *` (mỗi 15 phút) |
| Việc làm | Tính tỉ lệ đã chi / hạn mức; nếu vượt 70%, 90% hoặc 100% và chưa gửi mức đó trong tháng thì gửi thông báo |
| Khoá idempotent | UNIQUE `(user_id, category_id, month, level)` trên bảng `notifications` |
| Số lần thử | Không thử lại; lần quét sau tự bao phủ |

**Ngưỡng và mẫu câu:** xem [04 mục 9](04-wireframes.md#9-thông-báo-đẩy--mẫu-câu).

**Chống làm phiền:** tối đa 1 thông báo ngân sách/người/ngày. Nếu nhiều danh mục cùng vượt ngưỡng trong một lần quét, gộp thành một tin.

### 2.5. `daily-reminder` — nhắc ghi chép

| Trường | Nội dung |
|---|---|
| Lịch | `0 20 * * *` (20:00) |
| Việc làm | Với người dùng đã bật nhắc và hôm nay chưa ghi khoản nào, gửi một tin chứa số liệu thật của ngày |
| Khoá idempotent | UNIQUE `(user_id, date, type='daily_reminder')` |
| Số lần thử | Không thử lại |

**Múi giờ:** chạy một lần theo giờ Việt Nam; người dùng ở múi khác nhận theo giờ Việt Nam. Ghi rõ trong cài đặt để không ai bất ngờ.

**Điều kiện bỏ qua:** người dùng đã ghi ≥ 1 khoản hôm nay, hoặc đã tắt nhắc, hoặc đang trong 7 ngày đầu (tránh làm phiền người mới).

### 2.6. `winback` — kéo người dùng quay lại

| Trường | Nội dung |
|---|---|
| Lịch | `0 9 * * *` |
| Việc làm | Tìm người dùng có lần hoạt động cuối cách đây đúng 7 ngày → gửi tin thứ nhất; đúng 14 ngày → gửi tin thứ hai; sau đó dừng hẳn |
| Khoá idempotent | UNIQUE `(user_id, stage)` với `stage ∈ {7, 14}` |
| Số lần thử | Không thử lại |

**Dừng hẳn sau 2 lần.** Không gửi lần thứ ba. Đây là quyết định về sản phẩm, không phải kỹ thuật — ghi ở [chiến lược giữ chân](../../docs/Chien_luoc_giu_chan_nguoi_dung.docx).

### 2.7. `ai-monthly-review` — nhận xét thói quen tháng

| Trường | Nội dung |
|---|---|
| Lịch | `0 6 1 * *` |
| Việc làm | Với người dùng có ≥ 10 giao dịch trong tháng trước, đưa vào hàng đợi AI để sinh nhận xét; lưu kết quả vào `ai_results` |
| Khoá idempotent | UNIQUE `(user_id, month, kind='monthly_review')` |
| Số lần thử | 2, cách 30 phút |

**Không gọi AI trực tiếp trong job.** Job chỉ đưa vào hàng đợi; worker AI xử lý riêng, có hạn mức và cầu dao chi phí.

**Kiểm tra đầu ra:** nếu mô hình trả về chuỗi chứa con số không khớp dữ liệu thật, huỷ kết quả và ghi log. Mô hình không được sinh ra số tài chính.

### 2.8. `ai-quota-reset` — đặt lại hạn mức AI

| Trường | Nội dung |
|---|---|
| Lịch | `0 0 1 * *` (00:00 ngày 1) |
| Việc làm | Đặt `ai_quota_used = 0` cho mọi người dùng; ghi lại hạn mức theo gói hiện tại |
| Khoá idempotent | Chỉ ghi khi `quota_month < tháng hiện tại` |
| Số lần thử | 3, cách 5 phút |

### 2.9. `ai-cost-breaker` — cầu dao chi phí

| Trường | Nội dung |
|---|---|
| Lịch | `0 * * * *` (đầu mỗi giờ) |
| Việc làm | Tổng hợp chi phí AI của giờ vừa rồi; nếu vượt ngưỡng cấu hình, đặt khoá Redis `ai:disabled` với TTL tới đầu giờ sau |
| Khoá idempotent | Khoá Redis theo `ai:disabled:<hour>` |
| Số lần thử | Không thử lại; nếu lỗi 2 lần liên tiếp thì gửi cảnh báo cho nhóm |

**Ngưỡng mặc định:** 50.000đ/giờ. Điều chỉnh qua biến môi trường `AI_HOURLY_COST_LIMIT`.

**Vì sao cần:** một lỗi vòng lặp gọi AI có thể đốt hết ngân sách trong vài giờ. Cầu dao là lưới an toàn cuối.

### 2.10. `fcm-token-cleanup` — dọn token chết

| Trường | Nội dung |
|---|---|
| Lịch | `0 3 * * 0` (03:00 Chủ nhật) |
| Việc làm | Gọi FCM/APNs kiểm tra token; xoá token trả về `UNREGISTERED` hoặc `INVALID_ARGUMENT` |
| Khoá idempotent | Idempotent tự nhiên (xoá 2 lần không sao) |
| Số lần thử | 1 |

### 2.11. `soft-delete-purge` — xoá cứng bản ghi đã xoá mềm

| Trường | Nội dung |
|---|---|
| Lịch | `30 3 * * *` |
| Việc làm | Xoá cứng mọi bản ghi có `deleted_at < now() - 30 days` trên các bảng có `deleted_at` |
| Khoá idempotent | Idempotent tự nhiên |
| Số lần thử | 3, cách 10 phút |

**30 ngày là con số phải giữ.** Đây là thời hạn để người dùng hối hận và khôi phục. Ghi ở điều khoản sử dụng.

**Thứ tự xoá:** con trước, cha sau, để không vi phạm khoá ngoại. Hoặc dùng `ON DELETE CASCADE` và xoá cha.

### 2.12. `integrity-check` — kiểm tra toàn vẹn

| Trường | Nội dung |
|---|---|
| Lịch | `0 4 * * 0` (04:00 Chủ nhật) |
| Việc làm | Chạy bộ câu truy vấn kiểm tra; gửi báo cáo cho nhóm qua email/Telegram |
| Khoá idempotent | Chỉ đọc |
| Số lần thử | 1 |

**Danh sách kiểm tra:**

| # | Kiểm tra | Câu truy vấn ý tưởng |
|---|---|---|
| C1 | Giao dịch không có ví | `SELECT count(*) FROM transactions t LEFT JOIN wallets w ON t.wallet_id = w.id WHERE w.id IS NULL` |
| C2 | Giao dịch có `amount <= 0` | `SELECT count(*) FROM transactions WHERE amount <= 0` |
| C3 | Chuyển ví thiếu ví đích | `SELECT count(*) FROM transactions WHERE type = 'transfer' AND to_wallet_id IS NULL` |
| C4 | Chuyển ví cùng ví nguồn và đích | `SELECT count(*) FROM transactions WHERE type = 'transfer' AND wallet_id = to_wallet_id` |
| C5 | Ngân sách trỏ danh mục không tồn tại | LEFT JOIN, đếm `NULL` |
| C6 | Tổng hợp lệch so với tính trực tiếp | So sánh `SUM` từ bảng tổng hợp với `SUM` từ `transactions` |
| C7 | Người dùng có giao dịch nhưng không có ví | LEFT JOIN, đếm `NULL` |
| C8 | Bản ghi có `updated_at < created_at` | `SELECT count(*) FROM transactions WHERE updated_at < created_at` |

Nếu bất kỳ C1–C8 trả về > 0, báo cáo phải ghi rõ số lượng và 10 mã bản ghi mẫu.

---

## 3. Ba cơ chế không phải cron

### 3.1. Hàng đợi đồng bộ

| Tham số | Giá trị |
|---|---|
| Số lần thử | 5 |
| Khoảng cách | 1s, 5s, 25s, 2 phút, 10 phút (backoff ×5) |
| Sau lần cuối | Chuyển dead-letter queue, đánh dấu bản ghi `sync_failed`, báo người dùng trong app |
| Kích thước gói | Tối đa 200 thay đổi mỗi lượt đẩy |
| Thứ tự | Theo `created_at`, không đảo |

### 3.2. Trigger toàn vẹn trong Postgres

| Trigger | Bảng | Việc làm |
|---|---|---|
| `trg_updated_at` | mọi bảng có `updated_at` | Gán `updated_at = now()` khi UPDATE |
| `trg_amount_positive` | `transactions` | Từ chối nếu `amount <= 0` |
| `trg_transfer_target` | `transactions` | Từ chối nếu `type = 'transfer'` mà `to_wallet_id` NULL hoặc trùng `wallet_id` |
| `trg_occurred_on` | `transactions` | Sinh `occurred_on` từ `occurred_at` theo `Asia/Ho_Chi_Minh` |

**Trigger chỉ bảo vệ toàn vẹn, không chứa nghiệp vụ.** Cập nhật ví, tính ngân sách, gọi AI — đều nằm ở NestJS.

### 3.3. Cảnh báo vận hành

| Sự kiện | Kênh | Người nhận |
|---|---|---|
| Job lỗi 2 lần liên tiếp | Telegram + email | Nhóm kỹ thuật |
| `integrity-check` phát hiện lỗi | Telegram + email | Nhóm kỹ thuật |
| Cầu dao AI kích hoạt | Telegram | Nhóm kỹ thuật |
| Tỷ lệ lỗi API > 1% trong 10 phút | Telegram | Nhóm kỹ thuật |
| Dung lượng DB > 80% hạn mức | Email | Nhóm kỹ thuật |

---

## 4. Trình tự chạy trong một đêm

| Giờ | Job | Thời gian chạy ước tính |
|---|---|---|
| 00:00 | `ai-quota-reset` (ngày 1) | < 5 giây |
| 00:05 | `recurring-generate` | 10–60 giây tuỳ số rule |
| 00:10 | `budget-close` (ngày 1) | 10–30 giây |
| 00:30 | `aggregate-refresh` | 30 giây – 5 phút |
| 03:00 | `fcm-token-cleanup` (Chủ nhật) | < 30 giây |
| 03:30 | `soft-delete-purge` | 5–60 giây |
| 04:00 | `integrity-check` (Chủ nhật) | 10 giây – 2 phút |
| 06:00 | `ai-monthly-review` (ngày 1) | < 10 giây (chỉ đưa vào hàng đợi) |

**Không job nào chạy đồng thời với job khác trong khung 00:00–01:00.** Chúng ghi vào cùng bảng tổng hợp; chạy song song sẽ tranh khoá.

---

## 5. Giám sát

| Chỉ số | Ngưỡng cảnh báo |
|---|---|
| Số job chạy trong 24 giờ | Thiếu job nào so với lịch thì cảnh báo |
| Thời gian chạy của từng job | Vượt 2× trung bình 7 ngày thì cảnh báo |
| Số lần retry | Vượt 3 lần/ngày cho một job thì xem lại |
| Số bản ghi dead-letter | > 0 thì phải có người xem |
| Chi phí AI/ngày | Vượt 200.000đ thì cảnh báo |

---

## 6. Chạy cục bộ khi phát triển

```bash
# Khởi động Postgres + Redis
docker compose -f infra/docker-compose.yml up -d

# Chạy worker ở chế độ theo dõi
cd services/worker && npm run start:dev

# Chạy một job cụ thể ngay lập tức (không chờ lịch)
npm run job:run -- recurring-generate

# Xem hàng đợi
npm run queue:inspect
```

Cần biến môi trường: `DATABASE_URL`, `REDIS_URL`, `TZ=Asia/Ho_Chi_Minh`, `AI_HOURLY_COST_LIMIT`.

---

## 7. Điểm cần bạn quyết

| # | Điểm | Đề xuất | Phương án khác |
|---|---|---|---|
| 1 | Có gửi thông báo ngân sách ngoài giờ 8:00–22:00 không | Không. Gộp tới 8:00 sáng hôm sau | Gửi ngay khi vượt ngưỡng |
| 2 | `daily-reminder` có bỏ qua 7 ngày đầu không | Có, để người mới không thấy phiền | Nhắc từ ngày thứ 2 |
| 3 | Ngưỡng cầu dao AI 50.000đ/giờ | Giữ | Điều chỉnh theo dữ liệu thật tháng đầu |
| 4 | `winback` gửi bằng thông báo đẩy hay email | Thông báo đẩy trước; nếu không mở trong 3 ngày thì email (nếu có) | Chỉ thông báo đẩy |
