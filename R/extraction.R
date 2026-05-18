tdt_resolve_stream_set <- function(block, streams) {
  tdt_validate_stream_config(streams)

  resolved <- lapply(tdt_required_stream_roles(), function(role) {
    value <- streams[[role]]
    if (is.character(value) && length(value) == 1) {
      if (is.null(block)) {
        rlang::abort("Character stream names require a `block` object.")
      }
      tdt_get_stream(block, value)
    } else {
      value
    }
  })
  names(resolved) <- tdt_required_stream_roles()
  resolved
}

tdt_write_pickle <- function(py_object, path) {
  tdt_check_reticulate()
  pickle <- reticulate::import("pickle", delay_load = TRUE, convert = FALSE)
  builtins <- reticulate::import("builtins", delay_load = TRUE, convert = FALSE)
  handle <- builtins$open(path, "wb")
  on.exit(handle$close(), add = TRUE)
  pickle$dump(py_object, handle)
  invisible(path)
}

tdt_expected_subject_files <- function(subject_dir, write_pickle = TRUE, write_csv = TRUE) {
  files <- file.path(subject_dir, "streams.json")
  if (isTRUE(write_pickle)) {
    files <- c(
      files,
      file.path(subject_dir, "ttl_stream.pkl"),
      file.path(subject_dir, "iso_stream.pkl"),
      file.path(subject_dir, "exp_stream.pkl")
    )
  }
  if (isTRUE(write_csv)) {
    files <- c(
      files,
      file.path(subject_dir, "ttl_stream.csv"),
      file.path(subject_dir, "iso_stream.csv"),
      file.path(subject_dir, "exp_stream.csv")
    )
  }
  files
}

#' Mark a tank as unsuitable for extraction
#'
#' Writes a `DO_NOT_USE.json` marker in the tank directory.
#'
#' @param tank_dir TDT tank/block directory.
#' @param reason Human-readable reason.
#'
#' @return The marker path, invisibly.
#' @export
tdt_mark_do_not_use <- function(tank_dir, reason) {
  tdt_check_dir(tank_dir, "tank_dir")
  if (!dir.exists(tank_dir)) {
    rlang::abort(sprintf("Directory does not exist: %s.", tank_dir))
  }
  if (!is.character(reason) || length(reason) != 1 || !nzchar(reason)) {
    rlang::abort("`reason` must be a single non-empty string.")
  }

  marker <- file.path(tank_dir, "DO_NOT_USE.json")
  jsonlite::write_json(list(Reason = reason), marker, auto_unbox = TRUE, pretty = TRUE)
  invisible(marker)
}

#' Write selected streams for one subject
#'
#' @param block TDT block object. Required when `streams` contains stream names.
#' @param subject_dir Output directory for the subject.
#' @param streams List with `ttl_stream`, `iso_stream`, and `exp_stream` entries.
#'   Entries can be stream names or stream objects.
#' @param data_info Optional block info object. Defaults to `block$info`.
#' @param metadata Additional metadata written into `streams.json`.
#' @param overwrite If `TRUE`, overwrite existing output files.
#' @param num_of_points Number of samples per exported CSV row.
#' @param write_pickle If `TRUE`, write Python stream objects as pickle files.
#' @param write_csv If `TRUE`, write formatted stream CSV files.
#'
#' @return A one-row tibble describing the extraction.
#' @export
tdt_write_stream_set <- function(block = NULL,
                                 subject_dir,
                                 streams,
                                 data_info = NULL,
                                 metadata = list(),
                                 overwrite = FALSE,
                                 num_of_points = 128,
                                 write_pickle = TRUE,
                                 write_csv = TRUE) {
  tdt_check_dir(subject_dir, "subject_dir")
  resolved <- tdt_resolve_stream_set(block, streams)
  tdt_validate_stream_lengths(resolved)

  expected_files <- tdt_expected_subject_files(subject_dir, write_pickle, write_csv)
  existing_files <- expected_files[file.exists(expected_files)]
  if (!isTRUE(overwrite) && length(existing_files) == length(expected_files)) {
    return(tibble::tibble(
      subject_dir = subject_dir,
      subject_id = metadata$subject_id %||% NA_character_,
      status = "skipped",
      reason = "all expected files already exist"
    ))
  }
  if (!isTRUE(overwrite) && length(existing_files) > 0) {
    rlang::abort(
      sprintf("Output directory contains partial extraction output: %s.", subject_dir)
    )
  }

  dir.create(subject_dir, recursive = TRUE, showWarnings = FALSE)
  data_info <- data_info %||% tdt_object_get(block, "info")
  stream_names <- lapply(resolved, tdt_stream_label)

  json_dict <- c(
    list(
      ttl_stream = stream_names$ttl_stream,
      iso_stream = stream_names$iso_stream,
      exp_stream = stream_names$exp_stream
    ),
    metadata
  )
  jsonlite::write_json(
    json_dict,
    file.path(subject_dir, "streams.json"),
    auto_unbox = TRUE,
    pretty = TRUE
  )

  if (isTRUE(write_pickle)) {
    tdt_write_pickle(resolved$ttl_stream, file.path(subject_dir, "ttl_stream.pkl"))
    tdt_write_pickle(resolved$iso_stream, file.path(subject_dir, "iso_stream.pkl"))
    tdt_write_pickle(resolved$exp_stream, file.path(subject_dir, "exp_stream.pkl"))
  }

  if (isTRUE(write_csv)) {
    utils::write.csv(
      tdt_format_stream(data_info, resolved$ttl_stream, num_of_points = num_of_points),
      file.path(subject_dir, "ttl_stream.csv"),
      row.names = FALSE
    )
    utils::write.csv(
      tdt_format_stream(data_info, resolved$iso_stream, num_of_points = num_of_points),
      file.path(subject_dir, "iso_stream.csv"),
      row.names = FALSE
    )
    utils::write.csv(
      tdt_format_stream(data_info, resolved$exp_stream, num_of_points = num_of_points),
      file.path(subject_dir, "exp_stream.csv"),
      row.names = FALSE
    )
  }

  tibble::tibble(
    subject_dir = subject_dir,
    subject_id = metadata$subject_id %||% NA_character_,
    status = "extracted",
    reason = NA_character_
  )
}

