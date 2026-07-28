rm(list = ls(all.names = TRUE)) # Clear the memory of variables from previous run.
cat("\014") # Clear the console
cat("Working directory: ", getwd()) # Must be set to Project Directory

# ---- SECTION: Maelstrom Harmonization Ellis ----------------------------------
# Turns the Ferry staging database into analysis-ready rectangles for exploring
# the harmonization potential of longitudinal studies that touch dementia and
# cognitive decline.
#
# Input  : data-private/derived/maelstrom/maelstrom-catalog.sqlite  (0-ferry-extract.R)
# Output : data-private/derived/maelstrom/maelstrom-analytic.sqlite
#          data-private/derived/ellis/*.parquet
#          data-public/metadata/ellis-ontology/*.csv
#
# The lane makes exactly one opinionated judgement -- whether a study is relevant
# to dementia or cognitive decline -- and it makes that judgement auditable. Every
# textual signal is recorded in `screening_evidence` with the matched term, the
# field it was found in, and a surrounding snippet. Nothing is asserted here that
# a reader cannot check.

# ---- load-packages -----------------------------------------------------------
library(dplyr, warn.conflicts = FALSE)
library(tidyr, warn.conflicts = FALSE)
requireNamespace("stringr")
requireNamespace("DBI")
requireNamespace("RSQLite")
requireNamespace("arrow")
requireNamespace("config")

# ---- load-sources ------------------------------------------------------------
if (file.exists("./scripts/common-functions.R")) {
  source("./scripts/common-functions.R", local = TRUE)
}

# ---- declare-globals ---------------------------------------------------------
PROJECT_CONFIG <- config::get(file = "./config.yml")

DEFAULT_SOURCE_DB <- PROJECT_CONFIG$database$maelstrom_catalog$staging
DEFAULT_TARGET_DB <- PROJECT_CONFIG$database$maelstrom_catalog$analytic
DEFAULT_SCHEMA_PATH <- "./manipulation/maelstrom-analytic-schema.sql"
DEFAULT_PARQUET_DIR <- PROJECT_CONFIG$directories$ellis_parquet
DEFAULT_ONTOLOGY_DIR <- PROJECT_CONFIG$directories$ellis_ontology

if (is.null(DEFAULT_SOURCE_DB) || !nzchar(DEFAULT_SOURCE_DB)) {
  stop("Missing database.maelstrom_catalog.staging in config.yml")
}
if (is.null(DEFAULT_TARGET_DB) || !nzchar(DEFAULT_TARGET_DB)) {
  stop("Missing database.maelstrom_catalog.analytic in config.yml")
}

# Analytic thresholds. Every one of these is a decision, so none of them hides
# inside the transformation code.
MIN_WAVES_LONGITUDINAL <- 2L # data collection events required to call a study longitudinal
OLDER_ADULT_MIN_AGE <- 50L # population minimum age at or above which recruitment is older-adult
OLDER_ADULT_MAX_AGE <- 65L # population maximum age at or above which the study reaches later life
TIER_PROBABLE_SCORE <- 3 # relevance score at or above which a non-core study is "probable"
TIER_POSSIBLE_SCORE <- 1 # relevance score at or above which a study is at least "possible"
SNIPPET_WINDOW <- 60L # characters of context kept on each side of a lexicon hit
CURRENT_YEAR <- as.integer(format(Sys.Date(), "%Y"))

# Scoring weights for the structured (non-textual) signals. Textual weights live
# in the lexicon itself so that the lexicon table is self-describing.
WEIGHT_SOURCE_COGNITIVE <- 2 # study declares cognitive_measures at >= 1 event
WEIGHT_AREA_COGNITIVE <- 1 # study is annotated Cognitive_psychological_measures

# Controlled vocabulary of the Maelstrom event data-source taxonomy. The source
# spells the administrative term "administratives_databases".
DATA_SOURCE_CODES <- c(
  questionnaires = "has_questionnaires",
  cognitive_measures = "has_cognitive_measures",
  physical_measures = "has_physical_measures",
  biological_samples = "has_biological_samples",
  administratives_databases = "has_administrative_databases",
  others = "has_other_sources"
)

DESIGN_LABELS <- c(
  cohort_study = "Cohort study",
  registry = "Registry",
  cross_sectional = "Cross-sectional",
  case_control = "Case-control",
  clinical_trial = "Clinical trial",
  case_only = "Case only",
  other = "Other"
)

RELEVANCE_TIERS <- c("unrelated", "possible", "probable", "core")

# Free-text fields scanned by the lexicon, and the label recorded in the
# evidence table for each.
TEXT_FIELDS <- c(
  study_name = "Study name",
  study_acronym = "Study acronym",
  study_objectives = "Study objectives",
  study_methods_info = "Study methods description",
  study_follow_up_info = "Study follow-up description",
  population_text = "Population names and descriptions",
  event_text = "Data collection event names and descriptions"
)

# ---- declare-lexicon ---------------------------------------------------------
# Four concepts, ordered by how specific they are to the research question.
# `concept_weight` is the contribution a concept makes to `relevance_score` when
# at least one of its terms matches anywhere in a study's text. Weight is per
# concept, not per hit: a study that says "dementia" fourteen times is not four
# times more relevant than one that says it once.
#
# `ageing` carries weight 0 by design. Studying older adults is not the same as
# studying cognition, so the signal is retained as description and excluded from
# the score.

CONCEPT_WEIGHTS <- c(dementia = 3, cognition = 2, brain = 1, ageing = 0)

CONCEPT_LEXICON <- rbind(
  data.frame(
    concept = "dementia",
    term_label = c(
      "dementia", "alzheimer", "mild cognitive impairment", "MCI",
      "cognitive impairment", "cognitive decline", "lewy body",
      "frontotemporal", "neurodegenerative", "amyloid", "neurofibrillary",
      "vascular cognitive"
    ),
    pattern = c(
      "dementia", "alzheimer", "mild cognitive impairment", "\\bmci\\b",
      "cognitive impairment", "cognitive declin", "lewy bod",
      "frontotemporal", "neurodegenerat", "amyloid", "neurofibrillary",
      "vascular cognitive"
    ),
    stringsAsFactors = FALSE
  ),
  data.frame(
    concept = "cognition",
    term_label = c(
      "cognition or cognitive", "neurocognitive", "neuropsychological",
      "memory", "executive function", "MMSE", "mini-mental", "MoCA",
      "montreal cognitive assessment", "processing speed"
    ),
    pattern = c(
      "cogniti", "neurocogniti", "neuropsycholog",
      "\\bmemory\\b", "executive function", "\\bmmse\\b", "mini.mental", "\\bmoca\\b",
      "montreal cognitive assessment", "processing speed"
    ),
    stringsAsFactors = FALSE
  ),
  data.frame(
    concept = "brain",
    term_label = c(
      "hippocampus", "white matter", "neuroimaging", "brain MRI",
      "APOE", "cerebrospinal fluid", "brain volume", "brain health"
    ),
    pattern = c(
      "hippocamp", "white matter", "neuroimag", "brain mri",
      "\\bapoe\\b", "cerebrospinal", "brain volume", "brain health"
    ),
    stringsAsFactors = FALSE
  ),
  data.frame(
    concept = "ageing",
    term_label = c(
      "ageing or aging", "older adults", "elderly", "geriatric",
      "longevity", "senescence", "late life"
    ),
    pattern = c(
      "\\bage?ing\\b", "older adult", "elderly", "geriatric",
      "longevity", "senescen", "late.life"
    ),
    stringsAsFactors = FALSE
  )
)

