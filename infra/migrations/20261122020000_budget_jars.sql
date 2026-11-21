-- Additive: hũ ngân sách (chia ngân sách tháng thành từng hũ).
--
-- Vì sao bảng mới thay vì tận dụng `budgets`:
--   - `budgets` là HẠN MỨC của một danh mục (hoặc tổng), mỗi danh mục chỉ có
--     một ngân sách đang áp dụng — unique index `uq_budget_active` khoá chặt.
--   - Hũ là cách CHIA ngân sách tổng theo ý người dùng: "Ăn uống 40%",
--     "Đi lại 15%", "Để dành 20%". Một hũ có thể gom nhiều danh mục, và nhiều
--     hũ cùng tồn tại trong một tháng. Nhét vào `budgets` sẽ phải nới unique
--     index và trộn hai khái niệm khác nhau vào một bảng.
--   - Người dùng chưa có hũ nào thì ứng dụng chạy y như trước, không migration
--     dữ liệu, không rủi ro cho ngân sách đang dùng.
--
-- Hai bảng:
--   budget_jars              hũ: tên, tỷ lệ %, màu, thứ tự hiển thị
--   budget_jar_categories    hũ ↔ danh mục (n-n): một hũ gom nhiều danh mục
--
-- Tỷ lệ cộng lại phải ≤ 100% — kiểm ở tầng ứng dụng vì cần đọc toàn bộ hũ
-- của người dùng, không viết được CHECK theo từng dòng. Còn phần dư (100% -
-- tổng tỷ lệ) là "chưa chia", ứng dụng hiển thị thành hũ nhắc người dùng.

CREATE TABLE IF NOT EXISTS budget_jars (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  -- Tỷ lệ phần trăm của ngân sách tháng. Lưu số nguyên để không lệch dấu phẩy
  -- động: 40 nghĩa là 40%. Cho phép 1..100, cộng dồn kiểm ở service.
  share_pct INT NOT NULL CHECK (share_pct BETWEEN 1 AND 100),
  -- Màu hiển thị dạng #RRGGBB; NULL thì ứng dụng tự chọn theo thứ tự.
  color TEXT CHECK (color IS NULL OR color ~ '^#[0-9A-Fa-f]{6}$'),
  sort_order INT NOT NULL DEFAULT 0,
  rev INT NOT NULL DEFAULT 1,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ,
  CONSTRAINT budget_jars_name_len CHECK (char_length(btrim(name)) BETWEEN 1 AND 40)
);

-- Không cho hai hũ cùng tên còn sống: người dùng nhìn danh sách mà thấy hai
-- "Ăn uống" thì không biết hũ nào là hũ nào.
CREATE UNIQUE INDEX IF NOT EXISTS uq_jar_name
  ON budget_jars(user_id, lower(btrim(name)))
  WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_jar_user_sort
  ON budget_jars(user_id, sort_order, created_at)
  WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_jar_sync
  ON budget_jars(user_id, updated_at);

CREATE TABLE IF NOT EXISTS budget_jar_categories (
  jar_id UUID NOT NULL REFERENCES budget_jars(id) ON DELETE CASCADE,
  category_id UUID NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (jar_id, category_id)
);

-- Tra ngược "danh mục này thuộc hũ nào" khi tính chi tiêu theo hũ.
CREATE INDEX IF NOT EXISTS idx_jar_cat_category
  ON budget_jar_categories(category_id);

DROP TRIGGER IF EXISTS trg_updated_at_budget_jars ON budget_jars;
CREATE TRIGGER trg_updated_at_budget_jars BEFORE UPDATE ON budget_jars
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- RLS như mọi bảng khác. Bảng nối không có user_id nên phải kiểm qua hũ cha;
-- dùng EXISTS thay vì join để policy đọc được cả khi INSERT.
ALTER TABLE budget_jars ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_budget_jars_own ON budget_jars;
CREATE POLICY p_budget_jars_own ON budget_jars
  FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

ALTER TABLE budget_jar_categories ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_budget_jar_categories_own ON budget_jar_categories;
CREATE POLICY p_budget_jar_categories_own ON budget_jar_categories
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM budget_jars j
       WHERE j.id = budget_jar_categories.jar_id AND j.user_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM budget_jars j
       WHERE j.id = budget_jar_categories.jar_id AND j.user_id = auth.uid()
    )
  );

COMMENT ON TABLE budget_jars IS 'Hũ ngân sách: cách chia ngân sách tháng theo tỷ lệ phần trăm';
COMMENT ON COLUMN budget_jars.share_pct IS 'Tỷ lệ % của ngân sách tháng, 1..100; tổng các hũ không vượt 100';
COMMENT ON COLUMN budget_jars.sort_order IS 'Thứ tự hiển thị; số nhỏ đứng trước';
COMMENT ON COLUMN budget_jars.color IS 'Màu #RRGGBB; NULL thì ứng dụng tự chọn';
COMMENT ON TABLE budget_jar_categories IS 'Hũ gom những danh mục nào; một danh mục chỉ nên thuộc một hũ';
