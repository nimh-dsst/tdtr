test_that("tdt_discover_tanks finds tank directories from tsq files", {
  root <- withr::local_tempdir()
  tank <- file.path(root, "Photometry", "Cohort_A", "TDT Binaries", "12_M1-250103-001644")
  dir.create(tank, recursive = TRUE)
  file.create(file.path(tank, "block.tsq"))
  jsonlite::write_json(list(Reason = "test"), file.path(tank, "DO_NOT_USE.json"))

  found <- tdt_discover_tanks(root)

  expect_equal(nrow(found), 1)
  expect_true(found$do_not_use)
  expect_equal(found$tank_name, "12_M1-250103-001644")
})

test_that("tdt_completed_tanks returns only fully extracted tanks", {
  root <- withr::local_tempdir()
  analysis <- file.path(root, "Photometry", "Cohort_A", "Analysis")
  dir.create(file.path(analysis, "12_M1_20250103-001644"), recursive = TRUE)
  dir.create(file.path(analysis, "12_M2_20250103-001644"), recursive = TRUE)

  tank_dir <- "/tmp/12_M1_2-250103-001644"
  jsonlite::write_json(
    list(tank_dir = tank_dir, num_subjects_in_tank = 2, subject_id = "12_M1"),
    file.path(analysis, "12_M1_20250103-001644", "streams.json"),
    auto_unbox = TRUE
  )
  expect_equal(tdt_completed_tanks(root, cohort = "Cohort_A"), character(0))

  jsonlite::write_json(
    list(tank_dir = tank_dir, num_subjects_in_tank = 2, subject_id = "12_M2"),
    file.path(analysis, "12_M2_20250103-001644", "streams.json"),
    auto_unbox = TRUE
  )
  expect_equal(tdt_completed_tanks(root, cohort = "Cohort_A"), tank_dir)
})