CONCEPT_LEXICON <- CONCEPT_LEXICON %>%
  mutate(
    concept_weight = unname(CONCEPT_WEIGHTS[concept]),
    match_mode = ifelse(grepl("\\\\b", pattern), "word", "substring"),
    rationale = recode(
      concept,
      dementia = "Names the disease spectrum directly; sufficient on its own for the core tier",
      cognition = "Names cognitive function or a named cognitive instrument",
      brain = "Names a neural substrate or biomarker relevant to cognitive decline",
      ageing = "Describes an older-adult context; recorded but deliberately unscored"
    )
  ) %>%
  select(concept, concept_weight, term_label, pattern, match_mode, rationale)

# ---- declare-ontology --------------------------------------------------------
# Cognitive grouping of the physical objects, mirroring the Ferry's ontology so
# the two manifests read the same way.
CACHE_TABLE_ONTOLOGY <- data.frame(
  table_name = c(
    "ellis_runs",
    "concept_lexicon",
    "screening_evidence",
    "screening_flow",
    "study_profile",
    "study_population",
    "study_wave",
    "study_domain",
    "dementia_frame"
  ),
  object_type = c(
    "table", "table", "table", "table", "table", "table", "table", "table", "view"
  ),
  table_group = c(
    "1-run-provenance",
    "2-screening-apparatus",
    "2-screening-apparatus",
    "2-screening-apparatus",
    "3-study-spine",
    "4-population-layer",
    "5-wave-layer",
    "6-coverage-matrix",
    "7-analytic-frame"
  ),
  grain = c(
    "one row per Ellis run",
    "one row per run, concept, and lexicon term",
    "one row per run, study, concept, term, and source field",
    "one row per run and screening step",
    "one row per run and study",
    "one row per run, study, and population",
    "one row per run, study, population, and data collection event",
    "one row per run, study, and research area",
    "one row per run and in-frame study"
  ),
  stringsAsFactors = FALSE
)

CACHE_RELATIONSHIP_ONTOLOGY <- data.frame(
  parent_table = c(
    "study_profile", "study_profile", "study_profile", "study_population"
  ),
  child_table = c(
    "study_population", "study_domain", "screening_evidence", "study_wave"
  ),
  join_keys = c(
    "ellis_run_id|study_id",
    "ellis_run_id|study_id",
    "ellis_run_id|study_id",
    "ellis_run_id|study_id|population_id"
  ),
  declared_cardinality = c("1:N", "1:N", "1:N", "1:N"),
  stringsAsFactors = FALSE
)

CACHE_VOCABULARY_ONTOLOGY <- data.frame(
  table_name = c(
    "study_profile", "study_profile", "study_profile", "study_profile",
    "study_profile", "study_profile", "study_profile", "study_profile",
    "study_profile", "study_profile", "study_profile",
    "study_domain",
    "concept_lexicon", "concept_lexicon",
    "screening_evidence", "screening_evidence"
  ),
  column_name = c(
    "design_code", "design_label", "relevance_tier", "frame_exclusion_reason",
    "primary_country", "access_data", "access_biosamples", "access_other",
    "flag_longitudinal", "flag_in_frame", "flag_older_adult_reach",
    "area_code",
    "concept", "match_mode",
    "concept", "source_field"
  ),
  vocabulary_label = c(
    "source study design taxonomy",
    "readable study design label",
    "dementia relevance tier",
    "first failing frame criterion",
    "most frequent population country",
    "data access channel",
    "biosample access channel",
    "other access channel",
    "two or more data collection events",
    "analytic frame membership",
    "recruitment reaches later life",
    "Maelstrom research area",
    "screening concept",
    "regex matching mode",
    "screening concept",
    "field the term was found in"
  ),
  stringsAsFactors = FALSE
)

# Columns held out of value profiling: free text or wide identifiers whose
# distinct values carry no vocabulary.
OPAQUE_COLUMNS <- c(
  "study_name", "study_page_url", "website_url", "marker_paper", "pubmed_id",
  "countries", "population_name", "wave_name", "first_snippet", "pattern",
  "rationale", "notes", "definition", "criterion",
  "recruitment_data_sources", "recruitment_general", "recruitment_specific",
  "source_db_path", "target_db_path"
)

# ---- declare-functions -------------------------------------------------------
`%||%` <- function(lhs, rhs) if (is.null(lhs) || length(lhs) == 0) rhs else lhs

parse_args <- function(args) {
  parsed <- list(
    source_db = DEFAULT_SOURCE_DB,
    target_db = DEFAULT_TARGET_DB,
    schema_path = DEFAULT_SCHEMA_PATH,
    parquet_dir = DEFAULT_PARQUET_DIR,
    ontology_dir = DEFAULT_ONTOLOGY_DIR
  )

  for (argument in args) {
    parts <- strsplit(argument, "=", fixed = TRUE)[[1]]
    if (length(parts) != 2) next

    key <- parts[[1]]
    value <- parts[[2]]

    if (key == "--source-db") parsed$source_db <- value
    if (key == "--target-db") parsed$target_db <- value
    if (key == "--schema-path") parsed$schema_path <- value
    if (key == "--parquet-dir") parsed$parquet_dir <- value
    if (key == "--ontology-dir") parsed$ontology_dir <- value
  }

  parsed
}

ensure_dir <- function(path) {
  if (!dir.exists(path)) dir.create(path, recursive = TRUE)
  invisible(path)
}

ensure_parent_dir <- function(path) {
  ensure_dir(dirname(path))
}

now_utc <- function() format(Sys.time(), tz = "UTC", usetz = TRUE)

quote_identifier <- function(identifier) paste0("\"", identifier, "\"")

# Strip authored HTML down to plain lowercase text suitable for term matching.
strip_html <- function(text) {
  cleaned <- ifelse(is.na(text), "", as.character(text))
  cleaned <- gsub("<[^>]*>", " ", cleaned)
  cleaned <- gsub("&nbsp;", " ", cleaned, fixed = TRUE)
  cleaned <- gsub("&amp;", "&", cleaned, fixed = TRUE)
  cleaned <- gsub("&lt;", "<", cleaned, fixed = TRUE)
  cleaned <- gsub("&gt;", ">", cleaned, fixed = TRUE)
  cleaned <- gsub("&quot;", "\"", cleaned, fixed = TRUE)
  cleaned <- gsub("&#39;", "'", cleaned, fixed = TRUE)
  cleaned <- gsub("[[:space:]]+", " ", cleaned)
  tolower(trimws(cleaned))
}

