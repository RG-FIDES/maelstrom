rm(list = ls(all.names = TRUE)) # Clear the memory of variables from previous run.
cat("\014") # Clear the console
cat("Working directory: ", getwd()) # Must be set to Project Directory

# Purpose: Validate that every page in content/ honours the protocol the
#          publishing contract assigned to it, and write FIDELITY_REPORT.md.
# Bootstrapped from: .github/templates/audit-fidelity-template.R
# Extended with: page-level VERBATIM body equivalence, REDIRECT placement,
#          ADAPTED transform-log coverage, COMPOSED grounding, self-containment,
#          and source fingerprint capture.

# ---- load-packages -----------------------------------------------------------
if (!requireNamespace("tools", quietly = TRUE)) {
  stop("Package 'tools' is required.")
}

has_digest <- requireNamespace("digest", quietly = TRUE)

# ---- declare-globals ---------------------------------------------------------
args <- commandArgs(trailingOnly = TRUE)
frontend_path <- if (length(args) >= 1) args[[1]] else "."
repo_root <- file.path(frontend_path, "..")
contract_path <- file.path(frontend_path, "publishing-contract.prompt.md")
content_path <- file.path(frontend_path, "content")
site_path <- file.path(frontend_path, "_site")
transform_log_path <- file.path(frontend_path, "TRANSFORM_LOG.md")
report_path <- file.path(frontend_path, "FIDELITY_REPORT.md")

hash_label <- if (has_digest) "sha256" else "md5"

verbatim_pages <- list(
  list(page = "content/project/mission.qmd", source = "ai/project/mission.md"),
  list(page = "content/project/method.qmd", source = "ai/project/method.md"),
  list(page = "content/project/glossary.qmd", source = "ai/project/glossary.md"),
  list(page = "content/pipeline/cache-manifest.qmd", source = "data-public/metadata/CACHE-manifest.md"),
  list(page = "content/pipeline/input-manifest.qmd", source = "data-public/metadata/INPUT-manifest.md")
)

adapted_pages <- list(
  list(
    page = "content/pipeline/pipeline-guide.qmd",
    source = "manipulation/pipeline.md",
    partial = "content/pipeline/_mermaid-pipeline.qmd",
    allowed = c(
      "link_rewrite", "shortcode_injection", "sanitize",
      "extension_promotion", "frontmatter_add"
    )
  )
)

redirect_pages <- list(
  list(
    page = "content/primers/data-primer-1.qmd",
    source = "analysis/data-primer-1/data-primer-1.html",
    target = "_site/reports/data-primer-1.html",
    rendered_stub = "_site/content/primers/data-primer-1.html"
  )
)

composed_pages <- list(
  list(
    page = "content/index.qmd",
    brief_fields = c("Intent", "Goal", "Spirit", "Inputs"),
    grounding = c(
      "ai/project/mission.md",
      "manipulation/pipeline.md",
      "data-public/metadata/INPUT-manifest.md",
      "data-public/metadata/CACHE-manifest.md"
    ),
    required_markers = c("## Welcome", "images/pipeline-architecture.png")
  ),
  list(
    page = "content/site-map.qmd",
    brief_fields = c("Intent", "Goal", "Spirit", "Inputs"),
    grounding = character(0),
    required_markers = c("## Output Types", "## Navigation Structure")
  )
)

# ---- declare-functions -------------------------------------------------------
status_rank <- function(status) {
  if (identical(status, "fail")) {
    return(3L)
  }
  if (identical(status, "warn")) {
    return(2L)
  }
  1L
}

merge_status <- function(current_status, new_status) {
  if (status_rank(new_status) > status_rank(current_status)) {
    return(new_status)
  }
  current_status
}

check_condition <- function(ok, pass_message, fail_message, fail_is_warn = FALSE) {
  if (isTRUE(ok)) {
    return(list(status = "pass", message = pass_message))
  }
  if (isTRUE(fail_is_warn)) {
    return(list(status = "warn", message = fail_message))
  }
  list(status = "fail", message = fail_message)
}

count_matches <- function(path, pattern) {
  if (!file.exists(path)) {
    return(0L)
  }
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  sum(grepl(pattern, lines, perl = TRUE))
}

