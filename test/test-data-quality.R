# test-data-quality.R -----------------------------------------------------
# Tests for the P1 data-correctness fixes: NSA handling, coordinate validity,
# and the monthly panel's unknown-area behaviour.

source(file.path(TEST_ROOT, "test", "test_helper.R"))

test_that("NSA records are flagged unknown and carry NA coordinates", {
  raw <- make_synthetic_raw(n_neighborhoods = 3, n_years = 3, with_nsa = TRUE)
  prepared <- make_monthly_panel(raw)
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
  prepared <- make_monthly_panel(raw)
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
  prepared <- make_monthly_panel(raw)
  expect_false("Area1" %in% prepared$coordinates$neighborhood)
})

test_that("spatial scale excludes NSA and reflects real geographic extent", {
  raw <- make_synthetic_raw(n_neighborhoods = 5, n_years = 4, with_nsa = TRUE)
  prepared <- make_monthly_panel(raw)
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
  prepared <- make_monthly_panel(raw)
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
  prepared <- make_monthly_panel(raw)
  panel <- prepared$panel
  recipe <- make_basis_recipe(panel)
  X <- make_design_matrix(panel, recipe)
  expect_equal(nrow(X), nrow(panel))
})
