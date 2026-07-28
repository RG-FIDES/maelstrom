rm(list = ls(all.names = TRUE)) # Clear the memory of variables from previous run.
cat("\014") # Clear the console
cat("Working directory: ", getwd()) # Must be set to Project Directory

# ---- SECTION: Maelstrom Catalog Extraction -----------------------------------
# Pull public Maelstrom individual-study metadata into a local SQLite database.

# ---- load-packages -----------------------------------------------------------
invisible(requireNamespace("DBI", quietly = TRUE))
invisible(requireNamespace("RSQLite", quietly = TRUE))
invisible(requireNamespace("curl", quietly = TRUE))
invisible(requireNamespace("jsonlite", quietly = TRUE))
invisible(requireNamespace("config", quietly = TRUE))

# ---- load-sources ------------------------------------------------------------
if (file.exists("./scripts/common-functions.R")) {
  source("./scripts/common-functions.R", local = TRUE)
}

# ---- declare-globals ---------------------------------------------------------
BASE_URL <- "https://www.maelstrom-research.org"
INVENTORY_FIELDS <- paste(
  "id",
  "acronym.*",
  "name.*",
  "objectives.*",
  "studyResourcePath",
  "model.methods.design",
  "model.numberOfParticipants.participant",
  sep = ","
)
DEFAULT_PAGE_SIZE <- 50L
DEFAULT_MAX_STUDIES <- Inf
PROJECT_CONFIG <- config::get(file = "./config.yml")
DEFAULT_DB_PATH <- PROJECT_CONFIG$database$maelstrom_catalog$staging
DEFAULT_SCHEMA_PATH <- "./manipulation/maelstrom-catalog-schema.sql"

if (is.null(DEFAULT_DB_PATH) || !nzchar(DEFAULT_DB_PATH)) {
  stop("Missing database.maelstrom_catalog.staging in config.yml")
}

# ---- declare-functions -------------------------------------------------------
parse_args <- function(args) {
  parsed <- list(
    db_path = DEFAULT_DB_PATH,
    page_size = DEFAULT_PAGE_SIZE,
    max_studies = DEFAULT_MAX_STUDIES,
    schema_path = DEFAULT_SCHEMA_PATH
  )

  for (argument in args) {
    parts <- strsplit(argument, "=", fixed = TRUE)[[1]]
    if (length(parts) != 2) {
      next
    }

    key <- parts[[1]]
    value <- parts[[2]]

    if (key == "--db-path") {
      parsed$db_path <- value
    }
    if (key == "--page-size") {
      parsed$page_size <- as.integer(value)
    }
    if (key == "--max-studies") {
      parsed$max_studies <- as.integer(value)
    }
    if (key == "--schema-path") {
      parsed$schema_path <- value
    }
  }

  parsed
}

ensure_parent_dir <- function(path) {
  parent_dir <- dirname(path)
  if (!dir.exists(parent_dir)) {
    dir.create(parent_dir, recursive = TRUE)
  }
}

now_utc <- function() {
  format(Sys.time(), tz = "UTC", usetz = TRUE)
}

safe_scalar <- function(value) {
  if (is.null(value) || length(value) == 0) {
    return(NA)
  }

  if (is.list(value)) {
    return(NA)
  }

  value[[1]]
}

safe_integer <- function(value) {
  scalar <- safe_scalar(value)
  if (is.na(scalar) || identical(scalar, "")) {
    return(NA_integer_)
  }

  suppressWarnings(as.integer(scalar))
}

safe_logical_int <- function(value) {
  scalar <- safe_scalar(value)
  if (is.na(scalar)) {
    return(NA_integer_)
  }

  as.integer(isTRUE(scalar))
}

localized_value <- function(values, preferred_lang = "en") {
  if (is.null(values) || length(values) == 0) {
    return(NA_character_)
  }

  if (is.character(values) && length(values) == 1) {
    return(values)
  }

  if (!is.list(values)) {
    return(as.character(values[[1]]))
  }

  for (entry in values) {
    lang <- entry$lang %||% entry$locale
    if (!is.null(lang) && identical(lang, preferred_lang)) {
      return(entry$value %||% entry$text %||% NA_character_)
    }
  }

  first_entry <- values[[1]]
  first_entry$value %||% first_entry$text %||% NA_character_
}

