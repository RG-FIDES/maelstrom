-- Physical contract for the Maelstrom harmonization analytic store.
-- Applied by manipulation/1-ellis-1.R on every rebuild.
--
-- Design notes
--   * Every table carries ellis_run_id so a future multi-run archive needs no
--     schema change, mirroring run_id in the Ferry staging database.
--   * SQLite has no boolean type. Columns named flag_*, sig_*, has_*, and is_*
--     are 0/1 integers here; the parquet mirrors carry them as real logicals.
--   * dementia_frame is a VIEW, not a table, so the analytic frame can never
--     drift from the study_profile rectangle it is drawn from.

-- ---- Provenance --------------------------------------------------------------

CREATE TABLE IF NOT EXISTS ellis_runs (
  ellis_run_id TEXT PRIMARY KEY,
  ferry_run_id TEXT NOT NULL,
  ferry_run_status TEXT,
  ferry_run_completed_at_utc TEXT,
  started_at_utc TEXT NOT NULL,
  completed_at_utc TEXT,
  source_db_path TEXT NOT NULL,
  target_db_path TEXT NOT NULL,
  lexicon_concepts INTEGER,
  lexicon_terms INTEGER,
  studies_in INTEGER,
  studies_out INTEGER,
  studies_in_frame INTEGER,
  status TEXT NOT NULL,
  notes TEXT
);

-- ---- Screening reference and evidence ----------------------------------------

CREATE TABLE IF NOT EXISTS concept_lexicon (
  ellis_run_id TEXT NOT NULL,
  concept TEXT NOT NULL,
  concept_weight REAL NOT NULL,
  term_label TEXT NOT NULL,
  pattern TEXT NOT NULL,
  match_mode TEXT NOT NULL,
  rationale TEXT,
  PRIMARY KEY (ellis_run_id, concept, term_label)
);

CREATE TABLE IF NOT EXISTS screening_evidence (
  ellis_run_id TEXT NOT NULL,
  study_id TEXT NOT NULL,
  concept TEXT NOT NULL,
  term_label TEXT NOT NULL,
  source_field TEXT NOT NULL,
  n_hits INTEGER NOT NULL,
  first_snippet TEXT,
  PRIMARY KEY (ellis_run_id, study_id, concept, term_label, source_field)
);

CREATE TABLE IF NOT EXISTS screening_flow (
  ellis_run_id TEXT NOT NULL,
  step INTEGER NOT NULL,
  criterion TEXT NOT NULL,
  definition TEXT NOT NULL,
  n_remaining INTEGER NOT NULL,
  n_excluded INTEGER NOT NULL,
  PRIMARY KEY (ellis_run_id, step)
);

-- ---- Study spine -------------------------------------------------------------

CREATE TABLE IF NOT EXISTS study_profile (
  -- Identity and provenance
  ellis_run_id TEXT NOT NULL,
  ferry_run_id TEXT NOT NULL,
  study_id TEXT NOT NULL,
  study_acronym TEXT,
  study_name TEXT,
  study_page_url TEXT,
  website_url TEXT,
  inventory_rank INTEGER,
  -- Design
  design_code TEXT,
  design_label TEXT,
  study_start_year INTEGER,
  published INTEGER,
  marker_paper TEXT,
  pubmed_id TEXT,
  -- Enrolment scale
  n_populations INTEGER,
  target_number INTEGER,
  total_participants INTEGER,
  total_samples INTEGER,
  -- Longitudinal depth
  n_waves INTEGER,
  max_population_waves INTEGER,
  first_wave_year INTEGER,
  last_wave_year INTEGER,
  follow_up_span_years INTEGER,
  mean_wave_gap_years REAL,
  n_planned_waves INTEGER,
  flag_longitudinal INTEGER,
  flag_repeated_within_population INTEGER,
  -- Age reach
  min_population_min_age INTEGER,
  max_population_max_age INTEGER,
  flag_older_adult_reach INTEGER,
  -- Geography
  n_countries INTEGER,
  primary_country TEXT,
  countries TEXT,
  flag_multinational INTEGER,
  -- Access terms
  access_data TEXT,
  access_biosamples TEXT,
  access_other TEXT,
  access_fees INTEGER,
  access_restrictions INTEGER,
  maelstrom_authorized INTEGER,
  -- Declared research-area coverage
  attribute_coverage_known INTEGER,
  n_areas INTEGER,
  has_area_cognitive_psychological INTEGER,
  has_area_diseases INTEGER,
  has_area_health_status INTEGER,
  -- Measurement sources observed across waves
  n_events_cognitive INTEGER,
  prop_events_cognitive REAL,
  has_source_cognitive_measures INTEGER,
  has_source_questionnaires INTEGER,
  has_source_physical_measures INTEGER,
  has_source_biological_samples INTEGER,
  has_source_administrative_databases INTEGER,
  has_biosample_blood INTEGER,
  -- Screening signals
  n_dementia_hits INTEGER,
  n_cognition_hits INTEGER,
  n_brain_hits INTEGER,
  n_ageing_hits INTEGER,
  sig_text_dementia INTEGER,
  sig_text_cognition INTEGER,
  sig_text_brain INTEGER,
  sig_text_ageing INTEGER,
  sig_area_cognitive INTEGER,
  sig_source_cognitive INTEGER,
  -- Relevance and frame membership
  relevance_score REAL,
  relevance_tier TEXT,
  flag_topic_relevant INTEGER,
  flag_cognitive_evidence INTEGER,
  flag_in_frame INTEGER,
  frame_exclusion_reason TEXT,
  PRIMARY KEY (ellis_run_id, study_id)
);

