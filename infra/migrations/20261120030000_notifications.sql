-- Thông báo trong ứng dụng (chuông ở trang chủ) và khoá chống gửi trùng
-- cho các job đẩy tin.
--
-- Một bảng phục vụ hai việc, vì cả hai đều là "một tin đã phát cho một người":
--   * Hộp thư trong app: người dùng mở chuông ra đọc lại.
--   * Khoá idempotent cho job: `dedupe_key` UNIQUE bộ phận bảo đảm
--     `budget-alert` không gửi lại mức 70% của cùng danh mục trong cùng
--     tháng, dù job chạy lại bao nhiêu lần.
--
-- Tách khoá idempotent ra khỏi nội dung là cố ý: nội dung có thể sửa câu chữ
-- mà không làm job gửi lại, còn khoá thì không được đổi.
--
-- `read_at` thay cho cờ boolean: biết lúc nào đã đọc thì sau này thống kê
-- được tỉ lệ mở, và NULL/SET là một cột thay vì hai.

CREATE TABLE notifications (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

  -- Nhóm để client chọn icon và để job lọc theo loại.
  type TEXT NOT NULL CHECK (type IN (
    'budget_alert',
    'daily_reminder',
    'weekly_report',
    'monthly_report',
    'winback',
    'system'
  )),

  title TEXT NOT NULL,
  body TEXT NOT NULL,

  -- Dữ liệu kèm để bấm vào thì mở đúng chỗ (ví dụ category_id, month).
  data JSONB NOT NULL DEFAULT '{}'::jsonb,

  -- Khoá chống trùng do job sinh ra. Tin hệ thống không cần khoá thì để NULL,
  -- và NULL không tham gia UNIQUE nên nhiều tin NULL vẫn hợp lệ.
  dedupe_key TEXT,

  read_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Một tin chỉ phát một lần cho một người.
CREATE UNIQUE INDEX uq_notifications_dedupe
  ON notifications(user_id, dedupe_key)
  WHERE dedupe_key IS NOT NULL;

-- Hộp thư đọc theo thứ tự mới nhất trước, và đếm số chưa đọc cho badge chuông.
CREATE INDEX idx_notifications_user_time
  ON notifications(user_id, created_at DESC);

CREATE INDEX idx_notifications_unread
  ON notifications(user_id)
  WHERE read_at IS NULL;

-- Không có xoá mềm: thông báo cũ bị dọn theo thời gian, không cần giữ dấu vết.
-- Giữ lại là để sau này thêm job dọn tin quá 90 ngày.

ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Người dùng chỉ thấy tin của mình. Không cho INSERT/UPDATE từ client: chỉ
-- server (job, service) ghi, nên policy chỉ mở đường đọc và đường đánh dấu
-- đã đọc. Ghi từ client sẽ cho phép tự tạo thông báo giả.
CREATE POLICY p_notifications_read ON notifications
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY p_notifications_mark_read ON notifications
  FOR UPDATE USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
