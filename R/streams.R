#' Calculate stream timepoints
#'
#' @param n_points Number of samples in the stream.
#' @param fs Sampling frequency.
#' @param num_of_points Number of samples per exported row.
#'
#' @return A numeric vector of row-start timepoints in seconds.
#' @noRd
tdt_calc_timepoints <- function(n_points, fs, num_of_points = 128) {
  if (!is.numeric(n_points) || length(n_points) != 1 || is.na(n_points)) {
    rlang::abort("`n_points` must be a single number.")
  }
  if (!is.numeric(fs) || length(fs) != 1 || is.na(fs) || fs <= 0) {
    rlang::abort("`fs` must be a single positive number.")
  }
  if (!is.numeric(num_of_points) || length(num_of_points) != 1 ||
      is.na(num_of_points) || num_of_points <= 0) {
    rlang::abort("`num_of_points` must be a single positive number.")
  }

  if (n_points <= 0) {
    return(numeric(0))
  }

  seq(0, n_points - 1, by = num_of_points) * (1 / fs)
}

#' Format a TDT stream as a data frame
#'
#' Converts a single-channel TDT stream into a row-wise data frame for downstream
#' analysis.
#'
#' @param data_info TDT block info object or list containing `blockname`.
#' @param stream TDT stream object or list containing `name`, `fs`, `channel`,
#'   and `data`.
#' @param num_of_points Number of samples to place in each exported row.
#'
#' @return A data frame with block/event metadata and columns `D0` through
#'   `D{num_of_points - 1}`.
#' @noRd
tdt_format_stream <- function(data_info, stream, num_of_points = 128) {
  if (!is.numeric(num_of_points) || length(num_of_points) != 1 ||
      is.na(num_of_points) || num_of_points <= 0) {
    rlang::abort("`num_of_points` must be a single positive number.")
  }

  block_name <- as.character(tdt_py_to_r(tdt_object_get(data_info, "blockname", "")))
  event_name <- as.character(tdt_py_to_r(tdt_object_get(stream, "name", "")))
  fs <- as.numeric(tdt_py_to_r(tdt_object_get(stream, "fs", NA_real_)))

  if (is.na(fs) || fs <= 0) {
    rlang::abort(sprintf("Stream `%s` has an invalid sampling frequency.", event_name))
  }

  channel <- tdt_py_to_r(tdt_object_get(stream, "channel"))
  if (is.null(channel) || length(channel) != 1) {
    rlang::abort(sprintf("Stream `%s` has %s channels.", event_name, length(channel)))
  }

  stream_data <- tdt_py_to_r(tdt_object_get(stream, "data"))
  if (is.null(stream_data)) {
    rlang::abort(sprintf("Stream `%s` does not contain data.", event_name))
  }
  stream_values <- as.numeric(stream_data)

  num_rows <- floor(length(stream_values) / num_of_points)
  if (num_rows <= 0) {
    rlang::abort("Stream data length is too short for formatting.")
  }

  trimmed_values <- stream_values[seq_len(num_rows * num_of_points)]
  stream_matrix <- matrix(trimmed_values, ncol = num_of_points, byrow = TRUE)

  time_vals <- tdt_py_to_r(tdt_object_get(stream, "ts"))
  if (is.null(time_vals) || length(time_vals) == 0) {
    time_vals <- tdt_calc_timepoints(length(stream_values), fs, num_of_points)
  } else if (length(time_vals) == length(stream_values)) {
    time_vals <- time_vals[seq(1, length(stream_values), by = num_of_points)]
  } else if (length(time_vals) != num_rows) {
    time_vals <- tdt_calc_timepoints(length(stream_values), fs, num_of_points)
  }
  time_vals <- as.numeric(time_vals)[seq_len(num_rows)]

  data_names <- paste0("D", seq_len(num_of_points) - 1)
  stream_df <- as.data.frame(stream_matrix, stringsAsFactors = FALSE)
  names(stream_df) <- data_names

  stream_df$BLOCK <- block_name
  stream_df$EVENT <- event_name
  stream_df$TIME <- time_vals
  stream_df$CHAN <- as.numeric(channel)
  stream_df$Sampling_Freq <- fs
  stream_df$NumOfPoints <- num_of_points

  stream_df[, c("BLOCK", "EVENT", "TIME", "CHAN", "Sampling_Freq", "NumOfPoints", data_names)]
}

#' Return the display name for a stream object
#'
#' @param stream A stream object or a character stream name.
#'
#' @return A single character string.
#' @noRd
tdt_stream_label <- function(stream) {
  if (is.character(stream) && length(stream) == 1) {
    return(stream)
  }
  as.character(tdt_py_to_r(tdt_object_get(stream, "name", "")))
}

#' Validate selected TDT stream lengths
#'
#' @param streams A list containing `ttl_stream`, `iso_stream`, and
#'   `exp_stream` stream objects.
#'
#' @return A named integer vector of stream lengths, invisibly. Throws an error
#'   of class `tdt_stream_length_mismatch` if lengths differ.
#' @noRd
tdt_validate_stream_lengths <- function(streams) {
  tdt_validate_stream_config(streams)

  lengths <- vapply(tdt_required_stream_roles(), function(role) {
    stream_data <- tdt_py_to_r(tdt_object_get(streams[[role]], "data"))
    length(stream_data)
  }, integer(1))
  names(lengths) <- tdt_required_stream_roles()

  if (length(unique(lengths)) != 1) {
    rlang::abort(
      "Selected streams have different data lengths.",
      class = "tdt_stream_length_mismatch",
      lengths = lengths
    )
  }

  invisible(lengths)
}
