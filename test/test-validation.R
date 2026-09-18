# test-validation.R -------------------------------------------------------
# Tests for the expanding-window CV fold builder and time-aware splitting,
# including the relative-time-start fix and short-series boundary behaviour.

source(file.path(TEST_ROOT, "test", "test_helper.R"))

make_panel_subset <- function(start_index, n_months) {
  tibble::tibble(
    time_index = seq(start_index, start_index + n_months - 1L),
    theft_count = rpois(n_months, lambda = 1)
  )
}

test_that("expanding folds use relative months, independent of start index", {
  # A series starting at index 1 with 120 months.
  d1 <- make_panel_subset(1L, 120L)
  f1 <- make_expanding_folds(d1, initial_months = 60, step_months = 12,
                             horizon_months = 12)
  # A series starting at index 25 with the same length must yield the SAME
  # number of folds and the SAME fold sizes (the bug produced a short first
  # fold of 36 months instead of 60).
  d2 <- make_panel_subset(25L, 120L)
  f2 <- make_expanding_folds(d2, initial_months = 60, step_months = 12,
                             horizon_months = 12)

  expect_equal(length(f1), length(f2))
  expect_equal(
    vapply(f1, function(f) length(f$train), integer(1)),
    vapply(f2, function(f) length(f$train), integer(1))
  )
  expect_equal(
    vapply(f1, function(f) length(f$test), integer(1)),
    vapply(f2, function(f) length(f$test), integer(1))
  )
})

test_that("first fold trains on exactly initial_months", {
  d <- make_panel_subset(1L, 120L)
  folds <- make_expanding_folds(d, initial_months = 60, step_months = 12,
                                horizon_months = 12)
  expect_equal(length(folds[[1]]$train), 60L)
})

test_that("short series yields no folds instead of erroring", {
  # A series shorter than the initial window must not raise
  # "wrong sign in 'by' argument".
  d <- make_panel_subset(1L, 30L)
  expect_silent(
    folds <- make_expanding_folds(d, initial_months = 60)
  )
  expect_equal(length(folds), 0L)
})

test_that("folds never let test precede train (chronological integrity)", {
  d <- make_panel_subset(1L, 120L)
  folds <- make_expanding_folds(d, initial_months = 60, step_months = 12,
                                horizon_months = 12)
  for (f in folds) {
    expect_true(max(f$train) < min(f$test))
  }
})

test_that("split_panel produces non-overlapping chronological splits", {
  raw <- make_synthetic_raw(n_neighborhoods = 3, n_years = 5, with_nsa = TRUE)
  panel <- make_monthly_panel(raw)$panel
  splits <- split_panel(panel)
  expect_true(all(splits$train$year <= 2023))
  expect_true(all(splits$validation$year == 2024))
  expect_true(all(splits$test$year == 2025))
})
