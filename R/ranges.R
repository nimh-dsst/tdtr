#' Convert time windows to Python `tdt` ranges
#'
#' Python `tdt` expects a `2 x N` numeric matrix where row 1 is start time and
#' row 2 is stop time.
#'
#' @param ranges A numeric length-2 vector, a `2 x N` matrix, an `N x 2` matrix,
#'   or a data frame with `start` and `stop` columns.
#'
#' @return A numeric `2 x N` matrix.
#' @export
as_ranges <- function(ranges) {
  if (is.null(ranges)) {
    return(NULL)
  }

  if (is.data.frame(ranges)) {
    if (all(c("start", "stop") %in% names(ranges))) {
      mat <- as.matrix(ranges[, c("start", "stop"), drop = FALSE])
    } else if (ncol(ranges) >= 2) {
      mat <- as.matrix(ranges[, seq_len(2), drop = FALSE])
    } else {
      rlang::abort("`ranges` data frames must have at least two columns.")
    }
    storage.mode(mat) <- "double"
    mat <- t(mat)
  } else if (is.numeric(ranges) && is.null(dim(ranges))) {
    if (length(ranges) != 2) {
      rlang::abort("Numeric vector `ranges` must have length 2.")
    }
    mat <- matrix(as.numeric(ranges), nrow = 2)
  } else if (is.matrix(ranges)) {
    mat <- ranges
    storage.mode(mat) <- "double"
    if (nrow(mat) == 2) {
      mat <- mat
    } else if (ncol(mat) == 2) {
      mat <- t(mat)
    } else {
      rlang::abort("Matrix `ranges` must be `2 x N` or `N x 2`.")
    }
  } else {
    rlang::abort("`ranges` must be a numeric vector, matrix, or data frame.")
  }

  dimnames(mat) <- NULL

  if (nrow(mat) != 2) {
    rlang::abort("`ranges` must resolve to a `2 x N` matrix.")
  }
  if (!is.numeric(mat) || any(is.na(mat)) || any(!is.finite(mat[1, ]))) {
    rlang::abort("`ranges` must contain finite numeric start times and non-missing stop times.")
  }
  if (any(mat[2, ] <= mat[1, ])) {
    rlang::abort("Each range stop time must be greater than its start time.")
  }

  mat
}

#' Build time ranges from epoc/event onsets
#'
#' @param epocs A data frame with an onset column.
#' @param pre Start offset in seconds relative to onset. Use a negative value for
#'   time before onset.
#' @param post Stop offset in seconds relative to onset.
#' @param onset_col Name of the onset column.
#' @param drop_negative If `TRUE`, drop ranges with negative start times.
#'
#' @return A numeric `2 x N` matrix.
#' @export
ranges_from_epocs <- function(epocs, pre, post, onset_col = "onset", drop_negative = TRUE) {
  if (!is.data.frame(epocs)) {
    rlang::abort("`epocs` must be a data frame.")
  }
  if (!(onset_col %in% names(epocs))) {
    rlang::abort(sprintf("`epocs` does not contain onset column `%s`.", onset_col))
  }
  if (!is.numeric(pre) || length(pre) != 1 || is.na(pre)) {
    rlang::abort("`pre` must be a single numeric offset.")
  }
  if (!is.numeric(post) || length(post) != 1 || is.na(post)) {
    rlang::abort("`post` must be a single numeric offset.")
  }
  if (post <= pre) {
    rlang::abort("`post` must be greater than `pre`.")
  }

  onset <- as.numeric(epocs[[onset_col]])
  starts <- onset + pre
  stops <- onset + post
  keep <- !is.na(starts) & !is.na(stops)
  if (isTRUE(drop_negative)) {
    keep <- keep & starts >= 0
  }

  as_ranges(data.frame(start = starts[keep], stop = stops[keep]))
}
