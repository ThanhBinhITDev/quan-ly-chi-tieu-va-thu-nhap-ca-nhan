-- Correction: ảnh PHẢI thuộc một giao dịch.
--
-- Migration trước (20261121220000_photo_notes.sql) cho `transaction_id` NULL
-- để ảnh đứng rời. Sai với mô hình đã chốt: ảnh luôn gắn với một khoản chi
-- hoặc khoản thu — như một tấm ảnh trong dòng thời gian, mỗi ảnh là một ghi
-- chú của chính khoản đó. Chiều ngược lại mới tuỳ chọn: một khoản chi không
-- bắt buộc phải có ảnh.
--
-- Vì vậy:
--   - `transaction_id` NOT NULL.
--   - ON DELETE CASCADE thay cho SET NULL: ảnh không có chỗ đứng nếu giao
--     dịch mất hẳn. (Xoá thường ngày vẫn là xoá mềm qua `deleted_at`.)
--
-- Bảng còn rỗng ở mọi môi trường tại thời điểm này, nhưng vẫn viết theo kiểu
-- chịu được dữ liệu có sẵn: chỉ thêm NOT NULL sau khi đã chắc không còn NULL.

-- 1. Bỏ ràng buộc cũ (SET NULL) và thay bằng CASCADE.
ALTER TABLE photo_notes
  DROP CONSTRAINT IF EXISTS photo_notes_transaction_id_fkey;

ALTER TABLE photo_notes
  ADD CONSTRAINT photo_notes_transaction_id_fkey
    FOREIGN KEY (transaction_id) REFERENCES transactions(id) ON DELETE CASCADE;

-- 2. Siết NOT NULL. Nếu còn dòng mồ côi thì câu này sẽ báo lỗi — đúng ý đồ:
--    thà hỏng to tiếng còn hơn âm thầm xoá ảnh của người dùng.
ALTER TABLE photo_notes
  ALTER COLUMN transaction_id SET NOT NULL;

-- 3. Index cũ có điều kiện `transaction_id IS NOT NULL` không còn cần điều
--    kiện đó nữa; giữ lại cũng vô hại nhưng gọn hơn thì bỏ.
DROP INDEX IF EXISTS idx_photo_tx;
CREATE INDEX IF NOT EXISTS idx_photo_tx
  ON photo_notes(transaction_id) WHERE deleted_at IS NULL;

COMMENT ON COLUMN photo_notes.transaction_id IS
  'Giao dịch mà ảnh thuộc về; bắt buộc. Ảnh không tồn tại độc lập';
