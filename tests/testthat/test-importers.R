test_that("read_stream_csv imports samples by channels", {
  path <- tempfile(fileext = ".csv")
  utils::write.csv(data.frame(ch1 = 1:3, ch2 = 4:6), path, row.names = FALSE)

  stream <- read_stream_csv(path, fs = 100, name = "Wav1")

  expect_equal(stream$name, "Wav1")
  expect_equal(dim(stream$data), c(3, 2))
  expect_equal(stream$channels, 1:2)
})

test_that("read_epocs_csv requires standard event columns", {
  path <- tempfile(fileext = ".csv")
  utils::write.csv(
    data.frame(store = "Tick", onset = 1, offset = 2, value = 3),
    path,
    row.names = FALSE
  )

  ep <- read_epocs_csv(path)

  expect_s3_class(ep, "tbl_df")
  expect_equal(names(ep), c("store", "onset", "offset", "value"))
})
