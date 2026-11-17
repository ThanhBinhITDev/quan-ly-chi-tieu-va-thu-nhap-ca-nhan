-- Student Finance initial schema
-- Applied 2026-11-17 to project ebbqcnnwqeasozmcqigu as migration
-- 20261117122700_initial_student_finance (Supabase version 20261117072038).
-- Do not re-run against that project; this file is the applied schema snapshot.
-- citext is installed in the extensions schema by
-- 20261117123000_enable_citext_extensions_schema.sql (run first on a fresh project).
-- Source: docs/system-design/01-database-schema.md
-- 12 tables: users, wallets, categories, transactions, budgets, goals,
-- groups, group_members, shared_expenses, shared_shares, recurring_rules, devices.

CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS citext WITH SCHEMA extensions;

CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email CITEXT UNIQUE,
  phone TEXT UNIQUE,
  display_name TEXT NOT NULL,
  plan TEXT NOT NULL DEFAULT 'free' CHECK (plan IN ('free','pro_month','pro_year','pro_student')),
  plan_expires_at TIMESTAMPTZ,
  currency TEXT NOT NULL DEFAULT 'VND',
  timezone TEXT NOT NULL DEFAULT 'Asia/Ho_Chi_Minh',
  onboarded_at TIMESTAMPTZ,
  ai_quota_used JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ,
  CONSTRAINT users_contact CHECK (email IS NOT NULL OR phone IS NOT NULL)
);

CREATE TABLE wallets (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('cash','ewallet','bank','credit')),
  initial_balance BIGINT NOT NULL DEFAULT 0,
  color TEXT,
  icon TEXT,
  sort_order INT NOT NULL DEFAULT 0,
  is_archived BOOLEAN NOT NULL DEFAULT false,
  rev INT NOT NULL DEFAULT 1,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);
CREATE INDEX idx_wallets_user ON wallets(user_id) WHERE deleted_at IS NULL;

CREATE TABLE categories (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('expense','income')),
  icon TEXT,
  color TEXT,
  parent_id UUID REFERENCES categories(id),
  is_system BOOLEAN NOT NULL DEFAULT false,
  sort_order INT NOT NULL DEFAULT 0,
  rev INT NOT NULL DEFAULT 1,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);
CREATE UNIQUE INDEX uq_cat_user_name ON categories
  (COALESCE(user_id, '00000000-0000-0000-0000-000000000000'::uuid), name, type)
  WHERE deleted_at IS NULL;

CREATE TABLE transactions (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  wallet_id UUID NOT NULL REFERENCES wallets(id),
  category_id UUID REFERENCES categories(id),
  type TEXT NOT NULL CHECK (type IN ('expense','income','transfer')),
  amount BIGINT NOT NULL CHECK (amount > 0),
  to_wallet_id UUID REFERENCES wallets(id),
  recurring_rule_id UUID,
  occurrence_date DATE,
  note TEXT,
  occurred_at TIMESTAMPTZ NOT NULL,
  occurred_on DATE NOT NULL,
  source TEXT NOT NULL DEFAULT 'manual' CHECK (source IN ('manual','ocr','recurring','quick')),
  receipt_url TEXT,
  ai_confidence REAL CHECK (ai_confidence IS NULL OR (ai_confidence >= 0 AND ai_confidence <= 1)),
  rev INT NOT NULL DEFAULT 1,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ,
  CONSTRAINT tx_transfer_needs_target CHECK (type <> 'transfer' OR to_wallet_id IS NOT NULL),
  CONSTRAINT tx_transfer_distinct CHECK (type <> 'transfer' OR to_wallet_id <> wallet_id)
);
CREATE INDEX idx_tx_user_time ON transactions(user_id, occurred_on DESC) WHERE deleted_at IS NULL;
CREATE INDEX idx_tx_user_cat_time ON transactions(user_id, category_id, occurred_on DESC) WHERE deleted_at IS NULL;
CREATE INDEX idx_tx_wallet ON transactions(wallet_id, occurred_on DESC) WHERE deleted_at IS NULL;
CREATE INDEX idx_tx_sync ON transactions(user_id, updated_at);

CREATE TABLE budgets (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  category_id UUID REFERENCES categories(id),
  amount BIGINT NOT NULL CHECK (amount > 0),
  period TEXT NOT NULL DEFAULT 'month' CHECK (period IN ('week','month')),
  start_date DATE NOT NULL,
  end_date DATE,
  rev INT NOT NULL DEFAULT 1,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);
