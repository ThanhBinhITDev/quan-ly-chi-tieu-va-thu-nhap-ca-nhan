# services/ — Backend NestJS

| Thư mục | Chạy | Chứa |
|---|---|---|
| [api/](api/) | HTTP, stateless | Controller + service, 9 module |
| [worker/](worker/) | Luôn chạy, không HTTP | 12 job BullMQ + hàng đợi đồng bộ |

Chi tiết kiến trúc: [docs/system-design/00-architecture.md](../docs/system-design/00-architecture.md), job định kỳ: [docs/system-design/07-cron-jobs.md](../docs/system-design/07-cron-jobs.md).
