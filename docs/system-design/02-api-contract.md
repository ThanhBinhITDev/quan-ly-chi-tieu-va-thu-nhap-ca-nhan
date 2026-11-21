# 02 — Hợp đồng API

**Phiên bản:** 2.0 · **Ngày:** 2026-11-16 · **Trạng thái:** backend chuyển từ PostgREST sang NestJS (Q5)

Base URL: `https://api.<tenant>.com` (NestJS, sau API Gateway)

> API do NestJS tự viết — không dùng PostgREST. Mỗi module là một controller.
> Supabase chỉ cung cấp Postgres, Auth và Storage; logic nằm trong NestJS.

---

## 1. Nguyên tắc

| Nguyên tắc | Nội dung |
|---|---|
| Xác thực | JWT của Supabase trong header `Authorization: Bearer <token>` |
| Định dạng | JSON, `Content-Type: application/json` |
| Mã thời gian | ISO 8601 UTC: `2026-11-13T05:30:00Z` |
| Ngày | `YYYY-MM-DD`, luôn theo giờ Việt Nam |
| Số tiền | `integer`, đơn vị đồng, luôn dương |
| ID | UUID v4 chuỗi |
| Phân trang | `?limit=50&before=<uuid_or_timestamp>` (cursor), không dùng offset |
| Lỗi | Luôn có `code` dạng chuỗi ổn định để app xử lý, `message` chỉ để log |

---

## 2. Định dạng lỗi chuẩn

```json
{
  "error": {
    "code": "QUOTA_EXCEEDED",
    "message": "Đã dùng hết 10 lượt đọc hóa đơn trong tháng",
    "field": "ocr",
    "details": { "limit": 10, "used": 10, "reset_at": "2026-12-01T00:00:00+07:00" }
  }
}
```

### Bảng mã lỗi

| HTTP | code | Khi nào | App xử lý thế nào |
|---|---|---|---|
| 400 | `VALIDATION_FAILED` | Thiếu trường, sai kiểu | Hiện lỗi tại ô nhập, `field` cho biết ô nào |
| 401 | `UNAUTHENTICATED` | Thiếu hoặc hết hạn token | Điều hướng về đăng nhập |
| 403 | `FORBIDDEN` | Truy cập dữ liệu người khác | Không nên xảy ra; log và báo lỗi chung |
| 403 | `PLAN_LIMIT` | Vượt giới hạn gói free (số ví, danh mục) | Hiện màn hình nâng cấp |
| 403 | `QUOTA_EXCEEDED` | Vượt hạn mức AI | Hiện thông báo + nút nâng cấp |
| 404 | `NOT_FOUND` | Không tìm thấy bản ghi | Xóa khỏi cache local |
| 409 | `SYNC_CONFLICT` | Xung đột phiên bản khi đồng bộ | Xử lý theo mục 8 |
| 422 | `RULE_VIOLATION` | Vi phạm nghiệp vụ (VD chuyển ví trùng ví) | Hiện thông báo cụ thể |
| 429 | `RATE_LIMITED` | Gọi quá nhanh | Backoff lũy thừa |
| 500 | `INTERNAL` | Lỗi server | Giữ dữ liệu local, thử lại sau |

**Quy ước:** app **không được** hiển thị `message` trực tiếp cho người dùng. Phải map `code` sang câu tiếng Việt trong app, để câu chữ thống nhất và không lộ chi tiết kỹ thuật.

---

## 3. Xác thực

### 3.1. Đăng ký

```http
POST /auth/v1/signup
```

```json
{
  "email": "sinhvien@example.com",
  "password": "matkhau123",
  "data": { "display_name": "Nguyễn Văn A" }
}
```

Hoặc đăng ký bằng SĐT:

```json
{ "phone": "+84901234567", "password": "matkhau123" }
```

**Trả về 200:**

```json
{
  "user": { "id": "a1b2...", "email": "sinhvien@example.com" },
  "session": {
    "access_token": "eyJ...",
    "refresh_token": "v1...",
    "expires_in": 3600
  }
}
```

**Kiểm tra tuổi:** app chặn ở tầng giao diện (bước khởi động), không gửi ngày sinh lên server. Lý do: giảm dữ liệu cá nhân phải bảo vệ.

### 3.2. Làm mới token

