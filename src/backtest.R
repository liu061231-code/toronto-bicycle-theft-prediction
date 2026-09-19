# backtest.R ---------------------------------------------------------------
# Rolling-origin backtests for predeclared model selection (feedback2.0
# P0 Task 3).
#
# Two DISTINCT forecast tasks are evaluated separately; they must never be
# merged into a single conclusion:
#
#   horizon = 1  : each month, refit and predict the NEXT month
#                  (deployment-style updating)
#   horizon = 12 : from a year-end cutoff, predict the NEXT 12 MONTHS at once
#                  (annual planning)
#
# Both use expanding-window outer folds: every outer test window is strictly
# later than its training window. Tuned models select lambda INSIDE each
# outer training window via the shared nested chronological protocol
# (tune_lambda_time_cv), so no outer test information influences any
# hyperparameter.
#
# Model selection uses ONLY the predeclared backtest metrics (see
# SELECTION_RULE below, mirrored in README.md). The 2025 calendar year is a
# repeatedly-viewed retrospective window: it is reported descriptively and
# plays NO role in model selection.

# Predeclared selection rule (single source of truth; keep README.md in
# sync). Primary metric: mean outer-fold RMSE. Tie-break: lower mean MAE
# when mean RMSE differs by less than 1%. Selection is made PER HORIZON; if
# the two horizons select different models, both are reported -- no global
# champion is forced.
SELECTION_RULE <- list(
  primary_metric = "mean outer-fold RMSE",
  tie_break = "lower mean MAE when mean RMSE differs by less than 1%",
  per_horizon = TRUE,
  retrospective_note = paste(
    "2025 retrospective scores are descriptive and do not change selection"
  )
)

# Build rolling-origin outer folds over `data`.
#
# For horizon = 1 the default steps month-by-month; for horizon = 12 the
# default steps by 12 months (annual origins). `min_train_months` sets the
# first training window; `first_test_index` can pin the first origin
# explicitly (absolute time_index).
make_rolling_folds <- function(
    data,
    horizon_months,
    min_train_months = 60L,
    step_months = if (horizon_months == 1L) 1L else 12L,
    first_test_index = NULL) {
  min_index <- min(data$time_index)
  max_index <- max(data$time_index)
  if (is.null(first_test_index)) {
    first_test_index <- min_index + min_train_months
  }
  if (first_test_index > max_index - horizon_months + 1L) return(list())
  starts <- seq(
    first_test_index, max_index - horizon_months + 1L, by = step_months
  )
  folds <- lapply(starts, function(s) {
    list(
      train = seq(min_index, s - 1L),
      test = seq(s, min(s + horizon_months - 1L, max_index))
    )
  })
  Filter(function(f) length(f$test) > 0L && length(f$train) > 0L, folds)
}

# Per-fold evaluation: overall metrics plus the strata required by the
# review protocol (citywide total bias, non-zero cells, active
# neighbourhoods). Strata are descriptive partitions of the EVALUATION
# window; they are never used for fitting or selection.
backtest_fold_metrics <- function(test_data, pred) {
  m <- regression_metrics(test_data$theft_count, pred)

  total_actual <- sum(test_data$theft_count)
  total_pred <- sum(pred)
  # Guard the divide-by-zero edge (feedback2.0 Task 10): NA, never Inf.
  total_bias <- if (total_actual > 0) {
    (total_pred - total_actual) / total_actual
  } else {
    NA_real_
  }

  nz <- test_data$theft_count > 0
  if (any(nz)) {
    m_nz <- regression_metrics(test_data$theft_count[nz], pred[nz])
  } else {
    m_nz <- list(MAE = NA_real_, RMSE = NA_real_, R2 = NA_real_)
  }

  totals <- tapply(test_data$theft_count, test_data$neighborhood, sum)
  active_nb <- names(totals)[totals >= stats::median(totals)]
  is_active <- test_data$neighborhood %in% active_nb
  m_act <- regression_metrics(
    test_data$theft_count[is_active], pred[is_active]
  )

  tibble::tibble(
    MAE = m$MAE, RMSE = m$RMSE, R2 = m$R2,
    total_actual = total_actual, total_predicted = total_pred,
    total_bias = total_bias,
    nonzero_MAE = m_nz$MAE, nonzero_RMSE = m_nz$RMSE,
    active_MAE = m_act$MAE, active_RMSE = m_act$RMSE,
    n_test = nrow(test_data)
  )
}

# Run one backtest task (one horizon) for a named list of models.
#
# Returns one row per (fold, model) with the schema required by the review:
#   task_horizon, fold, train_end, test_start, test_end, model,
#   MAE, RMSE, R2, total_bias  (+ stratified columns)
run_backtest <- function(data, models, folds, horizon_months) {
  rows <- lapply(seq_along(folds), function(i) {
    fold <- folds[[i]]
    train_data <- data[data$time_index %in% fold$train, ]
    test_data <- data[data$time_index %in% fold$test, ]
    # Precompute scalars: inside dplyr::mutate the freshly-created `fold`
    # column would shadow the local `fold` variable.
    tr_end <- max(fold$train)
    te_start <- min(fold$test)
    te_end <- max(fold$test)
    dplyr::bind_rows(lapply(names(models), function(model_name) {
      pred <- models[[model_name]](train_data, test_data)
      backtest_fold_metrics(test_data, pred) |>
        dplyr::mutate(
          task_horizon = horizon_months,
          fold = i,
          train_end = tr_end,
          test_start = te_start,
          test_end = te_end,
          model = model_name,
          .before = 1
        )
    }))
  })
  dplyr::bind_rows(rows) |>
    dplyr::relocate(
      task_horizon, fold, train_end, test_start, test_end, model,
      MAE, RMSE, R2, total_bias
    )
}

# Summarise a backtest: per (horizon, model) mean and SD of each metric,
# plus the worst fold by RMSE. Selection columns (selected per horizon by
# the predeclared rule) are added for traceability.
summarise_backtest <- function(backtest_results) {
  summary <- backtest_results |>
    dplyr::group_by(task_horizon, model) |>
    dplyr::summarise(
      n_folds = dplyr::n(),
      mean_MAE = mean(MAE), sd_MAE = stats::sd(MAE),
      mean_RMSE = mean(RMSE), sd_RMSE = stats::sd(RMSE),
      mean_R2 = mean(R2, na.rm = TRUE),
      mean_total_bias = mean(total_bias, na.rm = TRUE),
      mean_nonzero_MAE = mean(nonzero_MAE, na.rm = TRUE),
      mean_active_MAE = mean(active_MAE, na.rm = TRUE),
      worst_fold_RMSE = max(RMSE),
      .groups = "drop"
    ) |>
    dplyr::arrange(task_horizon, mean_RMSE)

  # Predeclared selection per horizon: min mean RMSE; tie-break mean MAE
  # when mean RMSE differs by less than 1%.
  summary <- summary |>
    dplyr::group_by(task_horizon) |>
    dplyr::mutate(
      best_rmse = min(mean_RMSE),
      within_tol = mean_RMSE <= best_rmse * 1.01,
      selected = within_tol & mean_MAE == min(mean_MAE[within_tol])
    ) |>
    dplyr::ungroup() |>
    dplyr::select(-best_rmse, -within_tol)
  summary
}