# Aggregations that return NA rather than Inf or 0 when every input is missing.
sum_or_na <- function(x) if (all(is.na(x))) NA_integer_ else as.integer(sum(x, na.rm = TRUE))
min_or_na <- function(x) if (all(is.na(x))) NA_integer_ else as.integer(min(x, na.rm = TRUE))
max_or_na <- function(x) if (all(is.na(x))) NA_integer_ else as.integer(max(x, na.rm = TRUE))
mean_or_na <- function(x) if (all(is.na(x))) NA_real_ else as.numeric(mean(x, na.rm = TRUE))

# Most frequent non-missing value; ties resolved by first appearance.
modal_value <- function(x) {
  values <- x[!is.na(x)]
  if (length(values) == 0) return(NA_character_)
  counts <- table(values)
  top <- names(counts)[counts == max(counts)]
  values[values %in% top][1]
}

collapse_distinct <- function(x, separator = "|") {
  values <- sort(unique(x[!is.na(x)]))
  if (length(values) == 0) return(NA_character_)
  paste(values, collapse = separator)
}

# Guarantee that a pivoted frame carries every expected column, so a vocabulary
# term absent from the current catalogue does not silently drop a column.
ensure_columns <- function(data, columns, fill = FALSE) {
  missing_columns <- setdiff(columns, names(data))
  for (column in missing_columns) {
    data[[column]] <- fill
  }
  data
}

# Prettify a Maelstrom area code such as Cognitive_psychological_measures.
prettify_area <- function(code) {
  label <- gsub("_", " ", code)
  paste0(toupper(substr(label, 1, 1)), substr(label, 2, nchar(label)))
}

apply_schema <- function(con, schema_path) {
  if (!file.exists(schema_path)) {
    stop("Schema file not found: ", schema_path)
  }

  # Line comments are removed before splitting so a semicolon inside a comment
  # cannot fracture a statement.
  lines <- sub("--.*$", "", readLines(schema_path, warn = FALSE))
  statements <- trimws(strsplit(paste(lines, collapse = "\n"), ";", fixed = TRUE)[[1]])
  statements <- statements[nzchar(statements)]

  for (statement in statements) {
    DBI::dbExecute(con, statement)
  }

  invisible(length(statements))
}

# Factors and logicals are the right representation in R and parquet; SQLite
# wants text and integers. This is the only place that difference is handled.
db_ready <- function(data) {
  data %>%
    mutate(
      across(where(is.factor), as.character),
      across(where(is.logical), as.integer)
    ) %>%
    as.data.frame()
}

# Compare an R rectangle against the declared physical contract before writing,
# so drift is reported as a named column difference rather than a DBI error.
assert_schema_conformance <- function(con, table_name, data) {
  declared <- DBI::dbGetQuery(
    con,
    paste0("PRAGMA table_info(", quote_identifier(table_name), ")")
  )$name

  extra <- setdiff(names(data), declared)
  absent <- setdiff(declared, names(data))

  if (length(extra) > 0 || length(absent) > 0) {
    stop(
      "Schema drift in `", table_name, "`.\n",
      if (length(extra) > 0) paste0("  In R but not in the SQL contract: ", paste(extra, collapse = ", "), "\n") else "",
      if (length(absent) > 0) paste0("  In the SQL contract but not in R: ", paste(absent, collapse = ", "), "\n") else "",
      "  Reconcile manipulation/1-ellis-1.R with manipulation/maelstrom-analytic-schema.sql."
    )
  }

  invisible(TRUE)
}

write_rectangle <- function(con, table_name, data) {
  prepared <- db_ready(data)
  assert_schema_conformance(con, table_name, prepared)
  DBI::dbWriteTable(con, table_name, prepared, append = TRUE)
  invisible(nrow(prepared))
}

# ---- SECTION: Extraction -----------------------------------------------------
# Read one complete Ferry run. Every table is filtered to that run so the lane
# survives a future multi-run staging archive without modification.

# ---- load-data ---------------------------------------------------------------
arguments <- parse_args(commandArgs(trailingOnly = TRUE))

if (!file.exists(arguments$source_db)) {
  stop(
    "Ferry staging database not found: ", arguments$source_db,
    "\nRun ./manipulation/0-ferry-extract.R first."
  )
}

ellis_run_id <- paste0("ellis-", format(Sys.time(), "%Y%m%dT%H%M%S", tz = "UTC"))
ellis_started_at <- now_utc()

source_con <- DBI::dbConnect(RSQLite::SQLite(), arguments$source_db)

ds_run <- DBI::dbGetQuery(
  source_con,
  "SELECT *
   FROM extraction_runs
   WHERE status = 'completed'
   ORDER BY completed_at_utc DESC
   LIMIT 1"
)

if (nrow(ds_run) != 1) {
  DBI::dbDisconnect(source_con)
  stop("No completed extraction run found in ", arguments$source_db)
}

ferry_run_id <- ds_run$run_id[[1]]

read_ferry <- function(table_name) {
  DBI::dbGetQuery(
    source_con,
    paste0("SELECT * FROM ", quote_identifier(table_name), " WHERE run_id = ?"),
    params = list(ferry_run_id)
  )
}

ds_studies_raw <- read_ferry("studies")
ds_inventory_raw <- read_ferry("study_inventory")
ds_attributes_raw <- read_ferry("study_attributes")
ds_populations_raw <- read_ferry("study_populations")
ds_countries_raw <- read_ferry("population_countries")
ds_recruitment_raw <- read_ferry("population_recruitment_terms")
ds_events_raw <- read_ferry("data_collection_events")
ds_event_sources_raw <- read_ferry("dce_data_sources")
ds_event_biosamples_raw <- read_ferry("dce_biosamples")

DBI::dbDisconnect(source_con)

cat("\nFerry run: ", ferry_run_id, sep = "")
cat("\nStudies read: ", nrow(ds_studies_raw), sep = "")

# ---- SECTION: Transformation -------------------------------------------------
# Built from the inside out: waves aggregate into populations, populations
# aggregate into studies, and the study spine is scored last.

# ---- tweak-waves -------------------------------------------------------------
# One row per data collection event, with its measurement sources pivoted into
# flags and its position in the study's and population's wave sequence.

ds_source_flags <- ds_event_sources_raw %>%
  distinct(study_id, population_id, dce_id, data_source_code) %>%
  filter(data_source_code %in% names(DATA_SOURCE_CODES)) %>%
  mutate(present = TRUE) %>%
  pivot_wider(
    names_from = data_source_code,
    values_from = present,
    values_fill = FALSE
  ) %>%
  ensure_columns(names(DATA_SOURCE_CODES), fill = FALSE) %>%
  rename(all_of(setNames(names(DATA_SOURCE_CODES), unname(DATA_SOURCE_CODES)))) %>%
  mutate(
    n_data_sources = rowSums(across(all_of(unname(DATA_SOURCE_CODES))))
  )

