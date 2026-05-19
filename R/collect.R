tdt_warn_large_array <- function(x, max_bytes_warn, quiet) {
  if (isTRUE(quiet) || is.null(max_bytes_warn) || is.na(max_bytes_warn)) {
    return(invisible(FALSE))
  }

  nbytes <- as.numeric(tdt_scalar(tdt_object_get(x, "nbytes"), NA_real_))
  if (!is.na(nbytes) && nbytes > max_bytes_warn) {
    warning(
      sprintf(
        "Collecting this NumPy array will copy about %.1f MB into R.",
        nbytes / 1024^2
      ),
      call. = FALSE
    )
    return(invisible(TRUE))
  }

  invisible(FALSE)
}

tdt_stream_matrix <- function(data, channels = NULL) {
  data <- tdt_py_to_r(data)
  if (is.null(data)) {
    rlang::abort("Stream does not contain `data`.")
  }

  if (is.data.frame(data)) {
    data <- as.matrix(data)
  }

  dims <- dim(data)
  if (is.null(dims)) {
    return(matrix(as.numeric(data), ncol = 1))
  }

  if (length(dims) > 2) {
    rlang::abort("Only one- and two-dimensional stream arrays are currently supported.")
  }

  mat <- as.matrix(data)
  n_channels <- length(channels %||% integer(0))
  if (n_channels > 1 && nrow(mat) == n_channels) {
    return(t(mat))
  }
  if (nrow(mat) <= ncol(mat)) {
    return(t(mat))
  }
  mat
}

tdt_stream_metadata <- function(stream_obj, name) {
  channels <- tdt_py_to_r(tdt_object_get(stream_obj, "channel", NULL))
  list(
    name = as.character(tdt_scalar(tdt_object_get(stream_obj, "name"), name)),
    fs = as.numeric(tdt_scalar(tdt_object_get(stream_obj, "fs"), NA_real_)),
    t0 = as.numeric(tdt_scalar(tdt_object_get(stream_obj, "start_time"), 0)),
    channels = channels,
    units = tdt_py_to_r(tdt_object_get(stream_obj, "units", NULL)),
    metadata = list()
  )
}

#' Collect one stream into R
#'
#' @param x A `tdt_block`, `tdt_block_py`, `tdt_sev_py`, or compatible object.
#' @param store Stream store name. The sanitized Python key or original TDT
#'   store name may be used.
#' @param as Return shape: `"matrix"`, `"numeric"`, or `"list"`.
#' @param include_time If `TRUE`, return a list with `data`, `time`, and stream
#'   metadata.
#' @param max_bytes_warn Warn before copying a Python array larger than this many
#'   bytes.
#' @param quiet Suppress size warnings.
#'
#' @return A matrix, numeric vector, or stream metadata list.
#' @export
collect_stream <- function(x,
                           store,
                           as = c("matrix", "numeric", "list"),
                           include_time = FALSE,
                           max_bytes_warn = 500 * 1024^2,
                           quiet = FALSE) {
  as <- match.arg(as)
  tdt_check_string(store, "store")

  if (is_tdt_block(x)) {
    stream_obj <- stream(x, store)
    data <- tdt_stream_matrix(stream_obj$data, channels = stream_obj$channels)
    meta <- stream_obj
    meta$data <- data
  } else {
    stream_obj <- stream(x, store)
    tdt_warn_large_array(tdt_object_get(stream_obj, "data"), max_bytes_warn, quiet)
    meta <- tdt_stream_metadata(stream_obj, store)
    data <- tdt_stream_matrix(tdt_object_get(stream_obj, "data"), channels = meta$channels)
    meta$data <- data
  }

  if (isTRUE(include_time)) {
    n_samples <- nrow(data)
    fs <- as.numeric(meta$fs %||% NA_real_)
    t0 <- as.numeric(meta$t0 %||% 0)
    time <- if (!is.na(fs) && fs > 0) t0 + (seq_len(n_samples) - 1) / fs else rep(NA_real_, n_samples)
    meta$time <- time
    return(meta)
  }

  if (identical(as, "list")) {
    return(meta)
  }

  if (identical(as, "numeric")) {
    if (ncol(data) != 1) {
      rlang::abort("`as = \"numeric\"` requires a single-channel stream.")
    }
    return(as.numeric(data[, 1]))
  }

  data
}

tdt_collect_one_epoc <- function(container, key) {
  epoc_obj <- tdt_container_get(container, key)
  store <- as.character(tdt_scalar(tdt_object_get(epoc_obj, "name"), key))
  onset <- as.numeric(tdt_py_to_r(tdt_object_get(epoc_obj, "onset", numeric(0))))
  offset <- as.numeric(tdt_py_to_r(tdt_object_get(epoc_obj, "offset", rep(NA_real_, length(onset)))))
  value <- tdt_py_to_r(tdt_object_get(epoc_obj, "data", tdt_object_get(epoc_obj, "value", rep(NA_real_, length(onset)))))

  n <- max(length(onset), length(offset), length(value), 0)
  if (n == 0) {
    return(tdt_empty_epocs())
  }
  if (length(onset) == 0) onset <- rep(NA_real_, n)
  if (length(offset) == 0) offset <- rep(NA_real_, n)
  if (length(value) == 0) value <- rep(NA, n)

  tibble::tibble(
    store = rep(store, n),
    onset = rep(onset, length.out = n),
    offset = rep(offset, length.out = n),
    value = rep(value, length.out = n)
  )
}

