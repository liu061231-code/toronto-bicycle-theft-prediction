# validation.R ------------------------------------------------------------
# Time-aware validation strategies.
#
# The panel has strong temporal dependence (lag-1 autocorrelation ~0.83 and
# a clear annual cycle). A random train/test split would leak future
# information into training, so all validation is chronological:
#
#   - final hold-out test set  = calendar year 2025
#   - expanding-window CV      = hyperparameter selection on 2014-2024 only
#
# Expanding-window CV trains on all data up to a cutoff and evaluates on the
# following window, then rolls the cutoff forward. This mirrors how the model
# would be deployed (forecast the future from the past) and never evaluates
# on data that precedes training.

# Chronological split into train / validation / test by year.
#
# With the refreshed dataset (through 2025), the split is:
#   train      = 2014-2023
#   validation = 2024
#   test       = 2025
# The final test set is a full, untouched recent year; validation is used
# only for the tuned model's hyperparameter selection via CV on train+val.
split_panel <- function(panel) {
  list(
    train = dplyr::filter(panel, year <= 2023),
    validation = dplyr::filter(panel, year == 2024),
    test = dplyr::filter(panel, year == 2025)
  )
}

# Build expanding-window cross-validation folds.
#
# `initial_months` months are used for the first training window, then the
# window expands by `step_months` at each fold and evaluates on the next
# `horizon_months`. Returns a list of folds, each with train/test month
# indices (absolute time_index values).
make_expanding_folds <- function(
    data,
    initial_months = 60L,
    step_months = 12L,
    horizon_months = 12L) {
  min_index <- min(data$time_index)
  max_index <- max(data$time_index)

  fold_starts <- seq(
    initial_months + 1L,
    max_index - horizon_months + 1L,
    by = step_months
  )
  folds <- lapply(fold_starts, function(start_index) {
    train_end <- start_index - 1L
    test_start <- start_index
    test_end <- min(start_index + horizon_months - 1L, max_index)
    list(
      train = seq(min_index, train_end),
      test = seq(test_start, test_end)
    )
  })
  # Drop any fold whose test window is empty.
  Filter(function(f) length(f$test) > 0L, folds)
}

# Evaluate a model over expanding-window folds. `fit_predict` is a function
# taking (train_data, test_data) and returning a numeric vector of
# predictions on test_data. Returns a data frame of per-fold metrics.
cross_validate <- function(
    data,
    folds,
    fit_predict,
    metric_fun = regression_metrics) {
  results <- lapply(seq_along(folds), function(i) {
    fold <- folds[[i]]
    train_data <- data[data$time_index %in% fold$train, ]
    test_data <- data[data$time_index %in% fold$test, ]
    pred <- fit_predict(train_data, test_data)
    m <- metric_fun(test_data$theft_count, pred)
    tibble::tibble(
      fold = i,
      test_start = min(test_data$time_index),
      test_end = max(test_data$time_index),
      n_train = nrow(train_data),
      n_test = nrow(test_data),
      MAE = m$MAE, RMSE = m$RMSE, R2 = m$R2
    )
  })
  dplyr::bind_rows(results)
}
