# Môi trường test song song (Supabase + VPS)

Môi trường này **không phải** cơ sở hạ tầng chính thức. Nó tồn tại để chạy thử
luồng thật (app Android → API → Postgres) mà không đụng vào app dev local.

## Thành phần

| Thành phần | Giá trị |
|---|---|
| Supabase project ref | `lfvpeenfownujsccojnv` |
| Tổ chức | `svdvdebvwrhjwypdyuua` |
| Region | `ap-northeast-1` |
| Postgres | 17.12, `db.lfvpeenfownujsccojnv.supabase.co` |
| Pooler (API dùng) | `aws-0-ap-northeast-1.pooler.supabase.com:6543` |
| DB role | `qlct_api.lfvpeenfownujsccojnv` |
| API URL (HTTPS) | `https://api-test.103.229.52.143.sslip.io` |
| VPS | `103.229.52.143` (Debian 11, 2 core, 3.9 GB) |
| Đường dẫn deploy | `/opt/qlct-test` |
| Container | `qlct-api-test`, bind `127.0.0.1:3101` |
| Nginx vhost | `/www/server/panel/vhost/nginx/api-test.103.229.52.143.sslip.io.conf` |
| Chứng chỉ | Let's Encrypt, `/www/server/panel/vhost/letsencrypt/api-test.103.229.52.143.sslip.io/` |

## Vì sao dùng `sslip.io` mà không dùng `*.thanhbinhit.com`

Mọi subdomain của `thanhbinhit.com` đi qua Cloudflare và trả **403 "Just a
moment..."** (challenge JS) cho request không phải trình duyệt. App Android
không vượt được challenge đó, nên API đứng sau Cloudflare không dùng được cho
mobile. `sslip.io` trỏ thẳng về IP VPS, không có proxy chen giữa.

## Đã áp migration

Toàn bộ 8 migration trong `infra/migrations/` đã chạy trên project test: 16 bảng
public, 28 policy. Role `qlct_api` được tạo riêng và cấp quyền, API kết nối qua
pooler bằng role đó chứ không dùng `postgres` superuser.

## Biến môi trường của API trên VPS

File `/opt/qlct-test/api.env` (không commit, chứa mật khẩu):

- `DATABASE_URL` — pooler URL với role `qlct_api`
- `SUPABASE_URL`, `SUPABASE_JWT_ISSUER`, `SUPABASE_JWKS_URL`
- `SUPABASE_JWT_SECRET` **không đặt**: project dùng signing key `ES256`, xác
  thực qua JWKS. Đặt secret HS256 vào đây sẽ làm mọi token bị từ chối.
- `HOST=0.0.0.0` — bắt buộc. Để `127.0.0.1` thì docker-proxy reset kết nối từ
  nginx vào container.

## Tài khoản test

`test.qlct@gmail.com` trên Supabase Auth của project test. Chỉ dùng cho môi
trường này.

## Lấy chứng chỉ

`aaPanel` xin cert bằng webroot HTTP-01. Hai điều kiện bắt buộc, thiếu một là
ACME trả 404:

1. Block `server` của domain phải được **nginx thật** nạp — `nginx -T` phải
   thấy `server_name`. aaPanel từng tạo file nhưng `nginx -t` fail vì block
   trùng cổng `3101` với container, nên nginx chết và domain rơi về trang
   "website has been stopped".
2. `location /.well-known/acme-challenge/` phải trỏ đúng webroot, không bị
   `location /` nuốt mất.

Sau khi sửa: `nginx -t && nginx -s reload`, kiểm bằng
`curl http://<domain>/.well-known/acme-challenge/probe`.

Nginx trên VPS là bản cũ: dùng `listen 443 ssl http2;`, **không** dùng directive
`http2 on;` (bản mới mới có).

## Kiểm chứng end-to-end đã chạy

- `GET /health` qua HTTPS → `{"status":"ok","database":"up"}`
- Đăng nhập `test.qlct@gmail.com` trên app flavor `prod` → vào trang chủ
- Số dư hiện tại 4.720.000 đ khớp dữ liệu seed
- Tạo hũ "An-uong" 40% từ app → `budget_jars` có bản ghi, `budget_jar_categories` có 1 dòng