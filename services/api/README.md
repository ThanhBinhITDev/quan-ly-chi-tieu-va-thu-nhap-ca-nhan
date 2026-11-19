# services/api — API NestJS

Đã dựng project NestJS (ESM, TypeScript, vitest). Chạy local:

```bash
cp .env.example .env    # điền DATABASE_URL và SUPABASE_URL
npm install
npm run start:dev       # http://localhost:3000
npm test                # unit test
npm run test:e2e        # e2e test
npm run build           # build production
```

Biến môi trường bắt buộc: `DATABASE_URL`, `SUPABASE_URL`. Xem `.env.example`.

## Trạng thái module

| Module (src/modules/) | Trách nhiệm | Trạng thái |
|---|---|---|
| `auth/` | Hồ sơ người dùng (`GET/PATCH /v1/me`) | Đã có. Đăng ký/đăng nhập dùng thẳng Supabase Auth, API chỉ xác thực JWT |
| `wallets/` | CRUD ví (Q1: không lưu `balance`) | Đã có: GET, POST, PATCH |
| `categories/` | Danh mục hệ thống + riêng, seed mặc định | Đã có: GET, POST, PATCH |
| `transactions/` | CRUD giao dịch (Q3: mọi tổng chi có `AND type = 'expense'`) | Đã có: GET (cursor), POST, PATCH (kể cả xoá mềm) |
| `budgets/` | Ngân sách + tiến độ | Đã có: GET, POST, PATCH, GET `/progress` |
| `reports/` | Tổng hợp tháng, xu hướng | Đã có: GET `/month-summary` |
| `devices/` | Đăng ký FCM/APNs token | Đã có: GET, POST (idempotent theo id) |
| `goals/` | Mục tiêu tiết kiệm nhập tay (Q8) | Đã có: GET, POST, PATCH, DELETE (mềm, 204) |
| `groups/` | Chia tiền nhóm — nhóm, thành viên, chi phí, phần chia (Q9) | Đã có: GET, POST, POST `/join`, GET `/:id/balances`, POST `/:id/expenses`, POST `/:id/settle` |
| `sync/` | `POST /v1/sync/push`, `GET /v1/sync/pull` — giải quyết xung đột theo rev | Đã có |
| `ai/` | OCR, chat, quota | Chưa viết — hợp đồng xếp giai đoạn 2 |

## Tầng hạ tầng

| Đường dẫn | Nội dung |
|---|---|
| `src/common/db/` | `Database` interface + `PostgresDatabase` dùng `pg`, có `transaction()` |
| `src/common/auth/` | Xác thực JWT Supabase qua JWKS (`jose`), `AuthGuard` |
| `src/common/errors/` | `ApiError` + filter chuẩn hoá `{ error: { code, message } }` |
| `src/common/http/` | `GET /health` kiểm tra API và database |

## Kiểm chứng

- `npx tsc --noEmit`: sạch
- `npm test`: 51 test, 4 file
- `npm run test:e2e`: 8 test
- `npm run build`: sạch
- 31 route đã map; mọi route nghiệp vụ trả 401 khi thiếu token

`user_id` luôn lấy từ `sub` trong token, không nhận từ client.

## Quy ước bắt buộc

- Mọi tổng chi có `AND type = 'expense'`.
- Công thức `daily_limit` nằm ở `src/modules/reports/report-calculator.ts`; phải khớp bản Dart của app.
- Tạo/sửa theo `rev`: sai `rev` trả `SYNC_CONFLICT` kèm `server_data`.
- Không xoá cứng; `delete` là set `deleted_at`.

Hợp đồng endpoint: [docs/system-design/02-api-contract.md](../../docs/system-design/02-api-contract.md).
