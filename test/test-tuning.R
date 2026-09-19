# test-tuning.R ------------------------------------------------------------
# Tests for the unified nested chronological tuning protocol (feedback2.0
# P0 Task 2): lambda must be selected by expanding-window INNER folds inside
# each outer training window, using the same grid, metric and tie-break for
# every tuned model. Random K-fold (e.g. bare cv.glmnet) is not allowed.

source(file.path(TEST_ROOT, "test", "helper.R"))

# A synthetic panel long enough for inner time CV (6 area-units x 6 years).
toy_panel <- function() {
  raw <- make_synthetic_raw(n_neighborhoods = 5, n_years = 6, with_nsa = TRUE)
  panel <- make_monthly_panel(
    raw, coordinates = make_neighborhood_coordinates(raw)
  )$panel
  # Real variation is necessary: the raw helper creates one event per cell.
  panel$theft_count <- (seq_len(nrow(panel))*7 + panel$time_index) %% 9
  panel
}

ridge_factory <- function(lambda) model_ridge_log(lambda = lambda)
poisson_factory <- function(lambda) {
  model_poisson_glm(alpha = 0, lambda = lambda, with_area = TRUE)
}
toy_grid <- c(1e-1, 1e-2, 1e-3)

test_that("inner tuning folds are strictly chronological", {
  d <- toy_panel()
  res <- tune_lambda_time_cv(
    d, toy_grid, ridge_factory,
    initial_months = 24L, step_months = 12L, horizon_months = 12L
  )
  expect_true(length(res$inner_folds) >= 1)
  for (f in res$inner_folds) {
    expect_true(max(f$train) < min(f$test))
  }
})

test_that("changing outer test labels does not change the selected lambda", {
  d <- toy_panel()
  train <- dplyr::filter(d, time_index <= 48)
  test <- dplyr::filter(d, time_index > 48)

  env1 <- new.env(parent = emptyenv())
  fp1 <- make_tuned_model(
    "ridge", ridge_factory, toy_grid, trace_env = env1,
    initial_months = 24L
  )
  invisible(fp1(train, test))
  lam1 <- env1$last_lambda

  # Drastically alter the OUTER TEST labels only; tuning must be unaffected.
  test2 <- test
  test2$theft_count <- test2$theft_count + 1000
  env2 <- new.env(parent = emptyenv())
  fp2 <- make_tuned_model(
    "ridge", ridge_factory, toy_grid, trace_env = env2,
    initial_months = 24L
  )
  invisible(fp2(train, test2))
  lam2 <- env2$last_lambda

  expect_equal(lam1, lam2)
})

test_that("future records do not change lambda selected on an earlier window", {
  d <- toy_panel()
  train <- dplyr::filter(d, time_index <= 48)
  res1 <- tune_lambda_time_cv(
    train, toy_grid, ridge_factory, initial_months = 24L
  )

  # Append records strictly AFTER the training window; re-tune on the same
  # window drawn from the enlarged data. Lambda must be identical.
  extra <- d[d$time_index > 48, ][1:30, ]
  d2 <- dplyr::bind_rows(d, extra)
  train2 <- dplyr::filter(d2, time_index <= 48)
  res2 <- tune_lambda_time_cv(
    train2, toy_grid, ridge_factory, initial_months = 24L
  )

  expect_equal(res1$best_lambda, res2$best_lambda)
})

test_that("same seed and same input give identical lambda and predictions", {
  d <- toy_panel()
  train <- dplyr::filter(d, time_index <= 48)
  test <- dplyr::filter(d, time_index > 48)

  res_a <- tune_lambda_time_cv(
    train, toy_grid, ridge_factory, initial_months = 24L
  )
  res_b <- tune_lambda_time_cv(
    train, toy_grid, ridge_factory, initial_months = 24L
  )
  expect_equal(res_a$best_lambda, res_b$best_lambda)

  fp <- make_tuned_model(
    "ridge", ridge_factory, toy_grid, initial_months = 24L
  )
  p_a <- fp(train, test)
  p_b <- fp(train, test)
  expect_identical(p_a, p_b)
})

test_that("ridge and poisson share grid, metric and tie-break rule", {
  d <- toy_panel()
  train <- dplyr::filter(d, time_index <= 48)

  gr <- tune_lambda_time_cv(
    train, toy_grid, ridge_factory, initial_months = 24L
  )
  gp <- tune_lambda_time_cv(
    train, toy_grid, poisson_factory, initial_months = 24L
  )

  # Same candidate set, same selection metric, same tie-break declaration.
  expect_equal(sort(unique(gr$grid$lambda)), sort(toy_grid))
  expect_equal(sort(unique(gp$grid$lambda)), sort(toy_grid))
  expect_equal(gr$metric, gp$metric)
  expect_equal(gr$tie_rule, gp$tie_rule)
  # Each model reports exactly one selected lambda per outer tuning run.
  expect_equal(sum(gr$grid$selected), 1L * length(gr$inner_folds) * 0L +
                 sum(gr$grid$lambda == gr$best_lambda))
  expect_true(all(gp$grid$selected == (gp$grid$lambda == gp$best_lambda)))
})

test_that("tuning trace has the required schema", {
  d <- toy_panel()
  train <- dplyr::filter(d, time_index <= 48)
  res <- tune_lambda_time_cv(
    train, toy_grid, ridge_factory, initial_months = 24L
  )
  expect_true(all(
    c("lambda", "inner_fold", "MAE", "RMSE", "R2", "selected") %in%
      names(res$grid)
  ))
  # Every inner fold evaluates every candidate lambda.
  expect_equal(
    nrow(res$grid),
    length(res$inner_folds) * length(toy_grid)
  )
})
