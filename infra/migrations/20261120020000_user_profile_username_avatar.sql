-- Hồ sơ người dùng: tên người dùng công khai và ảnh đại diện.
--
-- Vì sao lưu ảnh trong CSDL thay vì object storage:
--   Ảnh đại diện đã được cắt về 256×256 JPEG (~15–40 KB). Ở quy mô này, một
--   cột bytea nhỏ hơn nhiều so với việc thêm phụ thuộc vào dịch vụ lưu trữ
--   ngoài (bucket, policy, URL công khai, chi phí). Khi số người dùng lớn tới
--   mức ảnh chiếm đáng kể dung lượng, chuyển sang bucket là việc của một
--   migration riêng — dữ liệu hiện có xuất ra được bằng `avatar_data`.
--
-- `username` là citext (không phân biệt hoa thường) và UNIQUE một phần: chỉ
--   xét các dòng chưa xoá mềm để người dùng đã rời đi không chặn tên của người
--   mới. NULL được phép vì người dùng cũ chưa đặt tên người dùng.

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS username citext,
  ADD COLUMN IF NOT EXISTS avatar_mime text,
  ADD COLUMN IF NOT EXISTS avatar_data bytea,
  ADD COLUMN IF NOT EXISTS avatar_updated_at timestamptz;

-- Giới hạn độ dài ngay ở CSDL: UI đã chặn, nhưng API là biên giới tin cậy.
ALTER TABLE users
  DROP CONSTRAINT IF EXISTS users_username_format;
ALTER TABLE users
  ADD CONSTRAINT users_username_format
  CHECK (username IS NULL OR username ~ '^[a-z0-9._]{3,30}$');

-- Ảnh đại diện: chỉ nhận JPEG/PNG/WebP và tối đa 256 KB. Ảnh lớn hơn là lỗi
-- của client (đã cắt trước khi gửi), không phải dữ liệu hợp lệ.
ALTER TABLE users
  DROP CONSTRAINT IF EXISTS users_avatar_size;
ALTER TABLE users
  ADD CONSTRAINT users_avatar_size
  CHECK (avatar_data IS NULL OR octet_length(avatar_data) <= 262144);

ALTER TABLE users
  DROP CONSTRAINT IF EXISTS users_avatar_mime;
ALTER TABLE users
  ADD CONSTRAINT users_avatar_mime
  CHECK (avatar_mime IS NULL OR avatar_mime IN ('image/jpeg', 'image/png', 'image/webp'));

-- Ảnh và mime phải đi cùng nhau: có ảnh thì phải có mime, và ngược lại.
ALTER TABLE users
  DROP CONSTRAINT IF EXISTS users_avatar_pair;
ALTER TABLE users
  ADD CONSTRAINT users_avatar_pair
  CHECK ((avatar_data IS NULL) = (avatar_mime IS NULL));

CREATE UNIQUE INDEX IF NOT EXISTS users_username_active_key
  ON users (username)
  WHERE username IS NOT NULL AND deleted_at IS NULL;

COMMENT ON COLUMN users.username IS
  'Tên người dùng công khai, 3–30 ký tự [a-z0-9._], không phân biệt hoa thường.';
COMMENT ON COLUMN users.avatar_data IS
  'Ảnh đại diện đã cắt sẵn (256×256), tối đa 256 KB. Phục vụ qua GET /v1/me/avatar.';
