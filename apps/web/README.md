# apps/web — Web / PWA (app shell Flutter)

Chưa tạo project. Sẽ có ở tuần 1, **ưu tiên thấp**.

Đây là **app shell mỏng**, giống Android.

```bash
flutter create --org com.qlct --platforms web .
```

Phụ thuộc: `packages/flutter_core`.

| Điểm khác Android | Cách xử lý |
|---|---|
| Không có SQLite gốc | drift dùng `sqlite3.wasm` + OPFS, hoặc chuyển sang IndexedDB nếu chậm |
| Không có thông báo đẩy FCM | Dùng Web Push (VAPID) hoặc bỏ — giai đoạn 2 |
| Không có widget màn hình chính | Bỏ, thay bằng PWA shortcut |
| Kích thước tải lớn (~2–3 MB) | Chấp nhận, hoặc lazy-load |

> **D1 chưa quyết:** nếu thiếu thời gian thì cắt hẳn Web khỏi MVP (xem [05-lo-trinh](../../docs/05-lo-trinh.md) mục 4). Thư mục này để sẵn, chưa cần làm.