read_lines_safe <- function(path) {
  if (!file.exists(path)) {
    return(character(0))
  }
  readLines(path, warn = FALSE, encoding = "UTF-8")
}

strip_frontmatter <- function(lines) {
  if (length(lines) < 2L || !identical(trimws(lines[[1]]), "---")) {
    return(lines)
  }
  closing <- which(trimws(lines[-1]) == "---")
  if (length(closing) == 0L) {
    return(lines)
  }
  lines[-seq_len(closing[[1]] + 1L)]
}

trim_blank_edges <- function(lines) {
  if (length(lines) == 0L) {
    return(lines)
  }
  keep <- which(trimws(lines) != "")
  if (length(keep) == 0L) {
    return(character(0))
  }
  lines[seq(min(keep), max(keep))]
}

fingerprint <- function(path) {
  if (!file.exists(path)) {
    return("<missing>")
  }
  if (has_digest) {
    return(digest::digest(file = path, algo = "sha256"))
  }
  unname(tools::md5sum(path))
}

first_diff_line <- function(a, b) {
  n <- min(length(a), length(b))
  if (n > 0L) {
    mismatch <- which(a[seq_len(n)] != b[seq_len(n)])
    if (length(mismatch) > 0L) {
      return(mismatch[[1]])
    }
  }
  if (length(a) != length(b)) {
    return(n + 1L)
  }
  NA_integer_
}

# ---- load-data ---------------------------------------------------------------
has_contract <- file.exists(contract_path)
has_content <- dir.exists(content_path)
has_site <- dir.exists(site_path)
has_transform_log <- file.exists(transform_log_path)

protocol_mode_output_mapping <- list(
  VERBATIM = "Direct Line \\(VERBATIM\\)",
  REDIRECT = "Direct Line \\(REDIRECTED\\)",
  ADAPTED = "Technical Bridge",
  COMPOSED = "Narrative Bridge"
)

output_type_counts <- lapply(protocol_mode_output_mapping, function(pattern) {
  count_matches(contract_path, pattern)
})

verbatim_count <- output_type_counts$VERBATIM
redirect_count <- output_type_counts$REDIRECT
adapted_count <- output_type_counts$ADAPTED
composed_count <- output_type_counts$COMPOSED

# Count only real digests. The template matched the bare token, which a contract
# can satisfy merely by discussing source_sha256 in prose.
source_hash_count <- count_matches(
  contract_path,
  "source_sha256\\*{0,2}\\s*:\\s*\\**[0-9a-fA-F]{64}"
)
allowed_transform_count <- count_matches(contract_path, "allowed_transforms\\*{0,2}\\s*:")

contract_lines <- read_lines_safe(contract_path)
transform_log_lines <- read_lines_safe(transform_log_path)

# ---- validate-structure ------------------------------------------------------
overall_status <- "pass"
checks <- list()

checks[[length(checks) + 1L]] <- check_condition(
  has_contract,
  "Contract file found.",
  "Contract file missing: publishing-contract.prompt.md"
)

checks[[length(checks) + 1L]] <- check_condition(
  has_content,
  "content/ exists.",
  "content/ missing."
)

checks[[length(checks) + 1L]] <- check_condition(
  has_site,
  "_site/ exists.",
  "_site/ missing."
)

checks[[length(checks) + 1L]] <- check_condition(
  !(adapted_count > 0L) || has_transform_log,
  "Transform log requirement satisfied.",
  "TRANSFORM_LOG.md is required when Technical Bridge pages are present."
)

checks[[length(checks) + 1L]] <- check_condition(
  source_hash_count > 0L,
  "Contract includes source_sha256 metadata.",
  "No source_sha256 fields found in contract (recommended for deterministic drift checks). Fingerprints captured below can seed them.",
  fail_is_warn = TRUE
)

checks[[length(checks) + 1L]] <- check_condition(
  !(adapted_count > 0L) || allowed_transform_count > 0L,
  "allowed_transforms metadata present for Technical Bridge pages.",
  "Technical Bridge pages detected but allowed_transforms metadata was not found.",
  fail_is_warn = TRUE
)

