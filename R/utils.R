`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

tdt_is_python_object <- function(x) {
  any(startsWith(class(x), "python."))
}

tdt_is_py_wrapper <- function(x) {
  inherits(x, "tdt_py")
}

tdt_py_unwrap <- function(x) {
  if (tdt_is_py_wrapper(x)) {
    x$py
  } else {
    x
  }
}

tdt_py_is_null <- function(x) {
  x <- tdt_py_unwrap(x)
  if (!tdt_is_python_object(x) || !requireNamespace("reticulate", quietly = TRUE)) {
    return(FALSE)
  }
  isTRUE(tryCatch(reticulate::py_is_null_xptr(x), error = function(e) FALSE))
}

tdt_check_live_py <- function(x) {
  if (tdt_py_is_null(x)) {
    rlang::abort(
      paste(
        "This Python-backed TDT object is no longer available.",
        "Reload it with `read_block()` or collect it into R before saving."
      ),
      class = "tdt_stale_python_object"
    )
  }
  invisible(x)
}

tdt_py_to_r <- function(x) {
  x <- tdt_py_unwrap(x)
  if (tdt_is_python_object(x)) {
    tdt_check_reticulate()
    reticulate::py_to_r(x)
  } else {
    x
  }
}

tdt_object_get <- function(x, name, default = NULL) {
  x <- tdt_py_unwrap(x)
  if (is.null(x)) {
    return(default)
  }

  if (is.list(x) && !is.null(names(x)) && name %in% names(x)) {
    return(x[[name]])
  }

  sentinel <- new.env(parent = emptyenv())
  value <- tryCatch(x[[name]], error = function(e) sentinel)
  if (!identical(value, sentinel)) {
    return(value)
  }

  if (is.environment(x) && exists(name, envir = x, inherits = FALSE)) {
    return(get(name, envir = x, inherits = FALSE))
  }

  if (tdt_is_python_object(x) && requireNamespace("reticulate", quietly = TRUE)) {
    has_attr <- tryCatch(reticulate::py_has_attr(x, name), error = function(e) FALSE)
    if (isTRUE(has_attr)) {
      return(reticulate::py_get_attr(x, name))
    }
  }

  default
}

tdt_check_reticulate <- function() {
  if (!requireNamespace("reticulate", quietly = TRUE)) {
    rlang::abort("The reticulate package is required for Python-backed TDT objects.")
  }
  invisible(TRUE)
}

tdt_check_string <- function(x, arg = "x", allow_empty = FALSE) {
  if (!is.character(x) || length(x) != 1 || (!allow_empty && !nzchar(x))) {
    rlang::abort(sprintf("`%s` must be a single%s string.", arg, if (allow_empty) "" else " non-empty"))
  }
  invisible(x)
}

tdt_check_dir <- function(path, arg = "path") {
  if (!is.character(path) || length(path) != 1 || !nzchar(path)) {
    rlang::abort(sprintf("`%s` must be a single non-empty path.", arg))
  }
  invisible(path)
}

tdt_required_stream_roles <- function() {
  c("ttl_stream", "iso_stream", "exp_stream")
}

tdt_validate_stream_config <- function(streams) {
  if (!is.list(streams)) {
    rlang::abort("`streams` must be a list.")
  }

  missing <- setdiff(tdt_required_stream_roles(), names(streams))
  if (length(missing) > 0) {
    rlang::abort(
      sprintf("`streams` is missing required field(s): %s.", paste(missing, collapse = ", "))
    )
  }

  invisible(streams)
}

tdt_order_label <- function(index) {
  labels <- c("First", "Second", "Third", "Fourth", "Fifth")
  if (index <= length(labels)) {
    labels[[index]]
  } else {
    paste0("Subject ", index)
  }
}

tdt_find_stream_map_entry <- function(stream_map, order, index, n_subjects) {
  if (!is.list(stream_map)) {
    rlang::abort("`stream_map` must be a list.")
  }

  candidates <- c(order, tolower(order), paste0("subject_", index), as.character(index))
  for (candidate in candidates) {
    if (!is.null(stream_map[[candidate]])) {
      return(stream_map[[candidate]])
    }
  }

  if (n_subjects == 1 && all(tdt_required_stream_roles() %in% names(stream_map))) {
    return(stream_map)
  }

  rlang::abort(sprintf("No stream map entry found for subject order `%s`.", order))
}

tdt_normalize_path <- function(path, must_work = FALSE) {
  normalizePath(path, winslash = "/", mustWork = must_work)
}

tdt_call <- function(fun, args, error = "Python `tdt` call failed.") {
  tryCatch(
    do.call(fun, args),
    error = function(e) rlang::abort(error, parent = e)
  )
}

tdt_quiet_python_output <- function(expr) {
  value <- NULL
  reticulate::py_capture_output(
    reticulate::py_capture_output(
      value <- force(expr),
      type = "stderr"
    ),
    type = "stdout"
  )
  value
}

tdt_capture_when_quiet <- function(verbose) {
  isFALSE(verbose) ||
    (is.numeric(verbose) && length(verbose) == 1 && !is.na(verbose) && verbose <= 0)
}

tdt_container_names <- function(x, prefer_original = TRUE) {
  x <- tdt_py_unwrap(x)
  if (is.null(x)) {
    return(character(0))
  }

  keys_fun <- tdt_object_get(x, "keys")
  if (is.function(keys_fun)) {
    raw_keys <- keys_fun()
    keys <- if (tdt_is_python_object(raw_keys) && requireNamespace("reticulate", quietly = TRUE)) {
      tryCatch(
        as.character(reticulate::import_builtins(convert = TRUE)$list(raw_keys)),
        error = function(e) as.character(tdt_py_to_r(raw_keys))
      )
    } else {
      as.character(tdt_py_to_r(raw_keys))
    }
  } else if (is.list(x) && !is.null(names(x))) {
    keys <- names(x)
  } else {
    converted <- tryCatch(tdt_py_to_r(x), error = function(e) NULL)
    keys <- names(converted) %||% character(0)
  }

  if (!isTRUE(prefer_original) || length(keys) == 0) {
    return(keys)
  }

  vapply(keys, function(key) {
    item <- tdt_object_get(x, key)
    original <- tdt_py_to_r(tdt_object_get(item, "name", key))
    if (is.character(original) && length(original) == 1 && nzchar(original)) {
      original
    } else {
      key
    }
  }, character(1), USE.NAMES = FALSE)
}

tdt_py_mapping_to_list <- function(x) {
  x <- tdt_py_unwrap(x)
  if (!tdt_is_python_object(x)) {
    return(tdt_py_to_r(x))
  }

  keys_fun <- tdt_object_get(x, "keys")
  if (!is.function(keys_fun)) {
    return(tdt_py_to_r(x))
  }

  keys <- tdt_container_names(x, prefer_original = FALSE)
  values <- lapply(keys, function(key) {
    value <- tdt_object_get(x, key)
    converted <- tdt_py_to_r(value)
    if (tdt_is_python_object(converted)) {
      as.character(converted)
    } else {
      converted
    }
  })
  names(values) <- keys
  values
}

tdt_container_get <- function(x, name) {
  tdt_check_string(name, "name")
  x <- tdt_py_unwrap(x)
  if (is.null(x)) {
    return(NULL)
  }

  sentinel <- new.env(parent = emptyenv())
  direct <- tdt_object_get(x, name, sentinel)
  if (!identical(direct, sentinel)) {
    return(direct)
  }

  keys <- tdt_container_names(x, prefer_original = FALSE)
  for (key in keys) {
    item <- tdt_object_get(x, key)
    original <- tdt_py_to_r(tdt_object_get(item, "name", key))
    if (identical(original, name)) {
      return(item)
    }
  }

  NULL
}

tdt_scalar <- function(x, default = NA_real_) {
  x <- tdt_py_to_r(x)
  if (is.null(x) || length(x) == 0) {
    return(default)
  }
  x[[1]]
}

tdt_empty_epocs <- function() {
  tibble::tibble(
    store = character(),
    onset = numeric(),
    offset = numeric(),
    value = numeric()
  )
}
