# test-data-quality.R -----------------------------------------------------
# Tests for the data-correctness guarantees: NSA handling, coordinate
# validity, and the monthly panel's unknown-area behaviour.
#
# Note (feedback2.0 P0 Task 1): make_monthly_panel() no longer derives
# coordinates from raw events. Tests pass an explicit synthetic reference
# table, mirroring the frozen data/reference/neighborhood_coordinates.csv
# used in production.

source(file.path(TEST_ROOT, "test", "helper.R"))

# Build a panel from synthetic raw with an explicit synthetic reference
# table (the test-fixture analogue of the frozen production reference).
make_test_panel <- function(raw) {
  make_monthly_panel(raw, coordinates = make_neighborhood_coordinates(raw))
}

test_that("NSA records are flagged unknown and carry NA coordinates", {
  raw <- make_synthetic_raw(n_neighborhoods = 3, n_years = 3, with_nsa = TRUE)
  prepared <- make_test_panel(raw)
  panel <- prepared$panel

  nsa <- dplyr::filter(panel, neighborhood == "NSA")
  expect_true(nrow(nsa) > 0)
  # NSA must be flagged unknown and have no spatial coordinates.
  expect_true(all(nsa$is_unknown))
  expect_true(all(is.na(nsa$lon)))
  expect_true(all(is.na(nsa$lat)))
})

test_that("NSA is excluded from the neighbourhood coordinate table", {
  raw <- make_synthetic_raw(n_neighborhoods = 4, n_years = 3, with_nsa = TRUE)
  prepared <- make_test_panel(raw)
  coords <- prepared$coordinates

  expect_false("NSA" %in% coords$neighborhood)
  # Only real neighbourhoods with valid coordinates remain.
  expect_equal(nrow(coords), 4L)
})

test_that("zero-coordinate records do not enter the coordinate table", {
  # Build a raw set where one named area has a zero coordinate (simulating a
  # missing/encoded-as-zero coordinate) to ensure it is dropped too.
  raw <- make_synthetic_raw(n_neighborhoods = 3, n_years = 2, with_nsa = FALSE)
  raw$long[raw$neighborhood == "Area1"] <- 0
  raw$lat[raw$neighborhood == "Area1"] <- 0
  expect_warning(prepared <- make_test_panel(raw), "missing from the coordinate")
  expect_false("Area1" %in% prepared$coordinates$neighborhood)
})

test_that("spatial scale excludes NSA and reflects real geographic extent", {
  raw <- make_synthetic_raw(n_neighborhoods = 5, n_years = 4, with_nsa = TRUE)
  prepared <- make_test_panel(raw)
  panel <- prepared$panel
  train <- dplyr::filter(panel, year <= 2016)
  recipe <- make_basis_recipe(train)

  # Spatial scale must be a small, finite positive number (not inflated by a
  # synthetic (0,0) point, which would push it toward ~40 degrees).
  expect_true(is.finite(recipe$spatial_scale))
  expect_true(recipe$spatial_scale > 0)
  expect_true(recipe$spatial_scale < 1)
})

test_that("design matrix has no NA and NSA rows carry zero spatial signal", {
  raw <- make_synthetic_raw(n_neighborhoods = 5, n_years = 4, with_nsa = TRUE)
  prepared <- make_test_panel(raw)
  panel <- prepared$panel
  train <- dplyr::filter(panel, year <= 2016)
  recipe <- make_basis_recipe(train)
  X <- make_design_matrix(panel, recipe)

  expect_false(anyNA(X))
  expect_equal(nrow(X), nrow(panel))

  nsa_idx <- which(panel$neighborhood == "NSA")
  rbf_cols <- grep("^space_rbf_", colnames(X))
  area_cols <- grep("^area_", colnames(X))
  expect_true(all(X[nsa_idx, rbf_cols] == 0))
  expect_true(all(X[nsa_idx, area_cols] == 0))
})

test_that("design matrix has one row per input row (no dropped NSA rows)", {
  raw <- make_synthetic_raw(n_neighborhoods = 3, n_years = 2, with_nsa = TRUE)
  prepared <- make_test_panel(raw)
  panel <- prepared$panel
  recipe <- make_basis_recipe(panel)
  X <- make_design_matrix(panel, recipe)
  expect_equal(nrow(X), nrow(panel))
})

test_that("the production reference table covers all non-NSA neighbourhoods", {
  # Integration guard: data/reference/neighborhood_coordinates.csv must exist
  # and cover every non-NSA neighbourhood in the real raw data, with sane
  # Toronto coordinates.
  paths <- project_paths(file.path(TEST_ROOT))
  skip_if_not(file.exists(paths$raw_data), "Local snapshot not redistributed")
  ref <- load_reference_coordinates(paths$reference_coordinates)
  raw <- read_bicycle(paths$raw_data)
  real_nb <- setdiff(unique(raw$neighborhood), "NSA")

  expect_true(all(real_nb %in% ref$neighborhood))
  expect_equal(anyDuplicated(ref$neighborhood), 0L)
  expect_true(all(ref$lon > -80.5 & ref$lon < -78.5))
  expect_true(all(ref$lat > 43.0 & ref$lat < 44.5))
  # NSA must never appear in the reference table.
  expect_false("NSA" %in% ref$neighborhood)
})
