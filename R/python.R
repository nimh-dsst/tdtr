#' Check whether Python `tdt` is available
#'
#' @param initialize If `TRUE`, allow reticulate to initialize Python while
#'   checking for `tdt`.
#'
#' @return `TRUE` if reticulate can find Python `tdt`, otherwise `FALSE`.
#' @export
tdt_available <- function(initialize = TRUE) {
  if (!requireNamespace("reticulate", quietly = TRUE)) {
    return(FALSE)
  }
  if (!isTRUE(initialize) && !isTRUE(tryCatch(reticulate::py_available(initialize = FALSE), error = function(e) FALSE))) {
    return(FALSE)
  }
  isTRUE(tryCatch(reticulate::py_module_available("tdt"), error = function(e) FALSE))
}

#' Show Python configuration for `tdtr`
#'
#' @param initialize If `TRUE`, include `reticulate::py_config()` details. This
#'   may initialize Python.
#'
#' @return A list with reticulate, Python, and Python `tdt` availability fields.
#' @export
tdt_config <- function(initialize = FALSE) {
  has_reticulate <- requireNamespace("reticulate", quietly = TRUE)
  py_available <- FALSE
  py_module <- FALSE
  py_config <- NULL

  if (has_reticulate) {
    py_available <- isTRUE(tryCatch(
      reticulate::py_available(initialize = FALSE),
      error = function(e) FALSE
    ))
    py_module <- tdt_available(initialize = initialize)
    if (isTRUE(initialize)) {
      py_config <- tryCatch(reticulate::py_config(), error = function(e) e)
    }
  }

  list(
    reticulate = has_reticulate,
    python_available = py_available,
    tdt_available = py_module,
    python = py_config,
    requirement = "tdt>=0.7.3"
  )
}

tdt_import <- function() {
  tdt_check_reticulate()

  if (!is.null(.tdtr_env$py_require_error)) {
    rlang::abort(
      "Failed to declare Python requirement `tdt>=0.7.3` with reticulate.",
      parent = .tdtr_env$py_require_error
    )
  }

  if (is.null(.tdtr_env$tdt)) {
    .tdtr_env$tdt <- tryCatch(
      reticulate::import("tdt", delay_load = TRUE, convert = FALSE),
      error = function(e) {
        .tdtr_env$import_error <- e
        NULL
      }
    )
  }

  if (!tdt_available(initialize = TRUE)) {
    rlang::abort(
      paste(
        "Python module `tdt>=0.7.3` is not available to reticulate.",
        "Install it in the active Python environment with `python -m pip install 'tdt>=0.7.3'`,",
        "or configure reticulate before calling Python-backed tdtr functions."
      ),
      class = "tdt_python_unavailable"
    )
  }

  .tdtr_env$tdt
}

new_tdt_py <- function(py, path = NULL, args = list(), class = character()) {
  structure(
    list(
      py = py,
      path = path,
      args = args
    ),
    class = c(class, "tdt_py")
  )
}

#' Read a TDT block through Python `tdt`
#'
#' @param block_path Path to a TDT block/tank directory.
#' @param ... Extra keyword arguments passed to `tdt.read_block()`.
#' @param collect If `FALSE`, return a Python-backed `tdt_block_py` wrapper. If
#'   `TRUE`, collect into a materialized R `tdt_block`.
#'
#' @return A `tdt_block_py` wrapper or a materialized `tdt_block`.
#'
#' @details
#' `read_block()` normalizes read-time `store` filters against the block
#' header, so the stream names returned by [stream_names()] can also be used for
#' filtering. This matters for TDT stores whose original names are not valid
#' Python identifiers. For example, Python `tdt` filters a store originally
#' named `465A` with `store = "465A"`, but the returned stream is exposed under
#' the sanitized name `_465A`. `read_block()` accepts either spelling. Use
#' [read_block_py()] when you need Python `tdt.read_block()` store matching
#' exactly as implemented upstream.
#'
#' @export
read_block <- function(block_path, ..., collect = FALSE) {
  args <- list(...)
  if (!is.null(args$store) && !tdt_store_filter_is_empty(args$store)) {
    args$store <- tdt_normalize_read_store_filter(block_path, args$store, args)
  }

  block <- do.call(read_block_py, c(list(block_path = block_path), args))
  if (isTRUE(collect)) {
    collect_block(block)
  } else {
    block
  }
}

tdt_read_block_evtype <- function(evtype) {
  if (is.null(evtype)) {
    NULL
  } else if (is.character(evtype)) {
    as.list(evtype)
  } else {
    evtype
  }
}

