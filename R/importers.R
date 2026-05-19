tdt_stream_object <- function(data, fs, name, channels = NULL, t0 = 0, units = NULL, metadata = list()) {
  if (!is.numeric(fs) || length(fs) != 1 || is.na(fs) || fs <= 0) {
    rlang::abort("`fs` must be a single positive number.")
  }
  tdt_check_string(name, "name")

  data <- if (is.data.frame(data)) as.matrix(data) else data
  if (is.null(dim(data))) {
    data <- matrix(as.numeric(data), ncol = 1)
  } else if (length(dim(data)) != 2) {
    rlang::abort("Stream data must be one- or two-dimensional.")
  } else {
    data <- as.matrix(data)
  }

  if (is.null(channels)) {
    channels <- seq_len(ncol(data))
  }
  colnames(data) <- as.character(channels)

  list(
    name = name,
    data = data,
    fs = fs,
    t0 = t0,
    channels = channels,
    units = units,
    metadata = metadata
  )
}

#' Read a stream CSV export
#'
#' @param path CSV file path.
#' @param fs Sampling frequency.
#' @param name Stream name.
#' @param channels Optional channel labels.
#' @param t0 Stream start time in seconds.
#' @param ... Passed to [utils::read.csv()].
#'
#' @return A materialized stream object.
#' @export
read_stream_csv <- function(path, fs, name, channels = NULL, t0 = 0, ...) {
  tdt_check_dir(path, "path")
  data <- utils::read.csv(path, check.names = FALSE, ...)
  tdt_stream_object(data, fs = fs, name = name, channels = channels, t0 = t0)
}

#' Read an epoc/event CSV export
#'
#' @param path CSV file path.
#' @param ... Passed to [utils::read.csv()].
#'
#' @return A tibble with `store`, `onset`, `offset`, and `value` columns.
#' @export
read_epocs_csv <- function(path, ...) {
  tdt_check_dir(path, "path")
  data <- utils::read.csv(path, check.names = FALSE, stringsAsFactors = FALSE, ...)
  required <- c("store", "onset", "offset", "value")
  missing <- setdiff(required, names(data))
  if (length(missing) > 0) {
    rlang::abort(sprintf("Epoc CSV is missing required column(s): %s.", paste(missing, collapse = ", ")))
  }
  tibble::as_tibble(data)
}