CREATE UNIQUE INDEX uq_budget_active ON budgets
  (user_id, COALESCE(category_id,'00000000-0000-0000-0000-000000000000'::uuid), period)
  WHERE deleted_at IS NULL AND end_date IS NULL;

CREATE TABLE goals (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  target_amount BIGINT NOT NULL CHECK (target_amount > 0),
  saved_amount BIGINT NOT NULL DEFAULT 0 CHECK (saved_amount >= 0),
  deadline DATE,
  icon TEXT,
  is_completed BOOLEAN NOT NULL DEFAULT false,
  rev INT NOT NULL DEFAULT 1,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);

CREATE TABLE groups (
  id UUID PRIMARY KEY,
  name TEXT NOT NULL,
  owner_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  invite_code TEXT NOT NULL UNIQUE,
  rev INT NOT NULL DEFAULT 1,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);
CREATE TABLE group_members (
  group_id UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('owner','member')),
  joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  left_at TIMESTAMPTZ,
  PRIMARY KEY (group_id, user_id)
);
CREATE TABLE shared_expenses (
  id UUID PRIMARY KEY,
  group_id UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  payer_id UUID NOT NULL REFERENCES users(id),
  amount BIGINT NOT NULL CHECK (amount > 0),
  note TEXT,
  occurred_on DATE NOT NULL,
  split_method TEXT NOT NULL DEFAULT 'equal' CHECK (split_method IN ('equal','exact')),
  rev INT NOT NULL DEFAULT 1,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);
CREATE INDEX idx_shared_expenses_group ON shared_expenses(group_id, occurred_on DESC) WHERE deleted_at IS NULL;
CREATE TABLE shared_shares (
  expense_id UUID NOT NULL REFERENCES shared_expenses(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id),
  share_amount BIGINT NOT NULL CHECK (share_amount >= 0),
  settled_at TIMESTAMPTZ,
  PRIMARY KEY (expense_id, user_id)
);

CREATE TABLE recurring_rules (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  template JSONB NOT NULL,
  frequency TEXT NOT NULL CHECK (frequency IN ('daily','weekly','monthly','yearly')),
  day_of_month INT CHECK (day_of_month IS NULL OR day_of_month BETWEEN 1 AND 31),
  day_of_week INT CHECK (day_of_week IS NULL OR day_of_week BETWEEN 1 AND 7),
  next_run_on DATE NOT NULL,
  last_run_on DATE,
  is_active BOOLEAN NOT NULL DEFAULT true,
  rev INT NOT NULL DEFAULT 1,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);
CREATE INDEX idx_recurring_due ON recurring_rules(next_run_on) WHERE is_active = true AND deleted_at IS NULL;

