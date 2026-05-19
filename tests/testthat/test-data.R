test_that("packaged example block is stored as raw TDT files", {
  path <- tdtr_example_block_path()
  files <- list.files(path)

  expect_true(dir.exists(path))
  expect_true(any(grepl("\\.tsq$", files, ignore.case = TRUE)))
  expect_true(any(grepl("\\.tev$", files, ignore.case = TRUE)))
  expect_true(any(grepl("\\.Tbk$", files, ignore.case = TRUE)))
})

test_that("packaged example block reads through Python tdt", {
  expect_true(tdt_available(initialize = TRUE))

  path <- tdtr_example_block_path()
  block <- read_block(path, evtype = c("epocs", "streams"), t1 = 0, t2 = 1, verbose = 0)

  expect_s3_class(block, "tdt_block_py")
  expect_equal(stream_names(block), c("_405A", "_465A", "Fi1r"))
  expect_true(all(c("Cam1", "Tick") %in% epoc_names(block)))
  expect_gt(nrow(collect_epocs(block)), 0)
})

test_that("single evtype values are passed to Python as event-type lists", {
  expect_true(tdt_available(initialize = TRUE))

  path <- tdtr_example_block_path()
  block <- read_block(path, evtype = "streams", t1 = 0, t2 = 1, verbose = 0)

  expect_equal(stream_names(block), c("_405A", "_465A", "Fi1r"))
  expect_equal(epoc_names(block), character(0))
})

test_that("profile_tdt_memory reports read and collection steps", {
  expect_true(tdt_available(initialize = TRUE))

  path <- tdtr_example_block_path()
  profile <- profile_tdt_memory(
    path,
    evtype = c("epocs", "streams"),
    t1 = 0,
    t2 = 1,
    stream = "_465A",
    verbose = 0
  )

  expect_s3_class(profile, "tbl_df")
  expect_true(all(c("read_block", "metadata_accessors", "summary", "collect_stream:_465A", "collect_epocs") %in% profile$step))
  expect_true(all(c("elapsed_sec", "r_alloc_mb", "python_tracemalloc_peak_mb") %in% names(profile)))
})
