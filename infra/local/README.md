# Chạy API với Postgres local

Mục đích: có database dev riêng trên máy để test API thoải mái, không đụng
project Supabase thật (`ebbqcnnwqeasozmcqigu`).

## Vì sao cần file bootstrap

`infra/migrations/20261117122700_initial_student_finance.sql` được viết cho
Supabase và dùng ba thứ Supabase dựng sẵn mà Postgres thuần không có:

| Thành phần | Số lần trong migration | Supabase | Postgres brew |
| --- | --- | --- | --- |
| `auth.uid()` | 21 | có sẵn | **thiếu** |
| role `authenticated` | 2 | có sẵn | **thiếu** |
| schema `extensions` | 1 | có sẵn | **thiếu** |

Thiếu chúng thì migration dừng ngay dòng `CREATE POLICY` đầu tiên với lỗi
`function auth.uid() does not exist`.

`infra/local/00-bootstrap.sql` bù đúng ba thứ đó và **không sửa file
migration**. Nhờ vậy hai file migration là nguồn sự thật duy nhất, chạy
được ở cả local và Supabase, schema không bao giờ lệch nhau.

Bootstrap cũng đặt `search_path` của database gồm `extensions`, khớp với
role mặc định của Supabase — nếu thiếu, `CITEXT` trong migration không tìm
thấy type.

## Dựng lần đầu

```bash
export PATH="/opt/homebrew/opt/postgresql@17/bin:$PATH"

# macOS: thiếu LC_ALL thì postmaster báo "became multithreaded during startup"
LC_ALL="en_US.UTF-8" pg_ctl -D /opt/homebrew/var/postgresql@17 -l /tmp/sf-pg.log start

createdb -h 127.0.0.1 student_finance
psql -h 127.0.0.1 -d student_finance -v ON_ERROR_STOP=1 -f infra/local/00-bootstrap.sql
psql -h 127.0.0.1 -d student_finance -v ON_ERROR_STOP=1 -f infra/migrations/20261117122700_initial_student_finance.sql
psql -h 127.0.0.1 -d student_finance -v ON_ERROR_STOP=1 -f infra/migrations/20261117123000_enable_citext_extensions_schema.sql
```

Kết quả đúng phải là **12 bảng, 23 policy, 9 trigger**, extension
`citext` + `pgcrypto`.

## Dừng / chạy lại

```bash
export PATH="/opt/homebrew/opt/postgresql@17/bin:$PATH"
LC_ALL="en_US.UTF-8" pg_ctl -D /opt/homebrew/var/postgresql@17 stop
LC_ALL="en_US.UTF-8" pg_ctl -D /opt/homebrew/var/postgresql@17 -l /tmp/sf-pg.log start
```

Không dùng `brew services start postgresql@17` trừ khi muốn Postgres tự
chạy mỗi lần đăng nhập máy.

## Cấu hình API

`services/api/.env` (bị `.gitignore` chặn, không commit):

```
DATABASE_URL=postgresql://thanhbinh@127.0.0.1:5432/student_finance
DATABASE_SSL=false
AUTH_ALLOW_UNVERIFIED=true
PORT=3000
```

`AUTH_ALLOW_UNVERIFIED=true` chỉ dùng ở local vì máy không có GoTrue phát
JWT. Lên production phải đặt `SUPABASE_URL` để verify qua JWKS.

## Kiểm tra nhanh

```bash
curl -s http://127.0.0.1:3000/health
# {"status":"ok","database":"up","time":"..."}
```

## RLS ở local không có tác dụng

API kết nối bằng role owner (`thanhbinh`), nên Postgres **bỏ qua toàn bộ
23 policy**. Policy tồn tại nhưng là code chết ở local.

Phân quyền thật của API nằm ở **các câu `WHERE user_id = $1`** trong
service (48 chỗ). RLS chỉ có hiệu lực khi truy cập qua Supabase
(PostgREST hoặc client Supabase JS).

Muốn thử RLS ở local vẫn được, sau khi tạo role không phải owner:

```sql
SET LOCAL request.jwt.claims = '{"sub":"11111111-1111-4111-8111-111111111111"}';
SELECT auth.uid();  -- trả uuid ở trên
```

## Khác biệt local và Supabase

Hai database độc lập, **không tự đồng bộ**. Giống nhau vì cùng áp một bộ
migration, không phải vì nói chuyện với nhau.

| | Local | Supabase |
| --- | --- | --- |
| Câu SQL của API | y hệt | y hệt |
| Code API | không sửa | không sửa |
| Đổi môi trường | sửa `DATABASE_URL` | sửa `DATABASE_URL` |
| RLS | có nhưng bị bypass | có hiệu lực thật |
| Dữ liệu | riêng, xoá tạo lại thoải mái | dữ liệu thật |

Muốn copy dữ liệu Supabase về local để test cho sát: `pg_dump` rồi
`pg_restore`, một chiều, chạy lại mỗi lần muốn cập nhật.

## Phiên bản

Local `postgresql@17` 17.12 (brew), Supabase `Postgres 17.12.0.000` — khớp
nhau, không lệch major hay minor.
