source_dir <- normalizePath(".", winslash = "/", mustWork = TRUE)
temp_parent <- tempfile("tdtr-check-")
dir.create(temp_parent, recursive = TRUE)
on.exit(unlink(temp_parent, recursive = TRUE), add = TRUE)

temp_pkg <- file.path(temp_parent, basename(source_dir))
dir.create(temp_pkg)

exclude_top_level <- c(
  ".git",
  ".pixi",
  ".Rproj.user",
  ".Rhistory",
  ".RData",
  ".Ruserdata"
)

entries <- list.files(source_dir, all.files = TRUE, no.. = TRUE, full.names = TRUE)
entries <- entries[!basename(entries) %in% exclude_top_level]
entries <- entries[!grepl("\\.Rcheck$|\\.tar\\.gz$", basename(entries))]

ok <- file.copy(entries, temp_pkg, recursive = TRUE, copy.date = TRUE)
if (!all(ok)) {
  stop("Failed to create clean package copy for R CMD check.")
}

rcmdcheck::rcmdcheck(
  path = temp_pkg,
  args = c("--no-manual"),
  error_on = "error",
  check_dir = file.path(temp_parent, "check")
)