ds_biosample_flags <- ds_event_biosamples_raw %>%
  distinct(study_id, population_id, dce_id, biosample_code) %>%
  group_by(study_id, population_id, dce_id) %>%
  summarise(
    n_biosamples = n_distinct(biosample_code),
    has_biosample_blood = any(biosample_code == "blood"),
    .groups = "drop"
  )

ds_wave <- ds_events_raw %>%
  transmute(
    study_id,
    population_id,
    dce_id,
    wave_name = name_en,
    display_order = as.integer(display_order),
    start_year = as.integer(start_year),
    end_year = as.integer(end_year)
  ) %>%
  left_join(ds_source_flags, by = c("study_id", "population_id", "dce_id")) %>%
  left_join(ds_biosample_flags, by = c("study_id", "population_id", "dce_id")) %>%
  mutate(
    across(all_of(unname(DATA_SOURCE_CODES)), ~ tidyr::replace_na(.x, FALSE)),
    n_data_sources = tidyr::replace_na(n_data_sources, 0L),
    n_biosamples = tidyr::replace_na(n_biosamples, 0L),
    has_biosample_blood = tidyr::replace_na(has_biosample_blood, FALSE),
    duration_years = end_year - start_year,
    flag_planned_wave = !is.na(start_year) & start_year > CURRENT_YEAR
  ) %>%
  arrange(study_id, start_year, population_id, display_order, dce_id) %>%
  group_by(study_id) %>%
  mutate(
    wave_order_study = row_number(),
    years_since_first_wave = start_year - min_or_na(start_year)
  ) %>%
  ungroup() %>%
  arrange(study_id, population_id, start_year, display_order, dce_id) %>%
  group_by(study_id, population_id) %>%
  mutate(
    wave_order_population = row_number(),
    gap_from_prior_wave_years = start_year - lag(start_year)
  ) %>%
  ungroup() %>%
  mutate(ellis_run_id = ellis_run_id) %>%
  select(
    ellis_run_id, study_id, population_id, dce_id, wave_name,
    wave_order_study, wave_order_population,
    start_year, end_year, duration_years,
    years_since_first_wave, gap_from_prior_wave_years,
    n_data_sources,
    has_questionnaires, has_cognitive_measures, has_physical_measures,
    has_biological_samples, has_administrative_databases, has_other_sources,
    n_biosamples, has_biosample_blood, flag_planned_wave
  )

# ---- tweak-populations -------------------------------------------------------
# One row per population, carrying its age eligibility, geography, recruitment
# vocabulary, and the follow-up window implied by its waves.

ds_population_country <- ds_countries_raw %>%
  group_by(study_id, population_id) %>%
  summarise(
    n_countries = n_distinct(country_iso),
    primary_country = first(country_iso),
    countries = collapse_distinct(country_iso),
    .groups = "drop"
  )

ds_population_recruitment <- ds_recruitment_raw %>%
  group_by(study_id, population_id, term_group) %>%
  summarise(terms = collapse_distinct(term_value), .groups = "drop") %>%
  pivot_wider(names_from = term_group, values_from = terms) %>%
  ensure_columns(
    c("data_sources", "general_population_sources", "specific_population_sources"),
    fill = NA_character_
  ) %>%
  rename(
    recruitment_data_sources = data_sources,
    recruitment_general = general_population_sources,
    recruitment_specific = specific_population_sources
  )

ds_population_waves <- ds_wave %>%
  group_by(study_id, population_id) %>%
  summarise(
    n_waves = n(),
    first_wave_year = min_or_na(start_year),
    last_wave_year = max_or_na(start_year),
    .groups = "drop"
  ) %>%
  mutate(follow_up_span_years = last_wave_year - first_wave_year)

ds_population <- ds_populations_raw %>%
  transmute(
    study_id,
    population_id,
    population_order = as.integer(display_order),
    population_name = name_en,
    participant_number = as.integer(participant_number),
    sample_number = as.integer(sample_number),
    minimum_age = as.integer(minimum_age),
    maximum_age = as.integer(maximum_age),
    flag_newborn = as.logical(newborn),
    flag_twins = as.logical(twins)
  ) %>%
  left_join(ds_population_country, by = c("study_id", "population_id")) %>%
  left_join(ds_population_recruitment, by = c("study_id", "population_id")) %>%
  left_join(ds_population_waves, by = c("study_id", "population_id")) %>%
  mutate(
    age_span_years = maximum_age - minimum_age,
    # Later-life reach is claimed only from a stated age boundary. Missing age
    # metadata yields FALSE, never TRUE.
    flag_older_adult_reach = tidyr::replace_na(minimum_age >= OLDER_ADULT_MIN_AGE, FALSE) |
      tidyr::replace_na(maximum_age >= OLDER_ADULT_MAX_AGE, FALSE),
    n_countries = tidyr::replace_na(n_countries, 0L),
    n_waves = tidyr::replace_na(n_waves, 0L),
    ellis_run_id = ellis_run_id
  ) %>%
  select(
    ellis_run_id, study_id, population_id, population_order, population_name,
    participant_number, sample_number,
    minimum_age, maximum_age, age_span_years,
    flag_newborn, flag_twins, flag_older_adult_reach,
    n_countries, primary_country, countries,
    recruitment_data_sources, recruitment_general, recruitment_specific,
    n_waves, first_wave_year, last_wave_year, follow_up_span_years
  )

# ---- tweak-domains -----------------------------------------------------------
# A complete study-by-area rectangle. Areas are read from the data rather than
# hardcoded, and `attribute_coverage_known` records whether the study was
# annotated at all -- without it, has_area = FALSE is unreadable, because the
# Ferry manifest shows only 44% of studies carry any Mlstr_area annotation.

ds_areas_raw <- ds_attributes_raw %>%
  filter(attribute_namespace == "Mlstr_area") %>%
  distinct(study_id, area_code = attribute_name)

area_codes <- sort(unique(ds_areas_raw$area_code))

ds_domain <- expand_grid(
  study_id = sort(unique(ds_studies_raw$study_id)),
  area_code = area_codes
) %>%
  left_join(ds_areas_raw %>% mutate(has_area = TRUE), by = c("study_id", "area_code")) %>%
  mutate(
    has_area = tidyr::replace_na(has_area, FALSE),
    area_label = prettify_area(area_code)
  ) %>%
  group_by(study_id) %>%
  mutate(attribute_coverage_known = any(has_area)) %>%
  ungroup() %>%
  mutate(ellis_run_id = ellis_run_id) %>%
  select(ellis_run_id, study_id, area_code, area_label, has_area, attribute_coverage_known) %>%
  arrange(study_id, area_code)

# ---- screen-text -------------------------------------------------------------
# Assemble one plain-text document per study and source field, then run the
# lexicon over it. Population and event text are collapsed to the study level:
# the question asked here is whether the study is about cognition, not which
# wave mentioned it.

