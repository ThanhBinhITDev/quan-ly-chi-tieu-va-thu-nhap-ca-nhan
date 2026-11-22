# apps/android — Android (Flutter)

> Nhánh: `dev/android`. Phát triển vùng này thì đứng ở nhánh đó — xem [../../docs/BRANCHING.md](../../docs/BRANCHING.md).

Project đã dựng xong trên nhánh `dev/android` (Flutter + Riverpod + dio).

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

## Cấu trúc

Toàn bộ mã Flutter nằm trong `apps/android/lib/`, theo cây thư mục ở [docs/system-design/06-flutter-structure.md](../../docs/system-design/06-flutter-structure.md) mục 2.

Quy tắc giao diện bắt buộc xem tại [docs/system-design/11-android-ui-rules.md](../../docs/system-design/11-android-ui-rules.md).

Lý do: Web đã tách sang Next.js, chỉ còn Android dùng Dart, nên không còn gì để share.

Tên app và applicationId **chưa chốt** — cần quyết trước khi đăng ký Google Play (25 USD).

## Chạy app

```bash
# API local cho emulator (10.0.2.2 = máy host)
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000 \
  --dart-define=SUPABASE_URL=https://<ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon-key>

flutter test                      # unit + widget
flutter test integration_test -d emulator-5554   # chạy trên máy ảo
```

Thiếu `SUPABASE_URL`/`SUPABASE_ANON_KEY` thì app **vẫn mở form đăng nhập**
(`AuthGate`), không tự vào chế độ dữ liệu mẫu. Chỉ hai đường mới vào được dữ
liệu mẫu:

- build có `--dart-define=DEMO_MODE=true`, hoặc
- bấm nút "Xem dữ liệu mẫu" ngay trên form đăng nhập.

Mặc định tắt là cố ý: một app tài chính không được lặng lẽ hiện số liệu giả
khi thiếu cấu hình, vì người dùng sẽ tưởng đó là tiền thật của mình.

### Xem dữ liệu thật khi chưa có anon key

Có API local + một JWT hợp lệ của user test (API dev ký bằng
`SUPABASE_JWT_SECRET`) là đủ để kiểm giao diện với dữ liệu thật:

```bash
flutter run -d emulator-5554 \
  --dart-define=API_BASE_URL=http://10.0.2.2:3000 \
  --dart-define=DEV_ACCESS_TOKEN=<jwt-user-test>
```

`DEV_ACCESS_TOKEN` **chỉ có hiệu lực ở debug build** (`kDebugMode`) và không
được dùng ở profile/release; token được tiêm thẳng vào `ApiClient`, bỏ qua
secure storage. Không phải đường đăng nhập thật — đường thật vẫn là Supabase
Auth, cần anon key.

### Đăng nhập bằng dev login (không cần anon key)

API dev có `POST /v1/dev/login` để lấy JWT HS256. Endpoint tự tắt khi
`NODE_ENV=production`, và chỉ bật khi `DEV_LOGIN_PASSWORD` (≥12 ký tự) cùng
`SUPABASE_JWT_SECRET` được đặt.

```bash
flutter run -d emulator-5554 \
  --dart-define=API_BASE_URL=http://10.0.2.2:3000 \
  --dart-define=DEV_LOGIN_PASSWORD=<mật khẩu dev>
```

Có `DEV_LOGIN_PASSWORD` thì app ẩn nút "Tạo tài khoản" và dùng form đăng nhập
hiện có để gọi dev login. Mật khẩu chỉ nằm trong `--dart-define`, không nằm
trong repo (`services/api/.env` bị gitignore).

### Hai bản cài song song (flavor)

App có hai product flavor, khác `applicationId` nên cài cùng lúc trên một máy:

| Flavor | applicationId | Tên hiển thị | Trỏ tới |
|---|---|---|---|
| `prod` | `com.studentfinance.android` | Student Finance | API + Supabase test qua HTTPS |
| `dev` | `com.studentfinance.android.dev` | Student Finance Dev | API local `http://10.0.2.2:3000` |

Cấu hình từng bản nằm ở `tool/env.prod.json` và `tool/env.dev.json`, truyền vào
bằng `--dart-define-from-file`. File `env.prod.json` chứa anon key nên **bị
gitignore**; bản mẫu là `env.prod.json.example`.

