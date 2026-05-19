test_that("tdt availability diagnostics return stable shapes", {
  expect_type(tdt_available(initialize = FALSE), "logical")

  cfg <- tdt_config()
  expect_true(all(c("reticulate", "python_available", "tdt_available", "requirement") %in% names(cfg)))
  expect_equal(cfg$requirement, "tdt>=0.7.3")
})
