# nolint start
# Local functions and dictionary for ./analysis/data-primer-1/
# Sourced by data-primer-1.R via the `declare-functions` chunk.
#
# Division of labour in this primer:
#   - This file authors PROSE   : block membership and human descriptions.
#   - data-primer-1.R computes NUMBERS: fill rates, distinct counts, examples.
# Nothing in this file states a count. If it did, it would go stale the moment
# the Maelstrom catalogue grew.

# ---- declare-spine-blocks ----------------------------------------------------
# Reading order of the study_profile column blocks, mirroring the section order
# of data-public/metadata/CACHE-manifest.md so the two documents can be read
# side by side.
SPINE_BLOCK_ORDER <- c(
  "Identity and provenance",
  "Design",
  "Enrolment scale",
  "Longitudinal depth",
  "Age reach",
  "Geography",
  "Access terms",
  "Declared research-area coverage",
  "Measurement sources across waves",
  "Screening signals",
  "Relevance and frame membership"
)

# ---- declare-spine-dictionary ------------------------------------------------
# One row per study_profile column. `description` is the authoritative prose;
# `caution` carries the reading warnings the manifest raises, and is NA when the
# column can be read at face value.
SPINE_DICTIONARY <- tibble::tribble(
  ~column_name, ~block, ~description, ~caution,

  # -- Identity and provenance -------------------------------------------------
  "ellis_run_id", "Identity and provenance",
  "Ellis run identifier, `ellis-{YYYYMMDD}T{HHMMSS}` in UTC", NA_character_,
  "ferry_run_id", "Identity and provenance",
  "Ferry run this store was built from", NA_character_,
  "study_id", "Identity and provenance",
  "Maelstrom slug; the study key everywhere in this store", NA_character_,
  "study_acronym", "Identity and provenance",
  "Short study name as the catalogue gives it",
  "Not unique: a few acronyms are shared by two studies. Never key on it.",
  "study_name", "Identity and provenance",
  "Full English study name", NA_character_,
  "study_page_url", "Identity and provenance",
  "Public Maelstrom catalogue page for the study", NA_character_,
  "website_url", "Identity and provenance",
  "The study's own website, where the catalogue records one", NA_character_,
  "inventory_rank", "Identity and provenance",
  "Position in the name-sorted catalogue listing", NA_character_,

  # -- Design ------------------------------------------------------------------
  "design_code", "Design",
  "Study design as the source taxonomy names it", NA_character_,
  "design_label", "Design",
  "Readable design label; an ordered factor in the parquet mirror", NA_character_,
  "study_start_year", "Design",
  "Year the study began, as declared", NA_character_,
  "published", "Design",
  "Source publication flag",
  "Constant: the inventory query returns published studies only.",
  "marker_paper", "Design",
  "Free-text citation of the study's marker paper", NA_character_,
  "pubmed_id", "Design",
  "PubMed identifier for the marker paper", NA_character_,

  # -- Enrolment scale ---------------------------------------------------------
  "n_populations", "Enrolment scale",
  "Number of populations the study enrolled", NA_character_,
  "target_number", "Enrolment scale",
  "Study-level recruitment target declared by the source", NA_character_,
  "total_participants", "Enrolment scale",
  "Sum of participant counts across populations",
  "NA only when every population count is NA, never when some are.",
  "total_samples", "Enrolment scale",
  "Sum of biosample counts across populations", NA_character_,

  # -- Longitudinal depth ------------------------------------------------------
  "n_waves", "Longitudinal depth",
  "Data collection events across all populations", NA_character_,
  "max_population_waves", "Longitudinal depth",
  "Largest wave count within a single population", NA_character_,
  "first_wave_year", "Longitudinal depth",
  "Earliest event start year in the study", NA_character_,
  "last_wave_year", "Longitudinal depth",
  "Latest event start year in the study",
  "May be in the future: planned waves are carried, not censored.",
  "follow_up_span_years", "Longitudinal depth",
  "`last_wave_year - first_wave_year`", NA_character_,
  "mean_wave_gap_years", "Longitudinal depth",
  "Mean gap between consecutive waves within a population", NA_character_,
  "n_planned_waves", "Longitudinal depth",
  "Events whose start year is later than the current calendar year", NA_character_,
  "flag_longitudinal", "Longitudinal depth",
  "Two or more data collection events",
  "Counts events, not repeated measurement of the same people. Two populations measured once each satisfies it.",
  "flag_repeated_within_population", "Longitudinal depth",
  "At least one population measured twice or more",
  "The stricter reading of longitudinal. Prefer it when repeated measurement of the same cohort matters.",

  # -- Age reach ---------------------------------------------------------------
  "min_population_min_age", "Age reach",
  "Youngest stated minimum eligibility age across populations", NA_character_,
  "max_population_max_age", "Age reach",
  "Oldest stated maximum eligibility age across populations",
  "Sparsely reported; a missing value says nothing about who was enrolled.",
  "flag_older_adult_reach", "Age reach",
  "Any population with minimum age >= 50 or maximum age >= 65",
  "Claimed only from a stated boundary, never inferred. FALSE includes studies that simply did not report age.",

  # -- Geography ---------------------------------------------------------------
  "n_countries", "Geography",
  "Distinct ISO country codes across populations", NA_character_,
  "primary_country", "Geography",
  "Most frequent population country; ties resolved by first appearance",
  "At study level this is the modal country. At population level the same name means the FIRST country listed.",
  "countries", "Geography",
  "Pipe-delimited sorted ISO country codes", NA_character_,
  "flag_multinational", "Geography",
  "Study spans more than one country", NA_character_,

  # -- Access terms ------------------------------------------------------------
  "access_data", "Access terms",
  "Whether the catalogue records a data access channel", NA_character_,
  "access_biosamples", "Access terms",
  "Whether the catalogue records a biosample access channel", NA_character_,
  "access_other", "Access terms",
  "Whether the catalogue records another access channel", NA_character_,
  "access_fees", "Access terms",
  "Source flag for access fees, carried unchanged", NA_character_,
  "access_restrictions", "Access terms",
  "Source flag for access restrictions, carried unchanged", NA_character_,
  "maelstrom_authorized", "Access terms",
  "Source flag for Maelstrom authorization, carried unchanged", NA_character_,

  # -- Declared research-area coverage -----------------------------------------
  "attribute_coverage_known", "Declared research-area coverage",
  "Study carries at least one `Mlstr_area` annotation",
  "Read every `has_area_*` column through this one. Without it, 0 is ambiguous.",
  "n_areas", "Declared research-area coverage",
  "Count of declared Maelstrom research areas", NA_character_,
  "has_area_cognitive_psychological", "Declared research-area coverage",
  "Declares the `Cognitive_psychological_measures` area",
  "0 means 'not annotated' for studies where attribute_coverage_known is FALSE.",
  "has_area_diseases", "Declared research-area coverage",
  "Declares the `Diseases` area",
  "0 means 'not annotated' for studies where attribute_coverage_known is FALSE.",
  "has_area_health_status", "Declared research-area coverage",
  "Declares the `Health_status_functional_limitations` area",
  "0 means 'not annotated' for studies where attribute_coverage_known is FALSE.",

  # -- Measurement sources across waves ----------------------------------------
  "n_events_cognitive", "Measurement sources across waves",
  "Events declaring `cognitive_measures`", NA_character_,
  "prop_events_cognitive", "Measurement sources across waves",
  "`n_events_cognitive / n_waves`", NA_character_,
  "has_source_cognitive_measures", "Measurement sources across waves",
  "Any event declares `cognitive_measures` — the key harmonization signal",
  "Records that an instrument FAMILY was declared, not which instrument. Two flagged studies may share nothing harmonizable.",
  "has_source_questionnaires", "Measurement sources across waves",
  "Any event declares `questionnaires`", NA_character_,
  "has_source_physical_measures", "Measurement sources across waves",
  "Any event declares `physical_measures`", NA_character_,
  "has_source_biological_samples", "Measurement sources across waves",
  "Any event declares `biological_samples`", NA_character_,
  "has_source_administrative_databases", "Measurement sources across waves",
  "Any event declares `administratives_databases` (the source spelling)", NA_character_,
  "has_biosample_blood", "Measurement sources across waves",
  "Blood was collected at any event", NA_character_,

  # -- Screening signals -------------------------------------------------------
  "n_dementia_hits", "Screening signals",
  "Total `dementia` lexicon matches across all scanned fields", NA_character_,
  "n_cognition_hits", "Screening signals",
  "Total `cognition` lexicon matches across all scanned fields", NA_character_,
  "n_brain_hits", "Screening signals",
  "Total `brain` lexicon matches across all scanned fields", NA_character_,
  "n_ageing_hits", "Screening signals",
  "Total `ageing` lexicon matches across all scanned fields", NA_character_,
  "sig_text_dementia", "Screening signals",
  "At least one `dementia` hit; contributes weight 3 to the score", NA_character_,
  "sig_text_cognition", "Screening signals",
  "At least one `cognition` hit; contributes weight 2", NA_character_,
  "sig_text_brain", "Screening signals",
  "At least one `brain` hit; contributes weight 1", NA_character_,
  "sig_text_ageing", "Screening signals",
  "At least one `ageing` hit; descriptive only",
  "Deliberately absent from the score. Studying older adults is not the same as studying cognition.",
  "sig_area_cognitive", "Screening signals",
  "Alias of `has_area_cognitive_psychological`; contributes weight 1", NA_character_,
  "sig_source_cognitive", "Screening signals",
  "Alias of `has_source_cognitive_measures`; contributes weight 2", NA_character_,

  # -- Relevance and frame membership ------------------------------------------
  "relevance_score", "Relevance and frame membership",
  "Additive score over the six weighted signals",
  "Reconstructible from the sig_* columns of the same row. If it is not, the row is corrupt.",
  "relevance_tier", "Relevance and frame membership",
  "Ordered tier: unrelated < possible < probable < core", NA_character_,
  "flag_topic_relevant", "Relevance and frame membership",
  "Tier is `probable` or `core`; step 1 of the screening funnel", NA_character_,
  "flag_cognitive_evidence", "Relevance and frame membership",
  "`sig_source_cognitive` or `sig_text_dementia`; step 3 of the funnel", NA_character_,
  "flag_in_frame", "Relevance and frame membership",
  "All three funnel criteria hold; defines the `dementia_frame` view",
  "A screening result, not an eligibility decision. Confirming a study as harmonizable requires reading it.",
  "frame_exclusion_reason", "Relevance and frame membership",
  "First failing funnel criterion",
  "NA exactly when flag_in_frame is TRUE. An NA here is a pass, not a gap."
)

