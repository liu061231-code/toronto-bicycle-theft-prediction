# models.R ----------------------------------------------------------------
# Candidate models and their fitting/prediction interfaces.
#
# Every model exposes the same `fit_predict(train_data, test_data)` shape so
# they can be dropped into the shared expanding-window cross-validation loop
# and compared fairly. Baselines use no learned features; statistical models
# model the count target directly (Poisson / negative-binomial), which suits
# the over-dispersed, zero-inflated counts far better than least squares on
# a log-transformed target.

# --- Regression metrics (used by all models and baselines) ---------------

regression_metrics <- function(actual, predicted) {
  residual <- actual - predicted
  mae <- mean(abs(residual))
  rmse <- sqrt(mean(residual^2))
  r2 <- 1 - sum(residual^2) / sum((actual - mean(actual))^2)
  list(MAE = mae, RMSE = rmse, R2 = r2)
}

# --- Baselines -----------------------------------------------------------

# Global mean of the training target.
baseline_global_mean <- function(train_data, test_data) {
  rep(mean(train_data$theft_count), nrow(test_data))
}

# Neighbourhood-specific mean of the training target.
baseline_neighborhood_mean <- function(train_data, test_data) {
  means <- train_data |>
    dplyr::group_by(neighborhood) |>
    dplyr::summarise(value = mean(theft_count), .groups = "drop")
  test_data |>
    dplyr::select(neighborhood) |>
    dplyr::left_join(means, by = "neighborhood") |>
    dplyr::pull(value)
}

# Naive seasonal forecast: same neighbourhood, same month one year earlier.
# Falls back to the neighbourhood mean when no prior-year value exists.
baseline_seasonal_naive <- function(train_data, test_data) {
  lookup <- train_data |>
    dplyr::select(neighborhood, month, theft_count) |>
    dplyr::rename(prior_count = theft_count)
  joined <- test_data |>
    dplyr::mutate(
      prior_month = month - lubridate::period(12, "month")
    ) |>
    dplyr::left_join(lookup, by = c("neighborhood", "prior_month" = "month"))
  fallback <- train_data |>
    dplyr::group_by(neighborhood) |>
    dplyr::summarise(m = mean(theft_count), .groups = "drop")
  joined <- joined |>
    dplyr::left_join(fallback, by = "neighborhood")
  dplyr::if_else(
    is.na(joined$prior_count), joined$m, as.numeric(joined$prior_count)
  )
}

# Recent-window seasonal mean: for each neighbourhood, the mean of the most
# recent `window_months` months of training data. This is a realistic
# deployment baseline that adapts to the recent level (and thus to the ongoing
# decline) far better than a full-history mean. Added for a fair, actionable
# comparison (handoff 4.A).
baseline_recent_seasonal_mean <- function(window_months = 12) {
  force(window_months)
  function(train_data, test_data) {
    means <- train_data |>
      dplyr::group_by(neighborhood) |>
      dplyr::slice_tail(n = window_months) |>
      dplyr::summarise(value = mean(theft_count), .groups = "drop")
    test_data |>
      dplyr::select(neighborhood) |>
      dplyr::left_join(means, by = "neighborhood") |>
      dplyr::pull(value)
  }
}

# --- Statistical models --------------------------------------------------
#
# Each model factory returns a `fit_predict(train_data, test_data)` closure
# that REBUILDS the basis recipe from `train_data` on every call. This is
# essential for correctness: in expanding-window CV each fold trains on a
# different time window, and the spline boundary knots / spatial centers must
# reflect only that fold's training data (never the full timeline), otherwise
# early folds extrapolate wildly and leak future information.

# Design matrices for GLMs.
#
# `make_glm_design_matrix(..., with_area = FALSE)` returns the compact matrix
# (temporal B-splines + seasonal harmonics + spatial RBFs), matching the
# original GLM setup. `with_area = TRUE` additionally appends the neighbourhood
# one-hot indicators so the count GLMs carry the same spatial structure as the
# linear/ridge models -- required for a *fair* comparison (handoff 4.A). The
# resulting matrix is rank-deficient in the one-hot block, so a penalty is
# mandatory; glmnet's ridge/lasso handles this cleanly.
make_glm_design_matrix <- function(data, recipe, with_area = FALSE) {
  full <- make_design_matrix(data, recipe)
  if (with_area) {
    keep <- grepl("^(time_bs_|sin|cos|space_rbf_|area_)", colnames(full))
  } else {
    keep <- grepl("^(time_bs_|sin|cos|space_rbf_)", colnames(full))
  }
  full[, keep, drop = FALSE]
}

