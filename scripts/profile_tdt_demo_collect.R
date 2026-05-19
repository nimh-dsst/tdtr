source_blocks_file <- function(fixture_dir) {
  blocks_file <- file.path(fixture_dir, "blocks.txt")
  if (file.exists(blocks_file)) {
    blocks <- readLines(blocks_file, warn = FALSE)
    blocks <- blocks[nzchar(blocks)]
    if (length(blocks) > 0) {
      return(blocks)
    }
  }

  tsq_files <- list.files(fixture_dir, pattern = "\\.tsq$", recursive = TRUE, full.names = TRUE)
  sort(unique(dirname(tsq_files)))
}

rprofmem_bytes <- function(path) {
  if (!file.exists(path)) {
    return(NA_real_)
  }
  lines <- readLines(path, warn = FALSE)
  numbers <- regmatches(lines, regexpr("^[0-9]+", lines))
  numbers <- numbers[nzchar(numbers)]
  if (length(numbers) == 0) {
    return(0)
  }
  sum(as.numeric(numbers), na.rm = TRUE)
}

measure <- function(label, expr) {
  gc()
  mem_file <- tempfile("tdtr-rprofmem-")
  py_peak <- NA_real_
  tracemalloc <- NULL

  if (requireNamespace("reticulate", quietly = TRUE) &&
      isTRUE(tryCatch(reticulate::py_available(initialize = FALSE), error = function(e) FALSE))) {
    tracemalloc <- tryCatch(reticulate::import("tracemalloc", convert = TRUE), error = function(e) NULL)
  }

  if (!is.null(tracemalloc)) {
    tracemalloc$start()
  }
  Rprofmem(mem_file)
  elapsed <- system.time(value <- force(expr))
  Rprofmem(NULL)
  if (!is.null(tracemalloc)) {
    traced <- tracemalloc$get_traced_memory()
    py_peak <- as.numeric(traced[[2]])
    tracemalloc$stop()
  }

  list(
    value = value,
    row = data.frame(
      label = label,
      elapsed_sec = unname(elapsed[["elapsed"]]),
      r_alloc_mb = rprofmem_bytes(mem_file) / 1024^2,
      python_tracemalloc_peak_mb = py_peak / 1024^2,
      stringsAsFactors = FALSE
    )
  )
}

args <- commandArgs(trailingOnly = TRUE)
fixture_dir <- if (length(args) >= 1 && nzchar(args[[1]])) args[[1]] else Sys.getenv("TDTR_FIXTURE_DIR", file.path("data-raw", "tdt-demo"))
fixture_dir <- normalizePath(fixture_dir, winslash = "/", mustWork = FALSE)
out_dir <- Sys.getenv("TDTR_PROFILE_DIR", file.path("data-raw", "tdt-demo-profile"))
out_dir <- normalizePath(out_dir, winslash = "/", mustWork = FALSE)
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

blocks <- source_blocks_file(fixture_dir)
if (length(blocks) == 0) {
  stop("No TDT block directories found. Run scripts/download_tdt_demo_data.R first, or set TDTR_FIXTURE_DIR.")
}

block_path <- Sys.getenv("TDTR_PROFILE_BLOCK", blocks[[1]])
t1 <- as.numeric(Sys.getenv("TDTR_PROFILE_T1", "0"))
t2 <- as.numeric(Sys.getenv("TDTR_PROFILE_T2", "10"))

suppressPackageStartupMessages(library(tdtr))

if (!tdt_available(initialize = TRUE)) {
  stop("Python `tdt>=0.7.3` is not available to reticulate.")
}

message("Profiling block: ", block_path)
message("Time window: [", t1, ", ", t2, "] seconds")

rows <- list()

read_result <- measure(
  "read_block_py_t1_t2",
  read_block(block_path, evtype = c("epocs", "streams"), t1 = t1, t2 = t2, verbose = 0)
)
block <- read_result$value
rows[[length(rows) + 1]] <- read_result$row

names_result <- measure(
  "accessors_names_only",
  {
    list(
      streams = stream_names(block),
      epocs = epoc_names(block)
    )
  }
)
rows[[length(rows) + 1]] <- names_result$row

summary_result <- measure("summary_no_collect", summary(block))
rows[[length(rows) + 1]] <- summary_result$row

stream_to_collect <- Sys.getenv("TDTR_PROFILE_STORE", "")
if (!nzchar(stream_to_collect)) {
  stream_to_collect <- stream_names(block)[[1]]
}

collect_result <- measure(
  paste0("collect_stream_", stream_to_collect),
  collect_stream(block, stream_to_collect, as = "list", include_time = TRUE, quiet = TRUE)
)
rows[[length(rows) + 1]] <- collect_result$row

epoc_result <- measure("collect_epocs", collect_epocs(block))
rows[[length(rows) + 1]] <- epoc_result$row

results <- do.call(rbind, rows)
profile_path <- file.path(out_dir, paste0("profile-", format(Sys.time(), "%Y%m%d-%H%M%S"), ".csv"))
utils::write.csv(results, profile_path, row.names = FALSE)

print(results)
message("Wrote profile results to ", profile_path)
