# nolint start
# AI agents must consult ./analysis/eda-1/eda-style-guide.md before making changes to this file.
# ---- SECTION: Data Primer 1 --------------------------------------------------
# Mode: Data Primer (canonical, human-verified description of the Ellis output)
#
# Describes the data as it emerges from ./manipulation/1-ellis-1.R. Every EDA and
# Report in ./analysis/ links to the rendered companion rather than re-explaining
# the data.
#
# Input  : data-private/derived/ellis/*.parquet          (nine Ellis mirrors)
#          data-public/metadata/ellis-ontology/*.csv     (declared contract)
# Output : analysis/data-primer-1/data-primer-1.html     (via the .qmd companion)
#          analysis/data-primer-1/data-local/*.csv       (reference tables)
#
# House rule for this primer: prose is authored in local-functions.R, numbers are
# computed here. No count in this script is typed by hand.

rm(list = ls(all.names = TRUE)) # Clear the memory of variables from previous run.
cat("\014") # Clear the console
cat("Working directory: ", getwd()) # Must be set to Project Directory

# ---- load-packages -----------------------------------------------------------
library(magrittr)  # pipes
library(ggplot2)   # graphs
library(dplyr)     # data wrangling
library(tidyr)     # data reshaping
library(stringr)   # strings
library(forcats)   # factors
library(scales)    # formatting
library(tibble)    # tibbles
library(readr)     # delimited I/O
library(knitr)     # tables
library(fs)        # file system
library(arrow)     # parquet I/O

# ---- load-sources ------------------------------------------------------------
if (file.exists("./scripts/common-functions.R")) {
  base::source("./scripts/common-functions.R")      # project-level
}
if (file.exists("./scripts/operational-functions.R")) {
  base::source("./scripts/operational-functions.R") # project-level
}

# Template visual identity. Sourcing pulls in dichromat and RColorBrewer, so it
# is attempted rather than assumed. `acru_colors_9` is the qualitative palette;
# the spine has eleven column blocks, so it is recycled where needed.
acru_colors_9 <- c(
  "red"    = "#e41a1c",
  "blue"   = "#377eb8",
  "green"  = "#4daf4a",
  "purple" = "#984ea3",
  "orange" = "#ff7f00",
  "yellow" = "#d9b800",
  "brown"  = "#a65628",
  "pink"   = "#f781bf",
  "grey"   = "#999999"
)
tryCatch(
  base::source("./scripts/graphing/graph-presets.R"),
  error = function(e) message("graph-presets.R unavailable; using local fallback palette: ", conditionMessage(e))
)
# The template yellow (#ffff33) is illegible on white at point size; darken it.
acru_colors_9[["yellow"]] <- "#d9b800"

# ---- declare-globals ---------------------------------------------------------
local_root <- "./analysis/data-primer-1/"
local_data <- paste0(local_root, "data-local/")
prints_folder <- paste0(local_root, "prints/")

if (!fs::dir_exists(local_data)) { fs::dir_create(local_data) }
if (!fs::dir_exists(prints_folder)) { fs::dir_create(prints_folder) }

# Ellis outputs. The parquet mirrors are preferred over the SQLite store because
# SQLite has no boolean type: flag_*, sig_*, and has_* arrive there as 0/1
# integers and relevance_tier as plain text, while the parquet carries real
# logicals and ordered factors.
ellis_parquet_dir <- "./data-private/derived/ellis/"
ellis_ontology_dir <- "./data-public/metadata/ellis-ontology/"

# Reading order: run provenance, then the screening apparatus, then the layers of
# the data itself from the study spine outward, then the analytic frame.
ELLIS_OBJECTS <- c(
  "ellis_runs",
  "concept_lexicon",
  "screening_flow",
  "screening_evidence",
  "study_profile",
  "study_population",
  "study_wave",
  "study_domain",
  "dementia_frame"
)

# Composite key path per object. `dementia_frame` is a view over study_profile
# and inherits its key, which the declared ontology leaves blank.
OBJECT_KEYS <- list(
  ellis_runs         = c("ellis_run_id"),
  concept_lexicon    = c("ellis_run_id", "concept", "term_label"),
  screening_flow     = c("ellis_run_id", "step"),
  screening_evidence = c("ellis_run_id", "study_id", "concept", "term_label", "source_field"),
  study_profile      = c("ellis_run_id", "study_id"),
  study_population   = c("ellis_run_id", "study_id", "population_id"),
  study_wave         = c("ellis_run_id", "study_id", "population_id", "dce_id"),
  study_domain       = c("ellis_run_id", "study_id", "area_code"),
  dementia_frame     = c("ellis_run_id", "study_id")
)

