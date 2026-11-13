# 03 — Luồng đồng bộ dữ liệu

**Phiên bản:** 1.1 · **Ngày:** 2026-11-13 · **Trạng thái:** đã chốt Q1–Q3, các điểm khác chờ duyệt

Mục tiêu: ghi được khi không có mạng, không mất dữ liệu, không tạo bản ghi trùng, và mở đường cho đa thiết bị mà không phải viết lại.

---

## 1. Ba quyết định nền tảng

| Quyết định | Chọn | Vì sao không chọn phương án khác |
|:---:|:---:|:---:|
| Nguồn dữ liệu chính | **SQLite trên máy** | Ứng dụng phải dùng được khi mất mạng (sinh viên dùng 3G yếu, trong lớp không có wifi) |
| Khóa chính | **UUID sinh trên máy** | Nếu để server sinh ID, mọi bản ghi offline phải chờ có mạng mới có ID → không thể hiển thị ngay |
| Giải quyết xung đột | **`rev` tăng dần + server thắng** | CRDT quá phức tạp cho quy mô này; last-write-wins đủ dùng với 1 người dùng/1 thiết bị |

---

## 2. Trạng thái đồng bộ của một bản ghi

```sql
-- Mọi bảng nghiệp vụ có thêm 3 cột phía client
sync_status TEXT NOT NULL DEFAULT 'pending'
            CHECK (sync_status IN ('synced','pending','conflict','deleted_pending')),
synced_at   TIMESTAMPTZ,
server_rev  INT
```

| Trạng thái | Ý nghĩa | Hiển thị cho người dùng |
|:---:|:---:|:---:|
| `synced` | Đã lên server | Không hiện gì |
| `pending` | Đã ghi local, chưa lên server | Chấm vàng nhỏ cạnh bản ghi |
| `deleted_pending` | Đã xóa local, chưa báo server | Không hiện (đã ẩn) |
| `conflict` | Server có bản khác | Biểu tượng cảnh báo + hộp thoại chọn bản |

**Điểm quan trọng:** người dùng **không** phải thấy trạng thái đồng bộ trong điều kiện bình thường. Chấm vàng chỉ hiện khi mất mạng quá 24 giờ, để họ biết dữ liệu chưa được sao lưu.

---

## 3. Hàng đợi đồng bộ

```sql
CREATE TABLE sync_queue (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  table_name  TEXT NOT NULL,
  record_id   TEXT NOT NULL,
  op          TEXT NOT NULL CHECK (op IN ('insert','update','delete')),
  payload     TEXT,                    -- JSON của bản ghi tại thời điểm thay đổi
  rev         INTEGER NOT NULL,
  attempts    INTEGER NOT NULL DEFAULT 0,
  last_error  TEXT,
  created_at  TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX idx_queue_order ON sync_queue(id);
```

**Một bản ghi có thể xuất hiện nhiều lần trong hàng đợi** nếu người dùng sửa liên tục. Trước khi đẩy, gộp lại:

```
Sửa 35.000 → 40.000 → 42.000  =  hàng đợi có 3 dòng
   ↓ gộp
Chỉ đẩy 1 dòng: update, rev=4, amount=42000
```

Quy tắc gộp: giữ dòng **mới nhất** cho mỗi cặp `(table_name, record_id)`. Nếu chuỗi có `insert` rồi `delete` → bỏ cả hai, không gửi gì.

---

## 4. Ba luồng chính

### 4.1. Ghi giao dịch khi offline

```
Người dùng bấm Lưu
   ↓
1. Sinh UUID trên máy:        vd 7f3a-...
2. Ghi vào bảng transactions:  sync_status = 'pending', rev = 1
3. Ghi vào sync_queue:         op = 'insert'
4. Cập nhật UI ngay:           chỉ số hôm nay giảm, danh sách có dòng mới
   ↓ (ngay lập tức, không chờ mạng)
Người dùng thấy giao dịch đã lưu ✓
```

UI cập nhật **trước** khi mạng được gọi. Không có màn hình "đang lưu...". Nếu chờ server, app sẽ không dùng được trong lớp học.

### 4.2. Đẩy khi có mạng