-- ---- Population layer --------------------------------------------------------

CREATE TABLE IF NOT EXISTS study_population (
  ellis_run_id TEXT NOT NULL,
  study_id TEXT NOT NULL,
  population_id TEXT NOT NULL,
  population_order INTEGER,
  population_name TEXT,
  participant_number INTEGER,
  sample_number INTEGER,
  minimum_age INTEGER,
  maximum_age INTEGER,
  age_span_years INTEGER,
  flag_newborn INTEGER,
  flag_twins INTEGER,
  flag_older_adult_reach INTEGER,
  n_countries INTEGER,
  primary_country TEXT,
  countries TEXT,
  recruitment_data_sources TEXT,
  recruitment_general TEXT,
  recruitment_specific TEXT,
  n_waves INTEGER,
  first_wave_year INTEGER,
  last_wave_year INTEGER,
  follow_up_span_years INTEGER,
  PRIMARY KEY (ellis_run_id, study_id, population_id)
);

-- ---- Wave layer --------------------------------------------------------------

CREATE TABLE IF NOT EXISTS study_wave (
  ellis_run_id TEXT NOT NULL,
  study_id TEXT NOT NULL,
  population_id TEXT NOT NULL,
  dce_id TEXT NOT NULL,
  wave_name TEXT,
  wave_order_study INTEGER,
  wave_order_population INTEGER,
  start_year INTEGER,
  end_year INTEGER,
  duration_years INTEGER,
  years_since_first_wave INTEGER,
  gap_from_prior_wave_years INTEGER,
  n_data_sources INTEGER,
  has_questionnaires INTEGER,
  has_cognitive_measures INTEGER,
  has_physical_measures INTEGER,
  has_biological_samples INTEGER,
  has_administrative_databases INTEGER,
  has_other_sources INTEGER,
  n_biosamples INTEGER,
  has_biosample_blood INTEGER,
  flag_planned_wave INTEGER,
  PRIMARY KEY (ellis_run_id, study_id, population_id, dce_id)
);

-- ---- Research-area coverage matrix -------------------------------------------

CREATE TABLE IF NOT EXISTS study_domain (
  ellis_run_id TEXT NOT NULL,
  study_id TEXT NOT NULL,
  area_code TEXT NOT NULL,
  area_label TEXT,
  has_area INTEGER NOT NULL,
  attribute_coverage_known INTEGER NOT NULL,
  PRIMARY KEY (ellis_run_id, study_id, area_code)
);

-- ---- Analytic frame ----------------------------------------------------------
-- A view rather than a table: the frame is a subset of the spine by definition,
-- so it cannot fall out of sync with it.

DROP VIEW IF EXISTS dementia_frame;

CREATE VIEW dementia_frame AS
SELECT *
FROM study_profile
WHERE flag_in_frame = 1;

-- ---- Indexes -----------------------------------------------------------------

CREATE INDEX IF NOT EXISTS idx_study_profile_tier
  ON study_profile (ellis_run_id, relevance_tier);

CREATE INDEX IF NOT EXISTS idx_study_profile_frame
  ON study_profile (ellis_run_id, flag_in_frame);

CREATE INDEX IF NOT EXISTS idx_study_profile_design
  ON study_profile (ellis_run_id, design_code);

CREATE INDEX IF NOT EXISTS idx_study_population_study
  ON study_population (ellis_run_id, study_id);

CREATE INDEX IF NOT EXISTS idx_study_wave_study
  ON study_wave (ellis_run_id, study_id);

CREATE INDEX IF NOT EXISTS idx_study_wave_cognitive
  ON study_wave (ellis_run_id, has_cognitive_measures);

CREATE INDEX IF NOT EXISTS idx_study_domain_area
  ON study_domain (ellis_run_id, area_code, has_area);

CREATE INDEX IF NOT EXISTS idx_screening_evidence_concept
  ON screening_evidence (ellis_run_id, concept, study_id);
