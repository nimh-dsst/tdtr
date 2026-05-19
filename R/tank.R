#' Parse metadata from a TDT tank directory name
#'
#' Parses tank names that follow a subject-date-time convention, for example
#' `12_M1-250103-001644`, `12_M1_2-250103-001644`, and
#' `12_M1_F2-250103-001644`.
#'
#' @param tank_dir Path to a TDT tank/block directory.
#' @param tz Time zone used for the parsed datetime. Defaults to `"UTC"`.
#'
#' @return A list with `tank_name`, `cage_number`, `num_subjects`,
#'   `subject_ids`, and `tank_datetime`.
#' @noRd
tdt_parse_tank_name <- function(tank_dir, tz = "UTC") {
  tdt_check_dir(as.character(tank_dir), "tank_dir")

  tank_name <- tools::file_path_sans_ext(basename(as.character(tank_dir)))
  split_list <- strsplit(tank_name, "-", fixed = TRUE)[[1]]
  if (length(split_list) != 3) {
    rlang::abort(sprintf("Invalid tank directory name: %s.", tank_name))
  }

  subject_data <- split_list[[1]]
  cage_number <- strsplit(subject_data, "_", fixed = TRUE)[[1]][[1]]

  tank_dt <- as.POSIXct(
    paste(split_list[[2]], split_list[[3]], sep = "-"),
    format = "%y%m%d-%H%M%S",
    tz = tz
  )
  if (is.na(tank_dt)) {
    rlang::abort(sprintf("Invalid tank directory datetime: %s.", tank_name))
  }

  subject_ids <- character(0)
  if (grepl("[MF]\\d+_[MF]\\d+", tank_name)) {
    subjects_group <- regmatches(tank_name, regexpr("[MF]\\d+_[MF]\\d+", tank_name))
    subject_ids <- strsplit(subjects_group, "_", fixed = TRUE)[[1]]
  } else if (grepl("[MF]\\d+_\\d+", tank_name)) {
    subjects_group <- regmatches(tank_name, regexpr("[MF]\\d+_\\d+", tank_name))
    sex <- substr(subjects_group, 1, 1)
    parts <- strsplit(subjects_group, "_", fixed = TRUE)[[1]]
    subject_ids <- c(parts[[1]], paste0(sex, parts[[2]]))
  } else if (grepl("[MF]\\d+-", tank_name)) {
    subjects_group <- regmatches(tank_name, regexpr("[MF]\\d+", tank_name))
    subject_ids <- subjects_group
  } else {
    rlang::abort(sprintf("Cannot parse subject ids from tank name: %s.", tank_name))
  }

  subject_ids <- paste0(cage_number, "_", subject_ids)

  list(
    tank_name = tank_name,
    cage_number = cage_number,
    num_subjects = length(subject_ids),
    subject_ids = subject_ids,
    tank_datetime = tank_dt
  )
}

#' Parse multiple TDT tank directory names
#'
#' @param tank_dirs Character vector of tank directory paths.
#' @param tz Time zone used for parsed datetimes.
#'
#' @return A tibble with one row per tank.
#' @noRd
tdt_parse_tank_names <- function(tank_dirs, tz = "UTC") {
  if (!is.character(tank_dirs)) {
    rlang::abort("`tank_dirs` must be a character vector.")
  }

  rows <- lapply(tank_dirs, function(path) {
    info <- tdt_parse_tank_name(path, tz = tz)
    tibble::tibble(
      tank_dir = path,
      tank_name = info$tank_name,
      cage_number = info$cage_number,
      num_subjects = info$num_subjects,
      subject_ids = list(info$subject_ids),
      tank_datetime = info$tank_datetime
    )
  })

  do.call(rbind, rows)
}
