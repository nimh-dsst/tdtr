test_that("new_tdt_block validates materialized blocks", {
  block <- new_tdt_block(
    info = list(source = "test"),
    streams = list(
      Wav1 = list(name = "Wav1", fs = 100, data = matrix(1:20, nrow = 10, ncol = 2))
    ),
    epocs = tibble::tibble(store = "Tick", onset = 1, offset = 2, value = 1)
  )

  expect_true(is_tdt_block(block))
  expect_s3_class(block, "tdt_block")
  expect_no_error(validate_tdt_block(block))
  expect_output(print(block), "<tdt_block>")
})

test_that("new_tdt_block rejects invalid epoc tables", {
  expect_error(
    new_tdt_block(epocs = data.frame(onset = 1)),
    "missing required column"
  )
})
