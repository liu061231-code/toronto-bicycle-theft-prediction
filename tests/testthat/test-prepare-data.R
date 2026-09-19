source(testthat::test_path("..", "..", "R", "config.R"))
source(testthat::test_path("..", "..", "R", "01_prepare_data.R"))

p <- project_paths()
raw <- read_bicycle(p$source_csv)
result <- make_monthly_panel(raw)

testthat::test_that("raw data has the documented grain and range", {
  testthat::expect_equal(nrow(raw), 31833)
  testthat::expect_equal(length(unique(raw$neighborhood)), 140)
  testthat::expect_equal(
    range(raw$date),
    as.Date(c("2014-01-01", "2023-12-31"))
  )
})

testthat::test_that("neighbourhood coordinates are static source attributes", {
  coordinate_counts <- raw |>
    dplyr::distinct(neighborhood, long, lat) |>
    dplyr::count(neighborhood, name = "coordinate_pairs")
  testthat::expect_true(all(coordinate_counts$coordinate_pairs == 1L))

  changing_coordinates <- raw
  changing_coordinates$long[1] <- changing_coordinates$long[1] + 0.01
  testthat::expect_error(
    make_monthly_panel(changing_coordinates),
    "Coordinates must be static within neighbourhood"
  )
})

testthat::test_that("monthly panel is complete", {
  panel <- result$panel
  testthat::expect_equal(nrow(panel), 140 * 120)
  testthat::expect_equal(length(unique(panel$month)), 120)
  testthat::expect_equal(length(unique(panel$neighborhood)), 140)
  testthat::expect_false(anyNA(panel$theft_count))
  testthat::expect_true(all(panel$theft_count >= 0))
})

testthat::test_that("derived quarters expose source-field mismatch", {
  audit <- audit_bicycle(raw)
  mismatch <- audit$value[audit$metric == "quarter_mismatch_rows"]
  testthat::expect_equal(mismatch, 15751)
})
