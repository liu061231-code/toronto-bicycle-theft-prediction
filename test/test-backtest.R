# test-backtest.R ----------------------------------------------------------
# Tests for the rolling-origin backtest protocol (feedback2.0 P0 Task 3):
# horizon=1 and horizon=12 are separate tasks; outer folds are chronological;
# the output schema carries the required columns; selection follows the
# predeclared rule; the 2025 window never participates in selection.

source(file.path(TEST_ROOT, "test", "helper.R"))

toy_panel_bt <- function() {
  raw <- make_synthetic_raw(n_neighborhoods = 4, n_years = 7, with_nsa = TRUE)
  make_monthly_panel(
    raw, coordinates = make_neighborhood_coordinates(raw)
  )$panel
}

test_that("rolling folds are chronological for both horizons", {
  d <- toy_panel_bt()
  for (h in c(1L, 12L)) {
    folds <- make_rolling_folds(d, horizon_months = h, min_train_months = 48L)
    expect_true(length(folds) >= 1)
    for (f in folds) {
      expect_true(max(f$train) < min(f$test))
      expect_equal(length(f$test), as.integer(h))
    }
  }
})

test_that("run_backtest emits the required schema", {
  d <- toy_panel_bt()
  models <- list(
    "Global mean" = baseline_global_mean,
    "Seasonal naive" = baseline_seasonal_naive
  )
  folds <- make_rolling_folds(d, horizon_months = 1L, min_train_months = 60L)
  res <- run_backtest(d, models, folds, horizon_months = 1L)

  required <- c(
    "task_horizon", "fold", "train_end", "test_start", "test_end",
    "model", "MAE", "RMSE", "R2", "total_bias"
  )
  expect_true(all(required %in% names(res)))
  expect_true(all(res$task_horizon == 1L))
  expect_equal(
    nrow(res), length(folds) * length(models)
  )
  # train_end is strictly before test_start on every row.
  expect_true(all(res$train_end < res$test_start))
})

test_that("stratified columns are present and finite where defined", {
  d <- toy_panel_bt()
  models <- list("Neighbourhood mean" = baseline_neighborhood_mean)
  folds <- make_rolling_folds(d, horizon_months = 12L, min_train_months = 48L)
  res <- run_backtest(d, models, folds, horizon_months = 12L)

  expect_true(all(c(
    "nonzero_MAE", "nonzero_RMSE", "active_MAE", "active_RMSE",
    "total_actual", "total_predicted"
  ) %in% names(res)))
  # No Inf anywhere (zero-total folds must yield NA bias, not Inf).
  expect_false(any(is.infinite(res$total_bias)))
  expect_false(any(is.infinite(res$RMSE)))
})

test_that("total_bias is NA (never Inf) when a fold's actual total is zero", {
  d <- toy_panel_bt()
  # Force an all-zero evaluation window.
  zero_test <- d[d$time_index == max(d$time_index), ]
  zero_test$theft_count <- 0
  pred <- rep(2, nrow(zero_test))
  fm <- backtest_fold_metrics(zero_test, pred)
  expect_true(is.na(fm$total_bias))
  expect_false(is.infinite(fm$total_bias))
})

test_that("selection follows the predeclared rule, per horizon", {
  # Synthetic backtest table: model A has min RMSE; model B is within 1%
  # RMSE but has higher MAE; model C within 1% with lower MAE would win the
  # tie-break.
  mk <- function(model, rmse, mae, horizon) {
    tibble::tibble(
      task_horizon = horizon, fold = 1:2,
      train_end = 60L, test_start = 61L, test_end = 61L,
      model = model, MAE = mae, RMSE = rmse, R2 = 0.5,
      total_bias = 0, nonzero_MAE = mae, nonzero_RMSE = rmse,
      active_MAE = mae, active_RMSE = rmse,
      total_actual = 10, total_predicted = 10, n_test = 5L
    )
  }
  bt <- dplyr::bind_rows(
    mk("A", 2.00, 1.00, 1L),
    mk("B", 2.01, 0.90, 1L),  # within 1% RMSE, better MAE -> tie-break win
    mk("C", 2.50, 0.50, 1L)   # worse RMSE beyond 1% -> not selected
  )
  s <- summarise_backtest(bt)
  sel <- s$model[s$task_horizon == 1 & s$selected]
  expect_equal(sel, "B")

  # Selection is computed per horizon, not globally.
  bt2 <- dplyr::bind_rows(
    bt,
    mk("A", 1.00, 1.00, 12L),
    mk("B", 2.00, 0.50, 12L)
  )
  s2 <- summarise_backtest(bt2)
  expect_equal(s2$model[s2$task_horizon == 12 & s2$selected], "A")
  expect_equal(s2$model[s2$task_horizon == 1 & s2$selected], "B")
})

test_that("tuned models produce one lambda trail per outer fold", {
  d <- toy_panel_bt()
  trace_env <- new.env(parent = emptyenv())
  trace_env$traces <- list()
  models <- list(
    "Ridge (tuned)" = make_tuned_model(
      "Ridge (tuned)",
      function(lambda) model_ridge_log(lambda = lambda),
      c(1e-1, 1e-2, 1e-3),
      trace_env = trace_env,
      initial_months = 36L
    )
  )
  folds <- make_rolling_folds(d, horizon_months = 12L, min_train_months = 48L)
  invisible(run_backtest(d, models, folds, horizon_months = 12L))

  traces <- dplyr::bind_rows(trace_env$traces)
  # One tuning grid per outer fold, each with exactly one selected lambda
  # per inner fold evaluated for every candidate.
  expect_equal(
    length(unique(traces$outer_train_end)), length(folds)
  )
  per_fold <- traces |>
    dplyr::group_by(outer_train_end) |>
    dplyr::summarise(n_selected_lambda = dplyr::n_distinct(lambda[selected]),
                     .groups = "drop")
  expect_true(all(per_fold$n_selected_lambda == 1))
})

test_that("SELECTION_RULE is declared and matches its README anchors", {
  expect_equal(SELECTION_RULE$primary_metric, "mean outer-fold RMSE")
  expect_true(isTRUE(SELECTION_RULE$per_horizon))
  expect_true(grepl("descriptive", SELECTION_RULE$retrospective_note))
})
