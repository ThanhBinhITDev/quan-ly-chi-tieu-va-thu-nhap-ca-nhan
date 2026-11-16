# 08 — Nguyên tắc thiết kế backend cho ba nền tảng

**Phiên bản:** 1.0 · **Ngày:** 2026-11-16

Backend phục vụ ba client khác nhau: iOS (Swift), Android (Dart), Web (TypeScript). Tài liệu này định nghĩa hai nguyên tắc để ba client đều dùng được mà không phải biết về nhau.

---

## 1. API chuẩn REST, trả JSON thuần

Server không biết client là gì. Mọi endpoint:

| Quy tắc | Nội dung |
|---|---|
| Giao thức | REST qua HTTPS |
| Định dạng | JSON thuần, `Content-Type: application/json; charset=utf-8` |
| Không phụ thuộc nền tảng | Không trả HTML, không trả định dạng riêng của Flutter hay SwiftUI |
| Phía client parse | Dart: `jsonDecode` rồi map sang class. Swift: `Codable`. TypeScript: `JSON.parse` + type từ OpenAPI |

**Vì sao không GraphQL:** GraphQL mạnh khi nhiều client cần lấy các tập trường khác nhau. Ở đây các màn hình có dữ liệu cố định, REST đủ, dễ cache, dễ kiểm thử bằng curl, và không cần thư viện thêm cho Swift và Dart.

### Ví dụ một response

```json
{
  "id": "3f2a9c1e-7b4d-4e8a-9f11-2c5d6e7a8b90",
  "type": "expense",
  "amount": 35000,
  "category_id": "c1",
  "wallet_id": "w1",
  "occurred_at": "2026-11-16T04:30:00Z",
  "note": "Trà sữa",
  "rev": 3
}
```

Cùng một JSON này được ba client đọc như sau:

| Client | Cách đọc |
|---|---|
| Android (Dart) | `Transaction.fromJson(jsonDecode(body))` |
| iOS (Swift) | `JSONDecoder().decode(Transaction.self, from: data)` |
| Web (TypeScript) | `const t: Transaction = await res.json()` |

### Quy ước đặt tên

| Quy tắc | Ví dụ đúng | Ví dụ sai |
|---|---|---|
| Trường JSON: `snake_case` | `occurred_at` | `occurredAt` |
| Đường dẫn: danh từ số nhiều | `/v1/transactions` | `/v1/getTransactions` |
| Phiên bản trong đường dẫn | `/v1/...` | Header tuỳ biến |
| Mã trạng thái chuẩn | `201` khi tạo, `409` khi xung đột | `200` cho mọi thứ |

**Lý do snake_case:** Swift và Dart đều map được qua `CodingKeys` hoặc `@JsonKey`, không cần đổi tên trường ở server. Giữ một kiểu đặt tên cho cả ba.

---

## 2. Token thống nhất: Bearer JWT

Ba client gửi token **đúng cùng một cách**:

```http
GET /v1/transactions?limit=50
Authorization: Bearer eyJhbGciOiJIUzI1NiIs...
```

| Quy tắc | Nội dung |
|---|---|
| Header | `Authorization: Bearer <access_token>` — chuỗi giống hệt nhau trên cả ba nền |
| Loại token | JWT do Supabase Auth cấp, server xác minh chữ ký |
| Thời hạn access token | 1 giờ |
| Refresh token | Xoay vòng: mỗi lần dùng cấp cặp mới, token cũ vô hiệu |
| Lưu trữ phía client | iOS: Keychain. Android: `flutter_secure_storage` (Keystore). Web: cookie `HttpOnly; Secure; SameSite=Strict` |
| Gửi lại khi hết hạn | Nhận `401 TOKEN_EXPIRED` → gọi `/v1/auth/refresh` một lần → thử lại request |
| Đăng xuất | Thu hồi refresh token trên server, xoá token trên máy |

### Vì sao Web dùng cookie, không dùng header

Trình duyệt không cho JavaScript đọc cookie `HttpOnly`, nên token không bị đánh cắp qua XSS. Với Web, server đặt cookie khi đăng nhập; các request sau tự gửi kèm cookie. Client Web vẫn gửi `Authorization: Bearer` nếu gọi từ môi trường không phải trình duyệt (test, script).

Điều này **không làm Web khác với hai nền còn lại ở phía server**: API vẫn nhận `Authorization: Bearer`, chỉ thêm một đường đọc cookie cho trình duyệt.

### Mã lỗi xác thực chuẩn

| HTTP | Mã lỗi (`code`) | Ý nghĩa | Client làm gì |
|---|---|---|---|
| 401 | `TOKEN_MISSING` | Không gửi token | Đưa về màn đăng nhập |
| 401 | `TOKEN_EXPIRED` | Hết hạn | Refresh rồi thử lại một lần |
| 401 | `TOKEN_INVALID` | Sai chữ ký, bị thu hồi | Đăng xuất, đăng nhập lại |
| 403 | `FORBIDDEN` | Không có quyền trên tài nguyên | Báo lỗi, không thử lại |

---

## 3. Định dạng lỗi thống nhất

Mọi lỗi trả về cùng một hình dạng:

```json
{
  "error": {
    "code": "SYNC_CONFLICT",
    "message": "Bản ghi đã được sửa ở thiết bị khác",
    "details": { "server_rev": 4 }
  }
}
```

`code` là chuỗi ổn định để client rẽ nhánh. `message` chỉ để ghi log, không hiển thị thẳng cho người dùng.

---

## 4. Hệ quả kiểm chứng được

| Nguyên tắc | Cách kiểm |
|---|---|
| JSON thuần | Gọi endpoint bằng `curl`, kết quả parse được bằng `jq` |
| Ba client parse giống nhau | Một bộ JSON mẫu trong `packages/shared-types/examples/`, cả ba client có test đọc file đó |
| Token giống nhau | Một bộ test ở server: cùng token từ ba User-Agent khác nhau, kết quả giống hệt |
| Không phụ thuộc nền tảng | Server không có nhánh `if (platform === 'ios')` — CI grep để chặn |

---

## 5. Điểm cần bạn quyết

| # | Điểm | Đề xuất |
|---|---|---|
| 1 | Web lưu token ở cookie hay localStorage | Cookie `HttpOnly` (an toàn hơn) |
| 2 | Thời hạn access token | 1 giờ |
| 3 | Có giữ đăng nhập qua nhiều ngày không | Có, refresh token 30 ngày |
