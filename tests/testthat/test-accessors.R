test_block <- function() {
  new_tdt_block(
    info = list(source = "fixture", block_path = "/tmp/block"),
    streams = list(
      Wav1 = list(name = "Wav1", fs = 100, data = matrix(seq_len(20), nrow = 10, ncol = 2), channels = 1:2),
      Wav2 = list(name = "Wav2", fs = 50, data = seq_len(5), channels = 1)
    ),
    epocs = tibble::tibble(
      store = c("Tick", "Tick", "Stim"),
      onset = c(1, 3, 5),
      offset = c(1.5, 3.5, 6),
      value = c(1, 2, 1)
    )
  )
}

test_that("accessors expose materialized block components", {
  block <- test_block()

  expect_equal(block_info(block)$source, "fixture")
  expect_equal(stream_names(block), c("Wav1", "Wav2"))
  expect_equal(stream(block, "Wav1")$fs, 100)
  expect_equal(epoc_names(block), c("Tick", "Stim"))
  expect_equal(nrow(epoc(block, "Tick")), 2)
})

test_that("Python wrapper accessors work with compatible structures without collecting", {
  wrapped <- structure(
    list(py = unclass(test_block()), path = "/tmp/block", args = list()),
    class = c("tdt_block_py", "tdt_py")
  )

  expect_equal(stream_names(wrapped), c("Wav1", "Wav2"))
  expect_equal(epoc_names(wrapped), c("Tick", "Stim"))
  expect_output(print(wrapped), "<tdt_block_py>")
})
