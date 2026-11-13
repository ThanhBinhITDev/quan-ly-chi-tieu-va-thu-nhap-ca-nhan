# 01 — Thiết kế cơ sở dữ liệu

**Phiên bản:** 1.0 · **Ngày:** 2026-11-13 · **Trạng thái:** chờ duyệt

Mục tiêu: đủ cho MVP, mở rộng được sang AI và đồng bộ đa thiết bị mà không phải migrate lại.

---

## 1. Quy ước chung

| Quy ước | Giá trị | Lý do |
|:---:|:---:|:---:|
| Kiểu khóa chính | `UUID v4` sinh **trên thiết bị** | Cho phép ghi offline rồi đồng bộ, không đụng độ |
| Đơn vị tiền | `BIGINT`, lưu **đồng** (VND), không dùng số thực | Tránh sai số dấu phẩy động |
| Số tiền | Luôn **dương**. Loại giao dịch quyết định dấu | Không có amount âm, tránh lỗi cộng trừ |
| Thời gian | `TIMESTAMPTZ` lưu UTC | Hiển thị theo múi giờ thiết bị |
| Ngày nghiệp vụ | `DATE` cột `occurred_on` (theo giờ VN) | Nhóm theo ngày/tháng không phụ thuộc UTC |
| Xóa mềm | `deleted_at TIMESTAMPTZ NULL` | Cần cho đồng bộ, không xóa thật |
| Phiên bản bản ghi | `rev INT` tăng mỗi lần sửa | Phát hiện xung đột khi sync |
| Tên bảng | `snake_case`, số nhiều | |

**Hai loại ID cần phân biệt:**

- `id` — UUID sinh trên máy, **không bao giờ đổi**. Dùng làm khóa chính và khóa đồng bộ.
- `server_id` — `BIGSERIAL`, chỉ có trên server. Dùng cho index nội bộ, không gửi xuống client.

---

## 2. Sơ đồ quan hệ

```
users
  │
  ├──< wallets            (1 user có nhiều ví)
  ├──< categories         (danh mục mặc định user_id = NULL)
  ├──< budgets            (1 ngân sách thuộc 1 danh mục)
  ├──< goals              (mục tiêu tiết kiệm)
  ├──< recurring_rules    (giao dịch định kỳ)
  ├──< devices            (thiết bị đăng nhập, push token)
  │
  └──< transactions >──── wallets
                └──────> categories
                └──────> recurring_rules (nếu sinh tự động)
```

---

## 3. Bảng `users`

```sql
CREATE TABLE users (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email         CITEXT UNIQUE,
  phone         TEXT UNIQUE,
  display_name  TEXT NOT NULL,
  plan          TEXT NOT NULL DEFAULT 'free'
                CHECK (plan IN ('free','pro_month','pro_year','pro_student')),
  plan_expires_at TIMESTAMPTZ,
  currency      TEXT NOT NULL DEFAULT 'VND',
  timezone      TEXT NOT NULL DEFAULT 'Asia/Ho_Chi_Minh',
  onboarded_at  TIMESTAMPTZ,          -- hoàn thành 3 bước khởi động
  ai_quota_used JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at    TIMESTAMPTZ,
  CONSTRAINT users_contact CHECK (email IS NOT NULL OR phone IS NOT NULL)
);
```

**Ghi chú thiết kế:**

- `email` và `phone` đều nullable nhưng phải có ít nhất một → cho phép đăng ký bằng SĐT (sinh viên VN phổ biến hơn email).
- `onboarded_at` dùng để quyết định có hiện luồng khởi động hay không, và để đo chỉ số D1.
- `ai_quota_used` là JSONB dạng `{"2026-11": {"ocr": 3, "chat": 1}}` — reset theo tháng bằng cách đọc key tháng hiện tại, không cần job dọn dẹp.
- `plan_expires_at` NULL với gói free; có giá trị với gói Pro để job kiểm tra hết hạn.

---

## 4. Bảng `wallets`