# The four parent-child edges the Ellis lane declares.
OBJECT_EDGES <- tibble::tribble(
  ~parent_table,      ~child_table,         ~join_keys,
  "study_profile",    "study_population",   c("ellis_run_id", "study_id"),
  "study_profile",    "study_domain",       c("ellis_run_id", "study_id"),
  "study_profile",    "screening_evidence", c("ellis_run_id", "study_id"),
  "study_population", "study_wave",         c("ellis_run_id", "study_id", "population_id")
)

# Columns whose distinct values constitute a controlled vocabulary. Free text and
# wide identifiers are deliberately absent.
VOCABULARY_COLUMNS <- tibble::tribble(
  ~table_name,          ~column_name,             ~vocabulary_label,
  "study_profile",      "design_label",           "Study design",
  "study_profile",      "relevance_tier",         "Dementia relevance tier",
  "study_profile",      "frame_exclusion_reason", "First failing frame criterion",
  "study_profile",      "access_data",            "Data access channel",
  "study_profile",      "access_biosamples",      "Biosample access channel",
  "study_profile",      "access_other",           "Other access channel",
  "study_domain",       "area_label",             "Maelstrom research area",
  "concept_lexicon",    "concept",                "Screening concept",
  "concept_lexicon",    "match_mode",             "Regex matching mode",
  "screening_evidence", "source_field",           "Field the term was found in"
)

# Set to a study_id to pin the worked example; NULL selects one deterministically.
PRIMER_EXAMPLE_STUDY_ID <- NULL

# ---- declare-functions -------------------------------------------------------
base::source(paste0(local_root, "local-functions.R")) # dictionary + profiling helpers

# ---- load-data ---------------------------------------------------------------
# Every object is read; a primer that documented only some of them would be a
# partial map of the store.
ds_ellis <- setNames(
  lapply(ELLIS_OBJECTS, function(object_name) {
    path <- paste0(ellis_parquet_dir, object_name, ".parquet")
    if (!file.exists(path)) {
      stop("Missing Ellis parquet mirror: ", path,
           "\nRun `Rscript ./manipulation/1-ellis-1.R` first.")
    }
    arrow::read_parquet(path)
  }),
  ELLIS_OBJECTS
)

ds_runs       <- ds_ellis[["ellis_runs"]]
ds_lexicon    <- ds_ellis[["concept_lexicon"]]
ds_flow       <- ds_ellis[["screening_flow"]]
ds_evidence   <- ds_ellis[["screening_evidence"]]
ds_profile    <- ds_ellis[["study_profile"]]
ds_population <- ds_ellis[["study_population"]]
ds_wave       <- ds_ellis[["study_wave"]]
ds_domain     <- ds_ellis[["study_domain"]]
ds_frame      <- ds_ellis[["dementia_frame"]]

# The contract the Ellis lane published alongside the data, used throughout to
# render "declared" beside "observed".
ds_declared_tables <- readr::read_csv(
  paste0(ellis_ontology_dir, "cache-tables.csv"),
  show_col_types = FALSE
)
ds_declared_edges <- readr::read_csv(
  paste0(ellis_ontology_dir, "cache-relationships.csv"),
  show_col_types = FALSE
)

# ---- out1 --------------------------------------------------------------------
# Level-1 output: which run produced the store this primer describes.
cat("Output out1: Provenance of the Ellis analytic store\n")
cat(strrep("-", 68), "\n")

ds_runs %>%
  dplyr::slice(1) %>%
  {
    provenance <- .
    field_width <- max(nchar(names(provenance)))
    for (field in names(provenance)) {
      value <- as.character(provenance[[field]])
      cat(sprintf(
        paste0("%-", field_width, "s : %s\n"),
        field,
        if (is.na(value)) "(none)" else value
      ))
    }
  }

cat("\nEvery count in this primer is an observation of the run named above,\n")
cat("not an invariant. The catalogue grows; re-read after any rebuild.\n")