`%||%` <- function(lhs, rhs) {
  if (is.null(lhs) || length(lhs) == 0) {
    rhs
  } else {
    lhs
  }
}

country_iso_from_address <- function(address) {
  if (is.null(address) || is.null(address$country)) {
    return(NA_character_)
  }

  safe_scalar(address$country$iso)
}

api_get_json <- function(url, referer) {
  handle <- curl::new_handle()
  curl::handle_setheaders(
    handle,
    "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)",
    "Referer" = referer,
    "Accept" = "application/json, text/plain, */*"
  )

  response <- curl::curl_fetch_memory(url, handle = handle)

  if (!identical(response$status_code, 200L)) {
    stop("Request failed [", response$status_code, "] for ", url)
  }

  jsonlite::fromJSON(rawToChar(response$content), simplifyVector = FALSE)
}

build_inventory_url <- function(offset, limit) {
  query <- paste0(
    "study(in(Mica_study.className,Study),",
    "limit(", offset, ",", limit, "),",
    "fields(", INVENTORY_FIELDS, "),",
    "sort(name))"
  )

  paste0(
    BASE_URL,
    "/ws/studies/_rql?query=",
    utils::URLencode(query, reserved = TRUE),
    ",locale(en)"
  )
}

fetch_inventory_page <- function(offset, limit) {
  inventory_url <- build_inventory_url(offset = offset, limit = limit)
  payload <- api_get_json(
    url = inventory_url,
    referer = paste0(BASE_URL, "/individual-studies?query=study(in(Mica_study.className,Study),limit(0,50),sort(name))")
  )

  study_payload <- payload$studyResultDto
  list(
    url = inventory_url,
    total_hits = safe_integer(study_payload$totalHits),
    total_count = safe_integer(study_payload$totalCount),
    summaries = study_payload$studyResult$summaries %||% list()
  )
}

fetch_inventory <- function(page_size, max_studies) {
  offset <- 0L
  page_index <- 0L
  all_summaries <- list()
  expected_total <- NA_integer_
  inventory_url <- NA_character_

  repeat {
    page <- fetch_inventory_page(offset = offset, limit = page_size)
    inventory_url <- page$url
    expected_total <- ifelse(is.na(expected_total), page$total_hits, expected_total)
    page_summaries <- page$summaries

    if (length(page_summaries) == 0) {
      break
    }

    for (summary in page_summaries) {
      page_index <- page_index + 1L
      summary$inventory_rank <- page_index
      summary$inventory_source_url <- page$url
      all_summaries[[length(all_summaries) + 1L]] <- summary

      if (is.finite(max_studies) && page_index >= max_studies) {
        break
      }
    }

    if (is.finite(max_studies) && page_index >= max_studies) {
      break
    }

    offset <- offset + page_size
    if (!is.na(expected_total) && offset >= expected_total) {
      break
    }
  }

  list(
    inventory_url = inventory_url,
    expected_total = expected_total,
    summaries = all_summaries
  )
}

fetch_study_detail <- function(study_id) {
  url <- paste0(BASE_URL, "/ws/study/", study_id)
  payload <- api_get_json(
    url = url,
    referer = paste0(BASE_URL, "/study/", study_id)
  )

  list(url = url, payload = payload)
}

parse_content_json <- function(content_text) {
  if (is.null(content_text) || length(content_text) == 0 || is.na(content_text) || identical(content_text, "")) {
    return(list())
  }

  jsonlite::fromJSON(content_text, simplifyVector = FALSE)
}