```
Phát hiện có mạng (connectivity_plus) hoặc app vào foreground
   ↓
1. Gộp hàng đợi theo (table, id)
2. Cắt lô tối đa 100 thay đổi
3. POST /functions/v1/sync-push
   ↓
   ├─ Thành công  → đổi sync_status = 'synced', xóa khỏi queue, lưu server_rev
   ├─ Conflict    → đổi sync_status = 'conflict', lưu server_data
   ├─ 401         → refresh token, thử lại 1 lần
   ├─ 429 / 5xx   → giữ queue, backoff (2s, 4s, 8s, 16s, tối đa 60s)
   └─ 400         → đánh dấu lỗi vĩnh viễn, ghi log, không thử lại
4. Nếu còn queue → lặp lại bước 2
```

**Backoff:** lũy thừa, tối đa 5 lần, sau đó dừng và thử lại khi app mở lại. Không thử vô hạn vì sẽ tốn pin.

### 4.3. Kéo thay đổi từ server

```
Kích hoạt khi:
  • App vào foreground
  • Sau khi push thành công
  • Kéo xuống để làm mới (pull-to-refresh)
   ↓
1. Đọc sync_state.last_pull_at (mặc định: 30 ngày trước)
2. GET /functions/v1/sync-pull?since=<last_pull_at>&limit=500
3. Với mỗi bản ghi:
   ├─ Không có local           → insert, sync_status = 'synced'
   ├─ Có local, server rev cao → ghi đè nếu local đang 'synced'
   ├─ Có local, local 'pending'→ đánh dấu 'conflict', không ghi đè
   └─ Server deleted_at có giá trị → xóa mềm local
4. Cập nhật last_pull_at = next_since
5. Nếu has_more → lặp lại bước 2
```

**Quy tắc bất di bất dịch:** không bao giờ ghi đè bản ghi đang `pending`. Đó là dữ liệu người dùng vừa nhập mà server chưa biết.

---

## 5. Sinh mã giao dịch chống trùng

Đây là lỗi phổ biến nhất của app tài chính: cùng một giao dịch bị đẩy 2 lần → tổng chi sai.

### 5.1. Cơ chế

Mỗi giao dịch có UUID sinh trên máy. Server dùng `INSERT ... ON CONFLICT (id) DO NOTHING`.

```sql
INSERT INTO transactions (id, user_id, wallet_id, ...)
VALUES (...)
ON CONFLICT (id) DO NOTHING
RETURNING id;
```

Nếu không có dòng trả về → bản ghi đã tồn tại → coi như thành công, không báo lỗi.

**Vì sao đủ:** UUID v4 có 122 bit ngẫu nhiên. Xác suất trùng giữa 2 lần sinh là không đáng kể. Và nếu client gửi lại cùng một bản ghi (do timeout mạng), `ON CONFLICT` chặn trùng.

### 5.2. Trường hợp khó: timeout sau khi server đã ghi

```
Client gửi POST  →  Server ghi thành công  →  Response bị mất do mạng
   ↓
Client tưởng thất bại, thử lại  →  Server nhận lần 2
   ↓
ON CONFLICT (id) DO NOTHING  →  không tạo bản ghi thứ 2  ✓
```

Đây là lý do **bắt buộc** phải sinh UUID trên client, không dùng `BIGSERIAL`.

---

## 6. Xóa và khôi phục

| Hành động người dùng | Local | Queue | Server |
|:---:|:---:|:---:|:---:|
| Xóa giao dịch | `deleted_at = now()`, `sync_status = 'deleted_pending'` | `op = 'delete'` | `deleted_at` được set |
| Hoàn tác xóa (5 giây) | `deleted_at = NULL`, `sync_status = 'pending'` | Ghi đè thành `op = 'update'` | `deleted_at = NULL` |

**Cửa sổ hoàn tác 5 giây** hiện snackbar "Đã xóa · Hoàn tác". Sau 5 giây, giao dịch biến khỏi danh sách nhưng **vẫn còn trong DB** (xóa mềm).

Không có xóa vĩnh viễn ở client. Nếu người dùng muốn xóa thật, đó là thao tác "Xóa toàn bộ dữ liệu" trong Cài đặt, có xác nhận 2 bước.

---

## 7. Đồng bộ lần đầu trên thiết bị mới

```
1. Đăng nhập
2. GET /functions/v1/sync-pull?since=1970-01-01&limit=500   ← toàn bộ dữ liệu
3. Lặp đến khi has_more = false
4. Ghi tất cả vào SQLite với sync_status = 'synced'
5. Hiện thanh tiến trình: "Đang tải 1.240 giao dịch..."
```

