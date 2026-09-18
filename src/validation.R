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
#
# The fold schedule is expressed in *relative* month offsets from the start of
# `data` (not absolute time_index values), so `initial_months` means "the first
# N months of THIS series", regardless of whether the series starts at index 1
# or 25. This fixes a bug where a series starting at time_index 25 would yield
# a first fold with only 36 training months instead of 60.
make_expanding_folds <- function(
    data,
    initial_months = 60L,
    step_months = 12L,
    horizon_months = 12L) {
  min_index <- min(data$time_index)
  max_index <- max(data$time_index)
  n_months <- max_index - min_index + 1L

  # Guard against a series shorter than the initial window, which would make
  # `seq()` emit "wrong sign in 'by' argument" and produce no folds.
  if (n_months <= initial_months) {
    return(list())
  }

  fold_starts <- seq(
    initial_months + 1L,
    n_months - horizon_months + 1L,
    by = step_months
  )
  folds <- lapply(fold_starts, function(start_offset) {
    train_end <- min_index + start_offset - 2L
    test_start <- min_index + start_offset - 1L
    test_end <- min(test_start + horizon_months - 1L, max_index)
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

# --- Nested chronological tuning (feedback2.0 P0 Task 2) ------------------
#
# tune_lambda_time_cv() selects a regularisation strength using ONLY the
# supplied (outer-fold) training data: it builds expanding-window INNER folds
# inside that window, evaluates every candidate lambda on every inner fold,
# and picks the winner by a predeclared rule. No random K-fold anywhere --
# each inner validation window is strictly later than its training window,
# so future data never helps predict the past.
#
# Predeclared selection protocol (shared by ALL tuned models):
#   primary metric : mean inner-fold RMSE (count scale)
#   tie-break      : among lambdas within 1% of the best mean RMSE, choose
#                    the LARGEST lambda (strongest regularisation = simplest
#                    model)
#
# `model_factory` maps a lambda to a `fit_predict(train, test)` closure, so
# the same machinery tunes any model family (ridge-on-log, Poisson, ...).
#
# PERFORMANCE: glmnet fits a whole regularisation PATH in one call, so
# fitting 8 single-lambda models per inner fold wastes ~8x the work. When
# `path_model` is supplied (a list with fit / build_x / predict_x, see
# models.R), tune_lambda_time_cv fits ONE path per inner fold and reuses the
# test design matrix across lambdas. The protocol, grid, metric, tie-break
# and output schema are IDENTICAL either way; only the cost differs. (Ridge
# and log-link Poisson objectives are convex, so path fits and single-lambda
# fits coincide up to solver tolerance.)
tune_lambda_time_cv <- function(
    train_data,
    lambda_grid,
    model_factory,
    metric = "RMSE",
    initial_months = 48L,
    step_months = 12L,
    horizon_months = 12L,
    tie_tol = 0.01,
    path_model = NULL) {
  stopifnot(metric == "RMSE")
  inner_folds <- make_expanding_folds(
    train_data, initial_months = initial_months,
    step_months = step_months, horizon_months = horizon_months
  )
  if (length(inner_folds) == 0L) {
    stop(
      "Training window too short for inner chronological CV ",
      "(need > ", initial_months, " months)."
    )
  }

  # glmnet expects a decreasing lambda path.
  lambda_grid <- sort(lambda_grid, decreasing = TRUE)

  if (!is.null(path_model)) {
    # Fast path: one path-fit + one test design matrix per inner fold.
    grid <- lapply(seq_along(inner_folds), function(i) {
      f <- inner_folds[[i]]
      tr <- train_data[train_data$time_index %in% f$train, ]
      te <- train_data[train_data$time_index %in% f$test, ]
      fitted <- tryCatch(
        path_model$fit(tr, lambda_grid),
        error = function(e) NULL
      )
      # Evaluate ONLY the declared candidate grid. A path fit may carry a
      # much longer internal lambda sequence (warm-start path); restrict to
      # the requested values the solver actually reached. Values the solver
      # did not reach are dropped for this fold (with a warning) and the
      # aggregates average over the folds where they exist.
      avail <- if (!is.null(fitted)) fitted$fit$lambda else numeric(0)
      avail <- avail[is.finite(avail)]
      # Match by significant digits to be robust to solver float round-trip.
      avail <- lambda_grid[signif(lambda_grid, 8) %in% signif(avail, 8)]
      if (length(avail) == 0L) {
        # Degenerate window (e.g. tiny synthetic data): fall back to
        # per-lambda fits, which return the closest converged solution.
        warning(
          "inner fold ", i, ": path fit unusable; falling back to ",
          "per-lambda fits for this fold"
        )
        return(dplyr::bind_rows(lapply(lambda_grid, function(lam) {
          pred <- model_factory(lam)(tr, te)
          m <- regression_metrics(te$theft_count, pred)
          tibble::tibble(
            inner_fold = i, lambda = lam,
            MAE = m$MAE, RMSE = m$RMSE, R2 = m$R2
          )
        })))
      }
      if (length(avail) < length(lambda_grid)) {
        warning(
          "inner fold ", i, ": glmnet reached ", length(avail), " of ",
          length(lambda_grid), " requested lambdas; the rest are dropped ",
          "for this fold"
        )
      }
      x_te <- path_model$build_x(fitted$recipe, te)
      dplyr::bind_rows(lapply(avail, function(lam) {
        pred <- path_model$predict_x(fitted, x_te, lam)
        m <- regression_metrics(te$theft_count, pred)
        tibble::tibble(
          inner_fold = i, lambda = lam,
          MAE = m$MAE, RMSE = m$RMSE, R2 = m$R2
        )
      }))
    }) |>
      dplyr::bind_rows()
  } else {
    grid <- lapply(lambda_grid, function(lam) {
      cv <- cross_validate(train_data, inner_folds, model_factory(lam))
      cv |>
        dplyr::transmute(
          inner_fold = fold,
          lambda = lam,
          MAE = MAE, RMSE = RMSE, R2 = R2
        )
    }) |>
      dplyr::bind_rows()
  }

  aggregate <- grid |>
    dplyr::group_by(lambda) |>
    dplyr::summarise(
      mean_MAE = mean(MAE), mean_RMSE = mean(RMSE), mean_R2 = mean(R2),
      .groups = "drop"
    )

  best_rmse <- min(aggregate$mean_RMSE)
  within_tol <- aggregate$lambda[
    aggregate$mean_RMSE <= best_rmse * (1 + tie_tol)
  ]
  best_lambda <- max(within_tol)

  grid <- grid |>
    dplyr::mutate(selected = lambda == best_lambda)

  list(
    best_lambda = best_lambda,
    grid = grid,
    aggregate = aggregate,
    inner_folds = inner_folds,
    metric = "RMSE",
    tie_rule = "largest lambda within 1% of best mean inner-fold RMSE"
  )
}

# Wrap a model factory so that every call first tunes lambda by nested
# chronological CV on the given training window, then fits with the selected
# lambda. This is the ONLY way tuned models may be constructed for the outer
# backtest: it guarantees that the lambda seen by an outer test fold was
# chosen without any knowledge of that fold.
#
# When `trace_env` (an environment) is supplied, the full inner grid (with
# model id and outer training cutoff) is appended to `trace_env$traces` and
# the chosen lambda is stored in `trace_env$last_lambda`, giving every outer
# fold an auditable tuning trail.
make_tuned_model <- function(
    model_id,
    model_factory,
    lambda_grid,
    trace_env = NULL,
    metric = "RMSE",
    initial_months = 48L,
    step_months = 12L,
    horizon_months = 12L,
    path_model = NULL) {
  force(model_id); force(model_factory); force(lambda_grid)
  force(metric); force(initial_months); force(step_months)
  force(horizon_months); force(path_model)
  function(train_data, test_data) {
    tune <- tune_lambda_time_cv(
      train_data, lambda_grid, model_factory,
      metric = metric,
      initial_months = initial_months,
      step_months = step_months,
      horizon_months = horizon_months,
      path_model = path_model
    )
    if (!is.null(trace_env)) {
      trace <- tune$grid |>
        dplyr::mutate(
          model = model_id,
          outer_train_end = max(train_data$time_index)
        )
      if (is.null(trace_env$traces)) trace_env$traces <- list()
      trace_env$traces[[length(trace_env$traces) + 1L]] <- trace
      trace_env$last_lambda <- tune$best_lambda
    }
    model_factory(tune$best_lambda)(train_data, test_data)
  }
}
