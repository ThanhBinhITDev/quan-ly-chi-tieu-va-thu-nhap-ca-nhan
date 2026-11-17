# 01 — Thiết kế cơ sở dữ liệu

**Phiên bản:** 1.2 · **Ngày:** 2026-11-17 · **Trạng thái:** đã chốt Q1, Q3, Q8, Q9; các điểm khác chờ duyệt

Mục tiêu: đủ cho MVP, mở rộng được sang AI và đồng bộ đa thiết bị mà không phải migrate lại.

---

## 1. Quy ước chung

| Quy ước | Giá trị | Lý do |
|---|---|---|
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
  ├──< goals              (mục tiêu tiết kiệm, nhập tay, không gắn ví)
  ├──< recurring_rules    (giao dịch định kỳ)
  ├──< devices            (thiết bị đăng nhập, push token)
  │
  └──< group_members >── groups
  └──< shared_expenses >── groups
  └──< shared_shares >── shared_expenses
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
- `ai_quota_used` là JSONB dạng `{"2026-11": {"ocr": 3, "chat": 1}}` — hạn mức được đọc theo key tháng hiện tại (không cần reset số), job `ai-quota-reset` chỉ dọn key tháng cũ.
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
|---|---|
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

  -- Dùng cho giao dịch sinh từ recurring_rules (khoá chống trùng)
  recurring_rule_id UUID,
  occurrence_date   DATE,

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

**Đã chốt:** `occurred_on` do Postgres tạo bằng trigger `trg_occurred_on` (`occurred_at` đổi sang `Asia/Ho_Chi_Minh` rồi lấy phần ngày) — xem [07](07-cron-jobs.md) mục 3.2 và migration khởi tạo. Client chỉ gửi `occurred_at`. Không dùng generated column vì biểu thức đổi múi giờ không đạt tính IMMUTABLE mà Postgres yêu cầu.

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

Mục tiêu tiết kiệm (Q8, 2026-11-17). Giai đoạn đầu chỉ nhập tay: người dùng tự khai số đã tiết kiệm. **Không khoá ngoại tới `wallets`**, nên số này không đổi theo giao dịch thật.

```sql
CREATE TABLE goals (
  id             UUID PRIMARY KEY,
  user_id        UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name           TEXT NOT NULL,               -- "Mua laptop"
  target_amount  BIGINT NOT NULL CHECK (target_amount > 0),
  saved_amount   BIGINT NOT NULL DEFAULT 0 CHECK (saved_amount >= 0),
  deadline       DATE,
  icon           TEXT,
  is_completed   BOOLEAN NOT NULL DEFAULT false,
  rev            INT NOT NULL DEFAULT 1,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at     TIMESTAMPTZ
);
```

**Quy tắc:**
- `saved_amount` là số người dùng tự nhập, khác với số dư ví (Q1 không áp dụng ở đây vì không có nguồn giao dịch để tính).
- Khi `saved_amount >= target_amount`, đặt `is_completed = true`. Đây là quy tắc ở tầng ứng dụng, không ràng buộc DB.
- Giai đoạn sau có thể thêm ví loại `savings` và liên kết; khi đó sẽ có quyết định mới, không sửa bảng này âm thầm.

---

## 9. Bảng chia tiền nhóm (Split Bill)

Bốn bảng, thêm ngày 2026-11-17. Đây là **nhóm dữ liệu đầu tiên có nhiều người dùng cùng đọc**, khác toàn bộ phần còn lại (mỗi người chỉ thấy dữ liệu của mình). RLS phải viết riêng, không dùng mẫu `user_id = auth.uid()`.

### 9.1. `groups` — nhóm

```sql
CREATE TABLE groups (
  id           UUID PRIMARY KEY,
  name         TEXT NOT NULL,                -- "Nhóm trọ 4 người"
  owner_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  invite_code  TEXT NOT NULL UNIQUE,         -- 8 ký tự, để mời vào nhóm
  rev          INT NOT NULL DEFAULT 1,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at   TIMESTAMPTZ
);
```

