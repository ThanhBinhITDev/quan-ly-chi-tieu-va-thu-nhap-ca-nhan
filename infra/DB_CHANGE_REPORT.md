# Database Change Report

Project: Student Finance - Ứng dụng Quản lý Chi tiêu và Thu nhập Cá nhân
Repository: `/Users/thanhbinh/Projects/quan-ly-chi-tieu-sinh-vien`
Required Supabase project ref: `ebbqcnnwqeasozmcqigu`

## Pre-apply handoff (recorded before any DDL)

- Date and time (Asia/Ho_Chi_Minh): 2026-11-17 14:18:27 +07
- Repository path and branch: `/Users/thanhbinh/Projects/quan-ly-chi-tieu-sinh-vien`, `main`, HEAD `5580d4f` (confirmed with `pwd` and `git rev-parse --show-toplevel`).
- Verified Supabase project ref: `ebbqcnnwqeasozmcqigu`.
- How the project ref was verified: `supabase_get_project_url` returned `https://ebbqcnnwqeasozmcqigu.supabase.co`; the ref in the MCP-bound API URL matches the required ref exactly. No project was selected by display name.
- Existing schema inspected (read-only SQL, 2026-11-17 14:18 +07):
  - `public` tables: 0. No tables from this project exist yet.
  - `public` indexes: 0. `public` functions: 0. `public` triggers: 0. `public` RLS policies: 0. `public` tables with RLS enabled: 0.
  - Recorded Supabase migrations: 0 (`supabase_list_migrations`).
  - Installed extensions: `pgcrypto` (schema `extensions`), `uuid-ossp` (`extensions`), `pg_stat_statements` (`extensions`), `supabase_vault` (`vault`), `plpgsql` (`pg_catalog`). `citext` is available but not installed.
  - `auth` schema is Supabase-managed with its standard tables; it is untouched by this change.
- Planned migration path: `infra/migrations/20261117122700_initial_student_finance.sql` (canonical source `docs/system-design/01-database-schema.md`).
- Operation classification: additive only. No `DROP`, `TRUNCATE`, `DELETE`, data rewrite, or migration file rewrite.
- Conflict check: no existing table, index, function, trigger, policy, or RLS setting overlaps; the full migration can be applied as-is. `citext` must be installed first into the `extensions` schema to follow Supabase extension placement.

## Latest attempt

- Status: APPLIED and verified by reading the live schema back.
- Execution window (Asia/Ho_Chi_Minh): 2026-11-17 14:18:27 +07 (handoff recorded) → 14:22:34 +07 (verification completed).
- Branch: `main` (HEAD `5580d4f`).
- Verified Supabase project ref: `ebbqcnnwqeasozmcqigu`.
- How the project ref was verified: `supabase_get_project_url` returned `https://ebbqcnnwqeasozmcqigu.supabase.co`; the ref embedded in the MCP-bound API URL matches the required ref exactly. No selection by display name; no other project was touched.
- Existing schema before execution: `public` had 0 tables, 0 indexes, 0 functions, 0 triggers, 0 policies, 0 RLS-enabled tables and 0 recorded migrations. Installed extensions were `pgcrypto`, `uuid-ossp`, `pg_stat_statements` (schema `extensions`), `supabase_vault` (`vault`) and `plpgsql`; `citext` was available but not installed.
- SQL executed (both via `supabase_apply_migration`, additive only):
  1. Migration name `20261117123000_enable_citext_extensions_schema`: `CREATE EXTENSION IF NOT EXISTS citext WITH SCHEMA extensions;` — prerequisite so `users.email CITEXT` resolves while keeping Supabase extension placement. No file for this step; it is additive.
  2. Migration name `20261117122700_initial_student_finance`: full contents of `infra/migrations/20261117122700_initial_student_finance.sql`, with no edits. Created extensions declarations, 12 tables, all indexes/constraints, 2 trigger functions + 9 triggers, RLS on all 12 tables, 23 policies, 2 SECURITY DEFINER group helper functions, and the column-level grant on `shared_shares.settled_at`.
