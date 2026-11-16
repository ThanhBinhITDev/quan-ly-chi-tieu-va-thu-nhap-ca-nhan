# apps/android — Android (Flutter)

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

Lý do: Web đã tách sang Next.js, chỉ còn Android dùng Dart, nên không còn gì để share.

Tên app và applicationId **chưa chốt** — cần quyết trước khi đăng ký Google Play (25 USD).