```http
POST /auth/v1/token?grant_type=refresh_token
{ "refresh_token": "v1..." }
```

**Thời hạn:** access token 1 giờ, refresh token 30 ngày. App tự làm mới trước khi hết hạn 5 phút.

---

## 4. Ví

### 4.1. Lấy danh sách ví

```http
GET /v1/wallets
```

**Tham số (tuỳ chọn):**

| Tên | Kiểu | Ý nghĩa |
|---|---|---|
| `include_deleted` | `true`\|`false` | Trả cả ví đã xoá mềm (đồng bộ offline). Mặc định `false`. |

**Trả về 200:**

```json
[
  { "id": "w1...", "name": "Tiền mặt", "type": "cash",
    "initial_balance": 500000, "balance": 1700000,
    "color": "#4CAF50", "icon": "wallet",
    "is_archived": false, "rev": 2, "deleted_at": null },
  { "id": "w2...", "name": "MoMo", "type": "ewallet",
    "initial_balance": 120000, "balance": 120000,
    "color": "#E91E63", "icon": "phone",
    "is_archived": false, "rev": 1, "deleted_at": null }
]
```

**`balance` là số dư hiện tại, server luôn tính, client không gửi lên:**

```
balance = initial_balance + SUM(income) - SUM(expense)
        + SUM(transfer vào ví) - SUM(transfer ra khỏi ví)
```

Giao dịch đã xoá mềm không được tính. Không lưu cột `balance` trong DB
(Q1: `transactions` là nguồn sự thật duy nhất).

### 4.1.1. Tổng hợp số dư theo ví

```http
GET /v1/wallets/summary
```

**Trả về 200:**

```json
{
  "wallets": [
    { "id": "w1...", "name": "Tiền mặt", "type": "cash",
      "is_archived": false, "balance": 1700000 }
  ],
  "total_balance": 295000,
  "by_type": { "cash": -135000, "bank": 430000 },
  "computed_at": "2026-11-19T18:35:58.218Z"
}
```

Ví đã xoá mềm không được cộng vào `total_balance` lẫn `by_type`.

### 4.2. Tạo ví

```http
POST /v1/wallets
```

```json
{
  "id": "c3d4e5f6-...",
  "name": "Vietcombank",
  "type": "bank",
  "initial_balance": 2000000,
  "color": "#1976D2",
  "icon": "bank"
}
```

**Quan trọng:** `id` do client sinh và gửi lên. Cho phép tạo ví khi offline, đồng bộ sau mà không đụng độ.

**Lỗi có thể gặp:**

```json
{ "error": { "code": "PLAN_LIMIT",
  "message": "Gói miễn phí chỉ cho phép 3 ví đang hoạt động",
  "details": { "limit": 3, "current": 3 } } }
```

### 4.3. Sửa ví

```http
PATCH /v1/wallets/<wallet_id>
```

```json
{ "name": "VCB", "rev": 2 }
```

**Quy tắc `rev`:** client gửi `rev` hiện tại + 1. Server kiểm tra `rev` client gửi phải bằng `rev` hiện tại + 1; nếu không, trả `SYNC_CONFLICT` kèm bản ghi mới nhất.

### 4.4. Xoá ví (mềm)

```http
DELETE /v1/wallets/<wallet_id>?rev=<rev hiện tại + 1>
```

**Trả về 200:** chính bản ghi đã xoá.

```json
{ "id": "w1...", "name": "Tiền mặt", "balance": 0,
  "rev": 3, "deleted_at": "2026-11-19T18:36:34.845Z" }
```

- Chỉ set `deleted_at`, **không xoá dòng** — giao dịch cũ vẫn tham chiếu được
  và client offline biết ví đã bị xoá.
- `rev` (tuỳ chọn) sai thì trả `SYNC_CONFLICT` kèm `server_rev`/`server_data`.
- Xoá lần hai trả `NOT_FOUND`.
- Không xoá được ví của người khác (`NOT_FOUND`).

---

## 5. Giao dịch

### 5.1. Lấy danh sách (phân trang cursor)

```http
GET /v1/transactions?limit=50&before=<occurred_at>&type=<expense|income|transfer>
```

Tham số `occurred_at=lt.<mốc>` là cursor: lấy 50 bản ghi trước mốc đó.

**Trả về 200:**

