test_that("tdt_calc_timepoints returns row-start timepoints", {
  expect_equal(tdt_calc_timepoints(256, fs = 128, num_of_points = 128), c(0, 1))
})

test_that("tdt_format_stream formats a single-channel R stream", {
  stream <- list(
    name = "Wav1",
    fs = 128,
    channel = 1,
    data = seq_len(256)
  )

  result <- tdt_format_stream(
    data_info = list(blockname = "12_M1-250103-001644"),
    stream = stream,
    num_of_points = 128
  )

  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 2)
  expect_equal(names(result)[seq_len(6)], c("BLOCK", "EVENT", "TIME", "CHAN", "Sampling_Freq", "NumOfPoints"))
  expect_equal(result$BLOCK, rep("12_M1-250103-001644", 2))
  expect_equal(result$EVENT, rep("Wav1", 2))
  expect_equal(result$TIME, c(0, 1))
  expect_equal(result$D0, c(1, 129))
})

test_that("tdt_validate_stream_lengths detects mismatched stream lengths", {
  streams <- list(
    ttl_stream = list(data = 1:10),
    iso_stream = list(data = 1:10),
    exp_stream = list(data = 1:9)
  )

  expect_error(tdt_validate_stream_lengths(streams), class = "tdt_stream_length_mismatch")
})
