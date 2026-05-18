`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

tdt_is_python_object <- function(x) {
  any(startsWith(class(x), "python."))
}

tdt_py_to_r <- function(x) {
  if (tdt_is_python_object(x)) {
    tdt_check_reticulate()
    reticulate::py_to_r(x)
  } else {
    x
  }
}

tdt_object_get <- function(x, name, default = NULL) {
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
