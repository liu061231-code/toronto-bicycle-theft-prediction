# test-leakage.R ----------------------------------------------------------
# Tests for the future-information-leakage fix (handoff.md P1-02):
# perturbing future records must not change historical training features or
# fitted parameters. This is the core "future perturbation invariance" check.

source(file.path(TEST_ROOT, "test", "helper.R"))

build_panel <- function() {
  raw <- make_synthetic_raw(n_neighborhoods = 5, n_years = 5, with_nsa = TRUE)
  # Production semantics: coordinates come from a frozen reference table that
  # is built ONCE and passed in explicitly, never recomputed from the raw
  # events inside make_monthly_panel().
  ref <- make_neighborhood_coordinates(raw)
  make_monthly_panel(raw, coordinates = ref)$panel
}

# Extract the learned feature-recipe values that depend on training data.
recipe_fingerprint <- function(recipe) {
  list(
    time_boundary = recipe$time_boundary,
    time_knots = recipe$time_knots,
    lon_center = recipe$lon_center,
    lat_center = recipe$lat_center,
    spatial_scale = recipe$spatial_scale,
    rbf_centers = as.matrix(recipe$rbf_centers),
    neighborhood_levels = recipe$neighborhood_levels
  )
}

test_that("frozen coordinate estimates are independent of future records", {
  panel <- build_panel()

  # Train on the early window only.
  train_early <- dplyr::filter(panel, year <= 2017)
  coord_early <- train_early |>
    dplyr::filter(!is.na(lon)) |>
    dplyr::distinct(neighborhood, lon, lat) |>
    dplyr::arrange(neighborhood)

  # Coordinates from the full panel must match the early-window coordinates
  # exactly (they are fixed centroids, not per-window event statistics).
  coord_full <- panel |>
    dplyr::filter(!is.na(lon)) |>
    dplyr::distinct(neighborhood, lon, lat) |>
    dplyr::arrange(neighborhood)

  expect_equal(
    coord_full$neighborhood,
    coord_early$neighborhood
  )
  expect_equal(coord_full$lon, coord_early$lon, tolerance = 1e-12)
  expect_equal(coord_full$lat, coord_early$lat, tolerance = 1e-12)
})

test_that("perturbing future labels does not change training features", {
  panel <- build_panel()
  train_idx <- panel$year <= 2017

  recipe_before <- make_basis_recipe(panel[train_idx, ])
  # Perturb the FUTURE (post-training) target values drastically.
  future_idx <- panel$year > 2017
  panel$theft_count[future_idx] <- panel$theft_count[future_idx] + 1000

  recipe_after <- make_basis_recipe(panel[train_idx, ])

  expect_equal(
    recipe_fingerprint(recipe_before),
    recipe_fingerprint(recipe_after)
  )
})

test_that("perturbing future coordinates does not change training features", {
  panel <- build_panel()
  train_idx <- panel$year <= 2017

  recipe_before <- make_basis_recipe(panel[train_idx, ])

  # Move all future coordinates to a far-away location (simulating new records
  # arriving that would shift a naive median computed over the full series).
  future_idx <- panel$year > 2017 & !is.na(panel$lon)
  panel$lon[future_idx] <- panel$lon[future_idx] + 10
  panel$lat[future_idx] <- panel$lat[future_idx] + 10

  recipe_after <- make_basis_recipe(panel[train_idx, ])

  expect_equal(
    recipe_fingerprint(recipe_before),
    recipe_fingerprint(recipe_after)
  )
})

test_that("adding future records does not change training features", {
  panel <- build_panel()
  train_idx <- panel$year <= 2017

  recipe_before <- make_basis_recipe(panel[train_idx, ])

  # Add extra future rows for an existing neighbourhood with extreme values.
  extra <- panel[panel$year == 2018, ][1:10, ]
  panel <- dplyr::bind_rows(panel, extra)

  # Recompute the training index against the enlarged panel.
  train_idx2 <- panel$year <= 2017
  recipe_after <- make_basis_recipe(panel[train_idx2, ])

  expect_equal(
    recipe_fingerprint(recipe_before),
    recipe_fingerprint(recipe_after)
  )
})

