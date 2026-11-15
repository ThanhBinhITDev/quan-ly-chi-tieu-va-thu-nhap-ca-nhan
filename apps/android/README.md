# apps/android — Android (app shell Flutter)

Chưa tạo project. Sẽ có ở tuần 1.

Đây là **app shell mỏng**, không chứa logic.

| Chứa | Không chứa |
|---|---|
| `lib/main.dart` (gọi `runApp` từ core) | Widget, màn hình, repository, model |
| `android/` (Gradle, manifest, icon, splash) | Logic tính hạn mức, sync, DB |
| Cấu hình theme riêng nếu Android cần khác | Bất kỳ thứ gì Web cũng cần |

```bash
flutter create --org com.qlct --platforms android .
```

Phụ thuộc: `packages/flutter_core` (path dependency trong `pubspec.yaml`).

Tên app và applicationId **chưa chốt** — cần quyết trước khi đăng ký Google Play.