- Result: both calls returned `{"success":true}`. Supabase recorded them with internal versions `20261117071940` and `20261117072038` respectively (the recorded version numbers differ from the migration-name prefixes; this is platform-assigned, not a schema drift).
- Post-change schema verification (read-only SQL on the same MCP connection):
  - Tables: exactly 12 — `users`, `wallets`, `categories`, `transactions`, `budgets`, `goals`, `groups`, `group_members`, `shared_expenses`, `shared_shares`, `recurring_rules`, `devices`.
  - Columns: `transactions.recurring_rule_id UUID`, `transactions.occurrence_date DATE`, `transactions.occurred_on DATE NOT NULL`, `transactions.updated_at TIMESTAMPTZ NOT NULL`; `recurring_rules.last_run_on DATE`; `shared_shares.share_amount BIGINT` and `settled_at TIMESTAMPTZ`; `users.email CITEXT` — all present.
  - Indexes: 25 total. Verified `uq_tx_recurring_occurrence` is `UNIQUE (recurring_rule_id, occurrence_date) WHERE recurring_rule_id IS NOT NULL`, plus `idx_tx_user_time`, `idx_tx_user_cat_time`, `idx_tx_wallet`, `idx_tx_sync`, `idx_recurring_due`, `idx_shared_expenses_group`, `idx_wallets_user`, `uq_cat_user_name`, `uq_budget_active`, `users_email_key`, `users_phone_key`, `groups_invite_code_key`.
  - Constraints: verified `fk_tx_recurring_rule`, `tx_recurring_pair`, `tx_transfer_needs_target`, `tx_transfer_distinct`, `transactions_amount_check`, `users_contact`, `users_plan_check`, `budgets_amount_check`, `shared_shares_share_amount_check` and all expected primary/unique/foreign keys.
  - Triggers: `trg_occurred_on` fires `BEFORE INSERT OR UPDATE OF occurred_at` with `set_occurred_on()` = `(occurred_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date`; eight `trg_updated_at_*` triggers fire `BEFORE UPDATE` with `set_updated_at()` setting `NEW.updated_at = now()`. Both function bodies were read back from `pg_get_functiondef`.
  - Recurring idempotency: the partial unique index and the pairing CHECK both exist; a duplicate insert for the same `(recurring_rule_id, occurrence_date)` cannot be stored.
  - Functions: `set_updated_at`, `set_occurred_on`, `is_group_member(uuid)` and `is_group_owner(uuid)` exist in `public`; the two group helpers are `SECURITY DEFINER`, executable by `authenticated` and not by `PUBLIC`.
  - RLS: enabled on all 12 tables; 23 policies present with the expected names and commands (including separate SELECT/INSERT/UPDATE/DELETE policies for the four Split Bill tables and `p_shares_settle`).
  - Extensions: `citext` and `pgcrypto` both installed in schema `extensions`.
  - Data: `users`, `wallets`, `transactions`, `groups` all have 0 rows; no data was inserted, deleted or modified by this work.
- Objects created or changed: see the post-change verification list. Nothing was dropped, truncated, rewritten or deleted.
- Errors: none. Both migrations succeeded on first attempt; no partial/failed step.
- Remaining work / caveats (no approval requested for these):
  - `anon` retains Supabase's default table/column grants on the new tables, including `shared_shares`. RLS blocks anon because every policy requires `auth.uid()`. Revoking anon grants was not done because it is outside the applied migration.
  - The six RLS behaviour tests described in `docs/system-design/01-database-schema.md` section 12.1 have not been executed against live users; they require test identities and were not run here.
  - Tables required by the 12 planned cron jobs (`notifications`, `ai_results`, monthly aggregate/cache) are still absent; tracked in `docs/TODO.md` item 8b.
  - The migration file itself remains untracked in Git; committing it is a separate decision.

## Repository synchronization with live schema

- Date and time (Asia/Ho_Chi_Minh): 2026-11-17 14:30:43 +07.
- Project ref re-verified: `ebbqcnnwqeasozmcqigu` via `supabase_get_project_url` → `https://ebbqcnnwqeasozmcqigu.supabase.co`.
- Live re-read before editing files: 12 tables, 25 indexes, 23 policies, RLS enabled on 12 tables, 4 functions in `public`, 9 distinct triggers. `citext` and `pgcrypto` both in schema `extensions`. `uq_tx_recurring_occurrence` and `tx_recurring_pair` present; `trg_occurred_on` uses `(occurred_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date`; eight `trg_updated_at_*` triggers present.
- Comparison with the previous report: no discrepancy. No stopping condition was triggered, so no schema correction was needed.
- Files changed in the repository (documentation/snapshot only — no SQL was executed):
  - `infra/migrations/20261117123000_enable_citext_extensions_schema.sql` — added; exact SQL of the prerequisite migration already applied earlier.
  - `infra/migrations/20261117122700_initial_student_finance.sql` — header now records the applied migration and the prerequisite; `CREATE EXTENSION IF NOT EXISTS citext WITH SCHEMA extensions;` now matches the live extension placement.
  - `infra/README.md` — lists both applied migration files and their contents.
  - `infra/DB_CHANGE_REPORT.md` — this synchronization record.