# ---- t1-data-prep ------------------------------------------------------------
# Declared grain and primary key beside the rows and columns actually delivered.
t1_inventory <- lapply(ELLIS_OBJECTS, function(object_name) {
  data <- ds_ellis[[object_name]]
  tibble::tibble(
    object_name = object_name,
    observed_rows = nrow(data),
    observed_columns = ncol(data)
  )
}) %>%
  dplyr::bind_rows() %>%
  dplyr::left_join(
    ds_declared_tables %>%
      dplyr::transmute(
        object_name = table_name,
        group = table_group,
        object_type,
        grain,
        declared_rows = row_count,
        declared_columns = column_count
      ),
    by = "object_name"
  ) %>%
  dplyr::mutate(
    matches_contract = (observed_rows == declared_rows) & (observed_columns == declared_columns)
  ) %>%
  dplyr::select(
    group, object_name, object_type, grain,
    observed_rows, observed_columns,
    declared_rows, declared_columns, matches_contract
  ) %>%
  dplyr::arrange(group, object_name)

# ---- t1 ----------------------------------------------------------------------
# Level-1 table: the object inventory.
t1_inventory %>%
  dplyr::rename(
    Group = group, Object = object_name, Type = object_type, `Grain (one row per)` = grain,
    Rows = observed_rows, Columns = observed_columns,
    `Rows (declared)` = declared_rows, `Cols (declared)` = declared_columns,
    `Matches contract` = matches_contract
  ) %>%
  neat_primer(caption = "Table t1: Object inventory — declared contract beside observed delivery")

# ---- out2 --------------------------------------------------------------------
# Level-1 output: does each object hold the grain it declares?
cat("Output out2: Grain proof — composite-key uniqueness for all nine objects\n")
cat(strrep("-", 68), "\n")

out2_grain <- lapply(ELLIS_OBJECTS, function(object_name) {
  grain_check(ds_ellis[[object_name]], OBJECT_KEYS[[object_name]]) %>%
    dplyr::mutate(object_name = object_name, .before = 1)
}) %>%
  dplyr::bind_rows()

out2_grain %>%
  dplyr::select(object_name, key_path, n_rows, n_distinct_keys, n_duplicated, grain_holds) %>%
  as.data.frame() %>%
  print(row.names = FALSE, right = FALSE)

cat("\nAll grains hold: ", all(out2_grain$grain_holds), "\n", sep = "")
if (any(!is.na(out2_grain$keys_missing))) {
  cat("Key columns absent from the delivered rectangle: ",
      paste(na.omit(out2_grain$keys_missing), collapse = "; "), "\n", sep = "")
}
cat("\nWarning worth carrying forward: population_id and dce_id are sequence\n")
cat("labels local to their parent, not global keys. Any join must carry the\n")
cat("full key path shown above.\n")

# ---- t2-data-prep ------------------------------------------------------------
# Measure each declared edge rather than trusting the declaration.
t2_edges <- lapply(seq_len(nrow(OBJECT_EDGES)), function(i) {
  edge <- OBJECT_EDGES[i, ]
  keys <- edge$join_keys[[1]]
  relationship_check(
    parent = ds_ellis[[edge$parent_table]],
    child  = ds_ellis[[edge$child_table]],
    keys   = keys
  ) %>%
    dplyr::mutate(
      parent_table = edge$parent_table,
      child_table = edge$child_table,
      .before = 1
    )
}) %>%
  dplyr::bind_rows() %>%
  dplyr::left_join(
    ds_declared_edges %>%
      dplyr::transmute(parent_table, child_table, declared_cardinality),
    by = c("parent_table", "child_table")
  )

# ---- t2 ----------------------------------------------------------------------
# Level-1 table: observed cardinality of every parent-child edge.
t2_edges %>%
  dplyr::transmute(
    Parent = parent_table,
    Child = child_table,
    `Join keys` = join_keys,
    Declared = declared_cardinality,
    `Children per parent (min / mean / max)` = paste0(
      children_min, " / ", children_mean, " / ", children_max
    ),
    `Parents without children` = parents_without_children,
    `Orphan child rows` = orphan_child_rows
  ) %>%
  neat_primer(caption = "Table t2: Observed relationships between Ellis objects")

# ---- out21 -------------------------------------------------------------------
# Level-2 output: referential integrity stated plainly.
cat("Output out21: Referential integrity across the four declared edges\n")
cat(strrep("-", 68), "\n")

t2_edges %>%
  dplyr::transmute(
    edge = paste0(parent_table, " -> ", child_table),
    n_parents,
    n_children,
    parents_without_children,
    orphan_child_rows
  ) %>%
  as.data.frame() %>%
  print(row.names = FALSE, right = FALSE)

