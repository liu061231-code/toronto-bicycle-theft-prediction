source(testthat::test_path("..", "..", "R", "03_model.R"))

panel <- readr::read_csv(
  testthat::test_path(
    "..", "..", "output", "analysis", "bicycle_monthly_panel.csv"
  ),
  show_col_types = FALSE
)
splits <- split_panel(panel)
recipe <- make_basis_recipe(splits$train)
x_train <- make_design_matrix(splits$train, recipe)
x_test <- make_design_matrix(splits$test, recipe)

testthat::test_that("time split has no future leakage", {
  testthat::expect_lte(max(splits$train$year), 2021)
  testthat::expect_equal(unique(splits$validation$year), 2022)
  testthat::expect_equal(unique(splits$test$year), 2023)
})

testthat::test_that("basis columns are stable across splits", {
  testthat::expect_identical(colnames(x_train), colnames(x_test))
  testthat::expect_false(anyNA(x_train))
  testthat::expect_false(anyNA(x_test))
})

fit <- fit_models(splits, recipe)

testthat::test_that("predictions are finite and non-negative", {
  testthat::expect_true(all(is.finite(fit$test_predictions$predicted)))
  testthat::expect_true(all(fit$test_predictions$predicted >= 0))
})

testthat::test_that("metrics include every planned baseline and model", {
  testthat::expect_setequal(
    fit$metrics$model,
    c("Global mean", "Neighborhood mean", "Basis OLS", "Basis Ridge")
  )
  testthat::expect_true(all(c("MAE", "RMSE", "R2") %in% names(fit$metrics)))
})

testthat::test_that("regularized basis model improves on the location baseline", {
  ridge_rmse <- fit$metrics$RMSE[fit$metrics$model == "Basis Ridge"]
  location_rmse <- fit$metrics$RMSE[
    fit$metrics$model == "Neighborhood mean"
  ]
  testthat::expect_lt(ridge_rmse, location_rmse)
})

tuning_panel <- dplyr::bind_rows(splits$train, splits$validation)

testthat::test_that("rolling folds use past years only and never include 2023", {
  folds <- make_rolling_folds(tuning_panel)
  testthat::expect_equal(
    unname(vapply(folds, `[[`, integer(1), "validation_year")),
    2018:2022
  )
  testthat::expect_true(all(vapply(
    folds,
    function(fold) max(fold$train$year) < fold$validation_year,
    logical(1)
  )))
  testthat::expect_true(all(vapply(
    folds,
    function(fold) all(fold$validation$year == fold$validation_year),
    logical(1)
  )))
  testthat::expect_false(any(vapply(
    folds,
    function(fold) any(c(fold$train$year, fold$validation$year) == 2023),
    logical(1)
  )))
})

testthat::test_that("Ridge lambda minimises mean rolling validation RMSE", {
  lambda_grid <- c(1, 0.1, 0.01)
  cv <- cross_validate_ridge(tuning_panel, lambda_grid)

  testthat::expect_equal(
    nrow(cv$fold_results),
    5L * length(lambda_grid)
  )
  testthat::expect_equal(
    sort(unique(cv$fold_results$validation_year)),
    2018:2022
  )
  testthat::expect_equal(nrow(cv$summary), length(lambda_grid))
  testthat::expect_equal(
    cv$selected_lambda,
    cv$summary$lambda[which.min(cv$summary$mean_rmse)]
  )
  testthat::expect_true(all(is.finite(cv$fold_results$RMSE)))
})

testthat::test_that("final models tune before the untouched 2023 test", {
  cv_fit <- fit_models(
    splits,
    lambda_grid = c(1, 0.1, 0.01)
  )
  testthat::expect_equal(
    sort(unique(cv_fit$cv_results$validation_year)),
    2018:2022
  )
  testthat::expect_false(any(
    cv_fit$cv_results$validation_year == 2023
  ))
  testthat::expect_equal(max(cv_fit$final_training_years), 2022)
  testthat::expect_equal(
    unique(cv_fit$test_predictions$year),
    2023
  )
  testthat::expect_equal(
    cv_fit$selected_lambda,
    cv_fit$cv_summary$lambda[
      which.min(cv_fit$cv_summary$mean_rmse)
    ]
  )
})
