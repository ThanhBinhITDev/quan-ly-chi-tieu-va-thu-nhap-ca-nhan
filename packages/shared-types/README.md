# packages/shared-types

`openapi.yaml` là nguồn sự thật duy nhất về hình dạng dữ liệu giữa ba client và backend.

```
packages/shared-types/
├── openapi.yaml          # đặc tả OpenAPI 3.1 (chưa tạo)
└── README.md
```

## Sinh client

| Đích | Lệnh | Ra |
|---|---|---|
| Dart (Android) | `openapi-generator-cli generate -i openapi.yaml -g dart-dio -o ../../apps/android/lib/data/remote` | Thư mục client Dart |
| Swift (iOS) | `openapi-generator-cli generate -i openapi.yaml -g swift5 -o ../../apps/ios/Generated` | File Swift |
| TypeScript (Web) | `openapi-typescript openapi.yaml -o ../../apps/web/src/types/api.d.ts` | File khai báo type |

**Quy tắc:** không sửa tay file đã sinh. Sửa `openapi.yaml` rồi sinh lại. CI kiểm tra file sinh khớp với spec.

## Quy ước dữ liệu

| Loại | Kiểu | Ghi chú |
|---|---|---|
| Tiền | `integer`, đơn vị đồng | Luôn dương; chi/thu phân biệt bằng `type` |
| Thời gian | ISO 8601 UTC chuỗi | `2026-11-16T05:30:00Z` |
| Ngày | `YYYY-MM-DD` chuỗi | Theo giờ Việt Nam |
| ID | UUID v4 chuỗi | Sinh trên máy, không chờ server |
| Sai | `{ code, message }` | `code` ổn định để app xử lý |

Chi tiết endpoint: [docs/system-design/02-api-contract.md](../../docs/system-design/02-api-contract.md).