```sql
CREATE TABLE wallets (
  id              UUID PRIMARY KEY,
  user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name            TEXT NOT NULL,                  -- "Tiền mặt", "MoMo", "VCB"
  type            TEXT NOT NULL
                  CHECK (type IN ('cash','ewallet','bank','credit')),
  initial_balance BIGINT NOT NULL DEFAULT 0,      -- số dư khai báo ban đầu
  color           TEXT,                           -- mã màu hex cho UI
  icon            TEXT,
  sort_order      INT NOT NULL DEFAULT 0,
  is_archived     BOOLEAN NOT NULL DEFAULT false, -- ẩn khỏi danh sách chọn
  rev             INT NOT NULL DEFAULT 1,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at      TIMESTAMPTZ
);

CREATE INDEX idx_wallets_user ON wallets(user_id) WHERE deleted_at IS NULL;
```

**Không lưu `balance` trực tiếp.** Số dư luôn tính:

```sql
balance = initial_balance
        + SUM(income) - SUM(expense)
        + SUM(transfer_in) - SUM(transfer_out)
```

Lý do: nếu lưu `balance` thì mỗi lần sync, sửa, xóa đều phải cập nhật lại và dễ lệch. Tính từ giao dịch luôn đúng, chỉ chậm hơn.

Với 1 user có ~1.000 giao dịch/năm, tính lại toàn bộ mất vài mili giây — chấp nhận được. Nếu sau này chậm, thêm bảng `wallet_balance_cache` cập nhật bằng trigger.

**Giới hạn gói free:** tối đa 3 ví đang hoạt động. Kiểm tra ở tầng ứng dụng, không phải ràng buộc DB.

---

## 5. Bảng `categories`

```sql
CREATE TABLE categories (
  id          UUID PRIMARY KEY,
  user_id     UUID REFERENCES users(id) ON DELETE CASCADE,  -- NULL = mặc định
  name        TEXT NOT NULL,
  type        TEXT NOT NULL CHECK (type IN ('expense','income')),
  icon        TEXT,
  color       TEXT,
  parent_id   UUID REFERENCES categories(id),               -- danh mục con (dự phòng)
  is_system   BOOLEAN NOT NULL DEFAULT false,               -- không cho user xóa
  sort_order  INT NOT NULL DEFAULT 0,
  rev         INT NOT NULL DEFAULT 1,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at  TIMESTAMPTZ
);

CREATE UNIQUE INDEX uq_cat_user_name
  ON categories(COALESCE(user_id, '00000000-0000-0000-0000-000000000000'::uuid), name, type)
  WHERE deleted_at IS NULL;
```

**Danh mục mặc định** (seed sẵn, `user_id = NULL`):

| Loại | Danh mục |
|:---:|:---:|
| Chi | Ăn uống, Đi lại, Mua sắm, Học tập, Giải trí, Sức khỏe, Nhà ở, Hóa đơn, Khác |
| Thu | Tiền gia đình, Học bổng, Lương làm thêm, Thu nhập khác |

**Vì sao `user_id = NULL` cho danh mục mặc định:** tránh phải copy 13 dòng cho mỗi user mới. Khi user tạo danh mục riêng thì `user_id` có giá trị, và có thể trùng tên với danh mục mặc định (unique index đã xử lý bằng COALESCE).

**Giới hạn gói free:** tối đa 10 danh mục tự tạo.

---

## 6. Bảng `transactions` — bảng trung tâm

```sql
CREATE TABLE transactions (
  id            UUID PRIMARY KEY,                    -- sinh trên máy
  user_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  wallet_id     UUID NOT NULL REFERENCES wallets(id),
  category_id   UUID REFERENCES categories(id),

  type          TEXT NOT NULL
                CHECK (type IN ('expense','income','transfer')),
  amount        BIGINT NOT NULL CHECK (amount > 0),  -- luôn dương

  -- Dùng cho type = 'transfer'
  to_wallet_id  UUID REFERENCES wallets(id),

  note          TEXT,
  occurred_at   TIMESTAMPTZ NOT NULL,                -- thời điểm chính xác UTC
  occurred_on   DATE NOT NULL,                       -- ngày theo giờ VN, để nhóm

  source        TEXT NOT NULL DEFAULT 'manual'
                CHECK (source IN ('manual','ocr','recurring','quick')),

  receipt_url   TEXT,                                -- ảnh hóa đơn (Supabase Storage)
  ai_confidence REAL,                                -- 0..1, chỉ khi source = 'ocr'

  rev           INT NOT NULL DEFAULT 1,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at    TIMESTAMPTZ,

  CONSTRAINT tx_transfer_needs_target
    CHECK (type <> 'transfer' OR to_wallet_id IS NOT NULL),
  CONSTRAINT tx_transfer_distinct
    CHECK (type <> 'transfer' OR to_wallet_id <> wallet_id)
);
```