`invite_code` sinh ngẫu nhiên, không đoán được. Mời bằng mã, không mời bằng email — tránh lộ danh bạ.

### 9.2. `group_members` — thành viên

```sql
CREATE TABLE group_members (
  group_id   UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role       TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('owner','member')),
  joined_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  left_at    TIMESTAMPTZ,
  PRIMARY KEY (group_id, user_id)
);
```

Rời nhóm là đặt `left_at`, **không xoá dòng** — nếu xoá thì lịch sử chi tiêu mất người, không tính lại được ai nợ ai.

### 9.3. `shared_expenses` — khoản chi chung

```sql
CREATE TABLE shared_expenses (
  id           UUID PRIMARY KEY,
  group_id     UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  payer_id     UUID NOT NULL REFERENCES users(id),   -- ai trả tiền
  amount       BIGINT NOT NULL CHECK (amount > 0),
  note         TEXT,                                  -- "Tiền điện tháng 11"
  occurred_on  DATE NOT NULL,
  split_method TEXT NOT NULL DEFAULT 'equal'
               CHECK (split_method IN ('equal','exact')),
  rev          INT NOT NULL DEFAULT 1,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at   TIMESTAMPTZ
);

CREATE INDEX idx_shared_expenses_group ON shared_expenses(group_id, occurred_on DESC)
  WHERE deleted_at IS NULL;
```

### 9.4. `shared_shares` — phần của từng người

```sql
CREATE TABLE shared_shares (
  expense_id   UUID NOT NULL REFERENCES shared_expenses(id) ON DELETE CASCADE,
  user_id      UUID NOT NULL REFERENCES users(id),
  share_amount BIGINT NOT NULL CHECK (share_amount >= 0),
  settled_at   TIMESTAMPTZ,        -- NULL = chưa thanh toán
  PRIMARY KEY (expense_id, user_id)
);
```

**Ràng buộc quan trọng, phải có test:** tổng `share_amount` của một `expense_id` **phải bằng** `shared_expenses.amount`. Kiểm tra ở tầng service trong một transaction, không dùng CHECK constraint vì cần đọc bảng khác.

### 9.5. Quan hệ với sổ cá nhân — điểm dễ sai nhất

**Không ghi toàn bộ số tiền vào sổ cá nhân của người trả.** Ví dụ: trả 400.000đ tiền điện cho 4 người, phần của mình là 100.000đ.

| Cách làm | Kết quả | Đúng? |
|---|---|---|
| Ghi 400.000đ vào chi tiêu cá nhân | Ngân sách tháng bị thổi 300.000đ, không phải tiền mình tiêu | **Sai** |
| Ghi 100.000đ vào chi tiêu cá nhân | Đúng số tiền mình thực sự tiêu | **Đúng** |
| Ghi 400.000đ chi + 300.000đ thu | Rối, phải tạo giao dịch giả | **Sai** |

**Quy tắc:** khi tạo khoản chi chung, hệ thống sinh **một giao dịch cá nhân** cho mỗi thành viên, số tiền = `share_amount` của người đó. Giao dịch đó có `note` gắn tên nhóm, `category_id` do người dùng chọn (hoặc để trống).

Hệ quả:
- Người trả: chi 100.000đ (phần mình), và có 300.000đ **phải thu** — khoản phải thu chỉ nằm trong Split Bill, **không** vào sổ cá nhân.
- Người nhận: chi 100.000đ, và có 100.000đ **phải trả**.

**Vì sao không đưa khoản phải thu/phải trả vào sổ cá nhân:** nó không phải chi tiêu. Đưa vào thì chỉ số "hôm nay được tiêu" bị sai, vì số dư bị đội lên bởi tiền chưa thực thu.

---

## 10. Bảng `recurring_rules`

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

