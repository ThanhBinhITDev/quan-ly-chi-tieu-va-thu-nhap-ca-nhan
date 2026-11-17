-- Enable citext in Supabase's extensions schema.
-- Already applied to project ebbqcnnwqeasozmcqigu on 2026-11-17 as migration
-- 20261117123000_enable_citext_extensions_schema (Supabase version 20261117071940).
-- Kept here so the repository matches the live schema exactly. Do not re-run.

CREATE EXTENSION IF NOT EXISTS citext WITH SCHEMA extensions;