ds_corpus <- bind_rows(
  ds_studies_raw %>% transmute(study_id, source_field = "study_name", text = name_en),
  ds_studies_raw %>% transmute(study_id, source_field = "study_acronym", text = acronym_en),
  ds_studies_raw %>% transmute(study_id, source_field = "study_objectives", text = objectives_html_en),
  ds_studies_raw %>% transmute(study_id, source_field = "study_methods_info", text = methods_info_html_en),
  ds_studies_raw %>% transmute(study_id, source_field = "study_follow_up_info", text = follow_up_info_html_en),
  ds_populations_raw %>%
    transmute(study_id, source_field = "population_text", text = paste(name_en, description_html_en)),
  ds_events_raw %>%
    transmute(study_id, source_field = "event_text", text = paste(name_en, description_html_en))
) %>%
  group_by(study_id, source_field) %>%
  summarise(text = paste(text, collapse = " "), .groups = "drop") %>%
  mutate(text = strip_html(text)) %>%
  filter(nzchar(text))

match_lexicon <- function(corpus, lexicon) {
  hits <- vector("list", nrow(lexicon))

  for (index in seq_len(nrow(lexicon))) {
    pattern <- lexicon$pattern[[index]]
    counts <- stringr::str_count(corpus$text, pattern)
    matched <- which(counts > 0)

    if (length(matched) == 0) next

    locations <- stringr::str_locate(corpus$text[matched], pattern)
    starts <- pmax(1L, locations[, "start"] - SNIPPET_WINDOW)
    ends <- pmin(nchar(corpus$text[matched]), locations[, "end"] + SNIPPET_WINDOW)

    hits[[index]] <- data.frame(
      study_id = corpus$study_id[matched],
      concept = lexicon$concept[[index]],
      term_label = lexicon$term_label[[index]],
      source_field = corpus$source_field[matched],
      n_hits = as.integer(counts[matched]),
      first_snippet = substr(corpus$text[matched], starts, ends),
      stringsAsFactors = FALSE
    )
  }

  bind_rows(hits)
}

ds_evidence <- match_lexicon(ds_corpus, CONCEPT_LEXICON) %>%
  mutate(ellis_run_id = ellis_run_id) %>%
  select(ellis_run_id, study_id, concept, term_label, source_field, n_hits, first_snippet) %>%
  arrange(study_id, concept, term_label, source_field)

ds_concept_signal <- ds_evidence %>%
  group_by(study_id, concept) %>%
  summarise(n_hits = sum(n_hits), .groups = "drop") %>%
  pivot_wider(
    names_from = concept,
    values_from = n_hits,
    names_prefix = "n_",
    values_fill = 0L
  ) %>%
  ensure_columns(paste0("n_", names(CONCEPT_WEIGHTS)), fill = 0L) %>%
  rename_with(~ paste0(.x, "_hits"), all_of(paste0("n_", names(CONCEPT_WEIGHTS))))

# ---- tweak-profile -----------------------------------------------------------
# The study spine. Structured signals are folded in first, textual signals
# second, and the relevance score is the last thing computed so that every
# input to it is already visible in a column of this rectangle.

ds_study_waves <- ds_wave %>%
  group_by(study_id) %>%
  summarise(
    n_waves = n(),
    first_wave_year = min_or_na(start_year),
    last_wave_year = max_or_na(start_year),
    mean_wave_gap_years = mean_or_na(gap_from_prior_wave_years),
    n_planned_waves = as.integer(sum(flag_planned_wave)),
    n_events_cognitive = as.integer(sum(has_cognitive_measures)),
    has_source_cognitive_measures = any(has_cognitive_measures),
    has_source_questionnaires = any(has_questionnaires),
    has_source_physical_measures = any(has_physical_measures),
    has_source_biological_samples = any(has_biological_samples),
    has_source_administrative_databases = any(has_administrative_databases),
    has_biosample_blood = any(has_biosample_blood),
    .groups = "drop"
  ) %>%
  mutate(
    follow_up_span_years = last_wave_year - first_wave_year,
    prop_events_cognitive = ifelse(n_waves > 0, n_events_cognitive / n_waves, NA_real_)
  )

ds_study_populations <- ds_population %>%
  group_by(study_id) %>%
  summarise(
    n_populations = n(),
    max_population_waves = max_or_na(n_waves),
    total_participants = sum_or_na(participant_number),
    total_samples = sum_or_na(sample_number),
    min_population_min_age = min_or_na(minimum_age),
    max_population_max_age = max_or_na(maximum_age),
    flag_older_adult_reach = any(flag_older_adult_reach),
    .groups = "drop"
  )

ds_study_geography <- ds_countries_raw %>%
  group_by(study_id) %>%
  summarise(
    n_countries = n_distinct(country_iso),
    primary_country = modal_value(country_iso),
    countries = collapse_distinct(country_iso),
    .groups = "drop"
  )

ds_study_domains <- ds_domain %>%
  group_by(study_id) %>%
  summarise(
    attribute_coverage_known = first(attribute_coverage_known),
    n_areas = as.integer(sum(has_area)),
    has_area_cognitive_psychological = any(has_area & area_code == "Cognitive_psychological_measures"),
    has_area_diseases = any(has_area & area_code == "Diseases"),
    has_area_health_status = any(has_area & area_code == "Health_status_functional_limitations"),
    .groups = "drop"
  )