### Index

```sql
-- Truy vấn chính: giao dịch của user trong khoảng thời gian
CREATE INDEX idx_tx_user_time
  ON transactions(user_id, occurred_on DESC)
  WHERE deleted_at IS NULL;

-- Lọc theo danh mục (biểu đồ cơ cấu)
CREATE INDEX idx_tx_user_cat_time
  ON transactions(user_id, category_id, occurred_on DESC)
  WHERE deleted_at IS NULL;

-- Lọc theo ví (tính số dư)
CREATE INDEX idx_tx_wallet
  ON transactions(wallet_id, occurred_on DESC)
  WHERE deleted_at IS NULL;

-- Đồng bộ: lấy bản ghi thay đổi sau một mốc thời gian
CREATE INDEX idx_tx_sync
  ON transactions(user_id, updated_at);
```

### Vì sao có cả `occurred_at` và `occurred_on`

- `occurred_at` (UTC) để sắp xếp chính xác và đồng bộ giữa các múi giờ.
- `occurred_on` (ngày VN) để nhóm theo ngày/tháng **không bị lỗi lệch ngày**.

Ví dụ: người dùng ghi lúc 23:30 ngày 30/11 giờ VN. Nếu chỉ có UTC, đó là 16:30 ngày 30/11 — đúng. Nhưng nếu ghi lúc 00:30 ngày 1/12 giờ VN, UTC là 17:30 ngày 30/11 → nếu nhóm theo UTC sẽ tính vào tháng 11 sai. Có `occurred_on` thì luôn đúng.

`occurred_on` được tính ở tầng ứng dụng: `occurred_at` đổi sang `Asia/Ho_Chi_Minh` rồi lấy phần ngày. Có thể dùng generated column nếu cần chắc chắn:

```sql
occurred_on DATE GENERATED ALWAYS AS (
  (occurred_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date
) STORED
```

Khuyến nghị dùng generated column để không phụ thuộc client tính đúng.

---

## 7. Bảng `budgets`

```sql
CREATE TABLE budgets (
  id           UUID PRIMARY KEY,
  user_id      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  category_id  UUID REFERENCES categories(id),   -- NULL = ngân sách tổng
  amount       BIGINT NOT NULL CHECK (amount > 0),
  period       TEXT NOT NULL DEFAULT 'month'
               CHECK (period IN ('week','month')),
  start_date   DATE NOT NULL,                    -- ngày bắt đầu kỳ áp dụng đầu tiên
  end_date     DATE,                             -- NULL = áp dụng vô hạn
  rev          INT NOT NULL DEFAULT 1,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at   TIMESTAMPTZ
);

CREATE UNIQUE INDEX uq_budget_active
  ON budgets(user_id, COALESCE(category_id,'00000000-0000-0000-0000-000000000000'::uuid), period)
  WHERE deleted_at IS NULL AND end_date IS NULL;
```

**Cách tính "đã chi bao nhiêu" trong kỳ hiện tại:**

```sql
SELECT COALESCE(SUM(t.amount), 0) AS spent
FROM transactions t
WHERE t.user_id = :uid
  AND t.type = 'expense'
  AND (t.category_id = :cat_id OR :cat_id IS NULL)
  AND t.occurred_on BETWEEN :period_start AND :period_end
  AND t.deleted_at IS NULL;
```

