mock_stream <- function(name, data = seq_len(256)) {
  list(name = name, fs = 128, channel = 1, data = data)
}

test_that("tdt_write_stream_set writes metadata and csv outputs", {
  subject_dir <- withr::local_tempdir()
  block <- list(
    info = list(blockname = "12_M1-250103-001644"),
    streams = list(
      Wav1 = mock_stream("Wav1"),
      X405 = mock_stream("X405"),
      X470 = mock_stream("X470")
    )
  )

  result <- tdt_write_stream_set(
    block = block,
    subject_dir = subject_dir,
    streams = list(ttl_stream = "Wav1", iso_stream = "X405", exp_stream = "X470"),
    metadata = list(subject_id = "12_M1", tank_dir = "/tmp/tank", num_subjects_in_tank = 1),
    write_pickle = FALSE
  )

  expect_equal(result$status, "extracted")
  expect_true(file.exists(file.path(subject_dir, "streams.json")))
  expect_true(file.exists(file.path(subject_dir, "ttl_stream.csv")))

  parsed <- jsonlite::fromJSON(file.path(subject_dir, "streams.json"))
  expect_equal(parsed$ttl_stream, "Wav1")
  expect_equal(parsed$subject_id, "12_M1")
})

test_that("tdt_extract_tank can use a pre-read R block", {
  root <- withr::local_tempdir()
  tank <- file.path(root, "12_M1-250103-001644")
  dir.create(tank)
  output <- file.path(root, "Analysis")

  block <- list(
    info = list(blockname = "12_M1-250103-001644"),
    streams = list(
      Wav1 = mock_stream("Wav1"),
      X405 = mock_stream("X405"),
      X470 = mock_stream("X470")
    )
  )

  result <- tdt_extract_tank(
    tank_dir = tank,
    output_dir = output,
    block = block,
    stream_map = list(ttl_stream = "Wav1", iso_stream = "X405", exp_stream = "X470"),
    write_pickle = FALSE
  )

  expect_equal(result$status, "extracted")
  expect_true(file.exists(file.path(output, "12_M1_20250103-001644", "streams.json")))
})