tdt_store_filter_is_empty <- function(store) {
  is.null(store) ||
    (is.character(store) && length(store) == 0) ||
    (is.character(store) && length(store) == 1 && !nzchar(store)) ||
    (is.list(store) && length(store) == 0)
}

tdt_store_filter_is_character <- function(store) {
  is.character(store) ||
    (is.list(store) && all(vapply(store, function(x) {
      is.character(x) && length(x) == 1
    }, logical(1))))
}

tdt_translate_store_filter <- function(store, store_map) {
  translate_one <- function(value) {
    if (!is.character(value) || length(value) != 1 || is.na(value)) {
      return(value)
    }
    mapped <- if (value %in% names(store_map)) store_map[[value]] else NULL
    if (is.null(mapped) || length(mapped) != 1 || is.na(mapped) || !nzchar(mapped)) {
      value
    } else {
      mapped
    }
  }

  if (is.character(store)) {
    return(vapply(store, translate_one, character(1), USE.NAMES = FALSE))
  }
  if (is.list(store)) {
    return(lapply(store, translate_one))
  }
  store
}

tdt_read_block_store_map <- function(block_path, args, tdt) {
  headers <- args$headers %||% NULL
  stores <- tdt_object_get(headers, "stores", NULL)

  if (is.null(stores)) {
    header_args <- list(
      block_path = tdt_normalize_path(block_path, must_work = FALSE),
      headers = 1,
      verbose = 0
    )

    for (name in c("evtype", "t1", "t2", "sortname", "dmy", "noepocauto")) {
      if (!is.null(args[[name]])) {
        header_args[[name]] <- args[[name]]
      }
    }
    header_args$evtype <- tdt_read_block_evtype(header_args$evtype)

    headers <- tdt_quiet_python_output(
      tdt_call(
        tdt$read_block,
        header_args,
        error = "Failed to inspect TDT block stores with Python `tdt.read_block(headers = 1)`."
      )
    )
    stores <- tdt_object_get(headers, "stores", NULL)
  }

  keys <- tdt_container_names(stores, prefer_original = FALSE)
  originals <- vapply(keys, function(key) {
    store_obj <- tdt_object_get(stores, key)
    original <- tdt_py_to_r(tdt_object_get(store_obj, "name", key))
    if (is.character(original) && length(original) == 1 && nzchar(original)) {
      original
    } else {
      key
    }
  }, character(1), USE.NAMES = FALSE)
  names(originals) <- keys
  originals
}

tdt_normalize_read_store_filter <- function(block_path, store, args) {
  if (!tdt_store_filter_is_character(store)) {
    return(store)
  }

  tdt <- tdt_import()
  store_map <- tryCatch(
    tdt_read_block_store_map(block_path, args, tdt),
    error = function(e) NULL
  )
  if (is.null(store_map) || length(store_map) == 0) {
    return(store)
  }

  tdt_translate_store_filter(store, store_map)
}

#' Read a TDT block through Python `tdt`
#'
#' This is the explicit Python-backed compatibility wrapper for
#' `tdt.read_block()`. It keeps Python objects live and does not copy stream
#' arrays into R unless a collection helper is called later.
#'
#' `read_block_py()` passes `store` directly to Python `tdt.read_block()`. For
#' stores whose returned names are sanitized by Python, such as `_465A`, pass the
#' original TDT store ID (`465A`) or use [read_block()] for tdtr's
#' header-based normalization.
#'
#' @param block_path Path to a TDT block/tank directory.
#' @param bitwise,channel,combine,headers,nodata,ranges,store,t1,t2,evtype,verbose,sortname,export,scale,dtype,outdir,prefix,outfile,dmy,noepocauto
#'   Arguments passed to Python `tdt.read_block()`.
#' @param ... Additional keyword arguments passed to Python `tdt.read_block()`.
#'
#' @return A `tdt_block_py` wrapper.
#' @export
read_block_py <- function(block_path,
                          bitwise = "",
                          channel = 0,
                          combine = NULL,
                          headers = 0,
                          nodata = FALSE,
                          ranges = NULL,
                          store = "",
                          t1 = 0,
                          t2 = 0,
                          evtype = NULL,
                          verbose = 0,
                          sortname = "TankSort",
                          export = NULL,
                          scale = 1,
                          dtype = NULL,
                          outdir = NULL,
                          prefix = NULL,
                          outfile = NULL,
                          dmy = FALSE,
                          noepocauto = FALSE,
                          ...) {
  tdt_check_dir(block_path, "block_path")
  tdt <- tdt_import()

  if (!is.null(ranges)) {
    ranges <- as_ranges(ranges)
  }
  evtype <- tdt_read_block_evtype(evtype)

  args <- c(
    list(
      block_path = tdt_normalize_path(block_path, must_work = FALSE),
      bitwise = bitwise,
      channel = channel,
      combine = combine,
      headers = headers,
      nodata = nodata,
      ranges = ranges,
      store = store,
      t1 = t1,
      t2 = t2,
      evtype = evtype,
      verbose = verbose,
      sortname = sortname,
      export = export,
      scale = scale,
      dtype = dtype,
      outdir = outdir,
      prefix = prefix,
      outfile = outfile,
      dmy = dmy,
      noepocauto = noepocauto
    ),
    list(...)
  )

  py <- if (tdt_capture_when_quiet(verbose)) {
    tdt_quiet_python_output(
      tdt_call(tdt$read_block, args, error = "Failed to read TDT block with Python `tdt.read_block()`.")
    )
  } else {
    tdt_call(tdt$read_block, args, error = "Failed to read TDT block with Python `tdt.read_block()`.")
  }
  new_tdt_py(py, path = block_path, args = args, class = "tdt_block_py")
}