# ---- declare-primer-helpers --------------------------------------------------

#' Truncate a character value for display in a reference table
#'
#' @param x Character vector.
#' @param width Maximum number of characters to keep.
#' @return Character vector, ellipsised where it exceeded `width`.
truncate_text <- function(x, width = 44L) {
  x <- as.character(x)
  ifelse(
    !is.na(x) & nchar(x) > width,
    paste0(substr(x, 1L, width - 1L), "\u2026"),
    x
  )
}

#' Profile every column of a rectangle
#'
#' Computes what a reader needs in order to trust a column: its R type, how
#' completely it is populated, how many distinct values it takes, and one real
#' value to anchor the abstraction.
#'
#' @param data A data frame.
#' @param example_width Characters kept from the example value.
#' @return A tibble with one row per column of `data`.
profile_columns <- function(data, example_width = 44L) {
  stopifnot(is.data.frame(data))
  n_row <- nrow(data)

  rows <- lapply(names(data), function(column_name) {
    values <- data[[column_name]]
    observed <- values[!is.na(values)]
    example <- if (length(observed) == 0L) NA_character_ else as.character(observed[[1L]])

    tibble::tibble(
      column_name = column_name,
      r_type      = paste(class(values), collapse = "/"),
      n_non_null  = length(observed),
      fill_rate   = if (n_row == 0L) NA_real_ else length(observed) / n_row,
      n_distinct  = length(unique(observed)),
      example_value = truncate_text(example, example_width)
    )
  })

  dplyr::bind_rows(rows)
}

