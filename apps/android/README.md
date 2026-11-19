# apps/android — Android (Flutter)

> Nhánh: `dev/android`. Phát triển vùng này thì đứng ở nhánh đó — xem [../../docs/BRANCHING.md](../../docs/BRANCHING.md).

Chưa tạo project. Sẽ có ở tuần 1.

| Việc | Giá trị |
|---|---|
| Framework | Flutter 3.24+, Dart 3 |
| State | Riverpod 2 |
| CSDL local | drift (SQLite) |
| Gọi HTTP | dio |
| Biểu đồ | fl_chart |
| Thông báo | FCM |
| Target | Android 8+ (API 26) |
| CI | GitHub Actions: `flutter analyze`, `flutter test` |

```bash
flutter create --org com.qlct --platforms android .
```

## Cấu trúc

Toàn bộ mã Flutter nằm trong `apps/android/lib/`, theo cây thư mục ở [docs/system-design/06-flutter-structure.md](../../docs/system-design/06-flutter-structure.md) mục 2.

Quy tắc giao diện bắt buộc xem tại [docs/system-design/11-android-ui-rules.md](../../docs/system-design/11-android-ui-rules.md).

Lý do: Web đã tách sang Next.js, chỉ còn Android dùng Dart, nên không còn gì để share.

Tên app và applicationId **chưa chốt** — cần quyết trước khi đăng ký Google Play (25 USD).

## Tiến độ UI hiện tại

App đã thay counter mặc định bằng khung 4 tab: Trang chủ, Giao dịch, Ngân sách, Thống kê. Mỗi tab có trạng thái loading, empty và error có chữ. Dữ liệu đến từ `FakeFinanceRepository` qua Riverpod; công thức `dailyLimit` nằm ở `lib/domain/finance_calculator.dart`, UI không tự tính số tài chính.

Menu “Trạng thái dữ liệu” trên thanh trên cùng cho phép chuyển giữa các kịch bản `Dữ liệu mẫu`, `Trống`, `Lỗi`, `Offline` để kiểm tra các trạng thái.

Kotlin hiện chỉ có `MainActivity.kt` mở rộng `FlutterActivity`, dùng để khởi chạy Flutter; chưa có platform channel.