#' Read TDT SEV data through Python `tdt`
#'
#' @param sev_dir Path to a SEV directory or file.
#' @param channel,event_name,t1,t2,fs,ranges,verbose,just_names,export,scale,dtype,outdir,prefix
#'   Arguments passed to Python `tdt.read_sev()`.
#' @param ... Additional keyword arguments passed to Python `tdt.read_sev()`.
#'
#' @return A `tdt_sev_py` wrapper.
#' @export
read_sev_py <- function(sev_dir,
                        channel = 0,
                        event_name = "",
                        t1 = 0,
                        t2 = 0,
                        fs = 0,
                        ranges = NULL,
                        verbose = 0,
                        just_names = FALSE,
                        export = NULL,
                        scale = 1,
                        dtype = NULL,
                        outdir = NULL,
                        prefix = NULL,
                        ...) {
  tdt_check_dir(sev_dir, "sev_dir")
  tdt <- tdt_import()

  if (!is.null(ranges)) {
    ranges <- as_ranges(ranges)
  }

  args <- c(
    list(
      sev_dir = tdt_normalize_path(sev_dir, must_work = FALSE),
      channel = channel,
      event_name = event_name,
      t1 = t1,
      t2 = t2,
      fs = fs,
      ranges = ranges,
      verbose = verbose,
      just_names = just_names,
      export = export,
      scale = scale,
      dtype = dtype,
      outdir = outdir,
      prefix = prefix
    ),
    list(...)
  )

  py <- if (tdt_capture_when_quiet(verbose)) {
    tdt_quiet_python_output(
      tdt_call(tdt$read_sev, args, error = "Failed to read SEV data with Python `tdt.read_sev()`.")
    )
  } else {
    tdt_call(tdt$read_sev, args, error = "Failed to read SEV data with Python `tdt.read_sev()`.")
  }
  new_tdt_py(py, path = sev_dir, args = args, class = "tdt_sev_py")
}

#' Filter TDT epocs through Python `tdt`
#'
#' @param data A `tdt_block_py` wrapper or raw Python block object.
#' @param epoc Epoc store name.
#' @param values,modifiers,t,tref,keepdata Arguments passed to Python
#'   `tdt.epoc_filter()`.
#' @param ... Additional keyword arguments passed to Python `tdt.epoc_filter()`.
#'
#' @return A `tdt_block_py` wrapper.
#' @export
epoc_filter_py <- function(data,
                           epoc,
                           values = NULL,
                           modifiers = NULL,
                           t = NULL,
                           tref = FALSE,
                           keepdata = TRUE,
                           ...) {
  tdt_check_string(epoc, "epoc")
  tdt_check_live_py(data)
  tdt <- tdt_import()

  args <- c(
    list(
      data = tdt_py_unwrap(data),
      epoc = epoc,
      values = values,
      modifiers = modifiers,
      t = t,
      tref = tref,
      keepdata = keepdata
    ),
    list(...)
  )

  py <- tdt_call(tdt$epoc_filter, args, error = "Failed to filter TDT data with Python `tdt.epoc_filter()`.")
  path <- if (tdt_is_py_wrapper(data)) data$path else NULL
  new_tdt_py(py, path = path, args = args, class = "tdt_block_py")
}

# Backwards-compatible internal names used by older prototype helpers.
tdt_read_block <- read_block_py
