# infra/ — Hạ tầng

> Nhánh: `dev/infra`. Phát triển vùng này thì đứng ở nhánh đó — xem [docs/BRANCHING.md](../docs/BRANCHING.md).

| Thư mục | Chạy ở đâu | Ghi chú |
|---|---|---|
| `docker-compose.yml` (chưa tạo) | Máy dev | Postgres + Redis + API + worker |
| [migrations/](migrations/) | Mọi môi trường | 2 migration đã áp dụng ở **cả local và Supabase**: `20261117123000_enable_citext_extensions_schema.sql` (cài `citext` vào schema `extensions`) và `20261117122700_initial_student_finance.sql` (12 bảng, 25 index, 23 policy, RLS, 9 trigger). Khớp schema live và [docs/system-design/01-database-schema.md](../docs/system-design/01-database-schema.md). **Chưa áp lên Supabase:** `20261120020000_user_profile_username_avatar.sql` (username + ảnh đại diện) mới chỉ chạy ở Postgres local — xem [DB_CHANGE_REPORT.md](DB_CHANGE_REPORT.md) |

Không chứa mã nguồn nghiệp vụ. Chỉ định nghĩa môi trường chạy.
