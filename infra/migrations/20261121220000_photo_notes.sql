-- Additive: photo notes (sổ ảnh).
--
-- Mỗi dòng là MỘT tấm ảnh kèm ghi chú của chính nó — đơn vị nội dung, không
-- phải thuộc tính của giao dịch. Ảnh có thể gắn vào một khoản chi/thu, hoặc
-- đứng rời (không gắn gì). Giao dịch thì không bắt buộc có ảnh.
--
-- Vì sao tách bảng thay vì thêm cột vào `transactions`:
--   - Ảnh rời không có giao dịch để bám vào.
--   - Một giao dịch có thể có nhiều ảnh (ảnh món ăn + ảnh hoá đơn).
--   - Xoá giao dịch không nên xoá luôn kỷ niệm; chỉ gỡ liên kết.
--
-- `transactions.receipt_data` / `receipt_mime` giữ nguyên, không xoá: dữ liệu
-- cũ vẫn đọc được. Ảnh mới đi qua bảng này.

CREATE TABLE IF NOT EXISTS photo_notes (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  -- Gắn tuỳ chọn. ON DELETE SET NULL: xoá khoản chi thì ảnh vẫn còn, chỉ mất
  -- liên kết — người dùng không mất kỷ niệm vì sửa sổ sách.
  transaction_id UUID REFERENCES transactions(id) ON DELETE SET NULL,
  caption TEXT,
  taken_at TIMESTAMPTZ NOT NULL,
  taken_on DATE NOT NULL,
  photo_mime TEXT NOT NULL
    CHECK (photo_mime IN ('image/jpeg','image/png','image/webp')),
  photo_data BYTEA NOT NULL
    CHECK (octet_length(photo_data) <= 524288),
  rev INT NOT NULL DEFAULT 1,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ,
  CONSTRAINT photo_notes_caption_len CHECK (caption IS NULL OR char_length(caption) <= 500)
);

-- Dòng thời gian sổ ảnh: mới nhất trước, chỉ ảnh chưa xoá.
CREATE INDEX IF NOT EXISTS idx_photo_user_time
  ON photo_notes(user_id, taken_at DESC) WHERE deleted_at IS NULL;

-- Nhóm ảnh của một giao dịch (mở chi tiết giao dịch).
CREATE INDEX IF NOT EXISTS idx_photo_tx
  ON photo_notes(transaction_id) WHERE transaction_id IS NOT NULL AND deleted_at IS NULL;

-- Đồng bộ theo rev, giống các bảng khác.
CREATE INDEX IF NOT EXISTS idx_photo_sync ON photo_notes(user_id, updated_at);

-- `taken_on` do server sinh theo giờ Việt Nam, client không gửi. Dùng lại
-- `set_occurred_on()` đã có vì nó chỉ đụng `occurred_at`; ở đây cần bản riêng
-- đọc `taken_at` nên viết hàm mới thay vì sửa hàm đang chạy cho bảng khác.
CREATE OR REPLACE FUNCTION set_taken_on() RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.taken_on := (NEW.taken_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_updated_at_photo_notes ON photo_notes;
CREATE TRIGGER trg_updated_at_photo_notes BEFORE UPDATE ON photo_notes
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_taken_on_photo_notes ON photo_notes;
CREATE TRIGGER trg_taken_on_photo_notes BEFORE INSERT OR UPDATE OF taken_at ON photo_notes
  FOR EACH ROW EXECUTE FUNCTION set_taken_on();

-- RLS giống mọi bảng khác: mỗi người chỉ thấy ảnh của mình.
ALTER TABLE photo_notes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_photo_notes_own ON photo_notes;
CREATE POLICY p_photo_notes_own ON photo_notes
  FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

COMMENT ON TABLE photo_notes IS 'Sổ ảnh: mỗi dòng là một ảnh kèm ghi chú, gắn tuỳ chọn vào một giao dịch';
COMMENT ON COLUMN photo_notes.transaction_id IS 'Giao dịch được gắn; NULL = ảnh đứng rời. Xoá giao dịch thì ảnh vẫn còn';
COMMENT ON COLUMN photo_notes.caption IS 'Ghi chú của chính tấm ảnh, tối đa 500 ký tự';
COMMENT ON COLUMN photo_notes.taken_at IS 'Thời điểm ảnh được ghi lại; dùng để xếp dòng thời gian sổ ảnh';
COMMENT ON COLUMN photo_notes.taken_on IS 'Ngày theo giờ Việt Nam, server sinh từ taken_at';
COMMENT ON COLUMN photo_notes.photo_data IS 'Bytes ảnh, tối đa 512KB (client đã nén trước khi gửi)';
