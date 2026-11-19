-- Bootstrap cho Postgres local (Homebrew), KHÔNG dùng trên Supabase.
--
-- Supabase dựng sẵn ba thứ mà Postgres thuần không có, và migration
-- 20261117122700 cần chúng để chạy được:
--   1. schema `extensions`  -> chỗ đặt citext
--   2. role `authenticated` -> đích của GRANT EXECUTE
--   3. hàm `auth.uid()`     -> dùng trong 23 policy
--
-- File này chỉ tạo hạ tầng, KHÔNG tạo bảng và KHÔNG sửa migration.
-- Chạy một lần khi tạo database local:
--   psql -d student_finance -f infra/local/00-bootstrap.sql

CREATE SCHEMA IF NOT EXISTS extensions;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
    CREATE ROLE authenticated NOLOGIN;
  END IF;
END $$;

CREATE SCHEMA IF NOT EXISTS auth;

-- Bản rút gọn của auth.uid() phía Supabase: đọc claim `sub` từ GUC
-- `request.jwt.claims` do PostgREST/GoTrue đặt. Khi API kết nối bằng role
-- owner thì RLS bị bỏ qua nên hàm này không được gọi, nhưng policy vẫn
-- cần nó tồn tại lúc CREATE POLICY.
--
-- Muốn thử RLS ở local: SET LOCAL request.jwt.claims = '{"sub":"<uuid>"}';
CREATE OR REPLACE FUNCTION auth.uid() RETURNS uuid
LANGUAGE sql STABLE AS $$
  SELECT NULLIF(
    current_setting('request.jwt.claims', true)::jsonb ->> 'sub',
    ''
  )::uuid;
$$;

-- Cùng lý do với auth.uid(): một số policy của Supabase dùng auth.jwt().
CREATE OR REPLACE FUNCTION auth.jwt() RETURNS jsonb
LANGUAGE sql STABLE AS $$
  SELECT COALESCE(
    NULLIF(current_setting('request.jwt.claims', true), '')::jsonb,
    '{}'::jsonb
  );
$$;

-- Supabase đặt search_path của role mặc định gồm `extensions`, nhờ đó
-- `CITEXT` trong migration tìm thấy type dù nó nằm ở schema extensions.
-- Postgres thuần mặc định chỉ có "$user", public -> phải bổ sung cho khớp.
ALTER DATABASE student_finance SET search_path TO "$user", public, extensions;
