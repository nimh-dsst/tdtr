#' Return block metadata
#'
#' @param x A `tdt_block`, `tdt_block_py`, or compatible object.
#'
#' @return A named list.
#' @export
block_info <- function(x) {
  if (is_tdt_block(x)) {
    return(x$info)
  }
  tdt_check_live_py(x)
  info <- tdt_object_get(tdt_py_unwrap(x), "info", list())
  info <- tdt_py_mapping_to_list(info)
  if (is.null(info)) {
    list()
  } else if (is.environment(info)) {
    as.list(info, all.names = TRUE)
  } else {
    as.list(info)
  }
}

#' Return the stream container
#'
#' @param x A `tdt_block`, `tdt_block_py`, `tdt_sev_py`, or compatible object.
#'
#' @return A stream container. For Python-backed objects this may be a live
#'   Python object and does not copy stream arrays into R.
#' @export
streams <- function(x) {
  if (is_tdt_block(x)) {
    return(x$streams)
  }
  tdt_check_live_py(x)
  py <- tdt_py_unwrap(x)
  tdt_object_get(py, "streams", py)
}

#' Return stream names
#'
#' @param x A `tdt_block`, `tdt_block_py`, `tdt_sev_py`, stream container, or
#'   compatible object.
#'
#' @return A character vector of stream names.
#' @export
stream_names <- function(x) {
  if (is_tdt_block(x)) {
    return(names(x$streams) %||% character(0))
  }
  tdt_container_names(streams(x), prefer_original = TRUE)
}

#' Return one stream
#'
#' @param x A `tdt_block`, `tdt_block_py`, `tdt_sev_py`, or compatible object.
#' @param name Stream name. The sanitized Python key or original TDT store name
#'   may be used.
#'
#' @return A stream object. For Python-backed blocks this is a live Python stream
#'   object and does not copy stream data into R.
#' @export
stream <- function(x, name) {
  tdt_check_string(name, "name")
  if (is_tdt_block(x)) {
    value <- x$streams[[name]]
    if (is.null(value)) {
      rlang::abort(sprintf("Stream `%s` was not found.", name))
    }
    return(value)
  }

  value <- tdt_container_get(streams(x), name)
  if (is.null(value)) {
    rlang::abort(sprintf("Stream `%s` was not found.", name))
  }
  value
}

#' Return the epoc/event container or rows
#'
#' @param x A `tdt_block`, `tdt_block_py`, or compatible object.
#' @param store Optional epoc store name.
#'
#' @return For materialized blocks, a tibble. For Python-backed blocks with no
#'   `store`, the live Python epocs container.
#' @export
epocs <- function(x, store = NULL) {
  if (is_tdt_block(x)) {
    if (is.null(store)) {
      return(x$epocs)
    }
    return(x$epocs[x$epocs$store %in% store, , drop = FALSE])
  }

  tdt_check_live_py(x)
  container <- tdt_object_get(tdt_py_unwrap(x), "epocs")
  if (is.null(container)) {
    return(NULL)
  }
  if (is.data.frame(container)) {
    if (is.null(store)) {
      return(tibble::as_tibble(container))
    }
    return(tibble::as_tibble(container[container$store %in% store, , drop = FALSE]))
  }
  if (is.null(store)) {
    return(container)
  }
  value <- tdt_container_get(container, store)
  if (is.null(value)) {
    rlang::abort(sprintf("Epoc `%s` was not found.", store))
  }
  value
}

#' Return epoc/event store names
#'
#' @param x A `tdt_block`, `tdt_block_py`, epoc container, or compatible object.
#'
#' @return A character vector of epoc store names.
#' @export
epoc_names <- function(x) {
  if (is_tdt_block(x)) {
    return(unique(x$epocs$store))
  }
  container <- epocs(x)
  if (is.null(container)) {
    character(0)
  } else if (is.data.frame(container) && "store" %in% names(container)) {
    unique(container$store)
  } else {
    tdt_container_names(container, prefer_original = TRUE)
  }
}

#' Return one epoc/event store
#'
#' @param x A `tdt_block`, `tdt_block_py`, or compatible object.
#' @param store Epoc store name.
#'
#' @return One epoc object or tibble subset.
#' @export
epoc <- function(x, store) {
  epocs(x, store = store)
}

# Backwards-compatible internal names used by older prototype helpers.
tdt_stream_names <- stream_names
tdt_get_stream <- stream