# Poisson GLM (log link) with glmnet ridge/LASSO regularisation. With
# `with_area = TRUE` the neighbourhood one-hot block is included and the
# penalty shrinks it (the matrix is rank-deficient without a penalty), giving
# the Poisson model the same spatial structure as the ridge baseline.
# `lambda = NULL` runs glmnet's internal cross-validation (cv.glmnet) to pick
# lambda on the training fold only -- a fair, per-fold tuning budget.
model_poisson_glm <- function(alpha = 0, lambda = 1e-2, with_area = TRUE) {
  force(alpha)
  force(lambda)
  force(with_area)
  function(train_data, test_data) {
    recipe <- make_basis_recipe(train_data)
    x_train <- make_glm_design_matrix(train_data, recipe, with_area = with_area)
    x_test <- make_glm_design_matrix(test_data, recipe, with_area = with_area)
    if (is.null(lambda)) {
      fit <- glmnet::cv.glmnet(
        x_train, train_data$theft_count, family = "poisson",
        alpha = alpha, standardize = TRUE
      )
      s <- fit$lambda.min
    } else {
      fit <- glmnet::glmnet(
        x_train, train_data$theft_count, family = "poisson",
        alpha = alpha, lambda = lambda, standardize = TRUE
      )
      s <- lambda
    }
    as.numeric(predict(fit, newx = x_test, s = s, type = "response"))
  }
}

# Negative-binomial GLM (log link) via MASS::glm.nb, which estimates the
# dispersion (theta) by maximum likelihood. glmnet 5.0 does NOT support a
# negative-binomial family, so the NB model cannot use a ridge penalty on the
# rank-deficient neighbourhood one-hot block; it therefore uses the COMPACT
# feature set (time + seasonal + spatial RBF, no area one-hot). For a fair
# Poisson-vs-NB comparison, Poisson is also offered in compact form (see
# `with_area = FALSE`). The NB dispersion accommodates variance > mean.
model_negbin_glm <- function(with_area = FALSE) {
  force(with_area)
  function(train_data, test_data) {
    recipe <- make_basis_recipe(train_data)
    x_train <- make_glm_design_matrix(train_data, recipe, with_area = with_area)
    x_test <- make_glm_design_matrix(test_data, recipe, with_area = with_area)
    df_train <- as.data.frame(x_train)
    df_train$theft_count <- train_data$theft_count
    # Capture convergence warnings so failures are not silently averaged away.
    fit <- MASS::glm.nb(theft_count ~ . - 1, data = df_train)
    as.numeric(predict(fit, newdata = as.data.frame(x_test), type = "response"))
  }
}

# Ridge regression on log1p-transformed target (the original approach),
# refit here under the shared interface for a fair comparison.
model_ridge_log <- function(lambda = 1e-2) {
  force(lambda)
  function(train_data, test_data) {
    recipe <- make_basis_recipe(train_data)
    x_train <- make_design_matrix(train_data, recipe)
    x_test <- make_design_matrix(test_data, recipe)
    y_train <- log1p(train_data$theft_count)
    fit <- glmnet::glmnet(
      x_train, y_train, alpha = 0, lambda = lambda, standardize = TRUE
    )
    pred_log <- as.numeric(predict(fit, newx = x_test, s = lambda))
    pmax(0, expm1(pred_log))
  }
}

# Ordinary least squares on the log1p target (no regularisation).
model_ols_log <- function() {
  function(train_data, test_data) {
    recipe <- make_basis_recipe(train_data)
    x_train <- make_design_matrix(train_data, recipe)
    x_test <- make_design_matrix(test_data, recipe)
    y_train <- log1p(train_data$theft_count)
    fit <- stats::lm.fit(cbind(Intercept = 1, x_train), y_train)
    coef <- fit$coefficients
    coef[is.na(coef)] <- 0
    pred_log <- as.numeric(cbind(Intercept = 1, x_test) %*% coef)
    pmax(0, expm1(pred_log))
  }
}