# ---- validate-verbatim -------------------------------------------------------
verbatim_rows <- list()

for (item in verbatim_pages) {
  page_path <- file.path(frontend_path, item$page)
  source_path <- file.path(repo_root, item$source)

  page_body <- trim_blank_edges(strip_frontmatter(read_lines_safe(page_path)))
  source_body <- trim_blank_edges(read_lines_safe(source_path))

  equivalent <- length(source_body) > 0L && identical(page_body, source_body)
  diff_at <- first_diff_line(page_body, source_body)

  checks[[length(checks) + 1L]] <- check_condition(
    equivalent,
    paste0("VERBATIM body equivalence: ", item$page),
    paste0(
      "VERBATIM body drift: ", item$page, " differs from ", item$source,
      if (is.na(diff_at)) "" else paste0(" at body line ", diff_at),
      ". Re-assemble the page from source."
    )
  )

  verbatim_rows[[length(verbatim_rows) + 1L]] <- c(
    item$page,
    item$source,
    as.character(length(source_body)),
    if (equivalent) "pass" else "fail",
    fingerprint(source_path)
  )
}

# ---- validate-adapted --------------------------------------------------------
adapted_rows <- list()

for (item in adapted_pages) {
  page_path <- file.path(frontend_path, item$page)
  source_path <- file.path(repo_root, item$source)
  partial_path <- file.path(frontend_path, item$partial)

  page_lines <- read_lines_safe(page_path)
  page_name <- basename(item$page)

  logged <- any(grepl(page_name, transform_log_lines, fixed = TRUE))
  has_include <- any(grepl("{{< include", page_lines, fixed = TRUE))
  partial_exists <- file.exists(partial_path)
  no_private <- !any(grepl("data-private", page_lines, fixed = TRUE))

  logged_transforms <- item$allowed[vapply(
    item$allowed,
    function(tr) any(grepl(tr, transform_log_lines, fixed = TRUE)),
    logical(1)
  )]
  undeclared <- setdiff(logged_transforms, item$allowed)

  checks[[length(checks) + 1L]] <- check_condition(
    logged,
    paste0("ADAPTED page has TRANSFORM_LOG coverage: ", item$page),
    paste0("ADAPTED page missing from TRANSFORM_LOG.md: ", item$page)
  )

  checks[[length(checks) + 1L]] <- check_condition(
    length(undeclared) == 0L,
    paste0("ADAPTED transforms all within the allowed list: ", item$page),
    paste0(
      "ADAPTED page applied transforms outside allowed_transforms: ",
      paste(undeclared, collapse = ", ")
    )
  )

  checks[[length(checks) + 1L]] <- check_condition(
    has_include && partial_exists,
    paste0("ADAPTED mermaid partial resolved: ", item$partial),
    paste0(
      "ADAPTED page declares shortcode_injection but the include or partial is missing: ",
      item$partial
    )
  )

  checks[[length(checks) + 1L]] <- check_condition(
    no_private,
    paste0("ADAPTED sanitize removed all data-private references: ", item$page),
    paste0("ADAPTED page still exposes data-private paths: ", item$page)
  )

  adapted_rows[[length(adapted_rows) + 1L]] <- c(
    item$page,
    item$source,
    paste(logged_transforms, collapse = ", "),
    fingerprint(source_path)
  )
}

# ---- validate-redirect -------------------------------------------------------
redirect_rows <- list()

