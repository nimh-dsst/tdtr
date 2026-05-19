tdt_rprofmem_bytes <- function(path) {
  if (!file.exists(path)) {
    return(NA_real_)
  }

  lines <- readLines(path, warn = FALSE)
  numbers <- regmatches(lines, regexpr("^[0-9]+", lines))
  numbers <- suppressWarnings(as.numeric(numbers[nzchar(numbers)]))
  if (length(numbers) == 0) {
    return(0)
  }

  sum(numbers, na.rm = TRUE)
}

tdt_profile_tracemalloc <- function() {
  if (!requireNamespace("reticulate", quietly = TRUE)) {
    return(NULL)
  }
  if (!isTRUE(tryCatch(reticulate::py_available(initialize = FALSE), error = function(e) FALSE))) {
    return(NULL)
  }

  tryCatch(reticulate::import("tracemalloc", convert = TRUE), error = function(e) NULL)
}

tdt_profile_step <- function(step, expr) {
  gc()
  mem_file <- tempfile("tdtr-rprofmem-")
  tracemalloc <- tdt_profile_tracemalloc()
  py_peak <- NA_real_
  tracing_before <- FALSE
  profmem_active <- FALSE
  tracemalloc_stopped <- FALSE

  if (!is.null(tracemalloc)) {
    tracing_before <- isTRUE(tryCatch(tracemalloc$is_tracing(), error = function(e) FALSE))
    if (tracing_before) {
      tryCatch(tracemalloc$reset_peak(), error = function(e) NULL)
    } else {
      tracemalloc$start()
    }
  }

  Rprofmem(mem_file)
  profmem_active <- TRUE
  on.exit({
    if (isTRUE(profmem_active)) {
      tryCatch(Rprofmem(NULL), error = function(e) NULL)
    }
    if (!is.null(tracemalloc) && !tracing_before && !tracemalloc_stopped) {
      tryCatch(tracemalloc$stop(), error = function(e) NULL)
    }
    unlink(mem_file)
  }, add = TRUE)

  elapsed <- system.time(value <- force(expr))
  Rprofmem(NULL)
  profmem_active <- FALSE

  if (!is.null(tracemalloc)) {
    traced <- tryCatch(tracemalloc$get_traced_memory(), error = function(e) NULL)
    if (!is.null(traced) && length(traced) >= 2) {
      py_peak <- as.numeric(traced[[2]]) / 1024^2
    }
    if (!tracing_before) {
      tracemalloc$stop()
      tracemalloc_stopped <- TRUE
    }
  }

  row <- tibble::tibble(
    step = step,
    elapsed_sec = unname(elapsed[["elapsed"]]),
    r_alloc_mb = tdt_rprofmem_bytes(mem_file) / 1024^2,
    python_tracemalloc_peak_mb = py_peak
  )

  list(value = value, row = row)
}

#' Profile memory movement for a TDT read workflow
#'
#' `profile_tdt_memory()` runs a small read workflow and records elapsed time,
#' R allocations reported by [Rprofmem()], and Python allocations reported by
#' Python `tracemalloc` when available. Use reader arguments such as `store`,
#' `channel`, `t1`, `t2`, `evtype`, and `ranges` to test a bounded workflow
#' before scaling up to a larger block.
#'
#' The numbers are diagnostics, not portable benchmarks. They are most useful
#' for comparing alternative reads on the same machine and Python environment.
#'
#' @param block_path Path to a TDT block directory.
#' @param ... Arguments passed to [read_block()].
#' @param stream Optional stream store to collect after the read. Leave `NULL`
#'   to profile metadata and events without copying stream data into R.
#' @param events If `TRUE`, collect epocs/events after the read.
#' @param summarize If `TRUE`, call [summary()] on the Python-backed block.
#' @param quiet Suppress collection size warnings.
#'
#' @return A tibble with one row per profiled step.
#' @export
profile_tdt_memory <- function(block_path,
                               ...,
                               stream = NULL,
                               events = TRUE,
                               summarize = TRUE,
                               quiet = TRUE) {
  tdt_check_dir(block_path, "block_path")
  if (!is.null(stream)) {
    tdt_check_string(stream, "stream")
  }

  # Profile the data workflow, not reticulate's one-time Python initialization.
  invisible(tdt_import())

  rows <- list()

  read_result <- tdt_profile_step(
    "read_block",
    read_block(block_path, ...)
  )
  block <- read_result$value
  rows[[length(rows) + 1]] <- read_result$row

  names_result <- tdt_profile_step(
    "metadata_accessors",
    list(streams = stream_names(block), epocs = epoc_names(block))
  )
  rows[[length(rows) + 1]] <- names_result$row

  if (isTRUE(summarize)) {
    summary_result <- tdt_profile_step("summary", base::summary(block))
    rows[[length(rows) + 1]] <- summary_result$row
  }

  if (!is.null(stream)) {
    stream_result <- tdt_profile_step(
      paste0("collect_stream:", stream),
      collect_stream(block, stream, as = "list", include_time = TRUE, quiet = quiet)
    )
    rows[[length(rows) + 1]] <- stream_result$row
  }

  if (isTRUE(events)) {
    events_result <- tdt_profile_step("collect_epocs", collect_epocs(block))
    rows[[length(rows) + 1]] <- events_result$row
  }

  do.call(rbind, rows)
}
