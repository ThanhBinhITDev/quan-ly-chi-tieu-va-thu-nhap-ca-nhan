# services/api — API NestJS

Chưa tạo project NestJS. Sẽ có ở tuần 1.

Lệnh khởi tạo (tham khảo):

```bash
npx @nestjs/cli new api --language ts
cd api
npm i @nestjs/bullmq @nestjs/config @nestjs/jwt
```

| Module (src/modules/) | Trách nhiệm |
|---|---|
| `auth/` | Đăng ký, đăng nhập, refresh — nối Supabase Auth |
| `wallets/` | CRUD ví (Q1: không lưu `balance`) |
| `categories/` | Danh mục, seed mặc định |
| `transactions/` | CRUD giao dịch (Q3: mọi tổng chi có `AND type = 'expense'`) |
| `budgets/` | Ngân sách + tiến độ |
| `reports/` | Tổng hợp tháng, xu hướng |
| `sync/` | `POST /v1/sync/push`, `GET /v1/sync/pull` — giải quyết xung đột theo rev |
| `ai/` | OCR, chat, quota |
| `devices/` | Đăng ký FCM/APNs token |

Hợp đồng endpoint: [docs/system-design/02-api-contract.md](../../docs/system-design/02-api-contract.md).