#' Extract selected streams from one TDT tank
#'
#' @param tank_dir TDT tank/block directory.
#' @param output_dir Directory where subject extraction directories should be
#'   created.
#' @param stream_map Subject stream mapping. For multi-subject tanks, use
#'   entries named `First` and `Second`; each entry must contain `ttl_stream`,
#'   `iso_stream`, and `exp_stream`.
#' @param block Optional pre-read TDT block object. If omitted, the function
#'   calls [tdt_read_block()].
#' @param overwrite If `TRUE`, overwrite existing output files.
#' @param num_of_points Number of samples per exported CSV row.
#' @param write_pickle If `TRUE`, write Python stream objects as pickle files.
#' @param write_csv If `TRUE`, write formatted stream CSV files.
#' @param mark_bad If `TRUE`, write `DO_NOT_USE.json` when selected stream
#'   lengths do not match.
#'
#' @return A tibble with one row per subject.
#' @export
tdt_extract_tank <- function(tank_dir,
                             output_dir,
                             stream_map,
                             block = NULL,
                             overwrite = FALSE,
                             num_of_points = 128,
                             write_pickle = TRUE,
                             write_csv = TRUE,
                             mark_bad = TRUE) {
  tdt_check_dir(tank_dir, "tank_dir")
  tdt_check_dir(output_dir, "output_dir")

  info <- tdt_parse_tank_name(tank_dir)
  block <- block %||% tdt_read_block(tank_dir)
  data_info <- tdt_object_get(block, "info")
  datetime_label <- format(info$tank_datetime, "%Y%m%d-%H%M%S", tz = "UTC")

  rows <- vector("list", length(info$subject_ids))
  for (index in seq_along(info$subject_ids)) {
    subject_id <- info$subject_ids[[index]]
    order <- tdt_order_label(index)
    subject_streams <- tdt_find_stream_map_entry(
      stream_map,
      order = order,
      index = index,
      n_subjects = info$num_subjects
    )

    subject_dir <- file.path(output_dir, paste0(subject_id, "_", datetime_label))
    metadata <- list(
      order = order,
      tank_dir = as.character(tank_dir),
      num_subjects_in_tank = info$num_subjects,
      subject_ids = info$subject_ids,
      subject_id = subject_id,
      datetime = datetime_label
    )

    rows[[index]] <- tryCatch(
      tdt_write_stream_set(
        block = block,
        subject_dir = subject_dir,
        streams = subject_streams,
        data_info = data_info,
        metadata = metadata,
        overwrite = overwrite,
        num_of_points = num_of_points,
        write_pickle = write_pickle,
        write_csv = write_csv
      ),
      tdt_stream_length_mismatch = function(e) {
        if (isTRUE(mark_bad)) {
          tdt_mark_do_not_use(tank_dir, "Stream data have different lengths")
        }
        tibble::tibble(
          subject_dir = subject_dir,
          subject_id = subject_id,
          status = "failed",
          reason = conditionMessage(e)
        )
      }
    )
  }

  do.call(rbind, rows)
}

#' Extract selected streams from multiple TDT tanks
#'
#' @param tank_dirs Character vector of TDT tank/block directories.
#' @param output_dirs Output directory or directories. A single value is reused
#'   for all tanks.
#' @param stream_map Subject stream mapping passed to [tdt_extract_tank()].
#' @param ... Additional arguments passed to [tdt_extract_tank()].
#'
#' @return A tibble with one row per subject.
#' @export
tdt_extract_tanks <- function(tank_dirs, output_dirs, stream_map, ...) {
  if (!is.character(tank_dirs) || length(tank_dirs) == 0) {
    rlang::abort("`tank_dirs` must be a non-empty character vector.")
  }
  if (!is.character(output_dirs) || length(output_dirs) == 0) {
    rlang::abort("`output_dirs` must be a non-empty character vector.")
  }
  if (length(output_dirs) == 1) {
    output_dirs <- rep(output_dirs, length(tank_dirs))
  }
  if (length(output_dirs) != length(tank_dirs)) {
    rlang::abort("`output_dirs` must have length 1 or match `tank_dirs`.")
  }

  rows <- Map(
    function(tank_dir, output_dir) {
      tdt_extract_tank(
        tank_dir = tank_dir,
        output_dir = output_dir,
        stream_map = stream_map,
        ...
      )
    },
    tank_dirs,
    output_dirs
  )
  do.call(rbind, rows)
}
