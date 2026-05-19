#' Discover TDT tank directories
#'
#' Finds directories containing `.tsq` files and reports whether they have a
#' `DO_NOT_USE.json` marker.
#'
#' @param path Directory to search recursively.
#' @param ignore_do_not_use If `TRUE`, omit directories containing
#'   `DO_NOT_USE.json`.
#'
#' @return A tibble with `tank_dir`, `tank_name`, `n_tsq`, and `do_not_use`.
#' @noRd
tdt_discover_tanks <- function(path, ignore_do_not_use = FALSE) {
  tdt_check_dir(path, "path")
  if (!dir.exists(path)) {
    rlang::abort(sprintf("Directory does not exist: %s.", path))
  }

  tsq_files <- list.files(path, pattern = "\\.tsq$", recursive = TRUE, full.names = TRUE)
  if (length(tsq_files) == 0) {
    return(tibble::tibble(
      tank_dir = character(),
      tank_name = character(),
      n_tsq = integer(),
      do_not_use = logical()
    ))
  }

  tank_dirs <- unique(dirname(tsq_files))
  rows <- lapply(tank_dirs, function(tank_dir) {
    do_not_use <- file.exists(file.path(tank_dir, "DO_NOT_USE.json"))
    tibble::tibble(
      tank_dir = tdt_normalize_path(tank_dir, must_work = FALSE),
      tank_name = basename(tank_dir),
      n_tsq = sum(dirname(tsq_files) == tank_dir),
      do_not_use = do_not_use
    )
  })

  result <- do.call(rbind, rows)
  if (isTRUE(ignore_do_not_use)) {
    result <- result[!result$do_not_use, , drop = FALSE]
  }
  result
}

#' Find fully extracted tanks from `streams.json` files
#'
#' A tank is treated as complete when the number of `streams.json` files for the
#' tank equals `num_subjects_in_tank` in the metadata.
#'
#' @param path Project root containing a `Photometry` directory, a direct
#'   `Photometry` directory, or any directory to search for `streams.json`.
#' @param cohort Optional cohort directory name used to filter results.
#'
#' @return A character vector of completed tank directories.
#' @noRd
tdt_completed_tanks <- function(path, cohort = NULL) {
  tdt_check_dir(path, "path")

  search_dir <- if (basename(path) == "Photometry") {
    path
  } else if (dir.exists(file.path(path, "Photometry"))) {
    file.path(path, "Photometry")
  } else {
    path
  }

  if (!dir.exists(search_dir)) {
    return(character(0))
  }

  json_paths <- list.files(
    search_dir,
    pattern = "streams\\.json$",
    recursive = TRUE,
    full.names = TRUE
  )
  if (length(json_paths) == 0) {
    return(character(0))
  }

  entries <- lapply(json_paths, function(json_path) {
    if (!is.null(cohort)) {
      parts <- strsplit(tdt_normalize_path(json_path, must_work = FALSE), "/", fixed = TRUE)[[1]]
      if (!(cohort %in% parts)) {
        return(NULL)
      }
    }

    parsed <- tryCatch(
      jsonlite::fromJSON(json_path, simplifyVector = FALSE),
      error = function(e) NULL
    )
    if (is.null(parsed)) {
      return(NULL)
    }

    parsed$filepath <- json_path
    parsed
  })
  entries <- Filter(Negate(is.null), entries)
  if (length(entries) == 0) {
    return(character(0))
  }

  tank_dirs <- vapply(entries, function(entry) entry$tank_dir %||% "", character(1))
  num_subjects <- vapply(
    entries,
    function(entry) as.integer(entry$num_subjects_in_tank %||% NA_integer_),
    integer(1)
  )
  subject_ids <- vapply(entries, function(entry) entry$subject_id %||% "", character(1))

  data <- data.frame(
    tank_dir = tank_dirs,
    num_subjects_in_tank = num_subjects,
    subject_id = subject_ids,
    stringsAsFactors = FALSE
  )
  data <- data[nzchar(data$tank_dir), , drop = FALSE]
  if (nrow(data) == 0) {
    return(character(0))
  }

  subject_counts <- aggregate(subject_id ~ tank_dir, data = data, FUN = length)
  names(subject_counts)[[2]] <- "subject_count"

  merged <- merge(data, subject_counts, by = "tank_dir", all.x = TRUE)
  completed <- merged[merged$subject_count == merged$num_subjects_in_tank, , drop = FALSE]
  unique(completed$tank_dir)
}
