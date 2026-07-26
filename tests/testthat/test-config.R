source(testthat::test_path("..", "..", "R", "config.R"))

write_bicycle_header <- function(path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  writeLines(
    paste(
      c(
        "date", "quarter", "day_of_week", "neighborhood",
        "bike_cost", "location", "long", "lat"
      ),
      collapse = ","
    ),
    path
  )
}

testthat::test_that("project-local bicycle data is resolved", {
  withr::local_envvar(STAT3888_BICYCLE_CSV = NA)
  root <- withr::local_tempdir()
  local_csv <- file.path(root, "data", "bicycle.csv")
  write_bicycle_header(local_csv)

  result <- resolve_bicycle_csv(root, fallback_paths = character())

  testthat::expect_equal(result, normalizePath(local_csv))
})

testthat::test_that("environment variable has highest priority", {
  root <- withr::local_tempdir()
  local_csv <- file.path(root, "data", "bicycle.csv")
  env_csv <- tempfile(fileext = ".csv")
  write_bicycle_header(local_csv)
  write_bicycle_header(env_csv)
  withr::local_envvar(STAT3888_BICYCLE_CSV = env_csv)

  result <- resolve_bicycle_csv(root, fallback_paths = character())

  testthat::expect_equal(result, normalizePath(env_csv))
})

testthat::test_that("missing data error lists checked paths", {
  withr::local_envvar(STAT3888_BICYCLE_CSV = NA)
  root <- withr::local_tempdir()

  testthat::expect_error(
    resolve_bicycle_csv(root, fallback_paths = character()),
    "Checked paths:.*data/bicycle.csv.*STAT3888_BICYCLE_CSV"
  )
})

testthat::test_that("project paths are absolute and the source exists", {
  p <- project_paths()
  testthat::expect_true(file.exists(p$source_csv))
  testthat::expect_true(startsWith(p$source_csv, "/"))
  testthat::expect_match(
    p$pdf_file,
    "STAT3888_自行车盗窃时空基函数回归_完整项目手册.pdf$"
  )
})