cat("\nTotal orphan child rows: ", sum(t2_edges$orphan_child_rows), "\n", sep = "")
cat("\nA parent without children is not a defect. Studies with no\n")
cat("screening_evidence rows are studies where no lexicon term matched\n")
cat("anywhere -- a substantive finding about the catalogue, not a gap.\n")

# ---- out3 --------------------------------------------------------------------
# Level-1 output: one study, followed down through all five layers. Chosen
# deterministically so the example is stable between renders.
example_study_id <- PRIMER_EXAMPLE_STUDY_ID
if (is.null(example_study_id)) {
  example_candidates <- ds_profile %>%
    dplyr::filter(
      as.logical(flag_in_frame),
      n_populations >= 2,
      n_waves >= 4
    ) %>%
    dplyr::arrange(study_id)

  example_study_id <- example_candidates %>%
    dplyr::slice(ceiling(dplyr::n() / 2)) %>%
    dplyr::pull(study_id)
}

cat("Output out3: One study across all five layers -- study_id = '", example_study_id, "'\n", sep = "")
cat(strrep("-", 68), "\n")

cat("\n[3 - study spine] one row, the study's whole description\n")
ds_profile %>%
  dplyr::filter(study_id == example_study_id) %>%
  dplyr::glimpse()

cat("\n[4 - population layer] one row per population enrolled\n")
ds_population %>%
  dplyr::filter(study_id == example_study_id) %>%
  dplyr::select(population_id, population_name, participant_number,
                minimum_age, maximum_age, primary_country, n_waves,
                first_wave_year, last_wave_year) %>%
  as.data.frame() %>%
  print(row.names = FALSE, right = FALSE)

cat("\n[5 - wave layer] one row per data collection event\n")
ds_wave %>%
  dplyr::filter(study_id == example_study_id) %>%
  dplyr::select(population_id, dce_id, wave_name, start_year, end_year,
                gap_from_prior_wave_years, has_cognitive_measures,
                has_biological_samples) %>%
  as.data.frame() %>%
  print(row.names = FALSE, right = FALSE)

cat("\n[6 - coverage matrix] research areas the study declares\n")
ds_domain %>%
  dplyr::filter(study_id == example_study_id, as.logical(has_area)) %>%
  dplyr::select(area_label, has_area, attribute_coverage_known) %>%
  as.data.frame() %>%
  print(row.names = FALSE, right = FALSE)

cat("\n[2 - screening apparatus] why this study was called relevant\n")
ds_evidence %>%
  dplyr::filter(study_id == example_study_id) %>%
  dplyr::arrange(concept, term_label) %>%
  dplyr::select(concept, term_label, source_field, n_hits, first_snippet) %>%
  dplyr::mutate(first_snippet = truncate_text(first_snippet, 70)) %>%
  as.data.frame() %>%
  print(row.names = FALSE, right = FALSE)

# ---- out4 --------------------------------------------------------------------
# Level-1 output: does the authored dictionary still describe the physical spine?
cat("Output out4: Dictionary reconciliation for study_profile\n")
cat(strrep("-", 68), "\n")

documented_columns <- SPINE_DICTIONARY$column_name
physical_columns <- names(ds_profile)

undocumented <- setdiff(physical_columns, documented_columns)
phantom <- setdiff(documented_columns, physical_columns)

cat("Columns in study_profile        : ", length(physical_columns), "\n", sep = "")
cat("Columns in the dictionary       : ", length(documented_columns), "\n", sep = "")
cat("Present but undocumented        : ",
    if (length(undocumented) == 0) "none" else paste(undocumented, collapse = ", "), "\n", sep = "")
cat("Documented but absent           : ",
    if (length(phantom) == 0) "none" else paste(phantom, collapse = ", "), "\n", sep = "")
cat("Dictionary is complete          : ",
    length(undocumented) == 0 && length(phantom) == 0, "\n", sep = "")

# ---- t3-data-prep ------------------------------------------------------------
# Authored prose joined to computed profile. Ordinal position is preserved so the
# reference reads in the same order as the physical rectangle.
t3_spine_reference <- ds_profile %>%
  profile_columns() %>%
  dplyr::mutate(ordinal_position = dplyr::row_number()) %>%
  dplyr::left_join(SPINE_DICTIONARY, by = "column_name") %>%
  dplyr::mutate(
    block = factor(block, levels = SPINE_BLOCK_ORDER),
    fill_label = scales::percent(fill_rate, accuracy = 0.1)
  ) %>%
  dplyr::arrange(block, ordinal_position)

