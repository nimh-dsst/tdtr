#' Locate the packaged TDT example block
#'
#' `tdtr` includes a small raw TDT block from the official TDT example data so
#' examples, tests, and vignettes can exercise the reticulate-backed reader.
#' The files are stored in the same block layout used by TDT, under
#' `inst/extdata`.
#'
#' @param mustWork If `TRUE`, error when the example block is not available.
#'
#' @return A single path to the packaged `Subject1-211115-094936` block.
#' @export
tdtr_example_block_path <- function(mustWork = TRUE) {
  path <- system.file(
    "extdata",
    "Subject1-211115-094936",
    package = "tdtr",
    mustWork = mustWork
  )

  if (isTRUE(mustWork) && !nzchar(path)) {
    rlang::abort("The packaged TDT example block could not be found.")
  }

  path
}