**Với 1.200 giao dịch:** khoảng 3 lô × 500, mất 2–4 giây trên 4G. Chấp nhận được.

**Nếu dữ liệu quá lớn** (> 5.000 bản ghi): tăng `limit` lên 1.000 và hiện tiến trình theo lô. Không cần cơ chế khác.

---

## 8. Xử lý xung đột khi có 2 thiết bị

MVP chỉ 1 thiết bị, nhưng thiết kế sẵn:

```
Thiết bị A sửa giao dịch t8: 35.000 → 40.000   (rev 1 → 2)
Thiết bị B sửa giao dịch t8: 35.000 → 45.000   (rev 1 → 2)

A push trước  →  server rev = 2, amount = 40.000
B push sau    →  client rev 2, server rev 2  →  CONFLICT
   ↓
Server trả: { status: 'conflict', server_rev: 2, server_data: {...40.000} }
   ↓
B hiện hộp thoại:
   ┌─────────────────────────────────┐
   │ Giao dịch này đã được sửa       │
   │ trên thiết bị khác              │
   │                                 │
   │ ○ Giữ bản của tôi: 45.000đ      │
   │ ○ Dùng bản kia:    40.000đ      │
   └─────────────────────────────────┘
```

**Không tự động chọn.** Với dữ liệu tiền, tự động chọn sai sẽ làm người dùng mất niềm tin. Thà hỏi còn hơn đoán.

Nếu người dùng chọn "Giữ bản của tôi" → client gửi `rev = server_rev + 1` = 3.

---

## 9. Kiểm tra toàn vẹn dữ liệu

Chạy mỗi lần app khởi động (nền, không chặn UI):

| Kiểm tra | Phát hiện | Xử lý |
|:---:|:---:|:---:|
| Giao dịch trỏ tới ví không tồn tại | `wallet_id` mồ côi | Gán vào ví mặc định, ghi log |
| Giao dịch trỏ tới danh mục đã xóa | `category_id` mồ côi | Đổi thành "Khác", ghi log |
| `amount <= 0` | Dữ liệu hỏng | Bỏ qua, ghi log, không đồng bộ |
| `type = transfer` thiếu `to_wallet_id` | Dữ liệu hỏng | Chuyển thành `expense`, ghi log |
| Bản ghi `pending` quá 7 ngày | Không đẩy được | Hiện cảnh báo "Dữ liệu chưa được sao lưu" |

Không tự sửa âm thầm mà không ghi log — nếu có lỗi hệ thống, cần biết để sửa gốc.

---

## 10. Chỉ số cần theo dõi

| Chỉ số | Mục tiêu | Ý nghĩa |
|:---:|:---:|:---:|
| Tỷ lệ push thành công lần đầu | > 95% | Chất lượng mạng + API |
| Thời gian trung bình để queue rỗng | < 5 giây | Trải nghiệm đồng bộ |
| Số bản ghi `pending` trung bình/user | < 2 | Nếu cao, người dùng đang dùng offline nhiều |
| Số xung đột/tháng | ~0 (1 thiết bị) | Nếu > 0, có lỗi logic |
| Kích thước DB local trung bình | < 20 MB/năm | Nếu lớn, cần dọn ảnh |

---

## 11. Điểm cần bạn quyết

| # | Vấn đề | Đề xuất | Phương án khác |
|:---:|:---:|:---:|:---:|
| 1 | Có hiện chấm vàng "chưa đồng bộ" không | Chỉ hiện khi offline > 24 giờ | Hiện luôn, minh bạch hơn nhưng gây lo |
| 2 | Xung đột: hỏi người dùng hay tự chọn | Hỏi | Tự chọn theo thời gian, đơn giản hơn nhưng rủi ro |
| 3 | Kéo toàn bộ khi đăng nhập máy mới | Có, có thanh tiến trình | Chỉ kéo 90 ngày gần nhất, nhanh hơn nhưng thiếu lịch sử |
| 4 | Đồng bộ ảnh hóa đơn | Không ở MVP | Có, tốn Storage + băng thông |
| 5 | Tần suất tự đồng bộ | Khi mở app + sau mỗi thay đổi (debounce 3 giây) | Chỉ khi mở app, tiết kiệm pin hơn |

Điểm 5: debounce 3 giây để người dùng nhập liên tiếp 5 giao dịch thì chỉ đẩy 1 lần, không phải 5 lần.
