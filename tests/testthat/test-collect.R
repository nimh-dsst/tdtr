test_that("collect_stream returns matrices, vectors, and metadata lists", {
  block <- new_tdt_block(
    streams = list(
      Wav1 = list(name = "Wav1", fs = 100, data = matrix(seq_len(20), nrow = 10, ncol = 2), channels = 1:2),
      Wav2 = list(name = "Wav2", fs = 50, data = seq_len(5), channels = 1)
    ),
    epocs = tibble::tibble(store = character(), onset = numeric(), offset = numeric(), value = numeric())
  )

  expect_equal(dim(collect_stream(block, "Wav1")), c(10, 2))
  expect_equal(collect_stream(block, "Wav2", as = "numeric"), as.numeric(seq_len(5)))

  listed <- collect_stream(block, "Wav1", as = "list", include_time = TRUE)
  expect_equal(listed$time[1:3], c(0, 0.01, 0.02))
  expect_equal(dim(listed$data), c(10, 2))
})

test_that("collect_epocs returns stacked tibbles", {
  block <- new_tdt_block(
    streams = list(),
    epocs = tibble::tibble(
      store = c("Tick", "Tick", "Stim"),
      onset = c(1, 3, 5),
      offset = c(1.5, 3.5, 6),
      value = c(1, 2, 1)
    )
  )

  all_epocs <- collect_epocs(block)
  tick <- collect_epocs(block, store = "Tick")

  expect_s3_class(all_epocs, "tbl_df")
  expect_equal(nrow(all_epocs), 3)
  expect_equal(nrow(tick), 2)
})

test_that("collect_block materializes compatible Python wrappers", {
  py_like <- list(
    info = list(blockname = "fixture"),
    streams = list(
      Wav1 = list(name = "Wav1", fs = 100, data = matrix(seq_len(20), nrow = 2, ncol = 10), channel = 1:2)
    ),
    epocs = list(
      Tick = list(name = "Tick", onset = c(1, 2), offset = c(1.5, 2.5), data = c(3, 4))
    )
  )
  wrapped <- structure(list(py = py_like, path = "/tmp/block", args = list()), class = c("tdt_block_py", "tdt_py"))

  block <- collect_block(wrapped, quiet = TRUE)

  expect_s3_class(block, "tdt_block")
  expect_equal(dim(block$streams$Wav1$data), c(10, 2))
  expect_equal(block$epocs$value, c(3, 4))
})
