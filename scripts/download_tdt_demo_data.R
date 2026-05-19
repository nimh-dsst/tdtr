demo_url <- "https://www.tdt.com/files/examples/TDTExampleData.zip"
default_dir <- file.path("data-raw", "tdt-demo")

args <- commandArgs(trailingOnly = TRUE)
dest_dir <- if (length(args) >= 1 && nzchar(args[[1]])) args[[1]] else Sys.getenv("TDTR_FIXTURE_DIR", default_dir)
dest_dir <- normalizePath(dest_dir, winslash = "/", mustWork = FALSE)
zip_path <- file.path(dest_dir, "TDTExampleData.zip")

dir.create(dest_dir, recursive = TRUE, showWarnings = FALSE)

message("Downloading official TDT example data.")
message("Source: ", demo_url)
message("Destination: ", dest_dir)
message("The current server-reported zip size is about 330 MB.")

if (!file.exists(zip_path)) {
  utils::download.file(demo_url, zip_path, mode = "wb", quiet = FALSE)
} else {
  message("Zip already exists: ", zip_path)
}

unzip_dir <- file.path(dest_dir, "unzipped")
dir.create(unzip_dir, recursive = TRUE, showWarnings = FALSE)
utils::unzip(zip_path, exdir = unzip_dir)

tsq_files <- list.files(unzip_dir, pattern = "\\.tsq$", recursive = TRUE, full.names = TRUE)
block_dirs <- sort(unique(dirname(tsq_files)))

message("Found ", length(block_dirs), " candidate TDT block director", if (length(block_dirs) == 1) "y." else "ies.")
if (length(block_dirs) > 0) {
  writeLines(block_dirs)
  writeLines(block_dirs, file.path(dest_dir, "blocks.txt"))
  message("Wrote block list to ", file.path(dest_dir, "blocks.txt"))
}