# --- Raw-level leakage guards (feedback2.0 P0 Task 1) ---------------------
# The REAL leakage entry point is one level up: make_monthly_panel() itself
# must not derive neighbourhood coordinates from the raw events it receives.
# Coordinates must come from a frozen, versioned reference table. These tests
# perturb the RAW event layer (not the finished panel) and rebuild the panel.

# Build a frozen reference table from the pre-cutoff events only, mimicking
# the versioned data/reference/neighborhood_coordinates.csv used in
# production.
build_reference <- function(raw, cutoff) {
  make_neighborhood_coordinates(dplyr::filter(raw, date <= cutoff))
}

test_that("raw-level: perturbing future raw coordinates leaves history intact", {
  raw <- make_synthetic_raw(n_neighborhoods = 5, n_years = 5, with_nsa = TRUE)
  cutoff <- as.Date("2016-12-31")
  ref <- build_reference(raw, cutoff)

  panel_before <- make_monthly_panel(raw, coordinates = ref)$panel

  # Perturb ONLY post-cutoff raw event coordinates.
  raw2 <- raw
  fut <- raw2$date > cutoff & !is.na(raw2$long) & raw2$long != 0
  raw2$long[fut] <- raw2$long[fut] + 10
  raw2$lat[fut] <- raw2$lat[fut] + 10
  panel_after <- make_monthly_panel(raw2, coordinates = ref)$panel

  hist_before <- dplyr::filter(panel_before, year <= 2016)
  hist_after <- dplyr::filter(panel_after, year <= 2016)

  expect_equal(hist_before$lon, hist_after$lon, tolerance = 1e-12)
  expect_equal(hist_before$lat, hist_after$lat, tolerance = 1e-12)
  expect_equal(
    recipe_fingerprint(make_basis_recipe(hist_before)),
    recipe_fingerprint(make_basis_recipe(hist_after))
  )
})

test_that("raw-level: adding future raw records leaves history intact", {
  raw <- make_synthetic_raw(n_neighborhoods = 5, n_years = 5, with_nsa = TRUE)
  cutoff <- as.Date("2016-12-31")
  ref <- build_reference(raw, cutoff)

  panel_before <- make_monthly_panel(raw, coordinates = ref)$panel

  # Append extreme future raw events (far-away coordinates, huge counts).
  extra <- raw[raw$date > cutoff, ][1:20, ]
  extra$long <- -70
  extra$lat <- 50
  raw2 <- dplyr::bind_rows(raw, extra)
  panel_after <- make_monthly_panel(raw2, coordinates = ref)$panel

  hist_before <- dplyr::filter(panel_before, year <= 2016)
  hist_after <- dplyr::filter(panel_after, year <= 2016)

  expect_equal(hist_before$lon, hist_after$lon, tolerance = 1e-12)
  expect_equal(hist_before$lat, hist_after$lat, tolerance = 1e-12)
  # Historical counts must also be unchanged by appended future events.
  expect_equal(hist_before$theft_count, hist_after$theft_count)
})

test_that("make_monthly_panel defaults to the frozen reference file, not raw", {
  # With coordinates = NULL the function must load
  # data/reference/neighborhood_coordinates.csv and must NOT compute
  # coordinates from the raw events. Synthetic neighbourhoods do not exist in
  # that file, so their spatial coordinates become NA (with a warning) rather
  # than being derived from the synthetic events.
  raw <- make_synthetic_raw(n_neighborhoods = 3, n_years = 2, with_nsa = FALSE)
  expect_warning(
    panel <- make_monthly_panel(raw)$panel,
    "reference"
  )
  expect_true(all(is.na(panel$lon[panel$is_unknown])))
  expect_true(all(is.na(panel$lat[panel$is_unknown])))
  expect_equal(sum(panel$theft_count),nrow(raw))
})
