args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1L) {
  stop("Usage: Rscript scripts/set-release-version.R <version>", call. = FALSE)
}

version <- args[[1]]
if (!grepl("^[0-9]+\\.[0-9]+\\.[0-9]+$", version)) {
  stop("Release version must have the form x.y.z.", call. = FALSE)
}

desc <- readLines("DESCRIPTION", warn = FALSE)
version_line <- grep("^Version:", desc)
if (length(version_line) != 1L) {
  stop("DESCRIPTION must contain exactly one Version field.", call. = FALSE)
}
desc[[version_line]] <- paste("Version:", version)
writeLines(desc, "DESCRIPTION", useBytes = TRUE)

news <- readLines("NEWS.md", warn = FALSE)
if (length(news) > 0L && grepl("^# tdtr ", news[[1]])) {
  news[[1]] <- paste("# tdtr", version)
  writeLines(news, "NEWS.md", useBytes = TRUE)
}
