# packages/shared-types

DTO dùng chung giữa `services/api`, `apps/flutter`, `apps/ios`.

Khi tạo:

```
packages/shared-types/
├── src/
│   ├── transaction.ts      # hoặc transaction.yaml → sinh
│   ├── wallet.ts
│   ├── budget.ts
│   ├── sync_change.ts
│   └── api-error.ts
└── openapi.yaml            # spec sinh, dùng cho Dart + Swift client
```

Mọi con số tiền: `integer`, đơn vị đồng. Định dạng chi tiết: [docs/system-design/02-api-contract.md](../../docs/system-design/02-api-contract.md).