#' Collect epocs/events into R
#'
#' @param x A `tdt_block`, `tdt_block_py`, or compatible object.
#' @param store Optional epoc store name. If `NULL`, all epocs are collected.
#' @param as Return shape: `"tibble"` or `"list"`.
#'
#' @return A tibble or named list of tibbles.
#' @export
collect_epocs <- function(x, store = NULL, as = c("tibble", "list")) {
  as <- match.arg(as)

  if (is_tdt_block(x)) {
    result <- epocs(x, store = store)
    if (identical(as, "list")) {
      return(split(result, result$store))
    }
    return(tibble::as_tibble(result))
  }

  container <- epocs(x)
  if (is.null(container)) {
    result <- tdt_empty_epocs()
  } else {
    keys <- if (is.null(store)) {
      tdt_container_names(container, prefer_original = FALSE)
    } else {
      store
    }
    rows <- lapply(keys, function(key) tdt_collect_one_epoc(container, key))
    result <- if (length(rows) == 0) tdt_empty_epocs() else do.call(rbind, rows)
  }

  if (identical(as, "list")) {
    return(split(result, result$store))
  }
  tibble::as_tibble(result)
}

#' Collect a Python-backed TDT block into R
#'
#' @param x A `tdt_block`, `tdt_block_py`, or compatible object.
#' @param streams If `TRUE`, collect stream data.
#' @param epocs If `TRUE`, collect epoc/event data.
#' @param snips,scalars Reserved for future collection of Python `tdt` stores.
#' @param stores Optional stream names to collect.
#' @param max_bytes_warn Warn before copying a Python array larger than this many
#'   bytes.
#' @param quiet Suppress size warnings.
#'
#' @return A materialized `tdt_block`.
#' @export
collect_block <- function(x,
                          streams = TRUE,
                          epocs = TRUE,
                          snips = FALSE,
                          scalars = FALSE,
                          stores = NULL,
                          max_bytes_warn = 500 * 1024^2,
                          quiet = FALSE) {
  if (is_tdt_block(x)) {
    return(x)
  }

  if (isTRUE(snips) || isTRUE(scalars)) {
    warning("Collecting snips and scalars is not implemented yet.", call. = FALSE)
  }

  stream_list <- list()
  if (isTRUE(streams)) {
    names_to_collect <- stores %||% stream_names(x)
    stream_list <- lapply(names_to_collect, function(name) {
      collect_stream(
        x,
        store = name,
        as = "list",
        max_bytes_warn = max_bytes_warn,
        quiet = quiet
      )
    })
    names(stream_list) <- names_to_collect
  }

  epoc_tbl <- if (isTRUE(epocs)) collect_epocs(x) else tdt_empty_epocs()
  info <- block_info(x)
  info$source <- info$source %||% "python-tdt"
  info$block_path <- info$block_path %||% (if (tdt_is_py_wrapper(x)) x$path else NULL)

  new_tdt_block(info = info, streams = stream_list, epocs = epoc_tbl)
}

#' Coerce to a materialized TDT block
#'
#' @param x A `tdt_block`, `tdt_block_py`, or compatible object.
#' @param ... Passed to `collect_block()`.
#'
#' @return A materialized `tdt_block`.
#' @export
as_tdt_block <- function(x, ...) {
  collect_block(x, ...)
}

#' Return epocs/events as a tibble
#'
#' @param x A `tdt_block`, `tdt_block_py`, or compatible object.
#' @param store Optional epoc store name.
#'
#' @return A tibble with `store`, `onset`, `offset`, and `value` columns.
#' @export
as_tibble_epocs <- function(x, store = NULL) {
  collect_epocs(x, store = store, as = "tibble")
}

#' Return a bounded stream table
#'
#' @param x A `tdt_block`, `tdt_block_py`, or compatible object.
#' @param stream Stream name.
#' @param window Optional length-2 time window in seconds.
#' @param downsample Optional integer stride.
#' @param max_rows Optional maximum rows to return.
#'
#' @return A tibble with `time`, `channel`, and `value` columns.
#' @export
as_tibble_stream <- function(x, stream, window = NULL, downsample = NULL, max_rows = NULL) {
  collected <- collect_stream(x, stream, as = "list", include_time = TRUE)
  data <- collected$data
  time <- collected$time

  keep <- seq_len(nrow(data))
  if (!is.null(window)) {
    if (!is.numeric(window) || length(window) != 2 || anyNA(window) || window[[2]] <= window[[1]]) {
      rlang::abort("`window` must be a numeric length-2 vector with increasing values.")
    }
    keep <- keep[time[keep] >= window[[1]] & time[keep] < window[[2]]]
  }
  if (!is.null(downsample)) {
    if (!is.numeric(downsample) || length(downsample) != 1 || is.na(downsample) || downsample < 1) {
      rlang::abort("`downsample` must be a single positive number.")
    }
    keep <- keep[seq(1, length(keep), by = as.integer(downsample))]
  }
  if (!is.null(max_rows)) {
    if (!is.numeric(max_rows) || length(max_rows) != 1 || is.na(max_rows) || max_rows < 1) {
      rlang::abort("`max_rows` must be a single positive number.")
    }
    keep <- head(keep, as.integer(max_rows))
  }

  channels <- colnames(data) %||% paste0("channel_", seq_len(ncol(data)))
  rows <- lapply(seq_len(ncol(data)), function(j) {
    tibble::tibble(
      time = time[keep],
      channel = channels[[j]],
      value = as.numeric(data[keep, j])
    )
  })
  do.call(rbind, rows)
}
