# infra/ — Hạ tầng

| Thư mục | Chạy ở đâu | Ghi chú |
|---|---|---|
| `docker-compose.yml` (chưa tạo) | Máy dev | Postgres + Redis + API + worker |
| [migrations/](migrations/) | Mọi môi trường | 2 migration đã áp dụng: `20261117123000_enable_citext_extensions_schema.sql` (cài `citext` vào schema `extensions`) và `20261117122700_initial_student_finance.sql` (12 bảng, 25 index, 23 policy, RLS, 9 trigger). Khớp schema live và [docs/system-design/01-database-schema.md](../docs/system-design/01-database-schema.md) |

Không chứa mã nguồn nghiệp vụ. Chỉ định nghĩa môi trường chạy.