- Index accounting in the repo snapshot matches the live count of 25: 10 explicit `CREATE [UNIQUE] INDEX` statements plus 15 implicit indexes (12 primary keys, `users_email_key`, `users_phone_key`, `groups_invite_code_key`).
- No duplicate migration was created and no applied migration was re-run. The two files correspond 1:1 to the two migrations already recorded by Supabase (internal versions `20261117071940` and `20261117072038`).
- Remaining TODOs: revoke `anon` default grants if required by policy; run the six RLS behaviour tests with real test users; add the tables needed by the 12 cron jobs (`notifications`, `ai_results`, monthly aggregate/cache — see `docs/TODO.md` item 8b); commit the migration files (not done in this task).

## Handoff notes

Keep this report factual. Distinguish clearly between a migration file being written and SQL actually being applied to Supabase. Never include credentials or access tokens.

## 2026-11-19 — Dựng Postgres local để dev

**Không chạy SQL nào lên Supabase.** Project `ebbqcnnwqeasozmcqigu` trong
suốt phiên này chỉ được đọc metadata (service versions), không có DDL/DML.

### Đã làm trên máy

- Cài `postgresql@17` 17.12.0 (Homebrew, keg-only), cluster mặc định
  `/opt/homebrew/var/postgresql@17`.
- Tạo database `student_finance`.
- Chạy `infra/local/00-bootstrap.sql` — tạo schema `extensions`, schema
  `auth`, role `authenticated`, hàm stub `auth.uid()` / `auth.jwt()`, đặt
  `search_path` của database.
- Áp hai migration hiện có lên database mới.

### Vì sao cần bootstrap

Migration `20261117122700` phụ thuộc `auth.uid()` (21 lần),
`GRANT ... TO authenticated` (2), `CREATE EXTENSION citext WITH SCHEMA
extensions` (1). Đó đều là hạ tầng Supabase dựng sẵn. Trên Postgres thuần
phải tạo trước, nếu không migration dừng tại `CREATE POLICY` đầu tiên.

**Hai file migration trong `infra/migrations/` không bị sửa một byte nào.**
Bootstrap chỉ bù hạ tầng, nhờ vậy migration vẫn là nguồn sự thật duy nhất
cho cả local và Supabase.

### Kết quả

Local: 12 bảng, 23 policy, 9 trigger, extension `citext` + `pgcrypto` —
khớp schema đã áp trên Supabase. `select version()` trả PostgreSQL 17.12,
trùng bản Supabase đang chạy (17.12.0.000).

### Khác biệt so với Supabase

- RLS ở local **không có hiệu lực** vì API kết nối bằng role owner; policy
  chỉ là code chết. Trên Supabase, RLS có hiệu lực khi truy cập qua
  PostgREST hoặc client Supabase JS.
- Không có `storage`, `net`, `vault`, `realtime`. Migration hiện tại không
  dùng các schema này nên không ảnh hưởng.
- Không có GoTrue phát JWT; API dev tự xác thực bằng `SUPABASE_JWT_SECRET`
  (HS256). Cờ `AUTH_ALLOW_UNVERIFIED` đã bị xoá khỏi code vì từng cho phép
  token ký bằng secret bất kỳ đi qua.

## 2026-11-20 — Hồ sơ người dùng: username + ảnh đại diện (chỉ local)

**Không chạy SQL nào lên Supabase.** Project `ebbqcnnwqeasozmcqigu` trong
suốt phiên này không được kết nối, chỉ đọc lại ghi chú cũ trong file này.

### Đã làm

- Thêm `infra/migrations/20261120020000_user_profile_username_avatar.sql`
  và áp lên database local `student_finance` (PostgreSQL 17.12).
- Thay đổi: 4 cột mới trên `users` (`username citext`, `avatar_mime text`,
  `avatar_data bytea`, `avatar_updated_at timestamptz`), 4 CHECK
  (`users_username_format`, `users_avatar_size`, `users_avatar_mime`,
  `users_avatar_pair`) và 1 unique index bộ phận `users_username_active_key`.
- Kiểm chứng lại bằng `\d users`: cột, index và cả 4 CHECK đều có mặt; dữ
  liệu cũ không bị sửa (`username` để NULL).