# ---- t3 ----------------------------------------------------------------------
# Level-1 table: the full 69-column reference for the study spine.
t3_spine_reference %>%
  dplyr::transmute(
    Block = block,
    Column = column_name,
    Description = description,
    Type = r_type,
    Fill = fill_label,
    Distinct = n_distinct,
    Example = example_value
  ) %>%
  neat_primer(caption = "Table t3: study_profile — every column, described and profiled")

# ---- t31 ---------------------------------------------------------------------
# Level-2 table: the columns that carry a reading warning. Short, and the part of
# the reference most likely to prevent a wrong conclusion.
t3_spine_reference %>%
  dplyr::filter(!is.na(caution)) %>%
  dplyr::transmute(
    Column = column_name,
    Block = block,
    `Read with care` = caution
  ) %>%
  neat_primer(caption = "Table t31: Spine columns that cannot be read at face value")

# ---- g1-data-prep ------------------------------------------------------------
# Where is the catalogue thin? Fully populated columns say nothing interesting on
# a sparsity plot, so only the incomplete ones are drawn.
g1_data <- t3_spine_reference %>%
  dplyr::filter(fill_rate < 1) %>%
  dplyr::mutate(
    block = forcats::fct_drop(block),
    column_name = forcats::fct_reorder(column_name, fill_rate)
  )

g1_n_complete <- sum(t3_spine_reference$fill_rate >= 1)

# One colour per block present, recycled if the blocks outnumber the palette.
g1_palette <- setNames(
  rep(unname(acru_colors_9), length.out = nlevels(g1_data$block)),
  levels(g1_data$block)
)

# ---- g1 ----------------------------------------------------------------------
# Level-1 graph: the sparsity profile of the study spine.
g1_spine_sparsity <- g1_data %>%
  ggplot(aes(x = fill_rate, y = column_name, colour = block)) +
  geom_segment(aes(x = 0, xend = fill_rate, yend = column_name), linewidth = 0.4) +
  geom_point(size = 2.4) +
  geom_text(aes(label = fill_label), hjust = -0.25, size = 2.6, colour = "grey30") +
  scale_x_continuous(labels = scales::percent, limits = c(0, 1.12),
                     breaks = seq(0, 1, 0.25)) +
  scale_colour_manual(values = g1_palette, name = "Block") +
  labs(
    title = "Graph g1: Where the study spine is thin",
    subtitle = paste0(
      "Fill rate of every incompletely populated column of study_profile; the other ",
      g1_n_complete, " columns are fully populated"
    ),
    x = "Share of studies with a value",
    y = NULL,
    caption = "Source: data-private/derived/ellis/study_profile.parquet"
  ) +
  theme(legend.position = "bottom")

ggsave(
  paste0(prints_folder, "g1_spine_sparsity.png"),
  g1_spine_sparsity, width = 8.5, height = 5.5, dpi = 300
)
print(g1_spine_sparsity)

# ---- t4-data-prep ------------------------------------------------------------
# Spine-first: study_profile gets a full reference, the eight companions get a
# summary that says how complete each is and where its thinnest column sits.
companion_objects <- setdiff(ELLIS_OBJECTS, "study_profile")

t4_companion_profiles <- lapply(companion_objects, function(object_name) {
  profile_columns(ds_ellis[[object_name]]) %>%
    dplyr::mutate(object_name = object_name, .before = 1)
}) %>%
  dplyr::bind_rows()

t4_companion_summary <- t4_companion_profiles %>%
  dplyr::group_by(object_name) %>%
  dplyr::arrange(fill_rate, .by_group = TRUE) %>%
  dplyr::summarise(
    n_columns = dplyr::n(),
    n_fully_populated = sum(fill_rate >= 1),
    n_below_half = sum(fill_rate < 0.5),
    thinnest_column = dplyr::first(column_name),
    thinnest_fill = scales::percent(dplyr::first(fill_rate), accuracy = 0.1),
    .groups = "drop"
  ) %>%
  dplyr::mutate(object_name = factor(object_name, levels = ELLIS_OBJECTS)) %>%
  dplyr::arrange(object_name)

# ---- t4 ----------------------------------------------------------------------
# Level-1 table: how complete each companion object is.
t4_companion_summary %>%
  dplyr::transmute(
    Object = object_name,
    Columns = n_columns,
    `Fully populated` = n_fully_populated,
    `Below 50% fill` = n_below_half,
    `Thinnest column` = thinnest_column,
    `Its fill` = thinnest_fill
  ) %>%
  neat_primer(caption = "Table t4: Companion objects — column completeness at a glance")