```bash
cp tool/env.prod.json.example tool/env.prod.json   # điền anon key thật
tool/build_both.sh

# APK ra ở:
#   build/app/outputs/flutter-apk/app-prod-release.apk
#   build/app/outputs/flutter-apk/app-dev-debug.apk
```

Bản `prod` là release nên Android 9+ chặn cleartext: nó chỉ gọi được HTTPS,
đúng như thiết kế. Muốn đổi endpoint thì sửa `API_BASE_URL` trong
`tool/env.prod.json` rồi build lại, không cần sửa mã.

### Ảnh đại diện

`image_picker` cần hai khai báo `<queries>` trong `AndroidManifest.xml`
(`IMAGE_CAPTURE` và `GET_CONTENT`), nếu thiếu thì Android 11+ ẩn app camera và
thư viện ảnh nên plugin báo không có camera dù máy có. App **không** khai báo
`android.permission.CAMERA`: chụp ảnh đi qua intent của app camera hệ thống,
xin quyền trực tiếp chỉ làm người dùng phải bấm thêm một hộp thoại vô ích.

## Luồng dữ liệu

| Lớp | File | Việc |
|---|---|---|
| Cấu hình | `lib/core/config/app_config.dart` | đọc `--dart-define`, timeout |
| Phiên | `lib/data/session/session_store.dart` | token trong secure storage |
| Đăng nhập | `lib/data/remote/auth_api.dart` | gọi Supabase Auth, dịch lỗi sang tiếng Việt |
| HTTP | `lib/data/remote/api_client.dart` | Bearer, tự refresh khi <5 phút, thử lại 1 lần khi 401 |
| Endpoint | `lib/data/remote/finance_api.dart` | mỗi hàm = 1 route trong `02-api-contract.md` |
| DTO | `lib/data/remote/dto.dart` | parse đúng JSON API, có test khoá shape |
| Repository | `lib/data/api_finance_repository.dart` | DTO → model UI, giữ nguyên 4 tab hiện có |
| Gate | `lib/ui/auth/auth_gate.dart` | chưa đăng nhập → form; đã đăng nhập → `AppShell` |

API **không** có endpoint đăng nhập/đăng ký: app gọi thẳng Supabase Auth, API
chỉ xác thực JWT. Đây là thiết kế đã chốt, không phải thiếu sót.

## Số dư và xoá mềm (đã có ở API)

Ba khoảng trống trước đây đã được vá ở `dev/api`:

| Việc | Cách gọi |
|---|---|
| Số dư từng ví | `GET /v1/wallets` → mỗi ví có `balance` (server tính, client không cộng) |
| Tổng hợp số dư | `GET /v1/wallets/summary` → `total_balance`, `by_type`, `wallets[]` |
| Xoá mềm ví | `DELETE /v1/wallets/<id>?rev=<rev+1>` → set `deleted_at`, không xoá dòng |
| Xoá mềm danh mục | `DELETE /v1/categories/<id>?rev=<rev+1>` |
| Đồng bộ bản đã xoá | `?include_deleted=true` trên cả hai route `GET` |

`balance` **không** được gửi lên từ client: đó là trường server-owned, tính từ
`initial_balance` + giao dịch, đúng công thức trong `01-database-schema.md`.
Danh mục hệ thống (`is_system = true`) không xoá được.

Xem mã: `services/api/src/modules/wallets/wallets.service.ts`,
`services/api/src/modules/categories/categories.service.ts`.

## Tiến độ UI hiện tại

App đã thay counter mặc định bằng khung 4 tab: Trang chủ, Giao dịch, Ngân sách, Thống kê. Mỗi tab có trạng thái loading, empty và error có chữ. Dữ liệu đến từ `FakeFinanceRepository` qua Riverpod; công thức `dailyLimit` nằm ở `lib/domain/finance_calculator.dart`, UI không tự tính số tài chính.

Menu “Trạng thái dữ liệu” trên thanh trên cùng cho phép chuyển giữa các kịch bản `Dữ liệu mẫu`, `Trống`, `Lỗi`, `Offline` để kiểm tra các trạng thái. Menu này tự ẩn khi đang ở chế độ dữ liệu thật.

Khi đã đăng nhập, `financeRepositoryProvider` trả `ApiFinanceRepository` thay
cho bản giả; 4 tab giữ nguyên giao diện, chỉ đổi nguồn dữ liệu.

Kotlin hiện chỉ có `MainActivity.kt` mở rộng `FlutterActivity`, dùng để khởi chạy Flutter; chưa có platform channel.