summary_row_from_inventory <- function(run_id, summary) {
  participant <- summary$targetNumber %||% summary$model$numberOfParticipants$participant %||% list()

  data.frame(
    run_id = run_id,
    inventory_rank = safe_integer(summary$inventory_rank),
    study_id = safe_scalar(summary$id),
    source_url = safe_scalar(summary$inventory_source_url),
    study_page_url = paste0(BASE_URL, "/study/", safe_scalar(summary$id)),
    study_resource_path = safe_scalar(summary$studyResourcePath),
    name_en = localized_value(summary$name),
    acronym_en = localized_value(summary$acronym),
    objectives_html_en = localized_value(summary$objectives),
    design_code = safe_scalar(summary$design %||% summary$model$methods$design),
    target_number = safe_integer(participant$number),
    target_no_limit = safe_logical_int(participant$noLimit),
    summary_json = jsonlite::toJSON(summary, auto_unbox = TRUE, null = "null"),
    stringsAsFactors = FALSE
  )
}

study_row_from_detail <- function(run_id, detail_payload) {
  content <- parse_content_json(detail_payload$content)
  access <- content$access %||% list()
  methods <- content$methods %||% list()
  target <- content$numberOfParticipants$participant %||% list()
  maelstrom_auth <- content$maelstromAuthorization %||% list()
  specific_auth <- content$specificAuthorization %||% list()

  data.frame(
    run_id = run_id,
    study_id = safe_scalar(detail_payload$id),
    published = safe_logical_int(detail_payload$published),
    study_resource_path = safe_scalar(detail_payload$studyResourcePath),
    name_en = localized_value(detail_payload$name),
    acronym_en = localized_value(detail_payload$acronym),
    objectives_html_en = localized_value(detail_payload$objectives),
    website_url = safe_scalar(content$website),
    design_code = safe_scalar(methods$design),
    follow_up_info_html_en = methods$followUpInfo$en %||% NA_character_,
    methods_info_html_en = methods$info$en %||% NA_character_,
    start_year = safe_integer(content$startYear),
    recruitment_target = paste(methods$recruitments %||% character(), collapse = "|"),
    target_number = safe_integer(target$number),
    target_no_limit = safe_logical_int(target$noLimit),
    access_data = safe_scalar(access$access_data),
    access_biosamples = safe_scalar(access$access_bio_samples),
    access_other = safe_scalar(access$access_other),
    access_fees = safe_logical_int(content$access_fees),
    access_restrictions = safe_logical_int(content$access_restrictions),
    maelstrom_authorized = safe_logical_int(maelstrom_auth$authorized),
    maelstrom_authorizer = safe_scalar(maelstrom_auth$authorizer),
    maelstrom_authorization_date = safe_scalar(maelstrom_auth$date),
    specific_authorized = safe_logical_int(specific_auth$authorized),
    specific_authorizer = safe_scalar(specific_auth$authorizer),
    specific_authorization_date = safe_scalar(specific_auth$date),
    marker_paper = safe_scalar(content$markerPaper),
    pubmed_id = safe_scalar(content$pubmedId),
    content_json = jsonlite::toJSON(content, auto_unbox = TRUE, null = "null"),
    stringsAsFactors = FALSE
  )
}

membership_rows_from_detail <- function(run_id, study_id, memberships) {
  rows <- list()

  for (membership in memberships %||% list()) {
    role <- safe_scalar(membership$role)

    for (member in membership$members %||% list()) {
      rows[[length(rows) + 1L]] <- data.frame(
        run_id = run_id,
        study_id = study_id,
        membership_role = role,
        member_id = safe_scalar(member$id),
        title = safe_scalar(member$title),
        first_name = safe_scalar(member$firstName),
        last_name = safe_scalar(member$lastName),
        email = safe_scalar(member$email),
        phone = safe_scalar(member$phone),
        institution_name_en = localized_value(member$institution$name),
        department_en = localized_value(member$institution$department),
        city_en = localized_value(member$institution$address$city),
        country_iso = country_iso_from_address(member$institution$address),
        member_json = jsonlite::toJSON(member, auto_unbox = TRUE, null = "null"),
        stringsAsFactors = FALSE
      )
    }
  }

  rows
}

attribute_rows_from_detail <- function(run_id, study_id, attributes) {
  rows <- list()

  for (attribute in attributes %||% list()) {
    rows[[length(rows) + 1L]] <- data.frame(
      run_id = run_id,
      study_id = study_id,
      attribute_namespace = safe_scalar(attribute$namespace),
      attribute_name = safe_scalar(attribute$name),
      stringsAsFactors = FALSE
    )
  }

  rows
}