**Ai sinh giao dịch:** job `recurring-generate` trên Worker (00:05, múi giờ VN) — xem [07](07-cron-jobs.md) mục 2.1. Mỗi kỳ sinh được khoá bằng `UNIQUE (recurring_rule_id, occurrence_date)` trên `transactions`, nên chạy lại job không tạo trùng. Client chỉ đọc kết quả qua đồng bộ.

---

## 11. Bảng `devices`

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

## 12. Row Level Security (Supabase)

Bắt buộc bật cho mọi bảng, nếu không dữ liệu tài chính của người này đọc được bởi người khác.

```sql
ALTER TABLE wallets      ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE budgets      ENABLE ROW LEVEL SECURITY;
ALTER TABLE recurring_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE goals       ENABLE ROW LEVEL SECURITY;

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

### 12.1. Bốn bảng chia tiền — policy khác hẳn

Đây là chỗ dễ hở dữ liệu nhất. Bốn bảng này **không** có cột `user_id` để so trực tiếp, mà phải kiểm qua thành viên nhóm. Viết sai một policy là người ngoài nhóm đọc được chi tiêu của người khác.

```sql
ALTER TABLE groups           ENABLE ROW LEVEL SECURITY;
ALTER TABLE group_members    ENABLE ROW LEVEL SECURITY;
ALTER TABLE shared_expenses  ENABLE ROW LEVEL SECURITY;
ALTER TABLE shared_shares    ENABLE ROW LEVEL SECURITY;

-- Hàm kiểm thành viên, tránh lặp ở mọi policy
CREATE OR REPLACE FUNCTION is_group_member(g UUID)
RETURNS BOOLEAN LANGUAGE sql SECURITY DEFINER STABLE AS $$
  SELECT EXISTS (
    SELECT 1 FROM group_members
    WHERE group_id = g AND user_id = auth.uid() AND left_at IS NULL
  );
$$;

-- Xem nhóm: chỉ nhóm mình là thành viên
CREATE POLICY p_groups_read ON groups
  FOR SELECT USING (is_group_member(id) OR owner_id = auth.uid());

-- Chỉ chủ nhóm mới sửa/xoá nhóm
CREATE POLICY p_groups_write ON groups
  FOR UPDATE USING (owner_id = auth.uid()) WITH CHECK (owner_id = auth.uid());

CREATE POLICY p_groups_delete ON groups
  FOR DELETE USING (owner_id = auth.uid());

-- Hàm phụ: kiểm chủ nhóm
CREATE OR REPLACE FUNCTION is_group_owner(g UUID)
RETURNS BOOLEAN LANGUAGE sql SECURITY DEFINER STABLE AS $$
  SELECT EXISTS (SELECT 1 FROM groups WHERE id = g AND owner_id = auth.uid());
$$;

-- Thành viên: xem được thành viên cùng nhóm
CREATE POLICY p_members_read ON group_members
  FOR SELECT USING (is_group_member(group_id));

-- Chỉ chủ nhóm được thêm người trực tiếp.
-- Tự vào nhóm bằng mã mời KHÔNG đi qua policy này: API kiểm invite_code
-- rồi ghi bằng service role. RLS không biết mã mời, nên nếu cho user tự
-- INSERT thì ai biết group_id cũng vào được nhóm.
CREATE POLICY p_members_insert ON group_members
  FOR INSERT WITH CHECK (is_group_owner(group_id));

-- Khoản chi chung: thành viên được XEM
CREATE POLICY p_expenses_read ON shared_expenses
  FOR SELECT USING (is_group_member(group_id));

-- Thành viên được THÊM, nhưng phải ghi đúng mình là người trả
CREATE POLICY p_expenses_insert ON shared_expenses
  FOR INSERT WITH CHECK (is_group_member(group_id) AND payer_id = auth.uid());

-- Chỉ người trả hoặc chủ nhóm được SỬA/XOÁ
CREATE POLICY p_expenses_write ON shared_expenses
  FOR UPDATE USING (is_group_member(group_id)
                    AND (payer_id = auth.uid() OR is_group_owner(group_id)))
  WITH CHECK (is_group_member(group_id));

