CREATE TABLE IF NOT EXISTS extraction_runs (
  run_id TEXT PRIMARY KEY,
  started_at_utc TEXT NOT NULL,
  completed_at_utc TEXT,
  base_url TEXT NOT NULL,
  inventory_url TEXT NOT NULL,
  requested_max_studies INTEGER,
  page_size INTEGER NOT NULL,
  expected_total_studies INTEGER,
  extracted_inventory_studies INTEGER,
  extracted_detail_studies INTEGER,
  status TEXT NOT NULL,
  notes TEXT
);

CREATE TABLE IF NOT EXISTS study_inventory (
  run_id TEXT NOT NULL,
  inventory_rank INTEGER NOT NULL,
  study_id TEXT NOT NULL,
  source_url TEXT NOT NULL,
  study_page_url TEXT NOT NULL,
  study_resource_path TEXT,
  name_en TEXT,
  acronym_en TEXT,
  objectives_html_en TEXT,
  design_code TEXT,
  target_number INTEGER,
  target_no_limit INTEGER,
  summary_json TEXT NOT NULL,
  PRIMARY KEY (run_id, study_id)
);

CREATE TABLE IF NOT EXISTS study_detail_raw (
  run_id TEXT NOT NULL,
  study_id TEXT NOT NULL,
  source_url TEXT NOT NULL,
  fetched_at_utc TEXT NOT NULL,
  payload_json TEXT NOT NULL,
  PRIMARY KEY (run_id, study_id)
);

CREATE TABLE IF NOT EXISTS studies (
  run_id TEXT NOT NULL,
  study_id TEXT NOT NULL,
  published INTEGER,
  study_resource_path TEXT,
  name_en TEXT,
  acronym_en TEXT,
  objectives_html_en TEXT,
  website_url TEXT,
  design_code TEXT,
  follow_up_info_html_en TEXT,
  methods_info_html_en TEXT,
  start_year INTEGER,
  recruitment_target TEXT,
  target_number INTEGER,
  target_no_limit INTEGER,
  access_data TEXT,
  access_biosamples TEXT,
  access_other TEXT,
  access_fees INTEGER,
  access_restrictions INTEGER,
  maelstrom_authorized INTEGER,
  maelstrom_authorizer TEXT,
  maelstrom_authorization_date TEXT,
  specific_authorized INTEGER,
  specific_authorizer TEXT,
  specific_authorization_date TEXT,
  marker_paper TEXT,
  pubmed_id TEXT,
  content_json TEXT,
  PRIMARY KEY (run_id, study_id)
);

CREATE TABLE IF NOT EXISTS study_memberships (
  run_id TEXT NOT NULL,
  study_id TEXT NOT NULL,
  membership_role TEXT NOT NULL,
  member_id TEXT,
  title TEXT,
  first_name TEXT,
  last_name TEXT,
  email TEXT,
  phone TEXT,
  institution_name_en TEXT,
  department_en TEXT,
  city_en TEXT,
  country_iso TEXT,
  member_json TEXT
);

CREATE TABLE IF NOT EXISTS study_attributes (
  run_id TEXT NOT NULL,
  study_id TEXT NOT NULL,
  attribute_namespace TEXT NOT NULL,
  attribute_name TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS study_populations (
  run_id TEXT NOT NULL,
  study_id TEXT NOT NULL,
  population_id TEXT NOT NULL,
  display_order INTEGER,
  name_en TEXT,
  description_html_en TEXT,
  participant_number INTEGER,
  participant_no_limit INTEGER,
  sample_number INTEGER,
  sample_no_limit INTEGER,
  participant_info_html_en TEXT,
  minimum_age INTEGER,
  maximum_age INTEGER,
  newborn INTEGER,
  twins INTEGER,
  territory_html_en TEXT,
  content_json TEXT,
  PRIMARY KEY (run_id, study_id, population_id)
);

CREATE TABLE IF NOT EXISTS population_countries (
  run_id TEXT NOT NULL,
  study_id TEXT NOT NULL,
  population_id TEXT NOT NULL,
  country_iso TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS population_recruitment_terms (
  run_id TEXT NOT NULL,
  study_id TEXT NOT NULL,
  population_id TEXT NOT NULL,
  term_group TEXT NOT NULL,
  term_value TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS data_collection_events (
  run_id TEXT NOT NULL,
  study_id TEXT NOT NULL,
  population_id TEXT NOT NULL,
  dce_id TEXT NOT NULL,
  display_order INTEGER,
  name_en TEXT,
  description_html_en TEXT,
  start_year INTEGER,
  end_year INTEGER,
  other_data_sources_html_en TEXT,
  content_json TEXT,
  PRIMARY KEY (run_id, study_id, population_id, dce_id)
);

CREATE TABLE IF NOT EXISTS dce_data_sources (
  run_id TEXT NOT NULL,
  study_id TEXT NOT NULL,
  population_id TEXT NOT NULL,
  dce_id TEXT NOT NULL,
  data_source_code TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS dce_biosamples (
  run_id TEXT NOT NULL,
  study_id TEXT NOT NULL,
  population_id TEXT NOT NULL,
  dce_id TEXT NOT NULL,
  biosample_code TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_study_inventory_run_rank
  ON study_inventory (run_id, inventory_rank);

CREATE INDEX IF NOT EXISTS idx_studies_design
  ON studies (run_id, design_code);

CREATE INDEX IF NOT EXISTS idx_memberships_role
  ON study_memberships (run_id, membership_role);

CREATE INDEX IF NOT EXISTS idx_attributes_namespace
  ON study_attributes (run_id, attribute_namespace);

CREATE INDEX IF NOT EXISTS idx_populations_study
  ON study_populations (run_id, study_id);

CREATE INDEX IF NOT EXISTS idx_population_countries
  ON population_countries (run_id, country_iso);

CREATE INDEX IF NOT EXISTS idx_population_recruitment_terms
  ON population_recruitment_terms (run_id, term_group, term_value);

CREATE INDEX IF NOT EXISTS idx_dce_study
  ON data_collection_events (run_id, study_id);

CREATE INDEX IF NOT EXISTS idx_dce_sources
  ON dce_data_sources (run_id, data_source_code);

CREATE INDEX IF NOT EXISTS idx_dce_biosamples
  ON dce_biosamples (run_id, biosample_code);