`period_start` và `period_end` tính ở tầng ứng dụng theo `start_date` + `period`, không lưu sẵn. Lý do: nếu lưu sẵn, mỗi tháng phải sinh bản ghi mới → phình dữ liệu và phức tạp khi sửa.

---

## 8. Bảng `goals`

```sql
CREATE TABLE goals (
  id             UUID PRIMARY KEY,
  user_id        UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name           TEXT NOT NULL,               -- "Mua laptop"
  target_amount  BIGINT NOT NULL CHECK (target_amount > 0),
  saved_amount   BIGINT NOT NULL DEFAULT 0,
  deadline       DATE,
  icon           TEXT,
  is_completed   BOOLEAN NOT NULL DEFAULT false,
  rev            INT NOT NULL DEFAULT 1,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at     TIMESTAMPTZ
);
```

`saved_amount` lưu trực tiếp (khác với wallet balance) vì mục tiêu tiết kiệm là con số người dùng tự khai, không gắn với giao dịch thật ở MVP.

Giai đoạn 2 có thể liên kết `goals` với một ví riêng loại `savings`.

---

## 9. Bảng `recurring_rules`

```sql
CREATE TABLE recurring_rules (
  id           UUID PRIMARY KEY,
  user_id      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  template     JSONB NOT NULL,       -- {wallet_id, category_id, amount, note, type}
  frequency    TEXT NOT NULL
               CHECK (frequency IN ('daily','weekly','monthly','yearly')),
  day_of_month INT,                  -- 1..31 cho monthly
  day_of_week  INT,                  -- 1..7 cho weekly
  next_run_on  DATE NOT NULL,
  last_run_on  DATE,
  is_active    BOOLEAN NOT NULL DEFAULT true,
  rev          INT NOT NULL DEFAULT 1,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at   TIMESTAMPTZ
);

CREATE INDEX idx_recurring_due ON recurring_rules(next_run_on)
  WHERE is_active = true AND deleted_at IS NULL;
```

**Xử lý ngày 29–31 thiếu:** nếu `day_of_month = 31` và tháng chỉ có 30 ngày, chạy vào ngày cuối tháng. Logic ở tầng ứng dụng, không ràng buộc DB.

**Ai sinh giao dịch:** client, khi mở app và phát hiện `next_run_on <= hôm nay`. Sau đó cập nhật `next_run_on` và đẩy lên server. Không dùng cron server vì người dùng phải mở app mới thấy, và tránh phải chạy job 24/7.

---

## 10. Bảng `devices`

```sql
CREATE TABLE devices (
  id            UUID PRIMARY KEY,
  user_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  platform      TEXT NOT NULL CHECK (platform IN ('android','ios','web')),
  push_token    TEXT,
  app_version   TEXT,
  last_sync_at  TIMESTAMPTZ,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

Dùng để gửi push và để phát hiện sync bất thường.

---

## 11. Row Level Security (Supabase)

Bắt buộc bật cho mọi bảng, nếu không dữ liệu tài chính của người này đọc được bởi người khác.

```sql
ALTER TABLE wallets      ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE budgets      ENABLE ROW LEVEL SECURITY;
ALTER TABLE goals        ENABLE ROW LEVEL SECURITY;
ALTER TABLE recurring_rules ENABLE ROW LEVEL SECURITY;

CREATE POLICY p_wallets_own ON wallets
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- tương tự cho các bảng còn lại
```

**Riêng `categories`:** user chỉ thấy danh mục của mình **hoặc** danh mục mặc định:

```sql
CREATE POLICY p_categories_read ON categories
  FOR SELECT USING (user_id IS NULL OR user_id = auth.uid());

CREATE POLICY p_categories_write ON categories
  FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