CREATE POLICY p_expenses_delete ON shared_expenses
  FOR DELETE USING (is_group_member(group_id)
                    AND (payer_id = auth.uid() OR is_group_owner(group_id)));

-- Phần chia: xem được nếu là thành viên nhóm chứa khoản chi
CREATE POLICY p_shares_read ON shared_shares
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM shared_expenses e
            WHERE e.id = expense_id AND is_group_member(e.group_id))
  );

-- Chỉ người trả khoản chi đó mới được ghi phần chia
CREATE POLICY p_shares_write ON shared_shares
  FOR ALL USING (
    EXISTS (SELECT 1 FROM shared_expenses e
            WHERE e.id = expense_id AND e.payer_id = auth.uid())
  ) WITH CHECK (
    EXISTS (SELECT 1 FROM shared_expenses e
            WHERE e.id = expense_id AND e.payer_id = auth.uid())
  );

-- Đánh dấu đã trả: mỗi người chỉ sửa được dòng của chính mình
CREATE POLICY p_shares_settle ON shared_shares
  FOR UPDATE USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
```

**Sáu điều phải test bằng SQL thật, không chỉ đọc mã:**

1. Người ngoài nhóm gọi `GET /v1/groups/{id}` → 403, không trả dữ liệu.
2. Người đã rời nhóm (`left_at` khác NULL) → không đọc được khoản chi mới, nhưng **vẫn đọc được khoản cũ của mình** (cần cho việc đối chiếu nợ).
3. Người ngoài nhóm không chèn được `shared_shares` cho khoản chi của nhóm khác.
4. Thành viên thường **không** thêm được người khác vào nhóm (chỉ chủ nhóm).
5. Thành viên thường **không** sửa/xoá được khoản chi của người khác (chỉ người trả hoặc chủ nhóm).
6. Người trả khoản chi **không** ghi được `payer_id` là người khác (chống giả mạo người trả).

**RLS giới hạn dòng, không giới hạn cột.** Policy `p_shares_settle` cho người dùng sửa dòng của mình — nhưng nếu không chặn cột, họ sửa luôn `share_amount` để giảm nợ. Phải chặn bằng một trong hai cách:

```sql
-- Cách 1: chỉ cho ghi cột settled_at
REVOKE UPDATE ON shared_shares FROM authenticated;
GRANT UPDATE (settled_at) ON shared_shares TO authenticated;

-- Cách 2: trigger từ chối khi share_amount đổi mà không phải người trả
CREATE OR REPLACE FUNCTION guard_share_amount() RETURNS TRIGGER AS $$
BEGIN
  IF NEW.share_amount <> OLD.share_amount
     AND NOT EXISTS (SELECT 1 FROM shared_expenses e
                     WHERE e.id = OLD.expense_id AND e.payer_id = auth.uid())
  THEN RAISE EXCEPTION 'không được đổi số tiền chia';
  END IF;
  RETURN NEW;
END; $$ LANGUAGE plpgsql;

CREATE TRIGGER trg_guard_share_amount
  BEFORE UPDATE ON shared_shares
  FOR EACH ROW EXECUTE FUNCTION guard_share_amount();
