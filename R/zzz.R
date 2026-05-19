.tdtr_env <- new.env(parent = emptyenv())

.onLoad <- function(libname, pkgname) {
  if (requireNamespace("reticulate", quietly = TRUE)) {
    tryCatch(
      reticulate::py_require("tdt>=0.7.3"),
      error = function(e) {
        .tdtr_env$py_require_error <- e
      }
    )

    .tdtr_env$tdt <- tryCatch(
      reticulate::import("tdt", delay_load = TRUE, convert = FALSE),
      error = function(e) {
        .tdtr_env$import_error <- e
        NULL
      }
    )
  }
}
