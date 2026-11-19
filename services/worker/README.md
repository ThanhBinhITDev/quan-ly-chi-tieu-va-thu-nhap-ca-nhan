# services/worker — Worker NestJS (cron + queue)

> Nhánh: `dev/worker`. Phát triển vùng này thì đứng ở nhánh đó — xem [../../docs/BRANCHING.md](../../docs/BRANCHING.md).

Chưa tạo project. Sẽ có ở tuần 1, cùng API.

| Việc | Công cụ |
|---|---|
| Cron 12 job | BullMQ Repeatable + Redis |
| Hàng đợi đồng bộ | BullMQ, backoff ×5, dead-letter |
| Múi giờ | `TZ=Asia/Ho_Chi_Minh` |

**Bắt buộc:** mọi job phải chạy lại được, có khoá idempotent. Chi tiết từng job: [docs/system-design/07-cron-jobs.md](../../docs/system-design/07-cron-jobs.md).

Không chứa controller HTTP — chỉ nhận việc từ BullMQ.