```json
[
  { "id": "t1...", "wallet_id": "w1...", "category_id": "cat_food",
    "type": "expense", "amount": 35000, "note": "Cơm trưa",
    "occurred_at": "2026-11-13T04:30:00Z", "occurred_on": "2026-11-13",
    "source": "manual", "payment_method": "cash", "income_source": null,
    "receipt_mime": null, "has_receipt": false, "receipt_base64": null,
    "rev": 1 }
]
```

Danh sách **không** trả bytes ảnh: chỉ `has_receipt` (và `receipt_mime`). 50 dòng
kèm ảnh 512KB sẽ thành ~25MB mỗi lần mở tab Giao dịch. Ảnh lấy ở mục 5.2b khi
người dùng mở chi tiết.

### 5.2b. Chi tiết một giao dịch

```http
GET /v1/transactions/<tx_id>
```

**Trả về 200:** đúng bản ghi đó, kèm `receipt_base64` (base64 của ảnh, `null` nếu
không có) và `has_receipt`. Đây là endpoint duy nhất trả bytes ảnh.

**Mã lỗi:** `NOT_FOUND` khi id không tồn tại hoặc thuộc user khác.

### 5.2. Tạo giao dịch

```http
POST /v1/transactions
```

```json
{
  "id": "f7a8b9c0-...",
  "wallet_id": "w1...",
  "category_id": "cat_food",
  "type": "expense",
  "amount": 35000,
  "note": "Cơm trưa",
  "occurred_at": "2026-11-13T04:30:00Z",
  "source": "manual",
  "payment_method": "cash",
  "income_source": null,
  "receipt_base64": null,
  "receipt_mime": null
}
```

`occurred_on` không gửi lên — trigger DB tính theo giờ VN. `payment_method`: `cash|bank_transfer|card|ewallet|other`. `income_source` dùng cho thu nhập. Hóa đơn gửi `receipt_base64` + `receipt_mime` (`image/jpeg|png|webp`, <=512KB; server kiểm chữ ký tệp nên ảnh giả bị `RULE_VIOLATION`, và `receipt_mime` phải khớp ảnh thật); response trả `receipt_base64/receipt_mime/has_receipt`.

`remove_receipt` chỉ có ở PATCH, gửi lúc tạo là `VALIDATION_FAILED`.

Body JSON được nhận tới **2MB** (base64 phình ~33% so với 512KB nhị phân).

**Trả về 201:** bản ghi đầy đủ kèm `occurred_on`, `rev`, `created_at`, `payment_method`, `income_source`, `receipt_base64`, `receipt_mime`.

**Mã lỗi đặc thù:**

| code | Nguyên nhân |
|---|---|
| `RULE_VIOLATION` | `type=transfer` mà thiếu `to_wallet_id`, hoặc `to_wallet_id` trùng `wallet_id` |
| `NOT_FOUND` | `wallet_id` hoặc `category_id` không tồn tại hoặc không thuộc user |

### 5.3. Sửa giao dịch

```http
PATCH /v1/transactions/<tx_id>
{
  "wallet_id": "w2...",
  "type": "expense",
  "amount": 40000,
  "payment_method": "bank_transfer",
  "income_source": "Học bổng",
  "receipt_base64": "...",
  "receipt_mime": "image/jpeg",
  "remove_receipt": false,
  "rev": 2
}
```

`remove_receipt=true` xóa hóa đơn (không gửi cùng receipt mới).

Sửa được cả `wallet_id`, `type`, `to_wallet_id`: ghi nhầm ví hoặc ghi Chi tiêu
thành Thu nhập là chuyện có thật, bắt xóa rồi tạo lại sẽ mất `created_at`.
`wallet_id`/`to_wallet_id` được kiểm quyền sở hữu như lúc tạo; đổi `type` khỏi
`transfer` thì `to_wallet_id` tự về `null`.

Gửi `payment_method: null` hoặc `income_source: null` để xóa trắng — bỏ hẳn khóa
thì giữ nguyên giá trị cũ. Không gửi `id` (không có trong DTO).

### 5.4. Xóa giao dịch

```http
PATCH /v1/transactions/<tx_id>
{ "deleted_at": "2026-11-13T05:00:00Z", "rev": 2 }
```

Xóa mềm. Không có `DELETE` thật, để đồng bộ được giữa các thiết bị.