ds_profile <- ds_studies_raw %>%
  transmute(
    ferry_run_id = run_id,
    study_id,
    study_acronym = acronym_en,
    study_name = name_en,
    website_url,
    design_code,
    study_start_year = as.integer(start_year),
    published = as.logical(published),
    marker_paper,
    pubmed_id,
    target_number = as.integer(target_number),
    access_data,
    access_biosamples,
    access_other,
    access_fees = as.logical(access_fees),
    access_restrictions = as.logical(access_restrictions),
    maelstrom_authorized = as.logical(maelstrom_authorized)
  ) %>%
  left_join(
    ds_inventory_raw %>% transmute(study_id, study_page_url, inventory_rank = as.integer(inventory_rank)),
    by = "study_id"
  ) %>%
  left_join(ds_study_populations, by = "study_id") %>%
  left_join(ds_study_waves, by = "study_id") %>%
  left_join(ds_study_geography, by = "study_id") %>%
  left_join(ds_study_domains, by = "study_id") %>%
  left_join(ds_concept_signal, by = "study_id") %>%
  mutate(
    # --- absence of a child row means zero, not unknown -----------------------
    across(
      c(n_populations, n_waves, n_planned_waves, n_events_cognitive, n_countries, n_areas),
      ~ tidyr::replace_na(as.integer(.x), 0L)
    ),
    across(paste0("n_", names(CONCEPT_WEIGHTS), "_hits"), ~ tidyr::replace_na(as.integer(.x), 0L)),
    across(
      c(
        has_source_cognitive_measures, has_source_questionnaires,
        has_source_physical_measures, has_source_biological_samples,
        has_source_administrative_databases, has_biosample_blood,
        flag_older_adult_reach, attribute_coverage_known,
        has_area_cognitive_psychological, has_area_diseases, has_area_health_status
      ),
      ~ tidyr::replace_na(.x, FALSE)
    ),
    # --- readable design taxonomy --------------------------------------------
    design_label = factor(
      unname(DESIGN_LABELS[design_code]) %||% design_code,
      levels = unname(DESIGN_LABELS)
    ),
    # --- design descriptors ---------------------------------------------------
    flag_longitudinal = n_waves >= MIN_WAVES_LONGITUDINAL,
    flag_repeated_within_population = tidyr::replace_na(max_population_waves, 0L) >= MIN_WAVES_LONGITUDINAL,
    flag_multinational = n_countries > 1L,
    # --- screening signals ----------------------------------------------------
    sig_text_dementia = n_dementia_hits > 0L,
    sig_text_cognition = n_cognition_hits > 0L,
    sig_text_brain = n_brain_hits > 0L,
    sig_text_ageing = n_ageing_hits > 0L,
    sig_area_cognitive = has_area_cognitive_psychological,
    sig_source_cognitive = has_source_cognitive_measures,
    # --- relevance score ------------------------------------------------------
    # Additive and per-signal, not per-hit. Reading the score backwards from the
    # sig_* columns of this same row must always reproduce it.
    relevance_score =
      CONCEPT_WEIGHTS[["dementia"]] * as.integer(sig_text_dementia) +
        CONCEPT_WEIGHTS[["cognition"]] * as.integer(sig_text_cognition) +
        CONCEPT_WEIGHTS[["brain"]] * as.integer(sig_text_brain) +
        WEIGHT_SOURCE_COGNITIVE * as.integer(sig_source_cognitive) +
        WEIGHT_AREA_COGNITIVE * as.integer(sig_area_cognitive),
    relevance_tier = factor(
      case_when(
        sig_text_dementia ~ "core",
        relevance_score >= TIER_PROBABLE_SCORE ~ "probable",
        relevance_score >= TIER_POSSIBLE_SCORE ~ "possible",
        TRUE ~ "unrelated"
      ),
      levels = RELEVANCE_TIERS,
      ordered = TRUE
    ),
    # --- frame criteria, evaluated in the order of the screening funnel --------
    flag_topic_relevant = relevance_tier %in% c("probable", "core"),
    flag_cognitive_evidence = sig_source_cognitive | sig_text_dementia,
    flag_in_frame = flag_topic_relevant & flag_longitudinal & flag_cognitive_evidence,
    frame_exclusion_reason = case_when(
      !flag_topic_relevant ~ "Relevance tier below 'probable'",
      !flag_longitudinal ~ "Fewer than two data collection events",
      !flag_cognitive_evidence ~ "No declared cognitive instrument and no dementia text",
      TRUE ~ NA_character_
    ),
    ellis_run_id = ellis_run_id
  ) %>%
  select(
    ellis_run_id, ferry_run_id, study_id, study_acronym, study_name,
    study_page_url, website_url, inventory_rank,
    design_code, design_label, study_start_year, published, marker_paper, pubmed_id,
    n_populations, target_number, total_participants, total_samples,
    n_waves, max_population_waves, first_wave_year, last_wave_year,
    follow_up_span_years, mean_wave_gap_years, n_planned_waves,
    flag_longitudinal, flag_repeated_within_population,
    min_population_min_age, max_population_max_age, flag_older_adult_reach,
    n_countries, primary_country, countries, flag_multinational,
    access_data, access_biosamples, access_other,
    access_fees, access_restrictions, maelstrom_authorized,
    attribute_coverage_known, n_areas,
    has_area_cognitive_psychological, has_area_diseases, has_area_health_status,
    n_events_cognitive, prop_events_cognitive,
    has_source_cognitive_measures, has_source_questionnaires,
    has_source_physical_measures, has_source_biological_samples,
    has_source_administrative_databases, has_biosample_blood,
    n_dementia_hits, n_cognition_hits, n_brain_hits, n_ageing_hits,
    sig_text_dementia, sig_text_cognition, sig_text_brain, sig_text_ageing,
    sig_area_cognitive, sig_source_cognitive,
    relevance_score, relevance_tier,
    flag_topic_relevant, flag_cognitive_evidence, flag_in_frame,
    frame_exclusion_reason
  ) %>%
  arrange(study_id)

# ---- screen-flow -------------------------------------------------------------
# The funnel, in the same order the exclusion reasons are assigned. Each step is
# applied to the survivors of the step before it.

flow_step_0 <- ds_profile
flow_step_1 <- flow_step_0 %>% filter(flag_topic_relevant)
flow_step_2 <- flow_step_1 %>% filter(flag_longitudinal)
flow_step_3 <- flow_step_2 %>% filter(flag_cognitive_evidence)

ds_screening_flow <- data.frame(
  ellis_run_id = ellis_run_id,
  step = 0:3,
  criterion = c(
    "All individual studies in the Ferry run",
    "Relevance tier is 'probable' or 'core'",
    "Longitudinal design",
    "Cognitive measurement evidence"
  ),
  definition = c(
    "One row per study in the completed Ferry extraction",
    paste0("relevance_score >= ", TIER_PROBABLE_SCORE, " or any dementia lexicon hit"),
    paste0("n_waves >= ", MIN_WAVES_LONGITUDINAL, " data collection events"),
    "cognitive_measures declared at an event, or a dementia lexicon hit"
  ),
  n_remaining = c(nrow(flow_step_0), nrow(flow_step_1), nrow(flow_step_2), nrow(flow_step_3)),
  stringsAsFactors = FALSE
) %>%
  mutate(n_excluded = c(0L, -diff(n_remaining)))

ds_lexicon <- CONCEPT_LEXICON %>%
  mutate(ellis_run_id = ellis_run_id) %>%
  select(ellis_run_id, concept, concept_weight, term_label, pattern, match_mode, rationale)

# ---- SECTION: Delivery -------------------------------------------------------

# ---- validate ----------------------------------------------------------------
stopifnot(
  "study_profile lost or gained studies" =
    nrow(ds_profile) == nrow(ds_studies_raw),
  "study_profile study_id is not unique" =
    !anyDuplicated(ds_profile$study_id),
  "study_population references an unknown study" =
    all(ds_population$study_id %in% ds_profile$study_id),
  "study_wave references an unknown population" =
    all(paste(ds_wave$study_id, ds_wave$population_id) %in%
      paste(ds_population$study_id, ds_population$population_id)),
  "study_domain is not a complete study-by-area rectangle" =
    nrow(ds_domain) == nrow(ds_profile) * length(area_codes),
  "screening_evidence references an unknown study" =
    all(ds_evidence$study_id %in% ds_profile$study_id),
  "relevance_tier contains missing values" =
    !any(is.na(ds_profile$relevance_tier)),
  "flag_in_frame disagrees with its three criteria" =
    all(ds_profile$flag_in_frame ==
      (ds_profile$flag_topic_relevant & ds_profile$flag_longitudinal & ds_profile$flag_cognitive_evidence)),
  "frame_exclusion_reason disagrees with flag_in_frame" =
    all(is.na(ds_profile$frame_exclusion_reason) == ds_profile$flag_in_frame),
  "screening_flow does not end at the frame size" =
    tail(ds_screening_flow$n_remaining, 1) == sum(ds_profile$flag_in_frame)
)