for (item in redirect_pages) {
  stub_path <- file.path(frontend_path, item$page)
  source_path <- file.path(repo_root, item$source)
  target_path <- file.path(frontend_path, item$target)
  rendered_stub_path <- file.path(frontend_path, item$rendered_stub)

  stub_lines <- read_lines_safe(stub_path)
  has_meta_refresh <- any(grepl("http-equiv=\"refresh\"", stub_lines, fixed = TRUE))
  has_no_iframe <- !any(grepl("<iframe", stub_lines, fixed = TRUE))
  has_no_blank <- !any(grepl("_blank", stub_lines, fixed = TRUE))

  source_exists <- file.exists(source_path)
  target_placed <- file.exists(target_path)
  stub_rendered <- file.exists(rendered_stub_path)

  resolved <- FALSE
  if (stub_rendered && target_placed) {
    rendered_lines <- read_lines_safe(rendered_stub_path)
    url_match <- regmatches(
      rendered_lines,
      regexpr("(?<=url=)[^\"']+", rendered_lines, perl = TRUE)
    )
    url_match <- url_match[nzchar(url_match)]
    if (length(url_match) > 0L) {
      resolved_path <- file.path(dirname(rendered_stub_path), url_match[[1]])
      resolved <- file.exists(resolved_path)
    }
  }

  checks[[length(checks) + 1L]] <- check_condition(
    source_exists,
    paste0("REDIRECT source HTML exists: ", item$source),
    paste0(
      "REDIRECT source HTML missing: ", item$source,
      ". Render the report before building the site."
    )
  )

  checks[[length(checks) + 1L]] <- check_condition(
    target_placed,
    paste0("REDIRECT target placed in _site: ", item$target),
    paste0("REDIRECT target absent from _site: ", item$target)
  )

  checks[[length(checks) + 1L]] <- check_condition(
    resolved,
    paste0("REDIRECT stub URL resolves to the placed target: ", item$page),
    paste0("REDIRECT stub URL does not resolve from its rendered location: ", item$page)
  )

  checks[[length(checks) + 1L]] <- check_condition(
    has_meta_refresh && has_no_iframe && has_no_blank,
    paste0("REDIRECT stub uses meta refresh, no iframe, no target=_blank: ", item$page),
    paste0("REDIRECT stub violates stub construction rules: ", item$page)
  )

  redirect_rows[[length(redirect_rows) + 1L]] <- c(
    item$page,
    item$source,
    item$target,
    if (target_placed) format(file.size(target_path), big.mark = ",") else "<missing>",
    fingerprint(source_path)
  )
}

# ---- validate-composed -------------------------------------------------------
composed_rows <- list()

for (item in composed_pages) {
  page_path <- file.path(frontend_path, item$page)
  page_lines <- read_lines_safe(page_path)

  page_exists <- length(page_lines) > 0L
  markers_present <- all(vapply(
    item$required_markers,
    function(marker) any(grepl(marker, page_lines, fixed = TRUE)),
    logical(1)
  ))
  brief_present <- all(vapply(
    item$brief_fields,
    function(field) any(grepl(paste0("\\*\\*", field, "\\*\\*"), contract_lines)),
    logical(1)
  ))
  grounding_present <- length(item$grounding) == 0L || all(vapply(
    item$grounding,
    function(src) file.exists(file.path(repo_root, src)),
    logical(1)
  ))

  checks[[length(checks) + 1L]] <- check_condition(
    page_exists,
    paste0("COMPOSED page authored: ", item$page),
    paste0("COMPOSED page missing or empty: ", item$page)
  )

  checks[[length(checks) + 1L]] <- check_condition(
    brief_present,
    paste0("COMPOSED brief fields present in contract for: ", item$page),
    paste0("COMPOSED brief incomplete in contract for: ", item$page)
  )

  checks[[length(checks) + 1L]] <- check_condition(
    markers_present,
    paste0("COMPOSED required structure present: ", item$page),
    paste0(
      "COMPOSED page missing required structure (",
      paste(item$required_markers, collapse = "; "), "): ", item$page
    )
  )

  checks[[length(checks) + 1L]] <- check_condition(
    grounding_present,
    paste0("COMPOSED grounding sources all resolvable: ", item$page),
    paste0("COMPOSED page cites a source that does not exist: ", item$page)
  )

  composed_rows[[length(composed_rows) + 1L]] <- c(
    item$page,
    if (length(item$grounding) == 0L) {
      "publishing-contract.prompt.md"
    } else {
      paste(item$grounding, collapse = "<br>")
    },
    if (markers_present) "pass" else "fail"
  )
}

# ---- validate-self-containment -----------------------------------------------
content_files <- list.files(
  content_path,
  pattern = "[.]qmd$",
  recursive = TRUE,
  full.names = TRUE
)

