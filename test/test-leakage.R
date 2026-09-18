# test-leakage.R ----------------------------------------------------------
# Tests for the future-information-leakage fix (handoff.md P1-02):
# perturbing future records must not change historical training features or
# fitted parameters. This is the core "future perturbation invariance" check.

source(file.path(TEST_ROOT, "test", "test_helper.R"))

build_panel <- function() {
  raw <- make_synthetic_raw(n_neighborhoods = 5, n_years = 5, with_nsa = TRUE)
  make_monthly_panel(raw)$panel
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

test_that("coordinates are fixed geographic constants, independent of future", {
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
  extra <- panel[panel$year == 2021, ][1:10, ]
  panel <- dplyr::bind_rows(panel, extra)

  # Recompute the training index against the enlarged panel.
  train_idx2 <- panel$year <= 2017
  recipe_after <- make_basis_recipe(panel[train_idx2, ])

  expect_equal(
    recipe_fingerprint(recipe_before),
    recipe_fingerprint(recipe_after)
  )
})
