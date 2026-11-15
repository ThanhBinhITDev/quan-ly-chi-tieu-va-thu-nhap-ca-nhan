# packages/flutter_core — Dart dùng chung cho Android + Web

Toàn bộ mã Flutter thật nằm ở đây. `apps/android` và `apps/web` chỉ là vỏ gọi vào.

Cây thư mục lấy nguyên từ [docs/system-design/06-flutter-structure.md](../../docs/system-design/06-flutter-structure.md) mục 2, đổi `lib/` thành thư mục gốc của package:

```
lib/
├── core/          # theme, money_formatter, money_text, progress_bar
├── data/
│   ├── local/     # drift: tables/, daos/, seed/
│   ├── remote/    # dio, api_client, *_api.dart
│   ├── models/    # DTO có fromJson/toJson
│   └── repositories/
├── domain/
│   ├── entities/
│   └── usecases/
└── presentation/  # màn hình, widget, provider Riverpod
```

| Việc | Ghi chú |
|---|---|
| Tên package | `flutter_core` |
| State | Riverpod 2 |
| CSDL | drift |
| Gọi HTTP | dio |
| Biểu đồ | fl_chart |
| Test | flutter_test + mocktail — 40 test `DailyLimitCalculator` |
| Phụ thuộc vào | Không phụ thuộc `apps/*` (chiều ngược lại mới đúng) |

**Quy tắc:** `flutter_core` không được import bất kỳ thứ gì từ `apps/android` hay `apps/web`. Nếu cần thứ riêng cho một nền, dùng tham số hoặc abstraction, không `if (Platform.isAndroid)` rải rác trong core.