# n_waves on the spine must equal the wave rows actually delivered.
wave_parity <- ds_wave %>%
  count(study_id, name = "n_wave_rows") %>%
  right_join(ds_profile %>% select(study_id, n_waves), by = "study_id") %>%
  mutate(n_wave_rows = tidyr::replace_na(n_wave_rows, 0L)) %>%
  filter(n_wave_rows != n_waves)

if (nrow(wave_parity) > 0) {
  stop("n_waves disagrees with study_wave row counts for: ", paste(wave_parity$study_id, collapse = ", "))
}

cat("\nValidation passed.")
cat("\nStudies profiled: ", nrow(ds_profile), sep = "")
cat("\nStudies in the dementia frame: ", sum(ds_profile$flag_in_frame), sep = "")

# ---- save-to-disk ------------------------------------------------------------
# The analytic database is rebuilt atomically: writes go to a .building file and
# the canonical path is replaced only after the transaction closes cleanly.

invisible(ensure_parent_dir(arguments$target_db))
build_db_path <- paste0(arguments$target_db, ".building")

if (file.exists(build_db_path) && !file.remove(build_db_path)) {
  stop("Could not remove incomplete build database: ", build_db_path)
}

target_con <- DBI::dbConnect(RSQLite::SQLite(), build_db_path)
connection_open <- TRUE
on.exit({
  if (connection_open) DBI::dbDisconnect(target_con)
}, add = TRUE)

invisible(apply_schema(con = target_con, schema_path = arguments$schema_path))

invisible(DBI::dbWithTransaction(target_con, {
  DBI::dbWriteTable(
    target_con,
    "ellis_runs",
    data.frame(
      ellis_run_id = ellis_run_id,
      ferry_run_id = ferry_run_id,
      ferry_run_status = ds_run$status[[1]],
      ferry_run_completed_at_utc = ds_run$completed_at_utc[[1]],
      started_at_utc = ellis_started_at,
      completed_at_utc = NA_character_,
      source_db_path = arguments$source_db,
      target_db_path = arguments$target_db,
      lexicon_concepts = length(CONCEPT_WEIGHTS),
      lexicon_terms = nrow(CONCEPT_LEXICON),
      studies_in = nrow(ds_studies_raw),
      studies_out = nrow(ds_profile),
      studies_in_frame = sum(ds_profile$flag_in_frame),
      status = "running",
      notes = NA_character_,
      stringsAsFactors = FALSE
    ),
    append = TRUE
  )

  write_rectangle(target_con, "concept_lexicon", ds_lexicon)
  write_rectangle(target_con, "screening_evidence", ds_evidence)
  write_rectangle(target_con, "screening_flow", ds_screening_flow)
  write_rectangle(target_con, "study_profile", ds_profile)
  write_rectangle(target_con, "study_population", ds_population)
  write_rectangle(target_con, "study_wave", ds_wave)
  write_rectangle(target_con, "study_domain", ds_domain)

  invisible(DBI::dbExecute(
    target_con,
    "UPDATE ellis_runs SET completed_at_utc = ?, status = 'completed' WHERE ellis_run_id = ?",
    params = list(now_utc(), ellis_run_id)
  ))
}))

DBI::dbDisconnect(target_con)
connection_open <- FALSE

if (file.exists(arguments$target_db) && !file.remove(arguments$target_db)) {
  stop("Could not replace existing database: ", arguments$target_db)
}

if (!file.rename(build_db_path, arguments$target_db)) {
  stop("Could not promote completed database to: ", arguments$target_db)
}

cat("\nAnalytic database: ", arguments$target_db, sep = "")

# ---- save-parquet ------------------------------------------------------------
# Parquet mirrors preserve the R types the SQLite contract cannot hold: factors
# stay factors and flags stay logical. The run record is read back from the
# promoted database so the mirror carries the completed status and timestamp,
# which lets an analyst working only from parquet still trace provenance.

invisible(ensure_dir(arguments$parquet_dir))

ds_ellis_run <- local({
  con <- DBI::dbConnect(RSQLite::SQLite(), arguments$target_db)
  on.exit(DBI::dbDisconnect(con), add = TRUE)
  DBI::dbGetQuery(con, "SELECT * FROM ellis_runs")
})

parquet_targets <- list(
  ellis_runs = ds_ellis_run,
  study_profile = ds_profile,
  study_population = ds_population,
  study_wave = ds_wave,
  study_domain = ds_domain,
  screening_evidence = ds_evidence,
  screening_flow = ds_screening_flow,
  concept_lexicon = ds_lexicon,
  dementia_frame = ds_profile %>% filter(flag_in_frame)
)

for (target_name in names(parquet_targets)) {
  arrow::write_parquet(
    parquet_targets[[target_name]],
    file.path(arguments$parquet_dir, paste0(target_name, ".parquet"))
  )
}

cat("\nParquet mirrors written to: ", arguments$parquet_dir, sep = "")

# ---- profile-cache -----------------------------------------------------------
# Deterministic description of the database that was actually delivered. Every
# figure quoted in data-public/metadata/CACHE-manifest.md is regenerated here so
# the manifest stays falsifiable after any later run.