### Operation classification

Additive only. Không `DROP`, `TRUNCATE`, `DELETE`, không rewrite migration
đã áp, không đụng project Supabase nào.

### Vì sao chưa áp lên Supabase

Đây là thay đổi phục vụ màn hình hồ sơ trên nhánh `dev/android`, chưa có
yêu cầu phát hành. Áp lên Supabase là thao tác riêng, cần duyệt tường minh;
file migration đã sẵn sàng để áp khi được duyệt.

### Việc còn lại khi áp lên Supabase

1. Xác minh lại project ref `ebbqcnnwqeasozmcqigu` bằng URL trả về từ MCP
   trước khi chạy bất kỳ DDL nào.
2. Đọc schema live để chắc 4 cột/index/CHECK chưa tồn tại (migration đã có
   `IF NOT EXISTS` / `DROP CONSTRAINT IF EXISTS` nên chạy lại an toàn, nhưng
   vẫn phải kiểm trước theo quy tắc).
3. Áp migration, rồi đọc lại `information_schema` + `pg_constraint` để đối
   chiếu với local.
4. Cập nhật mục này từ "chỉ local" thành "đã áp" kèm thời điểm.

---

## 2026-11-20 — Bảng `notifications`

### Đã làm (local)

- Thêm `infra/migrations/20261120030000_notifications.sql` và áp lên
  database local `student_finance` (PostgreSQL 17.12), lúc 04:23 +07.
- Tạo bảng `notifications` (8 cột) phục vụ hai việc: hộp thư trong app cho
  icon chuông, và khoá chống gửi trùng cho các job đẩy tin.
- Chỉ mục: `uq_notifications_dedupe` UNIQUE bộ phận trên
  `(user_id, dedupe_key) WHERE dedupe_key IS NOT NULL`;
  `idx_notifications_user_time` trên `(user_id, created_at DESC)`;
  `idx_notifications_unread` trên `(user_id) WHERE read_at IS NULL`.
- RLS bật, 2 policy: `p_notifications_read` (SELECT) và
  `p_notifications_mark_read` (UPDATE), cả hai giới hạn `user_id = auth.uid()`.
  Cố ý **không** có policy INSERT: thông báo do job phía server sinh ra, cho
  client ghi là mở đường tự tạo tin giả.
- Kiểm chứng bằng `\d notifications`: 8 cột, 3 chỉ mục, 2 policy, 1 CHECK
  `type` và khoá ngoại `user_id → users` đều có mặt.

### Kiểm chứng khoá chống trùng

Chèn lại cùng `dedupe_key` cho cùng người dùng bị Postgres chặn đúng như
thiết kế:

```
ERROR: duplicate key value violates unique constraint "uq_notifications_dedupe"
DETAIL: Key (user_id, dedupe_key)=(5555..., budget:2026-11:total:90) already exists.
```

### Operation classification

Additive only. Bảng mới, không sửa cột/bảng cũ, không `DROP`, không
`TRUNCATE`, không rewrite migration đã áp.

### Vì sao chưa áp lên Supabase

Chưa có yêu cầu phát hành. Áp lên Supabase `ebbqcnnwqeasozmcqigu` là thao
tác riêng cần duyệt tường minh; file đã sẵn sàng.

Chặn kỹ thuật ghi nhận ngày 2026-11-20 04:49 +07: MCP `supabase`
(`project_ref=ebbqcnnwqeasozmcqigu`, transport streamable-http) có trong
`mcp.servers` và `openclaw mcp doctor` báo `ok`, nhưng phiên này **không**
thấy bộ công cụ Supabase; `openclaw mcp probe` và `openclaw mcp login` bị
từ chối với lý do "requires exclusive offline state ownership" trong khi
Gateway đang chạy. `~/.openclaw/credentials` cũng không có token OAuth nào
cho MCP này, nên lần chạy trước chắc chắn dùng một kênh khác. Muốn áp: cấp
lại kênh Supabase MCP (đăng nhập OAuth hoặc thêm access token) rồi làm 4
bước dưới.

### Việc còn lại khi áp lên Supabase

1. Xác minh project ref `ebbqcnnwqeasozmcqigu` bằng URL trả về từ MCP.
2. Đọc schema live xác nhận `public.notifications` chưa tồn tại.
3. Áp migration, rồi đọc lại `information_schema.columns`,
   `pg_indexes` và `pg_policies` để đối chiếu với local.
4. Cập nhật mục này thành "đã áp" kèm thời điểm.
