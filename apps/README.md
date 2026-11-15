# apps/ — Ba nền tảng, ba thư mục

| Thư mục | Nền tảng | Công nghệ | Mã dùng chung |
|---|---|---|---|
| [ios/](ios/) | iOS | **SwiftUI native** (SwiftData, Swift Charts) | Không share mã với Dart |
| [android/](android/) | Android | Flutter, Riverpod, drift | `packages/flutter_core/` |
| [web/](web/) | Web (PWA) | Flutter Web | `packages/flutter_core/` |

## Vì sao Android và Web là hai thư mục nhưng không nhân đôi mã

`apps/android` và `apps/web` là **hai app shell mỏng** — mỗi cái chỉ chứa `main.dart`, cấu hình nền tảng (`android/`, `web/`), và theme khác biệt nếu cần. Toàn bộ logic, widget, repository, model nằm trong **`packages/flutter_core/`** và cả hai cùng phụ thuộc vào nó.

```
apps/android/  ──┐
                 ├──► packages/flutter_core/   (Dart dùng chung ~95% mã)
apps/web/      ──┘
```

Hệ quả: sửa một màn hình ở `flutter_core` → cả Android và Web có ngay. Vẫn giữ được yêu cầu "ba thư mục riêng" mà không phải sửa hai lần.

Quản lý workspace: **melos** (khai báo ở `melos.yaml`, chưa tạo).

## iOS không share mã với Dart

Swift ↔ Dart khác ngôn ngữ, không share được. Bù lại bằng ba cơ chế:

1. **Cùng bộ số liệu test** cho `DailyLimitCalculator` — bộ test viết hai lần nhưng dùng chung file số liệu, để phát hiện lệch "iOS tính 96.000, Android tính 95.800"
2. **Cùng DTO JSON** từ `packages/shared-types/openapi.yaml`, sinh client Dart và Swift bằng OpenAPI Generator
3. **Cùng tài liệu thiết kế** — màn hình ở [04](../docs/system-design/04-wireframes.md), khác biệt nền tảng ghi rõ tại chỗ