### 5.5. Tổng hợp tháng (module reports)

```http
GET /v1/reports/month-summary?year=2026&month=11
```

**Trả về 200:**

```json
{
  "period": { "start": "2026-11-01", "end": "2026-11-30", "days_left": 18 },
  "income": 3000000,
  "expense": 1850000,
  "remaining": 1150000,
  "daily_limit": 63888,
  "budget": {
    "total": 3000000,
    "used_pct": 61.7
  },
  "previous": {
    "expense": 1150000,
    "delta_pct": 61
  },
  "by_category": [
    { "id": "cat_food", "name": "Ăn uống", "icon": "food",
      "color": "#FF9800", "total": 980000, "pct": 53.0 },
    { "id": "cat_travel", "name": "Đi lại", "icon": "bus",
      "color": "#2196F3", "total": 320000, "pct": 17.3 },
    { "id": null, "name": "Chưa phân loại",
      "total": 50000, "pct": 2.7 }
  ],
  "by_day": [
    { "date": "2026-11-01", "total": 120000 },
    { "date": "2026-11-02", "total": 0 }
  ],
  "computed_at": "2026-11-13T04:35:00Z"
}
```

`previous` dùng cho thẻ "so với tháng trước": `delta_pct = null` khi tháng
trước không có khoản chi nào — khác hẳn `0` (không đổi), vì client phải phân
biệt được "chưa có mốc" với "không thay đổi".

`by_category` **luôn** cộng lại đúng bằng `expense`: giao dịch chưa gắn danh
mục được gộp vào một dòng `id: null`, `name: "Chưa phân loại"`. Nếu lọc bỏ
những dòng này thì biểu đồ cơ cấu thiếu tiền và người dùng thấy biểu đồ trống
dù đã chi tiêu.

**Vì sao phải có endpoint tổng hợp thay vì để client tự tính:** chỉ số `daily_limit` là trung tâm của sản phẩm. Nếu client tự tính, mỗi nền tảng có thể cho kết quả khác nhau do làm tròn. Đưa lên server để **một công thức duy nhất**.

Ngoại lệ: khi offline, client dùng chính công thức đó tính từ dữ liệu local. Công thức phải được viết một lần và dùng chung (xem mục 7).

### 5.6. Danh mục

```http
GET    /v1/categories?type=<expense|income>&include_deleted=<true|false>
POST   /v1/categories
PATCH  /v1/categories/<category_id>
DELETE /v1/categories/<category_id>?rev=<rev hiện tại + 1>
```

Danh mục hệ thống có `user_id = null` và `is_system = true`, dùng chung cho mọi
người; danh mục người dùng tự tạo có `user_id` của họ. `GET` trả cả hai loại.

**Trả về 200 (một phần tử):**

```json
{ "id": "cat_food", "user_id": null, "name": "Ăn uống", "type": "expense",
  "icon": "food", "color": "#FF9800", "parent_id": null,
  "is_system": true, "sort_order": 1, "rev": 1, "deleted_at": null }
```

**`DELETE` xoá mềm** (đặt `deleted_at`, tăng `rev`), trả chính bản ghi đã xoá.
Danh mục hệ thống không xoá được (`FORBIDDEN`). `rev` sai trả `SYNC_CONFLICT`.
Mặc định `GET` ẩn danh mục đã xoá; `include_deleted=true` trả cả bản đã xoá để
đồng bộ offline.

---

## 6. Ngân sách

### 6.1. Lấy ngân sách đang áp dụng

```http
GET /v1/budgets?active=true
```

### 6.2. Đặt ngân sách

```http
POST /v1/budgets
```

```json
{
  "id": "b1...",
  "category_id": null,
  "amount": 3000000,
  "period": "month",
  "start_date": "2026-11-01"
}
```

**Trả về 409 nếu đã có ngân sách tổng đang áp dụng.** App phải gọi `PATCH` thay vì `POST` khi muốn sửa.

### 6.3. Tiến độ ngân sách

```http
GET /v1/budgets/progress
```

**Trả về 200:**

