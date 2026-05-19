#' Create a materialized TDT block
#'
#' @param info Named list of block metadata.
#' @param streams Named list of stream objects.
#' @param epocs Epoc/event table. If `NULL`, an empty tibble is used.
#'
#' @return A `tdt_block` object.
#' @export
new_tdt_block <- function(info = list(), streams = list(), epocs = NULL) {
  if (is.null(epocs)) {
    epocs <- tdt_empty_epocs()
  }

  x <- structure(
    list(
      info = info,
      streams = streams,
      epocs = epocs
    ),
    class = c("tdt_block", "list")
  )
  validate_tdt_block(x)
  x
}

#' Test whether an object is a materialized TDT block
#'
#' @param x Object to test.
#'
#' @return `TRUE` if `x` inherits from `tdt_block`, otherwise `FALSE`.
#' @export
is_tdt_block <- function(x) {
  inherits(x, "tdt_block")
}

#' Validate a materialized TDT block
#'
#' @param x Object to validate.
#'
#' @return `x`, invisibly.
#' @export
validate_tdt_block <- function(x) {
  if (!is.list(x)) {
    rlang::abort("`x` must be a list.")
  }
  for (field in c("info", "streams", "epocs")) {
    if (is.null(x[[field]])) {
      rlang::abort(sprintf("`x` is missing required field `%s`.", field))
    }
  }
  if (!is.list(x$info)) {
    rlang::abort("`x$info` must be a list.")
  }
  if (!is.list(x$streams)) {
    rlang::abort("`x$streams` must be a named list.")
  }
  if (length(x$streams) > 0 && is.null(names(x$streams))) {
    rlang::abort("`x$streams` must be a named list.")
  }

  for (name in names(x$streams)) {
    stream <- x$streams[[name]]
    data <- stream$data %||% NULL
    if (is.null(data)) {
      rlang::abort(sprintf("Stream `%s` is missing `data`.", name))
    }
    if (!is.atomic(data) && !is.matrix(data) && !is.array(data)) {
      rlang::abort(sprintf("Stream `%s` data must be an atomic vector, matrix, or array.", name))
    }
  }

  required_epoc_cols <- c("store", "onset", "offset", "value")
  missing <- setdiff(required_epoc_cols, names(x$epocs))
  if (length(missing) > 0) {
    rlang::abort(sprintf("`x$epocs` is missing required column(s): %s.", paste(missing, collapse = ", ")))
  }

  invisible(x)
}

#' @export
print.tdt_block <- function(x, ...) {
  cat("<tdt_block>\n")
  source <- x$info$source %||% x$info$block_path %||% NULL
  if (!is.null(source)) {
    cat("Source: ", source, "\n", sep = "")
  }
  cat("Streams: ", length(x$streams), "\n", sep = "")
  if (length(x$streams) > 0) {
    cat("  ", paste(names(x$streams), collapse = ", "), "\n", sep = "")
  }
  cat("Epocs: ", nrow(x$epocs), " rows\n", sep = "")
  invisible(x)
}

#' @export
summary.tdt_block <- function(object, ...) {
  stream_rows <- lapply(names(object$streams), function(name) {
    stream <- object$streams[[name]]
    data <- stream$data
    dims <- dim(data)
    if (is.null(dims)) {
      n_samples <- length(data)
      n_channels <- 1L
    } else {
      n_samples <- dims[[1]]
      n_channels <- if (length(dims) >= 2) dims[[2]] else 1L
    }
    fs <- as.numeric(stream$fs %||% NA_real_)
    tibble::tibble(
      stream = name,
      fs = fs,
      n_samples = as.integer(n_samples),
      n_channels = as.integer(n_channels)
    )
  })

  list(
    info = object$info,
    streams = if (length(stream_rows) == 0) {
      tibble::tibble(stream = character(), fs = numeric(), n_samples = integer(), n_channels = integer())
    } else {
      do.call(rbind, stream_rows)
    },
    epocs = object$epocs
  )
}

#' @export
print.tdt_block_py <- function(x, ...) {
  cat("<tdt_block_py>\n")
  if (tdt_py_is_null(x)) {
    cat("Python object: stale external pointer\n")
    return(invisible(x))
  }
  if (!is.null(x$path)) {
    cat("Path: ", x$path, "\n", sep = "")
  }
  cat("Streams: ", paste(stream_names(x), collapse = ", "), "\n", sep = "")
  cat("Epocs: ", paste(epoc_names(x), collapse = ", "), "\n", sep = "")
  invisible(x)
}

#' @export
summary.tdt_block_py <- function(object, ...) {
  if (tdt_py_is_null(object)) {
    return(list(stale = TRUE, path = object$path))
  }

  stream_rows <- lapply(stream_names(object), function(name) {
    stream_obj <- stream(object, name)
    data <- tdt_object_get(stream_obj, "data")
    shape <- tdt_py_to_r(tdt_object_get(data, "shape", NULL))
    tibble::tibble(
      stream = name,
      fs = as.numeric(tdt_scalar(tdt_object_get(stream_obj, "fs"), NA_real_)),
      shape = paste(shape %||% character(0), collapse = " x "),
      nbytes = as.numeric(tdt_scalar(tdt_object_get(data, "nbytes"), NA_real_))
    )
  })

  list(
    path = object$path,
    streams = if (length(stream_rows) == 0) {
      tibble::tibble(stream = character(), fs = numeric(), shape = character(), nbytes = numeric())
    } else {
      do.call(rbind, stream_rows)
    },
    epocs = epoc_names(object)
  )
}

#' @export
print.tdt_sev_py <- function(x, ...) {
  cat("<tdt_sev_py>\n")
  if (tdt_py_is_null(x)) {
    cat("Python object: stale external pointer\n")
    return(invisible(x))
  }
  if (!is.null(x$path)) {
    cat("Path: ", x$path, "\n", sep = "")
  }
  cat("Streams: ", paste(stream_names(x), collapse = ", "), "\n", sep = "")
  invisible(x)
}