# ---- t41 ---------------------------------------------------------------------
# Level-2 table: column-level reference for the four analytic layers. The run,
# lexicon, and flow objects are small enough to read directly from t1 and t6.
t41_layers <- c("study_population", "study_wave", "study_domain", "screening_evidence")

t4_companion_profiles %>%
  dplyr::filter(object_name %in% t41_layers) %>%
  dplyr::mutate(object_name = factor(object_name, levels = t41_layers)) %>%
  dplyr::arrange(object_name) %>%
  dplyr::transmute(
    Object = object_name,
    Column = column_name,
    Type = r_type,
    Fill = scales::percent(fill_rate, accuracy = 0.1),
    Distinct = n_distinct,
    Example = example_value
  ) %>%
  neat_primer(caption = "Table t41: Column reference for the population, wave, coverage, and evidence layers")

# ---- t5-data-prep ------------------------------------------------------------
# Every distinct value of every controlled-vocabulary column, counted.
t5_vocabularies <- lapply(seq_len(nrow(VOCABULARY_COLUMNS)), function(i) {
  spec <- VOCABULARY_COLUMNS[i, ]
  data <- ds_ellis[[spec$table_name]]
  if (!spec$column_name %in% names(data)) return(NULL)

  data %>%
    dplyr::count(value = .data[[spec$column_name]], name = "n_rows") %>%
    dplyr::arrange(dplyr::desc(n_rows)) %>%
    dplyr::mutate(
      table_name = spec$table_name,
      column_name = spec$column_name,
      vocabulary_label = spec$vocabulary_label,
      value = dplyr::coalesce(as.character(value), "(missing)"),
      .before = 1
    )
}) %>%
  dplyr::bind_rows()

# ---- t5 ----------------------------------------------------------------------
# Level-1 table: the controlled vocabularies, collapsed one row per column.
t5_vocabularies %>%
  dplyr::group_by(table_name, column_name, vocabulary_label) %>%
  dplyr::summarise(
    n_values = dplyr::n(),
    values = paste0(value, " (", scales::comma(n_rows), ")", collapse = "; "),
    .groups = "drop"
  ) %>%
  dplyr::transmute(
    Object = table_name,
    Column = column_name,
    Vocabulary = vocabulary_label,
    Values = n_values,
    `Distinct values (row count)` = truncate_text(values, 200)
  ) %>%
  neat_primer(caption = "Table t5: Controlled vocabularies of the Ellis store")

# ---- t6-data-prep ------------------------------------------------------------
# The funnel as the lane delivered it, plus the tier distribution behind step 1.
t6_funnel <- ds_flow %>%
  dplyr::select(-dplyr::any_of("ellis_run_id"))

t61_tiers <- ds_profile %>%
  dplyr::count(relevance_tier, flag_in_frame = as.logical(flag_in_frame), name = "n_studies") %>%
  tidyr::pivot_wider(
    names_from = flag_in_frame,
    values_from = n_studies,
    names_prefix = "in_frame_",
    values_fill = 0L
  ) %>%
  dplyr::arrange(relevance_tier)

# ---- t6 ----------------------------------------------------------------------
# Level-1 table: the screening funnel.
t6_funnel %>%
  neat_primer(caption = "Table t6: The screening funnel, as delivered by the Ellis lane")

# ---- t61 ---------------------------------------------------------------------
# Level-2 table: relevance tier against frame membership.
t61_tiers %>%
  dplyr::rename(
    `Relevance tier` = relevance_tier,
    `Excluded from frame` = in_frame_FALSE,
    `In frame` = in_frame_TRUE
  ) %>%
  neat_primer(caption = "Table t61: Relevance tier against analytic frame membership")

# ---- save-to-disk ------------------------------------------------------------
# The spine reference is written out so it can be diffed after a rebuild without
# re-rendering the document.
readr::write_csv(
  t3_spine_reference %>%
    dplyr::select(block, ordinal_position, column_name, description, caution,
                  r_type, n_non_null, fill_rate, n_distinct, example_value),
  paste0(local_data, "spine-variable-reference.csv")
)

readr::write_csv(
  t4_companion_profiles,
  paste0(local_data, "companion-column-profiles.csv")
)
# nolint end