```

Điểm này dễ làm sai: nếu dùng một policy chung `user_id = auth.uid()` thì user sẽ **không thấy** danh mục mặc định, và app hiện danh sách trống.

---

## 12. Câu truy vấn then chốt

### 12.1. Chỉ số "Hôm nay được tiêu bao nhiêu"

Đây là truy vấn chạy mỗi lần mở app. Phải nhanh.

```sql
WITH b AS (
  SELECT amount FROM budgets
  WHERE user_id = :uid AND category_id IS NULL
    AND deleted_at IS NULL AND end_date IS NULL
  LIMIT 1
),
spent AS (
  SELECT COALESCE(SUM(amount), 0) AS total
  FROM transactions
  WHERE user_id = :uid AND type = 'expense'
    AND occurred_on BETWEEN :month_start AND :today
    AND deleted_at IS NULL
)
SELECT
  b.amount                            AS budget,
  spent.total                         AS spent,
  b.amount - spent.total              AS remaining,
  (:month_end - :today) + 1           AS days_left,
  CASE WHEN (:month_end - :today) + 1 > 0
       THEN (b.amount - spent.total) / ((:month_end - :today) + 1)
       ELSE b.amount - spent.total
  END                                 AS daily_limit
FROM b, spent;
```

**Quy tắc nghiệp vụ quan trọng:** nếu `remaining` âm, `daily_limit` trả về chính `remaining` (số âm), không chia. Như vậy giao diện hiển thị "đã vượt 120.000đ" thay vì một con số dương gây hiểu nhầm.

### 12.2. Biểu đồ cơ cấu chi tiêu theo tháng

```sql
SELECT c.id, c.name, c.icon, c.color,
       SUM(t.amount) AS total,
       ROUND(100.0 * SUM(t.amount) / SUM(SUM(t.amount)) OVER (), 1) AS pct
FROM transactions t
JOIN categories c ON c.id = t.category_id
WHERE t.user_id = :uid
  AND t.type = 'expense'
  AND t.occurred_on BETWEEN :month_start AND :month_end
  AND t.deleted_at IS NULL
GROUP BY c.id, c.name, c.icon, c.color
ORDER BY total DESC;
```

### 12.3. Chi tiêu theo ngày trong tháng (biểu đồ cột)

```sql
SELECT occurred_on, SUM(amount) AS total
FROM transactions
WHERE user_id = :uid AND type = 'expense'
  AND occurred_on BETWEEN :month_start AND :month_end
  AND deleted_at IS NULL
GROUP BY occurred_on
ORDER BY occurred_on;
```

Client tự điền các ngày không có giao dịch bằng 0 (không dùng `generate_series` để tránh truy vấn nặng).

---

## 13. Dung lượng ước tính

| Bảng | 1 user/năm | 10.000 user/năm |
|:---:|:---:|:---:|
| transactions | ~1.200 dòng × 250 B = 300 KB | ~3 GB |
| wallets | 5 × 200 B = 1 KB | 10 MB |
| categories | 15 × 150 B = 2 KB | 20 MB |
| budgets | 20 × 150 B = 3 KB | 30 MB |
| **Tổng** | **~310 KB/user/năm** | **~3 GB** |

**Kết luận:** 10.000 user năm đầu cần khoảng 3 GB — nằm trong gói Supabase Pro (8 GB, 25 USD/tháng). Gói free 500 MB đủ cho ~1.500 user.

Đây là con số thật để đưa vào bảng tài chính, thay cho ước lượng "30–35% chi phí server".

---

## 14. Những điểm cần bạn quyết

| # | Vấn đề | Đề xuất của tôi | Phương án khác |
|:---:|:---:|:---:|:---:|
| 1 | Danh mục con (`parent_id`) | Giữ cột nhưng **không dùng ở MVP** | Bỏ hẳn, thêm sau bằng migration |
| 2 | Mục tiêu tiết kiệm có gắn với ví không | Không, `saved_amount` nhập tay | Gắn với ví loại `savings` |
| 3 | Giao dịch chuyển ví có tính vào tổng chi | Không | Có |
| 4 | `occurred_on` là generated column hay app tính | Generated column | App tính, linh hoạt hơn |
| 5 | Có lưu ảnh hóa đơn ở MVP | Không | Có, dùng Supabase Storage |

Riêng điểm 3: nếu tính chuyển ví vào tổng chi thì tổng chi bị thổi phồng mà không có ý nghĩa. Đề xuất chắc chắn: **không tính**.
