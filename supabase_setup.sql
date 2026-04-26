-- ============================================================
-- Umino Shift Reports — Supabase Setup
-- Project: vzeowbriddhvhpishmhn (invoice-tracker)
-- ============================================================

-- 1. Main table
CREATE TABLE IF NOT EXISTS shift_reports (
  id              BIGSERIAL PRIMARY KEY,
  venue           TEXT NOT NULL DEFAULT 'umino',
  shift_date      DATE NOT NULL,
  shift_type      TEXT NOT NULL CHECK (shift_type IN ('evening','morning','full_day')),
  manager_name    TEXT NOT NULL,

  -- KPIs
  revenue         NUMERIC,
  covers          INTEGER,
  deliveries      INTEGER,
  takeaway        INTEGER,
  taxis           INTEGER,
  cash_diff       NUMERIC,        -- positive = shortage, negative = surplus
  returns_count   INTEGER,

  -- Free text
  shift_narrative   TEXT,
  floor_notes       TEXT,
  kitchen_notes     TEXT,
  discipline_issues TEXT,
  wait_times        TEXT,
  late_arrivals     TEXT,
  tech_issues       TEXT,
  shortages         TEXT,
  credits           TEXT,
  daily_tasks       TEXT,

  -- Structured
  returned_dishes JSONB DEFAULT '[]'::jsonb,

  -- Meta
  submitted_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes for common queries
CREATE INDEX IF NOT EXISTS idx_shift_reports_date ON shift_reports (venue, shift_date DESC);
CREATE INDEX IF NOT EXISTS idx_shift_reports_manager ON shift_reports (manager_name);
CREATE INDEX IF NOT EXISTS idx_shift_reports_returned_dishes ON shift_reports USING GIN (returned_dishes);

-- 2. RLS — allow anon insert/select (matching your existing pattern from leads CRM)
ALTER TABLE shift_reports ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "anon insert shift_reports" ON shift_reports;
CREATE POLICY "anon insert shift_reports"
  ON shift_reports FOR INSERT
  TO anon
  WITH CHECK (true);

DROP POLICY IF EXISTS "anon select shift_reports" ON shift_reports;
CREATE POLICY "anon select shift_reports"
  ON shift_reports FOR SELECT
  TO anon
  USING (true);

-- 3. Useful views for the dashboard you'll build later

-- Last 30 days summary per venue
CREATE OR REPLACE VIEW shift_summary_30d AS
SELECT
  venue,
  shift_date,
  shift_type,
  manager_name,
  revenue,
  covers,
  deliveries + COALESCE(takeaway, 0) AS off_premise_count,
  cash_diff,
  returns_count,
  jsonb_array_length(returned_dishes) AS dishes_listed
FROM shift_reports
WHERE shift_date >= CURRENT_DATE - INTERVAL '30 days'
ORDER BY shift_date DESC, shift_type;

-- Returned dish frequency (last 60 days) — top recurring problems
CREATE OR REPLACE VIEW returned_dishes_freq_60d AS
SELECT
  venue,
  TRIM(LOWER(d->>'name')) AS dish_name,
  COUNT(*) AS times_returned,
  array_agg(DISTINCT d->>'reason') FILTER (WHERE d->>'reason' IS NOT NULL AND d->>'reason' <> '') AS reasons,
  MIN(shift_date) AS first_seen,
  MAX(shift_date) AS last_seen
FROM shift_reports,
     jsonb_array_elements(returned_dishes) AS d
WHERE shift_date >= CURRENT_DATE - INTERVAL '60 days'
  AND d->>'name' IS NOT NULL
  AND TRIM(d->>'name') <> ''
GROUP BY venue, TRIM(LOWER(d->>'name'))
HAVING COUNT(*) >= 2
ORDER BY times_returned DESC;

-- Shortage frequency — text search across last 60 days
-- (use ILIKE in queries against shortages column)

-- Cash diff trend
CREATE OR REPLACE VIEW cash_diff_30d AS
SELECT
  venue,
  shift_date,
  shift_type,
  manager_name,
  cash_diff
FROM shift_reports
WHERE shift_date >= CURRENT_DATE - INTERVAL '30 days'
  AND cash_diff IS NOT NULL
  AND cash_diff <> 0
ORDER BY ABS(cash_diff) DESC;
