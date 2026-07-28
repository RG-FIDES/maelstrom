rm(list = ls(all.names = TRUE)) # Clear the memory of variables from previous run.
cat("\014") # Clear the console
cat("Working directory: ", getwd()) # Must be set to Project Directory

# ---- load-packages -----------------------------------------------------------
library(magick)

# ---- declare-globals ---------------------------------------------------------
source_md <- "manipulation/pipeline.md"
output_jpg <- "manipulation/images/pipeline-architecture.jpg"
output_png <- "manipulation/images/pipeline-architecture.png"

width_in <- 8.5
min_height_in <- 2.5
dpi <- 300

# ---- extract-mermaid ---------------------------------------------------------
lines <- readLines(source_md, warn = FALSE)
src_marker <- "<!-- PIPELINE-DIAGRAM-SOURCE -->"
marker_ix <- which(trimws(lines) == src_marker)[1]

if (is.na(marker_ix)) {
  stop(
    "No <!-- PIPELINE-DIAGRAM-SOURCE --> marker found in: ", source_md, "\n",
    "Add this comment on the line immediately before the ```mermaid fence."
  )
}

start_ix <- which(grepl("^```mermaid", lines) & seq_along(lines) > marker_ix)[1]
if (is.na(start_ix)) {
  stop("No ```mermaid block found after the marker in: ", source_md)
}

fence_ix <- which(grepl("^```\\s*$", lines))
end_ix <- fence_ix[fence_ix > start_ix][1]
if (is.na(end_ix)) {
  stop("Unclosed mermaid block in: ", source_md)
}

mermaid_code <- paste(lines[(start_ix + 1L):(end_ix - 1L)], collapse = "\n")

# ---- render-with-mermaid-cli -------------------------------------------------
tmp_mmd <- tempfile(fileext = ".mmd")
tmp_png <- tempfile(fileext = ".png")
on.exit(suppressWarnings(file.remove(c(tmp_mmd, tmp_png))), add = TRUE)
writeLines(mermaid_code, tmp_mmd)

width_px <- round(width_in * dpi)
min_height_px <- round(min_height_in * dpi)

cmd <- paste(
  "npx --yes @mermaid-js/mermaid-cli",
  sprintf('-i "%s"', normalizePath(tmp_mmd, winslash = "/")),
  sprintf('-o "%s"', normalizePath(tmp_png, winslash = "/", mustWork = FALSE)),
  sprintf("-w %d", width_px),
  "-b white"
)

message("Rendering mermaid diagram via mmdc...")
rc <- system(cmd)
if (rc != 0L) {
  stop(
    "mmdc exited with code ", rc, ".\n",
    "Make sure Node.js and npx are on PATH.\n",
    "Verify with: node --version and npx --version"
  )
}

# ---- resize-and-export -------------------------------------------------------
# The canvas pads a short diagram up to the minimum height but never crops a tall
# one: silently losing the bottom of an architecture diagram is worse than an
# unusually tall image.
img <- image_read(tmp_png)
img <- image_resize(img, geometry_size_pixels(width = width_px))
height_px <- max(min_height_px, image_info(img)$height)
img <- image_extent(
  img,
  geometry_size_pixels(width = width_px, height = height_px),
  gravity = "Center",
  color = "white"
)

dir.create(dirname(output_jpg), showWarnings = FALSE, recursive = TRUE)
image_write(img, path = output_jpg, format = "jpeg", quality = 95)
image_write(img, path = output_png, format = "png")

message(sprintf(
  "Pipeline diagram saved to:\n  %s\n  %s\n  (%d x %d px @ %d dpi)",
  output_jpg,
  output_png,
  width_px,
  height_px,
  dpi
))

# ---- scan-insertion-sites ----------------------------------------------------
scan_exts <- c("*.md", "*.qmd", "*.R", "*.Rmd")
all_files <- unlist(lapply(scan_exts, function(ext) {
  list.files(
    ".",
    pattern = glob2rx(ext),
    recursive = TRUE,
    full.names = TRUE,
    ignore.case = TRUE
  )
}))

ins_marker <- "<!-- PIPELINE-DIAGRAM -->"
tagged <- Filter(function(f) {
  any(grepl(ins_marker, readLines(f, warn = FALSE), fixed = TRUE))
}, all_files)

if (length(tagged) == 0L) {
  message("No tagged files found. Add <!-- PIPELINE-DIAGRAM --> where needed.")
} else {
  message(sprintf("Found %d tagged file(s):", length(tagged)))
  for (f in sort(tagged)) {
    message("  ", sub("^\\./", "", f))
  }
}
