#' Check whether Python's `tdt` module is available
#'
#' @return `TRUE` if `reticulate` can find the Python `tdt` module, otherwise
#'   `FALSE`.
#' @export
tdt_available <- function() {
  requireNamespace("reticulate", quietly = TRUE) &&
    reticulate::py_module_available("tdt")
}

#' Import Python's `tdt` module
#'
#' @param delay_load Passed to [reticulate::import()].
#' @param convert Passed to [reticulate::import()]. The default keeps Python
#'   objects intact because TDT stream objects are often written back to pickle.
#'
#' @return A Python module proxy.
#' @export
tdt_import <- function(delay_load = TRUE, convert = FALSE) {
  tdt_check_reticulate()

  if (!tdt_available()) {
    rlang::abort(
      paste(
        "Python module `tdt` is not available.",
        "Install it in the active Python environment with `python -m pip install tdt`."
      )
    )
  }

  tryCatch(
    reticulate::import("tdt", delay_load = delay_load, convert = convert),
    error = function(e) {
      rlang::abort(
        paste(
          "Python module `tdt` is not available.",
          "Install it in the active Python environment with `python -m pip install tdt`."
        ),
        parent = e
      )
    }
  )
}

#' Read a TDT block
#'
#' Calls Python's `tdt.read_block()` through `reticulate`.
#'
#' @param block_path Path to a TDT block/tank directory.
#' @param ... Additional arguments passed to `tdt.read_block()`.
#' @param as Return type. `"python"` keeps the Python object proxy. `"r"`
#'   converts the result with [reticulate::py_to_r()].
#'
#' @return A TDT block object.
#' @export
tdt_read_block <- function(block_path, ..., as = c("python", "r")) {
  tdt_check_dir(block_path, "block_path")
  as <- match.arg(as)
  tdt <- tdt_import(convert = FALSE)

  block <- tryCatch(
    tdt$read_block(tdt_normalize_path(block_path, must_work = FALSE), ...),
    error = function(e) rlang::abort("Failed to read TDT block.", parent = e)
  )

  if (identical(as, "r")) {
    reticulate::py_to_r(block)
  } else {
    block
  }
}

#' List stream names in a TDT block
#'
#' @param block A TDT block object returned by [tdt_read_block()] or an
#'   equivalent R list.
#'
#' @return A character vector of stream names.
#' @export
tdt_stream_names <- function(block) {
  streams <- tdt_object_get(block, "streams")
  if (is.null(streams)) {
    return(character(0))
  }

  keys_fun <- tdt_object_get(streams, "keys")
  if (is.function(keys_fun)) {
    return(as.character(tdt_py_to_r(keys_fun())))
  }

  if (is.list(streams) && !is.null(names(streams))) {
    return(names(streams))
  }

  as.character(names(tdt_py_to_r(streams)) %||% character(0))
}

#' Get one stream from a TDT block
#'
#' @param block A TDT block object returned by [tdt_read_block()] or an
#'   equivalent R list.
#' @param stream Name of the stream to retrieve.
#'
#' @return A stream object.
#' @export
tdt_get_stream <- function(block, stream) {
  if (!is.character(stream) || length(stream) != 1 || !nzchar(stream)) {
    rlang::abort("`stream` must be a single non-empty stream name.")
  }

  streams <- tdt_object_get(block, "streams")
  if (is.null(streams)) {
    rlang::abort("`block` does not contain a `streams` field.")
  }

  value <- tdt_object_get(streams, stream)
  if (is.null(value)) {
    rlang::abort(sprintf("Stream `%s` was not found in `block`.", stream))
  }

  value
}