population_bundle_from_detail <- function(run_id, study_id, populations) {
  population_rows <- list()
  country_rows <- list()
  recruitment_rows <- list()
  dce_rows <- list()
  dce_source_rows <- list()
  dce_biosample_rows <- list()

  for (population in populations %||% list()) {
    population_content <- parse_content_json(population$content)
    pop_number <- population_content$numberOfParticipants$participant %||% list()
    sample_number <- population_content$numberOfParticipants$sample %||% list()
    selection <- population_content$selectionCriteria %||% list()
    recruitment <- population_content$recruitment %||% list()
    population_id <- safe_scalar(population$id)

    population_rows[[length(population_rows) + 1L]] <- data.frame(
      run_id = run_id,
      study_id = study_id,
      population_id = population_id,
      display_order = safe_integer(population$weight),
      name_en = localized_value(population$name),
      description_html_en = localized_value(population$description),
      participant_number = safe_integer(pop_number$number),
      participant_no_limit = safe_logical_int(pop_number$noLimit),
      sample_number = safe_integer(sample_number$number),
      sample_no_limit = safe_logical_int(sample_number$noLimit),
      participant_info_html_en = population_content$numberOfParticipants$info$en %||% NA_character_,
      minimum_age = safe_integer(selection$ageMin),
      maximum_age = safe_integer(selection$ageMax),
      newborn = safe_logical_int(selection$newborn),
      twins = safe_logical_int(selection$twins),
      territory_html_en = selection$territory$en %||% NA_character_,
      content_json = jsonlite::toJSON(population_content, auto_unbox = TRUE, null = "null"),
      stringsAsFactors = FALSE
    )

    for (country_iso in selection$countriesIso %||% character()) {
      country_rows[[length(country_rows) + 1L]] <- data.frame(
        run_id = run_id,
        study_id = study_id,
        population_id = population_id,
        country_iso = country_iso,
        stringsAsFactors = FALSE
      )
    }

    recruitment_map <- list(
      data_sources = recruitment$dataSources %||% character(),
      general_population_sources = recruitment$generalPopulationSources %||% character(),
      specific_population_sources = recruitment$specificPopulationSources %||% character()
    )

    for (term_group in names(recruitment_map)) {
      for (term_value in recruitment_map[[term_group]]) {
        recruitment_rows[[length(recruitment_rows) + 1L]] <- data.frame(
          run_id = run_id,
          study_id = study_id,
          population_id = population_id,
          term_group = term_group,
          term_value = term_value,
          stringsAsFactors = FALSE
        )
      }
    }

    for (dce in population$dataCollectionEvents %||% list()) {
      dce_content <- parse_content_json(dce$content)
      dce_id <- safe_scalar(dce$id)

      dce_rows[[length(dce_rows) + 1L]] <- data.frame(
        run_id = run_id,
        study_id = study_id,
        population_id = population_id,
        dce_id = dce_id,
        display_order = safe_integer(dce$weight),
        name_en = localized_value(dce$name),
        description_html_en = localized_value(dce$description),
        start_year = safe_integer(dce$startYear %||% dce$start),
        end_year = safe_integer(dce$endYear %||% dce$end),
        other_data_sources_html_en = dce_content$otherDataSources$en %||% NA_character_,
        content_json = jsonlite::toJSON(dce_content, auto_unbox = TRUE, null = "null"),
        stringsAsFactors = FALSE
      )

      for (data_source_code in dce_content$dataSources %||% character()) {
        dce_source_rows[[length(dce_source_rows) + 1L]] <- data.frame(
          run_id = run_id,
          study_id = study_id,
          population_id = population_id,
          dce_id = dce_id,
          data_source_code = data_source_code,
          stringsAsFactors = FALSE
        )
      }

      for (biosample_code in dce_content$bioSamples %||% character()) {
        dce_biosample_rows[[length(dce_biosample_rows) + 1L]] <- data.frame(
          run_id = run_id,
          study_id = study_id,
          population_id = population_id,
          dce_id = dce_id,
          biosample_code = biosample_code,
          stringsAsFactors = FALSE
        )
      }
    }
  }

  list(
    populations = population_rows,
    countries = country_rows,
    recruitment_terms = recruitment_rows,
    data_collection_events = dce_rows,
    dce_data_sources = dce_source_rows,
    dce_biosamples = dce_biosample_rows
  )
}

