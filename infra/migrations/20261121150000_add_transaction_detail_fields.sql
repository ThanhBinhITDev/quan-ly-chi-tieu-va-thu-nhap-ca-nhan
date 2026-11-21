-- Additive: enrich transactions for detailed record keeping.
-- Requested fields: occurred_at already exists; add payment method, income source,
-- and receipt attachment metadata/data (small image, like avatar pattern).
-- No drops, no data rewrites.

ALTER TABLE transactions
  ADD COLUMN IF NOT EXISTS payment_method TEXT
    CHECK (payment_method IN ('cash','bank_transfer','card','ewallet','other')),
  ADD COLUMN IF NOT EXISTS income_source TEXT,
  ADD COLUMN IF NOT EXISTS receipt_mime TEXT
    CHECK (receipt_mime IS NULL OR receipt_mime IN ('image/jpeg','image/png','image/webp')),
  ADD COLUMN IF NOT EXISTS receipt_data BYTEA
    CHECK (receipt_data IS NULL OR octet_length(receipt_data) <= 524288);

ALTER TABLE transactions
  ADD CONSTRAINT tx_receipt_pair
    CHECK ((receipt_data IS NULL) = (receipt_mime IS NULL));

COMMENT ON COLUMN transactions.payment_method IS 'cash|bank_transfer|card|ewallet|other; null for legacy/unspecified';
COMMENT ON COLUMN transactions.income_source IS 'Free-text income source label, mainly for income transactions';
COMMENT ON COLUMN transactions.receipt_mime IS 'Receipt attachment MIME type';
COMMENT ON COLUMN transactions.receipt_data IS 'Receipt attachment bytes, max 512KB';