#' Test whether a rectangle holds the grain it declares
#'
#' @param data A data frame.
#' @param keys Character vector of column names forming the composite key.
#' @return A one-row tibble; `grain_holds` is TRUE when no key repeats.
grain_check <- function(data, keys) {
  stopifnot(is.data.frame(data))
  keys_present <- intersect(keys, names(data))
  keys_absent <- setdiff(keys, names(data))

  n_rows <- nrow(data)
  n_unique <- if (length(keys_present) == 0L) {
    NA_integer_
  } else {
    nrow(dplyr::distinct(dplyr::select(data, dplyr::all_of(keys_present))))
  }

  tibble::tibble(
    key_path        = paste(keys_present, collapse = " + "),
    keys_missing    = if (length(keys_absent) == 0L) NA_character_ else paste(keys_absent, collapse = " + "),
    n_rows          = n_rows,
    n_distinct_keys = n_unique,
    n_duplicated    = n_rows - n_unique,
    grain_holds     = !is.na(n_unique) && n_rows == n_unique
  )
}

#' Measure a parent-child edge
#'
#' Counts children per parent, parents with no children at all, and — the check
#' that matters most — child rows whose key path finds no parent.
#'
#' @param parent Parent data frame.
#' @param child Child data frame.
#' @param keys Character vector of join columns.
#' @return A one-row tibble describing the observed edge.
relationship_check <- function(parent, child, keys) {
  stopifnot(is.data.frame(parent), is.data.frame(child))

  parent_keys <- dplyr::distinct(dplyr::select(parent, dplyr::all_of(keys)))
  child_counts <- child %>%
    dplyr::count(dplyr::across(dplyr::all_of(keys)), name = "n_children")

  joined <- dplyr::left_join(parent_keys, child_counts, by = keys) %>%
    dplyr::mutate(n_children = dplyr::coalesce(n_children, 0L))

  with_children <- joined$n_children[joined$n_children > 0L]
  orphans <- dplyr::anti_join(child, parent_keys, by = keys)

  tibble::tibble(
    join_keys                = paste(keys, collapse = " + "),
    n_parents                = nrow(parent_keys),
    n_children               = nrow(child),
    children_min             = if (length(with_children) == 0L) NA_integer_ else min(with_children),
    children_mean            = if (length(with_children) == 0L) NA_real_ else round(mean(with_children), 2),
    children_max             = if (length(with_children) == 0L) NA_integer_ else max(with_children),
    parents_without_children = sum(joined$n_children == 0L),
    orphan_child_rows        = nrow(orphans)
  )
}

#' Render a tibble as the primer's house table
#'
#' One place to change table styling for the whole document.
#'
#' @param data A data frame.
#' @param caption Caption text, already carrying its artifact ID.
#' @param ... Passed to `knitr::kable()`.
neat_primer <- function(data, caption, ...) {
  knitr::kable(data, caption = caption, format.args = list(big.mark = ","), ...)
}
# nolint end