bind_rows_safe <- function(rows) {
  if (length(rows) == 0) {
    return(NULL)
  }

  do.call(rbind, rows)
}

apply_schema <- function(con, schema_path) {
  schema_sql <- readLines(schema_path, warn = FALSE)
  statements <- strsplit(paste(schema_sql, collapse = "\n"), ";", fixed = TRUE)[[1]]
  statements <- trimws(statements)
  statements <- statements[nzchar(statements)]

  for (statement in statements) {
    DBI::dbExecute(con, statement)
  }
}

write_frame <- function(con, name, frame) {
  if (is.null(frame) || nrow(frame) == 0) {
    return(invisible(NULL))
  }

  DBI::dbWriteTable(con, name, frame, append = TRUE)
}

# ---- execute-extraction ------------------------------------------------------
arguments <- parse_args(commandArgs(trailingOnly = TRUE))
invisible(ensure_parent_dir(arguments$db_path))
build_db_path <- paste0(arguments$db_path, ".building")

if (file.exists(build_db_path) && !file.remove(build_db_path)) {
  stop("Could not remove incomplete build database: ", build_db_path)
}

run_id <- paste0("maelstrom-", format(Sys.time(), "%Y%m%dT%H%M%S", tz = "UTC"))
run_started_at <- now_utc()

inventory <- fetch_inventory(
  page_size = arguments$page_size,
  max_studies = arguments$max_studies
)

inventory_rows <- lapply(inventory$summaries, function(summary) {
  summary_row_from_inventory(run_id = run_id, summary = summary)
})

detail_rows <- list()
study_rows <- list()
membership_rows <- list()
attribute_rows <- list()
population_rows <- list()
country_rows <- list()
recruitment_rows <- list()
dce_rows <- list()
dce_source_rows <- list()
dce_biosample_rows <- list()

for (summary in inventory$summaries) {
  study_id <- safe_scalar(summary$id)
  detail <- fetch_study_detail(study_id = study_id)
  detail_payload <- detail$payload

  detail_rows[[length(detail_rows) + 1L]] <- data.frame(
    run_id = run_id,
    study_id = study_id,
    source_url = detail$url,
    fetched_at_utc = now_utc(),
    payload_json = jsonlite::toJSON(detail_payload, auto_unbox = TRUE, null = "null"),
    stringsAsFactors = FALSE
  )

  study_rows[[length(study_rows) + 1L]] <- study_row_from_detail(
    run_id = run_id,
    detail_payload = detail_payload
  )

  membership_rows <- c(
    membership_rows,
    membership_rows_from_detail(run_id = run_id, study_id = study_id, memberships = detail_payload$memberships)
  )
  attribute_rows <- c(
    attribute_rows,
    attribute_rows_from_detail(run_id = run_id, study_id = study_id, attributes = detail_payload$attributes)
  )

  population_bundle <- population_bundle_from_detail(
    run_id = run_id,
    study_id = study_id,
    populations = detail_payload$populations
  )

  population_rows <- c(population_rows, population_bundle$populations)
  country_rows <- c(country_rows, population_bundle$countries)
  recruitment_rows <- c(recruitment_rows, population_bundle$recruitment_terms)
  dce_rows <- c(dce_rows, population_bundle$data_collection_events)
  dce_source_rows <- c(dce_source_rows, population_bundle$dce_data_sources)
  dce_biosample_rows <- c(dce_biosample_rows, population_bundle$dce_biosamples)
}

inventory_frame <- bind_rows_safe(inventory_rows)
detail_frame <- bind_rows_safe(detail_rows)
study_frame <- bind_rows_safe(study_rows)
membership_frame <- bind_rows_safe(membership_rows)
attribute_frame <- bind_rows_safe(attribute_rows)
population_frame <- bind_rows_safe(population_rows)
country_frame <- bind_rows_safe(country_rows)
recruitment_frame <- bind_rows_safe(recruitment_rows)
dce_frame <- bind_rows_safe(dce_rows)
dce_source_frame <- bind_rows_safe(dce_source_rows)
dce_biosample_frame <- bind_rows_safe(dce_biosample_rows)

