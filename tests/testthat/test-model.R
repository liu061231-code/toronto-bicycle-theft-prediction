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
