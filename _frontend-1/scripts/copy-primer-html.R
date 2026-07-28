rm(list = ls(all.names = TRUE)) # Clear the memory of variables from previous run.
cat("\014") # Clear the console
cat("Working directory: ", getwd()) # Must be set to Project Directory

# Purpose: Copy the standalone Data Primer 1 HTML into the rendered site so the
#          Primers redirect stub has a target to forward the browser to.
# Registered as: post-render
# Why needed: The primer is a self-contained Quarto artifact rendered by the
#          Composing Orchestra outside this frontend. It is not a page of this
#          site and must not be re-rendered here, so it cannot live in content/
#          and cannot be covered by the self-containment rule. Quarto therefore
#          never sees it; this hook places it in _site/ after the render.

# ---- declare-globals ---------------------------------------------------------
path_source_html <- "../analysis/data-primer-1/data-primer-1.html"
path_target_dir <- "_site/reports"
path_target_html <- file.path(path_target_dir, "data-primer-1.html")

# ---- validate ----------------------------------------------------------------
if (!file.exists(path_source_html)) {
  stop(
    "Redirect target missing: ", path_source_html, "\n",
    "Render analysis/data-primer-1/data-primer-1.qmd before building this site."
  )
}

# ---- save-to-disk ------------------------------------------------------------
dir.create(path_target_dir, recursive = TRUE, showWarnings = FALSE)
copied <- file.copy(path_source_html, path_target_html, overwrite = TRUE)

if (!isTRUE(copied)) {
  stop("Failed to copy the Data Primer 1 HTML into ", path_target_html)
}

message(
  "post-render: copied Data Primer 1 (",
  format(file.size(path_target_html), big.mark = ","),
  " bytes) to ", path_target_html
)