profile_cache <- function(db_path = arguments$target_db, ontology_dir = arguments$ontology_dir) {
  invisible(ensure_dir(ontology_dir))

  con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  row_count <- function(object_name) {
    as.integer(DBI::dbGetQuery(con, paste0("SELECT COUNT(*) AS n FROM ", quote_identifier(object_name)))$n[[1]])
  }

  # --- tables ---------------------------------------------------------------
  table_rows <- lapply(seq_len(nrow(CACHE_TABLE_ONTOLOGY)), function(index) {
    object_name <- CACHE_TABLE_ONTOLOGY$table_name[[index]]
    columns <- DBI::dbGetQuery(con, paste0("PRAGMA table_info(", quote_identifier(object_name), ")"))
    primary_key <- columns$name[columns$pk > 0]

    data.frame(
      table_group = CACHE_TABLE_ONTOLOGY$table_group[[index]],
      table_name = object_name,
      object_type = CACHE_TABLE_ONTOLOGY$object_type[[index]],
      grain = CACHE_TABLE_ONTOLOGY$grain[[index]],
      row_count = row_count(object_name),
      column_count = nrow(columns),
      primary_key = if (length(primary_key) > 0) paste(primary_key, collapse = "|") else NA_character_,
      stringsAsFactors = FALSE
    )
  })
  ds_tables <- bind_rows(table_rows)

  # --- columns --------------------------------------------------------------
  column_rows <- list()
  for (index in seq_len(nrow(CACHE_TABLE_ONTOLOGY))) {
    object_name <- CACHE_TABLE_ONTOLOGY$table_name[[index]]
    columns <- DBI::dbGetQuery(con, paste0("PRAGMA table_info(", quote_identifier(object_name), ")"))
    total <- row_count(object_name)

    for (position in seq_len(nrow(columns))) {
      column_name <- columns$name[[position]]
      quoted <- quote_identifier(column_name)
      is_opaque <- column_name %in% OPAQUE_COLUMNS

      basics <- DBI::dbGetQuery(
        con,
        paste0(
          "SELECT COUNT(", quoted, ") AS n_non_null, COUNT(DISTINCT ", quoted, ") AS n_distinct",
          if (is_opaque) "" else paste0(", MIN(", quoted, ") AS min_value, MAX(", quoted, ") AS max_value"),
          " FROM ", quote_identifier(object_name)
        )
      )

      example <- if (is_opaque || total == 0) {
        NA_character_
      } else {
        value <- DBI::dbGetQuery(
          con,
          paste0("SELECT ", quoted, " AS v FROM ", quote_identifier(object_name),
                 " WHERE ", quoted, " IS NOT NULL LIMIT 1")
        )$v
        if (length(value) == 0) NA_character_ else substr(gsub("[\r\n\t]+", " ", as.character(value[[1]])), 1, 80)
      }

      column_rows[[length(column_rows) + 1L]] <- data.frame(
        table_name = object_name,
        column_name = column_name,
        declared_type = columns$type[[position]],
        ordinal_position = position,
        row_count = total,
        n_non_null = as.integer(basics$n_non_null[[1]]),
        fill_rate = if (total == 0) NA_real_ else round(as.numeric(basics$n_non_null[[1]]) / total, 4),
        n_distinct = as.integer(basics$n_distinct[[1]]),
        min_value = if (is_opaque) NA_character_ else as.character(basics$min_value[[1]]),
        max_value = if (is_opaque) NA_character_ else as.character(basics$max_value[[1]]),
        example_value = example,
        is_opaque_payload = as.integer(is_opaque),
        stringsAsFactors = FALSE
      )
    }
  }
  ds_columns <- bind_rows(column_rows)

  # --- relationships --------------------------------------------------------
  relationship_rows <- lapply(seq_len(nrow(CACHE_RELATIONSHIP_ONTOLOGY)), function(index) {
    edge <- CACHE_RELATIONSHIP_ONTOLOGY[index, ]
    keys <- strsplit(edge$join_keys, "|", fixed = TRUE)[[1]]
    join_clause <- paste0("p.", keys, " = c.", keys, collapse = " AND ")
    key_clause <- paste0("c.", keys, collapse = ", ")

    per_parent <- DBI::dbGetQuery(
      con,
      paste0(
        "SELECT MIN(n) AS min_n, MAX(n) AS max_n, AVG(n) AS mean_n FROM (",
        "SELECT COUNT(*) AS n FROM ", quote_identifier(edge$child_table), " c GROUP BY ", key_clause, ")"
      )
    )

    orphans <- DBI::dbGetQuery(
      con,
      paste0(
        "SELECT COUNT(*) AS n FROM ", quote_identifier(edge$child_table), " c ",
        "LEFT JOIN ", quote_identifier(edge$parent_table), " p ON ", join_clause, " ",
        "WHERE p.", keys[[1]], " IS NULL"
      )
    )$n[[1]]

    childless <- DBI::dbGetQuery(
      con,
      paste0(
        "SELECT COUNT(*) AS n FROM ", quote_identifier(edge$parent_table), " p ",
        "WHERE NOT EXISTS (SELECT 1 FROM ", quote_identifier(edge$child_table), " c WHERE ", join_clause, ")"
      )
    )$n[[1]]

    data.frame(
      parent_table = edge$parent_table,
      child_table = edge$child_table,
      join_keys = edge$join_keys,
      declared_cardinality = edge$declared_cardinality,
      children_min = as.integer(per_parent$min_n[[1]]),
      children_max = as.integer(per_parent$max_n[[1]]),
      children_mean = round(as.numeric(per_parent$mean_n[[1]]), 2),
      parents_without_children = as.integer(childless),
      orphan_child_rows = as.integer(orphans),
      stringsAsFactors = FALSE
    )
  })
  ds_relationships <- bind_rows(relationship_rows)

  # --- vocabularies ---------------------------------------------------------
  vocabulary_rows <- lapply(seq_len(nrow(CACHE_VOCABULARY_ONTOLOGY)), function(index) {
    entry <- CACHE_VOCABULARY_ONTOLOGY[index, ]
    quoted <- quote_identifier(entry$column_name)

    values <- DBI::dbGetQuery(
      con,
      paste0(
        "SELECT ", quoted, " AS term_value, COUNT(*) AS n_rows FROM ",
        quote_identifier(entry$table_name),
        " GROUP BY ", quoted, " ORDER BY n_rows DESC"
      )
    )

    if (nrow(values) == 0) return(NULL)

    data.frame(
      table_name = entry$table_name,
      column_name = entry$column_name,
      vocabulary_label = entry$vocabulary_label,
      term_value = as.character(values$term_value),
      n_rows = as.integer(values$n_rows),
      stringsAsFactors = FALSE
    )
  })
  ds_vocabularies <- bind_rows(vocabulary_rows)

  # --- provenance -----------------------------------------------------------
  ds_provenance <- data.frame(
    ellis_run_id = ellis_run_id,
    ferry_run_id = ferry_run_id,
    profiled_at_utc = now_utc(),
    source_db_path = arguments$source_db,
    target_db_path = db_path,
    target_db_bytes = as.numeric(file.info(db_path)$size),
    sqlite_version = DBI::dbGetQuery(con, "SELECT sqlite_version() AS v")$v[[1]],
    object_count = nrow(ds_tables),
    column_count = nrow(ds_columns),
    row_count = sum(ds_tables$row_count[ds_tables$object_type == "table"]),
    studies_profiled = nrow(ds_profile),
    studies_in_frame = sum(ds_profile$flag_in_frame),
    lexicon_terms = nrow(CONCEPT_LEXICON),
    evidence_rows = nrow(ds_evidence),
    stringsAsFactors = FALSE
  )

  write.csv(ds_provenance, file.path(ontology_dir, "cache-provenance.csv"), row.names = FALSE, na = "")
  write.csv(ds_tables, file.path(ontology_dir, "cache-tables.csv"), row.names = FALSE, na = "")
  write.csv(ds_columns, file.path(ontology_dir, "cache-columns.csv"), row.names = FALSE, na = "")
  write.csv(ds_relationships, file.path(ontology_dir, "cache-relationships.csv"), row.names = FALSE, na = "")
  write.csv(ds_vocabularies, file.path(ontology_dir, "cache-vocabularies.csv"), row.names = FALSE, na = "")
  write.csv(ds_screening_flow, file.path(ontology_dir, "cache-screening-flow.csv"), row.names = FALSE, na = "")

  invisible(ds_provenance)
}

invisible(profile_cache())
cat("\nOntology artifacts written to: ", arguments$ontology_dir, sep = "")
cat("\nEllis run: ", ellis_run_id, "\n", sep = "")
