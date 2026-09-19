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
  if (length(actual) != length(predicted)) stop("Prediction length mismatch")
  if (!length(actual)) return(list(MAE=NA_real_, RMSE=NA_real_, R2=NA_real_))
  if (any(!is.finite(actual)) || any(!is.finite(predicted))) stop("Non-finite prediction or target")
  residual <- actual - predicted
  mae <- mean(abs(residual))
  rmse <- sqrt(mean(residual^2))
  denom <- sum((actual - mean(actual))^2)
  r2 <- if (denom > 0) 1 - sum(residual^2) / denom else NA_real_
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
# decline) far better than a full-history mean. Added for a fair operational
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

# Two-stage warm-start Poisson glmnet fit.
#
# glmnet's coordinate descent converges quickly only along a warm-started
# path from lambda.max (sparse -> dense). Fitting a user lambda grid (or a
# single lambda) that starts far below lambda.max makes the Poisson IRLS hit
# maxit (~70s per fit, plus convergence warnings). Stage 1 walks the natural
# path to discover lambda.max; stage 2 refits the merged path (natural +
# requested values) so every requested lambda is an exact, warm-started path
# point. The objective is convex, so the solutions coincide with a cold
# single-lambda fit -- at a fraction of the cost.
.glmnet_poisson_fit <- function(x, y, alpha, lambdas) {
  fit0 <- tryCatch(
    glmnet::glmnet(
      x, y, family = "poisson", alpha = alpha, standardize = TRUE
    ),
    error = function(e) NULL
  )
  lam0 <- if (!is.null(fit0)) fit0$lambda else numeric(0)
  lam0 <- lam0[is.finite(lam0)]
  full_path <- sort(unique(c(lam0, lambdas)), decreasing = TRUE)
  full_path <- full_path[is.finite(full_path)]
  fit <- tryCatch(
    glmnet::glmnet(
      x, y, family = "poisson", alpha = alpha,
      lambda = full_path, standardize = TRUE
    ),
    error = function(e) NULL
  )
  ok <- !is.null(fit) && any(is.finite(fit$lambda)) &&
    any(lambdas %in% fit$lambda)
  if (!ok) {
    # Degenerate window (e.g. complete separation on tiny synthetic data):
    # fall back to a plain cold fit on the requested lambdas, matching
    # glmnet's legacy "solutions for larger lambdas returned" behaviour,
    # which still yields a predict-able object.
    fit <- glmnet::glmnet(
      x, y, family = "poisson", alpha = alpha,
      lambda = lambdas, standardize = TRUE
    )
  }
  fit
}

# Poisson GLM (log link) with glmnet ridge regularisation. With
# `with_area = TRUE` the neighbourhood one-hot block is included and the
# penalty shrinks it (the matrix is rank-deficient without a penalty), giving
# the Poisson model the same spatial structure as the ridge baseline.
#
# `lambda` is REQUIRED and must come from the shared nested chronological
# tuning protocol (tune_lambda_time_cv). Bare cv.glmnet() is deliberately NOT
# used: its random K-fold assignment has no time meaning and would let late
# periods inform the fit that "predicts" early ones (feedback2.0 P0 Task 2).
#
# Note on honesty: the Poisson mean model does NOT by itself resolve
# zero-inflation or over-dispersion; it is a candidate count-mean model with
# a log link, nothing more.
model_poisson_glm <- function(alpha = 0, lambda, with_area = TRUE) {
  force(alpha)
  if (missing(lambda) || is.null(lambda)) {
    stop(
      "model_poisson_glm() requires an explicit `lambda`. ",
      "Select it with tune_lambda_time_cv() (nested chronological CV) -- ",
      "random K-fold cv.glmnet is not an accepted tuning protocol here."
    )
  }
  force(lambda)
  force(with_area)
  function(train_data, test_data) {
    recipe <- make_basis_recipe(train_data)
    x_train <- make_glm_design_matrix(train_data, recipe, with_area = with_area)
    x_test <- make_glm_design_matrix(test_data, recipe, with_area = with_area)
    fit <- .glmnet_poisson_fit(
      x_train, train_data$theft_count, alpha, lambda
    )
    if(!signif(lambda,8) %in% signif(fit$lambda,8)) stop("Requested Poisson lambda did not converge")
    as.numeric(predict(fit, newx = x_test, s = lambda, type = "response"))
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
    # Fail explicitly if this exploratory comparator does not converge.
    fit <- MASS::glm.nb(theft_count ~ . - 1, data = df_train)
    if(!isTRUE(fit$converged)) stop("Negative-binomial did not converge")
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
    # glmnet's Gaussian standardisation rejects a constant response. This
    # occurs legitimately in tiny chronological synthetic folds (and can
    # occur in a genuinely quiet production window), for which the optimal
    # prediction is simply that constant response on the log scale.
    if (length(unique(y_train)) == 1L) {
      return(rep.int(pmax(0, expm1(y_train[[1L]])), nrow(x_test)))
    }
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

# --- Fast path-fit interfaces for nested tuning ---------------------------
#
# glmnet fits an entire regularisation path in a single call, so the tuning
# loop should fit ONE path per inner fold instead of one model per lambda.
# A path model exposes:
#   fit(train_data, lambda_grid) -> fitted object (with $recipe)
#   build_x(recipe, test_data)   -> design matrix for new data
#   predict_x(fitted, x_test, lambda) -> numeric predictions at `lambda`
# tune_lambda_time_cv() uses this interface when supplied; the selection
# protocol (grid, metric, tie-break) is unchanged. Both objectives are
# convex, so path fits match single-lambda fits up to solver tolerance.

ridge_log_path_model <- list(
  fit = function(train_data, lambda_grid) {
    recipe <- make_basis_recipe(train_data)
    x_train <- make_design_matrix(train_data, recipe)
    y_train <- log1p(train_data$theft_count)
    if (length(unique(y_train)) == 1L) {
      return(list(
        recipe = recipe,
        fit = list(constant_response = y_train[[1L]], lambda = lambda_grid)
      ))
    }
    fit <- glmnet::glmnet(
      x_train, y_train, alpha = 0,
      lambda = lambda_grid, standardize = TRUE
    )
    list(recipe = recipe, fit = fit)
  },
  build_x = function(recipe, test_data) {
    make_design_matrix(test_data, recipe)
  },
  predict_x = function(fitted, x_test, lambda) {
    if (!is.null(fitted$fit$constant_response)) {
      return(rep.int(pmax(0, expm1(fitted$fit$constant_response)), nrow(x_test)))
    }
    pred_log <- as.numeric(predict(fitted$fit, newx = x_test, s = lambda))
    pmax(0, expm1(pred_log))
  }
)

poisson_path_model <- function(alpha = 0, with_area = TRUE) {
  force(alpha)
  force(with_area)
  list(
    fit = function(train_data, lambda_grid) {
      recipe <- make_basis_recipe(train_data)
      x_train <- make_glm_design_matrix(
        train_data, recipe, with_area = with_area
      )
      # Warm-started path fit (see .glmnet_poisson_fit): seconds instead of
      # minutes, with every requested lambda an exact path point.
      fit <- .glmnet_poisson_fit(
        x_train, train_data$theft_count, alpha, lambda_grid
      )
      list(recipe = recipe, fit = fit)
    },
    build_x = function(recipe, test_data) {
      make_glm_design_matrix(test_data, recipe, with_area = with_area)
    },
    predict_x = function(fitted, x_test, lambda) {
      as.numeric(predict(
        fitted$fit, newx = x_test, s = lambda, type = "response"
      ))
    }
  )
}