```json
{
  "as_of": "2026-11-13",
  "items": [
    { "budget_id": "b1...", "category_id": null, "name": "Tổng",
      "amount": 3000000, "spent": 1850000, "remaining": 1150000,
      "used_pct": 61.7, "status": "ok", "days_left": 18 },
    { "budget_id": "b2...", "category_id": "cat_food", "name": "Ăn uống",
      "amount": 1500000, "spent": 980000, "remaining": 520000,
      "used_pct": 65.3, "status": "ok", "days_left": 18 },
    { "budget_id": "b3...", "category_id": "cat_shop", "name": "Mua sắm",
      "amount": 300000, "spent": 295000, "remaining": 5000,
      "used_pct": 98.3, "status": "warning", "days_left": 18 }
  ]
}
```

`status` do server tính: `ok` (< 70%), `notice` (70–89%), `warning` (90–99%), `exceeded` (≥ 100%).

**Vì sao server quyết định `status`:** để ngưỡng cảnh báo thống nhất giữa push notification và giao diện. Nếu client tự quyết, thông báo có thể nói 70% trong khi màn hình hiện vàng ở 75%.

---

## 7. Mục tiêu tiết kiệm

Mục tiêu nhập tay (Q8, 2026-11-17). `saved_amount` là số người dùng tự khai; **không** tính từ giao dịch, **không** gắn ví.

### 7.1. Lấy danh sách

```http
GET /v1/goals
```

**Trả về 200:**

```json
{
  "items": [
    { "id": "g1...", "name": "Mua laptop", "target_amount": 500000,
      "saved_amount": 200000, "progress_pct": 40.0, "deadline": "2027-03-01",
      "icon": "laptop", "is_completed": false, "rev": 2,
      "updated_at": "2026-11-17T03:00:00Z" }
  ]
}
```

`progress_pct` do server tính: `min(100, saved_amount / target_amount * 100)`, làm tròn 1 chữ số thập phân. `target_amount` luôn > 0 nên không có phép chia cho 0.

### 7.2. Tạo mục tiêu

```http
POST /v1/goals
```

```json
{ "name": "Mua laptop", "target_amount": 500000, "deadline": "2027-03-01", "icon": "laptop" }
```

**Trả về 201:** như mục 7.1 với `saved_amount = 0`.

**Lỗi 422:** `target_amount <= 0`, `name` rỗng, hoặc `deadline` ở quá khứ.

### 7.3. Cập nhật (kể cả nạp thêm tiền)

```http
PATCH /v1/goals/{id}
```

```json
{ "saved_amount": 350000, "rev": 2 }
```

**Trả về 200:** mục tiêu sau khi sửa.

**Lỗi 409:** `rev` không khớp — cùng cơ chế chống ghi đè như giao dịch (mục 9.3).

Chỉ gửi trường cần đổi. `saved_amount` là số tuyệt đối, không phải số cộng thêm — client tự cộng rồi gửi, để tránh hai lần cộng trùng khi mất mạng.

### 7.4. Xoá

```http
DELETE /v1/goals/{id}
```

Xoá mềm, đặt `deleted_at`. **Trả về 204.**

---

## 8. Chia tiền nhóm (Split Bill)