# ---- validate ----------------------------------------------------------------
expected_extract_count <- if (is.finite(arguments$max_studies)) {
  min(inventory$expected_total, arguments$max_studies)
} else {
  inventory$expected_total
}

if (nrow(inventory_frame) != expected_extract_count) {
  stop(
    "Inventory count mismatch: expected ", expected_extract_count,
    ", extracted ", nrow(inventory_frame)
  )
}

if (nrow(detail_frame) != nrow(inventory_frame)) {
  stop("Detail count does not match inventory count")
}

if (nrow(study_frame) != nrow(inventory_frame)) {
  stop("Normalized study count does not match inventory count")
}

if (anyDuplicated(inventory_frame$study_id)) {
  stop("Duplicate study IDs detected in the inventory")
}

if (!setequal(inventory_frame$study_id, study_frame$study_id)) {
  stop("Normalized study IDs do not match inventory study IDs")
}

# ---- save-to-disk ------------------------------------------------------------
con <- DBI::dbConnect(RSQLite::SQLite(), build_db_path)
connection_open <- TRUE
on.exit({
  if (connection_open) {
    DBI::dbDisconnect(con)
  }
}, add = TRUE)

invisible(apply_schema(con = con, schema_path = arguments$schema_path))

invisible(DBI::dbWithTransaction(con, {
  DBI::dbWriteTable(
    con,
    "extraction_runs",
    data.frame(
      run_id = run_id,
      started_at_utc = run_started_at,
      completed_at_utc = NA_character_,
      base_url = BASE_URL,
      inventory_url = inventory$inventory_url,
      requested_max_studies = if (is.finite(arguments$max_studies)) arguments$max_studies else NA_integer_,
      page_size = arguments$page_size,
      expected_total_studies = inventory$expected_total,
      extracted_inventory_studies = nrow(inventory_frame),
      extracted_detail_studies = nrow(study_frame),
      status = "running",
      notes = NA_character_,
      stringsAsFactors = FALSE
    ),
    append = TRUE
  )

  write_frame(con, "study_inventory", inventory_frame)
  write_frame(con, "study_detail_raw", detail_frame)
  write_frame(con, "studies", study_frame)
  write_frame(con, "study_memberships", membership_frame)
  write_frame(con, "study_attributes", attribute_frame)
  write_frame(con, "study_populations", population_frame)
  write_frame(con, "population_countries", country_frame)
  write_frame(con, "population_recruitment_terms", recruitment_frame)
  write_frame(con, "data_collection_events", dce_frame)
  write_frame(con, "dce_data_sources", dce_source_frame)
  write_frame(con, "dce_biosamples", dce_biosample_frame)

  invisible(DBI::dbExecute(
    con,
    paste(
      "UPDATE extraction_runs",
      "SET completed_at_utc = ?, status = 'completed'",
      "WHERE run_id = ?"
    ),
    params = list(now_utc(), run_id)
  ))
}))

DBI::dbDisconnect(con)
connection_open <- FALSE

if (file.exists(arguments$db_path) && !file.remove(arguments$db_path)) {
  stop("Could not replace existing database: ", arguments$db_path)
}

if (!file.rename(build_db_path, arguments$db_path)) {
  stop("Could not promote completed database to: ", arguments$db_path)
}

cat("\nRun ID: ", run_id, sep = "")
cat("\nDatabase: ", arguments$db_path, sep = "")
cat("\nExpected studies: ", inventory$expected_total, sep = "")
cat("\nInventory summaries written: ", nrow(inventory_frame), sep = "")
cat("\nStudy details written: ", nrow(study_frame), sep = "")
cat("\nPopulations written: ", ifelse(is.null(population_frame), 0L, nrow(population_frame)), sep = "")
cat("\nData collection events written: ", ifelse(is.null(dce_frame), 0L, nrow(dce_frame)), sep = "")