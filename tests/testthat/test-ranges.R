test_that("as_ranges normalizes common range shapes", {
  expect_equal(as_ranges(c(1, 2)), matrix(c(1, 2), nrow = 2))

  from_rows <- as_ranges(data.frame(start = c(1, 3), stop = c(2, 4)))
  expect_equal(dim(from_rows), c(2, 2))
  expect_equal(from_rows[, 1], c(1, 2))
  expect_equal(from_rows[, 2], c(3, 4))

  already_python_shape <- matrix(c(1, 2, 3, 4), nrow = 2)
  expect_equal(as_ranges(already_python_shape), already_python_shape)
})

test_that("ranges_from_epocs builds onset-relative windows", {
  ep <- tibble::tibble(onset = c(1, 3))
  ranges <- ranges_from_epocs(ep, pre = -0.5, post = 1)

  expect_equal(ranges, matrix(c(0.5, 2, 2.5, 4), nrow = 2))
})