Nhiều người dùng cùng đọc dữ liệu. Quy tắc tính tiền ở [01 mục 9.5](01-database-schema.md#95-quan-hệ-với-sổ-cá-nhân--điểm-dễ-sai-nhất): người trả chỉ ghi **phần của mình** vào sổ cá nhân.

### 8.1. Danh sách nhóm

```http
GET /v1/groups
```

**Trả về 200:**

```json
{
  "items": [
    { "id": "gr1...", "name": "Nhóm trọ 4 người", "role": "member",
      "member_count": 4, "invite_code": null,
      "my_balance": -100000, "rev": 3, "updated_at": "2026-11-17T04:00:00Z" }
  ]
}
```

`my_balance` âm = mình còn nợ nhóm; dương = nhóm còn nợ mình. `invite_code` chỉ trả về cho chủ nhóm; thành viên thường nhận `null`.

### 8.2. Tạo nhóm

```http
POST /v1/groups
```

```json
{ "name": "Nhóm trọ 4 người" }
```

**Trả về 201:** nhóm kèm `invite_code` (8 ký tự). Người tạo tự động thành `owner`.

### 8.3. Vào nhóm bằng mã mời

```http
POST /v1/groups/join
```

```json
{ "invite_code": "K7M2QP9X" }
```

**Trả về 200:** nhóm vừa vào. **Lỗi 404:** mã sai hoặc nhóm đã xoá. Không phân biệt hai trường hợp này, để không dò được mã.

**Lỗi 409:** đã là thành viên.

### 8.4. Thành viên và số dư

```http
GET /v1/groups/{id}/balances
```

**Trả về 200:**

```json
{
  "items": [
    { "user_id": "u1...", "display_name": "Nguyễn Huyền Diệu",
      "paid": 400000, "owed": 100000, "net": 300000 },
    { "user_id": "u2...", "display_name": "Trần Văn A",
      "paid": 0, "owed": 100000, "net": -100000 }
  ],
  "settlements": [
    { "from": "u2...", "to": "u1...", "amount": 100000 }
  ]
}
```

`settlements` là gợi ý chuyển tiền **tối thiểu** để tất cả về 0, tính bằng cách ghép người nợ nhiều nhất với người được nhận nhiều nhất. Server tính, không phải client.

### 8.5. Thêm khoản chi chung

```http
POST /v1/groups/{id}/expenses
```

```json
{
  "amount": 400000,
  "note": "Tiền điện tháng 11",
  "occurred_on": "2026-11-17",
  "split_method": "equal",
  "shares": [
    { "user_id": "u1...", "share_amount": 100000 },
    { "user_id": "u2...", "share_amount": 100000 },
    { "user_id": "u3...", "share_amount": 100000 },
    { "user_id": "u4...", "share_amount": 100000 }
  ]
}
```

**Trả về 201:** khoản chi kèm các phần chia.

**Lỗi 422:** tổng `share_amount` khác `amount`; có `user_id` không thuộc nhóm; `share_amount` âm; `amount <= 0`.

**Việc server làm trong một transaction:**
1. Tạo `shared_expenses`.
2. Tạo các dòng `shared_shares`.
3. Kiểm tổng phần chia bằng `amount` — sai thì rollback toàn bộ.
4. **Sinh giao dịch cá nhân** cho mỗi người có `share_amount > 0`: `type = 'expense'`, `amount = share_amount`, `note` gắn tên nhóm.

Bước 4 là chỗ dễ bỏ sót. Bỏ thì số liệu cá nhân của mọi thành viên sai, nhưng Split Bill vẫn hiện đúng — lỗi rất khó phát hiện.

### 8.6. Đánh dấu đã thanh toán

```http
POST /v1/groups/{id}/settle
```

```json
{ "with_user_id": "u1...", "amount": 100000 }
```

Đặt `settled_at` cho các phần chia liên quan. **Trả về 200** kèm số dư mới.

**Giới hạn:** chỉ đánh dấu được phần của **chính mình**. Muốn xác nhận người khác đã trả, họ phải tự đánh dấu. Không cho một người sửa nợ của người khác.

---

## 9. Công thức dùng chung (bắt buộc)

Đây là điểm dễ sai nhất khi có cả server và client cùng tính.

```
budget       = ngân sách tổng đang áp dụng (0 nếu chưa đặt)
spent        = tổng chi từ đầu kỳ đến hết hôm nay   ← CHỈ type = 'expense'
remaining    = budget - spent
days_left    = số ngày còn lại trong kỳ, tính cả hôm nay
daily_limit  = remaining > 0 AND days_left > 0
                 ? floor(remaining / days_left)
                 : remaining
```

**Ba quy tắc không được vi phạm:**

1. Làm tròn **xuống** (`floor`), không làm tròn gần. Nếu làm tròn lên, tổng các ngày sẽ vượt ngân sách.
2. `days_left` tính **cả hôm nay**. Ngày 30/11 thì `days_left = 1`, không phải 0.
3. `remaining ≤ 0` thì `daily_limit = remaining` (số âm), **không chia**. Giao diện hiển thị "đã vượt X đồng".

**Quy tắc thứ tư (đã chốt Q3):** `spent` chỉ cộng giao dịch `type = 'expense'`. Giao dịch `transfer` **không** được tính — nếu tính, chuyển tiền giữa hai ví sẽ làm giảm chỉ số hôm nay một cách vô lý.

Phải có bộ test cho công thức này, chạy trên cả Dart và SQL, đối chiếu cùng kết quả với ít nhất 20 bộ số.

---

## 10. Đồng bộ

### 10.1. Chiến lược

**Local-first, last-write-wins theo `rev`.**

```
1. Mọi thay đổi ghi vào SQLite local trước, đánh dấu sync_status = 'pending'
2. Đưa vào hàng đợi sync_queue
3. Khi có mạng, đẩy lần lượt lên server
4. Nhận kết quả, đổi sync_status = 'synced', lưu rev mới
5. Kéo thay đổi từ server về (pull) theo updated_at
```

### 10.2. Đẩy thay đổi

```http
POST /v1/sync/push
```

```json
{
  "device_id": "d1...",
  "changes": [
    { "table": "transactions", "op": "insert", "id": "t9...", "rev": 1,
      "data": { "wallet_id": "w1...", "type": "expense", "amount": 35000,
                "occurred_at": "2026-11-13T04:30:00Z" } },
    { "table": "transactions", "op": "update", "id": "t8...", "rev": 3,
      "data": { "amount": 40000 } },
    { "table": "wallets", "op": "delete", "id": "w3...", "rev": 4, "data": {} }
  ]
}
```

**Trả về 200:**

```json
{
  "applied": [
    { "table": "transactions", "id": "t9...", "status": "ok", "rev": 1 },
    { "table": "transactions", "id": "t8...", "status": "ok", "rev": 3 }
  ],
  "conflicts": [
    { "table": "wallets", "id": "w3...", "status": "conflict",
      "server_rev": 6,
      "server_data": { "name": "MoMo cũ", "deleted_at": null } }
  ],
  "server_time": "2026-11-13T05:00:00Z"
}
```

### 10.3. Giải quyết xung đột

**Quy tắc: server thắng, nhưng không mất dữ liệu người dùng.**

| Tình huống | Xử lý |
|---|---|
| `rev` client = `rev` server + 1 | Áp dụng bình thường |
| `rev` client ≤ `rev` server | Trả `conflict` kèm dữ liệu server |
| Hai thiết bị cùng sửa | Thiết bị gửi sau nhận `conflict`, app hiện hộp thoại "Bản ghi này đã được sửa trên thiết bị khác" kèm 2 phiên bản để chọn |

Với MVP dùng 1 thiết bị, xung đột gần như không xảy ra. Nhưng **phải có sẵn cơ chế**, nếu không sau này thêm đa thiết bị sẽ phải viết lại toàn bộ tầng sync.

### 10.4. Kéo thay đổi

```http
GET /v1/sync/pull?since=2026-11-13T04:00:00Z&limit=500
```

**Trả về 200:**

```json
{
  "changes": [
    { "table": "transactions", "op": "update", "id": "t7...", "rev": 2, "data": { } },
    { "table": "budgets", "op": "insert", "id": "b4...", "rev": 1, "data": { } }
  ],
  "next_since": "2026-11-13T05:00:00Z",
  "has_more": false
}
```

`next_since` là mốc thời gian lớn nhất trong lô vừa trả. Client lưu vào `sync_state.last_pull_at`.

**Quy tắc:** luôn `has_more` để client biết còn phải kéo tiếp. Giới hạn 500 bản ghi/lô để tránh response quá lớn.

---

## 11. AI (giai đoạn 2 — thiết kế sẵn để không phải sửa)

### 11.1. Đọc hóa đơn

```http
POST /v1/ai/ocr
Content-Type: multipart/form-data

file: <ảnh jpeg, tối đa 5 MB>
```

**Trả về 200:**

```json
{
  "ocr_id": "o1...",
  "amount": 35000,
  "occurred_at": "2026-11-12T05:00:00Z",
  "merchant": "Cơm Tấm Bụi",
  "suggested_category": { "id": "cat_food", "name": "Ăn uống", "confidence": 0.91 },
  "raw_text": "COM TAM BUI\n35000\n12/11/2026",
  "quota": { "used": 4, "limit": 10, "reset_at": "2026-12-01T00:00:00+07:00" }
}
```

**Lưu ý quan trọng:** endpoint này **không tạo giao dịch**. Nó chỉ trả về dữ liệu đề xuất. App hiện màn hình xác nhận cho người dùng sửa rồi mới gọi `POST /transactions`.

Lý do: nếu OCR tự tạo giao dịch, một lần nhận diện sai sẽ làm sai toàn bộ số liệu tài chính, và người dùng khó phát hiện.

> **Giai đoạn sau MVP.** Nhóm chốt MVP chỉ nhập tay.

### 11.2. Trợ lý hỏi đáp

```http
POST /v1/ai/chat
```

```json
{ "question": "Tháng này tôi tiêu ăn uống bao nhiêu?" }
```

**Trả về 200:**

```json
{
  "answer": "Tháng này bạn chi 980.000đ cho ăn uống, chiếm 53% tổng chi. Trung bình 75.000đ mỗi ngày.",
  "data_refs": [
    { "type": "month_summary", "period": "2026-11" }
  ],
  "quota": { "used": 3, "limit": 10, "reset_at": "2026-12-01T00:00:00+07:00" }
}
```

**Điều bắt buộc:** `data_refs` cho biết câu trả lời dựa trên truy vấn nào. Có thể bấm vào để mở đúng màn hình. Không có cơ chế này thì người dùng không kiểm chứng được AI nói đúng hay sai — rủi ro không chấp nhận được với dữ liệu tiền.

### 11.3. Hạn mức

Mọi endpoint AI đều trả `quota` trong response. Khi vượt:

```json
{ "error": { "code": "QUOTA_EXCEEDED", "field": "ocr",
  "details": { "limit": 10, "used": 10, "reset_at": "2026-12-01T00:00:00+07:00" } } }
```

App hiển thị: *"Bạn đã dùng hết 10 lượt xem hóa đơn trong tháng này. Nâng cấp Pro để có 300 lượt."*

---

## 12. Job định kỳ (server)

Đầy đủ **12 job** — lịch chạy, khoá idempotent, xử lý lỗi, giám sát — ở [07 — Công việc định kỳ](07-cron-jobs.md). Không lặp lại ở đây để tránh lệch.

Tóm tắt nhóm:

| Nhóm | Job |
|---|---|
| Dữ liệu định kỳ | `recurring-generate`, `soft-delete-purge` |
| Ngân sách | `budget-close`, `budget-alert` |
| Tổng hợp | `aggregate-refresh` |
| Người dùng | `daily-reminder`, `winback`, `fcm-token-cleanup` |
| AI | `ai-monthly-review`, `ai-quota-reset`, `ai-cost-breaker` |
| Chất lượng | `integrity-check` |

Mọi job chạy trong **Worker NestJS + BullMQ**, không dùng `pg_cron`, không dùng Edge Functions.

---

## 13. Giới hạn tải

| Endpoint | Giới hạn | Cách tính |
|---|---|---|
| Đăng nhập | 5 lần/phút/IP | Chống dò mật khẩu |
| `POST /transactions` | 120 lần/phút/user | Người dùng thật hiếm khi vượt |
| `sync-push` | 10 lần/phút/device | |
| `ai/ocr` | Theo quota gói | |
| `ai/chat` | Theo quota gói + 20 lần/phút | Chống gọi tự động |

---

## 14. Điểm cần bạn quyết

| # | Vấn đề | Đề xuất | Phương án khác |
|---|---|---|---|
| 1 | ~~Dùng PostgREST trực tiếp hay viết API riêng~~ | **Đã chốt Q5:** NestJS viết toàn bộ, không dùng PostgREST | — |
| 2 | Cursor phân trang hay offset | Cursor theo `occurred_at` | Offset đơn giản hơn nhưng sai khi có bản ghi mới chèn vào |
| 3 | `daily_limit` tính server hay client | Server khi online, client khi offline, dùng chung công thức | Chỉ client, đơn giản hơn nhưng dễ lệch |
| 4 | Có endpoint `sync-pull` riêng hay dùng PostgREST với `updated_at` | **Đã chốt:** endpoint riêng trong module sync, vì cần trả nhiều bảng trong một request | — |
| 5 | AI OCR nhận ảnh hay chỉ nhận text đã trích xuất | Nhận ảnh, ML Kit chạy server-side | Client trích xuất rồi gửi text, rẻ hơn nhưng phụ thuộc thiết bị |

Điểm 5 đáng cân nhắc: nếu client tự chạy ML Kit rồi chỉ gửi text, chi phí giảm nhưng chất lượng phụ thuộc camera và máy. Đề xuất MVP: **client trích xuất, gửi text**, và chỉ gửi ảnh khi text không đủ rõ (độ tin cậy < 0,6).
