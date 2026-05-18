test_that("tdt_parse_tank_name parses single subject tanks", {
  info <- tdt_parse_tank_name("/tmp/12_M1-250103-001644")

  expect_equal(info$tank_name, "12_M1-250103-001644")
  expect_equal(info$cage_number, "12")
  expect_equal(info$num_subjects, 1)
  expect_equal(info$subject_ids, "12_M1")
  expect_equal(format(info$tank_datetime, "%Y%m%d-%H%M%S", tz = "UTC"), "20250103-001644")
})

test_that("tdt_parse_tank_name parses same-sex dual subject tanks", {
  info <- tdt_parse_tank_name("/tmp/12_M1_2-250103-001644")

  expect_equal(info$num_subjects, 2)
  expect_equal(info$subject_ids, c("12_M1", "12_M2"))
})

test_that("tdt_parse_tank_name parses mixed-sex dual subject tanks", {
  info <- tdt_parse_tank_name("/tmp/12_M1_F2-250103-001644")

  expect_equal(info$num_subjects, 2)
  expect_equal(info$subject_ids, c("12_M1", "12_F2"))
})

test_that("tdt_parse_tank_name rejects invalid tank names", {
  expect_error(tdt_parse_tank_name("/tmp/not-a-tank"), "Invalid tank directory")
})