```

Chọn cách 1 nếu chỉ cần đánh dấu đã trả; chọn cách 2 nếu sau này cho sửa số tiền chia.

**Vì sao hàm `SECURITY DEFINER`:** nếu viết truy vấn con trực tiếp trong policy của `group_members`, Postgres sẽ đệ quy vô hạn (policy của `group_members` lại gọi `group_members`). Hàm `SECURITY DEFINER` cắt vòng đệ quy đó. Đây là lỗi kinh điển khi làm RLS cho bảng thành viên.

---

## 13. Câu truy vấn then chốt

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

## 14. Dung lượng ước tính

| Bảng | 1 user/năm | 10.000 user/năm |
|---|---|---|
| transactions | ~1.200 dòng × 250 B = 300 KB | ~3 GB |
| wallets | 5 × 200 B = 1 KB | 10 MB |
| categories | 15 × 150 B = 2 KB | 20 MB |
| budgets | 20 × 150 B = 3 KB | 30 MB |
| **Tổng** | **~310 KB/user/năm** | **~3 GB** |

**Kết luận:** 10.000 user năm đầu cần khoảng 3 GB — nằm trong gói Supabase Pro (8 GB, 25 USD/tháng). Gói free 500 MB đủ cho ~1.500 user.

Đây là con số thật để đưa vào bảng tài chính, thay cho ước lượng "30–35% chi phí server".

---

## 15. Những điểm cần bạn quyết

| # | Vấn đề | Đề xuất của tôi | Phương án khác | Trạng thái |
|---|---|---|---|---|
| 1 | Danh mục con (`parent_id`) | Giữ cột nhưng **không dùng ở MVP** | Bỏ hẳn, thêm sau bằng migration | Chờ quyết |
| 2 | Giao dịch chuyển ví có tính vào tổng chi | Không | Có | **Đã chốt (Q3)** |
| 4 | `occurred_on` do ai tạo | Trigger Postgres (`trg_occurred_on`) | Generated column / app tính | **Đã chốt:** trigger |
| 5 | Có lưu ảnh hóa đơn ở MVP | Không; cột `receipt_url` đã có sẵn | Có, dùng Supabase Storage | **Đã chốt:** không ở MVP |

Riêng điểm 2: nếu tính chuyển ví vào tổng chi thì tổng chi bị thổi phồng mà không có ý nghĩa. Đề xuất chắc chắn: **không tính**.

---

## 16. Quyết định đã chốt

Hai quyết định dưới đây được duyệt ngày 2026-11-13 và **không bàn lại** trừ khi có lý do kỹ thuật mới.

| # | Quyết định | Nội dung | Hệ quả lên thiết kế |
|---|---|---|---|
| Q1 | **Không lưu `balance` trong `wallets`** | Số dư luôn tính từ `initial_balance` + tổng giao dịch | Chỉ một nguồn sự thật là bảng `transactions`. Không có cột `balance`, không có trigger cập nhật, không có nguy cơ lệch |
| Q3 | **Chuyển ví không tính vào tổng chi** | `type = 'transfer'` chỉ đổi số dư hai ví | Mọi truy vấn tổng chi phải có `AND type = 'expense'`. Biểu đồ tròn và chỉ số hôm nay bỏ qua `transfer` |
| Q8 | **Mục tiêu tiết kiệm trở lại, nhập tay** | `goals.saved_amount` là số người dùng tự khai; không khoá ngoại tới `wallets` | Bảng `goals` ở mục 8. Đảo Q7 ngày 2026-11-16 |
| Q9 | **Chia tiền nhóm vào MVP** | 4 bảng mới; RLS theo thành viên nhóm, không theo `user_id` | Bảng ở mục 9. Người trả chỉ ghi phần của mình vào sổ cá nhân |

### Điều cần kiểm tra khi viết mã

Q3 dễ bị vi phạm nhất vì chỉ thiếu một điều kiện `WHERE` là số liệu sai ngay:

```sql
-- SAI: quên lọc type, transfer bị tính vào chi
SELECT SUM(amount) FROM transactions
WHERE user_id = :uid AND occurred_on BETWEEN :a AND :b AND deleted_at IS NULL;

-- ĐÚNG
SELECT SUM(amount) FROM transactions
WHERE user_id = :uid AND type = 'expense'
  AND occurred_on BETWEEN :a AND :b AND deleted_at IS NULL;
```

Phải có test khẳng định: tạo 1 giao dịch `expense` 100.000đ + 1 `transfer` 200.000đ → tổng chi = 100.000đ, không phải 300.000đ.
