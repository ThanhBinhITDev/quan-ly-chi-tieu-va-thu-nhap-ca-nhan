# infra/ — Hạ tầng

| Thư mục | Chạy ở đâu | Ghi chú |
|---|---|---|
| [docker-compose.yml](docker-compose.yml) (sẽ có) | Máy dev | Postgres + Redis + API + worker |
| [migrations/](migrations/) | Mọi môi trường | Migration SQL cho 7 bảng, khớp [docs/system-design/01-database-schema.md](../docs/system-design/01-database-schema.md) |

Không chứa mã nguồn nghiệp vụ. Chỉ định nghĩa môi trường chạy.