CREATE TABLE devices (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  platform TEXT NOT NULL CHECK (platform IN ('android','ios','web')),
  push_token TEXT,
  app_version TEXT,
  last_sync_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- recurring-generate must be idempotent: one transaction per rule and occurrence date.
ALTER TABLE transactions
  ADD CONSTRAINT fk_tx_recurring_rule FOREIGN KEY (recurring_rule_id) REFERENCES recurring_rules(id),
  ADD CONSTRAINT tx_recurring_pair CHECK ((recurring_rule_id IS NULL) = (occurrence_date IS NULL));
CREATE UNIQUE INDEX uq_tx_recurring_occurrence ON transactions(recurring_rule_id, occurrence_date)
  WHERE recurring_rule_id IS NOT NULL;

-- updated_at and occurred_on are server-owned; clients never send either.
CREATE OR REPLACE FUNCTION set_updated_at() RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END; $$;

CREATE OR REPLACE FUNCTION set_occurred_on() RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.occurred_on := (NEW.occurred_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date;
  RETURN NEW;
END; $$;

CREATE TRIGGER trg_updated_at_wallets BEFORE UPDATE ON wallets FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_updated_at_categories BEFORE UPDATE ON categories FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_updated_at_transactions BEFORE UPDATE ON transactions FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_updated_at_budgets BEFORE UPDATE ON budgets FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_updated_at_goals BEFORE UPDATE ON goals FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_updated_at_groups BEFORE UPDATE ON groups FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_updated_at_shared_expenses BEFORE UPDATE ON shared_expenses FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_updated_at_recurring_rules BEFORE UPDATE ON recurring_rules FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_occurred_on BEFORE INSERT OR UPDATE OF occurred_at ON transactions FOR EACH ROW EXECUTE FUNCTION set_occurred_on();

ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE budgets ENABLE ROW LEVEL SECURITY;
ALTER TABLE goals ENABLE ROW LEVEL SECURITY;
ALTER TABLE groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE group_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE shared_expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE shared_shares ENABLE ROW LEVEL SECURITY;
ALTER TABLE recurring_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE devices ENABLE ROW LEVEL SECURITY;

CREATE POLICY p_users_own ON users FOR ALL USING (id = auth.uid()) WITH CHECK (id = auth.uid());
CREATE POLICY p_wallets_own ON wallets FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE POLICY p_categories_read ON categories FOR SELECT USING (user_id IS NULL OR user_id = auth.uid());
CREATE POLICY p_categories_write ON categories FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE POLICY p_transactions_own ON transactions FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE POLICY p_budgets_own ON budgets FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE POLICY p_goals_own ON goals FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE POLICY p_recurring_own ON recurring_rules FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE POLICY p_devices_own ON devices FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

CREATE OR REPLACE FUNCTION is_group_member(g UUID)
RETURNS BOOLEAN LANGUAGE sql SECURITY DEFINER STABLE SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM group_members WHERE group_id = g AND user_id = auth.uid() AND left_at IS NULL);
$$;
CREATE OR REPLACE FUNCTION is_group_owner(g UUID)
RETURNS BOOLEAN LANGUAGE sql SECURITY DEFINER STABLE SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM groups WHERE id = g AND owner_id = auth.uid());
$$;
REVOKE ALL ON FUNCTION is_group_member(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION is_group_owner(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION is_group_member(UUID), is_group_owner(UUID) TO authenticated;

CREATE POLICY p_groups_read ON groups FOR SELECT USING (is_group_member(id) OR owner_id = auth.uid());
CREATE POLICY p_groups_insert ON groups FOR INSERT WITH CHECK (owner_id = auth.uid());
CREATE POLICY p_groups_write ON groups FOR UPDATE USING (owner_id = auth.uid()) WITH CHECK (owner_id = auth.uid());
CREATE POLICY p_groups_delete ON groups FOR DELETE USING (owner_id = auth.uid());
CREATE POLICY p_members_read ON group_members FOR SELECT USING (is_group_member(group_id));
CREATE POLICY p_members_insert ON group_members FOR INSERT WITH CHECK (is_group_owner(group_id));
CREATE POLICY p_expenses_read ON shared_expenses FOR SELECT USING (is_group_member(group_id));
CREATE POLICY p_expenses_insert ON shared_expenses FOR INSERT WITH CHECK (is_group_member(group_id) AND payer_id = auth.uid());
CREATE POLICY p_expenses_write ON shared_expenses FOR UPDATE USING (is_group_member(group_id) AND (payer_id = auth.uid() OR is_group_owner(group_id))) WITH CHECK (is_group_member(group_id));
CREATE POLICY p_expenses_delete ON shared_expenses FOR DELETE USING (is_group_member(group_id) AND (payer_id = auth.uid() OR is_group_owner(group_id)));
CREATE POLICY p_shares_read ON shared_shares FOR SELECT USING (EXISTS (SELECT 1 FROM shared_expenses e WHERE e.id = expense_id AND is_group_member(e.group_id)));
CREATE POLICY p_shares_insert ON shared_shares FOR INSERT WITH CHECK (EXISTS (SELECT 1 FROM shared_expenses e WHERE e.id = expense_id AND e.payer_id = auth.uid()));
CREATE POLICY p_shares_delete ON shared_shares FOR DELETE USING (EXISTS (SELECT 1 FROM shared_expenses e WHERE e.id = expense_id AND e.payer_id = auth.uid()));
CREATE POLICY p_shares_settle ON shared_shares FOR UPDATE USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

-- Settling is the only member-owned update; the payer/service layer owns share_amount changes.
REVOKE UPDATE ON shared_shares FROM authenticated;
GRANT UPDATE (settled_at) ON shared_shares TO authenticated;