escaping_refs <- character(0)
for (f in content_files) {
  lines <- read_lines_safe(f)
  refs <- unlist(regmatches(
    lines,
    gregexpr("\\]\\([^)]+\\)|\\{\\{< include [^>]+>\\}\\}", lines)
  ))
  refs <- refs[grepl("\\.\\./", refs)]
  refs <- refs[!grepl("reports/data-primer-1[.]html", refs)]
  if (length(refs) > 0L) {
    escaping_refs <- c(escaping_refs, paste0(basename(f), ": ", paste(refs, collapse = " ")))
  }
}

checks[[length(checks) + 1L]] <- check_condition(
  length(escaping_refs) == 0L,
  "Self-containment: no content/ page references a path outside content/ (the REDIRECT stub target is placed by a post-render hook and is exempt).",
  paste0("Self-containment violated by: ", paste(escaping_refs, collapse = "; "))
)

for (chk in checks) {
  overall_status <- merge_status(overall_status, chk$status)
}

# ---- write-report ------------------------------------------------------------
render_table <- function(header, rows) {
  if (length(rows) == 0L) {
    return(c("_No pages of this type._", ""))
  }
  separator <- paste0("| ", paste(rep("---", length(header)), collapse = " | "), " |")
  body <- vapply(
    rows,
    function(r) paste0("| ", paste(r, collapse = " | "), " |"),
    character(1)
  )
  c(paste0("| ", paste(header, collapse = " | "), " |"), separator, body, "")
}

report_lines <- c(
  "# Fidelity Report",
  "",
  paste0("- Overall Status: **", toupper(overall_status), "**"),
  paste0("- Generated: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
  paste0("- Frontend Path: `", normalizePath(frontend_path, winslash = "/", mustWork = FALSE), "`"),
  paste0("- Fingerprint algorithm: `", hash_label, "`"),
  "- Taxonomy Source: `.github/instructions/publishing-rules.instructions.md` (Section \"Taxonomy and Mapping Registry\" — designates Protocol, Mode, Output Type concepts)",
  "",
  "## Contract Protocol Counts",
  "",
  paste0("- VERBATIM pages: ", verbatim_count),
  paste0("- REDIRECTED pages: ", redirect_count),
  paste0("- ADAPTED pages: ", adapted_count),
  paste0("- COMPOSED pages: ", composed_count),
  "",
  "## VERBATIM Body Equivalence",
  "",
  render_table(
    c("Page", "Source", "Body lines", "Result", paste0("Source ", hash_label)),
    verbatim_rows
  ),
  "## ADAPTED Transform Compliance",
  "",
  render_table(
    c("Page", "Source", "Transforms logged", paste0("Source ", hash_label)),
    adapted_rows
  ),
  "## REDIRECT Placement",
  "",
  render_table(
    c("Stub", "Source HTML", "Placed at", "Bytes", paste0("Source ", hash_label)),
    redirect_rows
  ),
  "## COMPOSED Grounding",
  "",
  render_table(
    c("Page", "Grounding inputs", "Structure"),
    composed_rows
  ),
  "## Check Results",
  ""
)

for (i in seq_along(checks)) {
  chk <- checks[[i]]
  report_lines <- c(
    report_lines,
    paste0(i, ". [", toupper(chk$status), "] ", chk$message)
  )
}

report_lines <- c(
  report_lines,
  "",
  "## Notes",
  "",
  "- VERBATIM equivalence compares the page body against the source line by line,",
  "  after removing the added YAML frontmatter and blank edges. Any difference is a",
  "  `fail`, not a `warn`.",
  "- The contract records no `source_sha256` values. The fingerprints above are the",
  "  current source digests and can be pasted into the contract to enable drift",
  "  detection on the next run.",
  "- The REDIRECT resolution check follows the `url=` value out of the rendered stub",
  "  and confirms a file exists at that location inside `_site/`."
)

writeLines(report_lines, report_path, useBytes = TRUE)

message("FIDELITY_REPORT.md written: ", report_path)
if (identical(overall_status, "fail")) {
  stop("Fidelity audit failed. See FIDELITY_REPORT.md for details.")
}
