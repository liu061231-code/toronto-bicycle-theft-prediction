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
    lambda_grid = c(10, 0.1, 0.001)
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
  testthat::expect_length(cv_fit$candidate_fits, 2L)
  required_candidate_fields <- c(
    "model", "include_interactions", "cv", "recipe",
    "ridge_model", "selected_lambda", "prediction", "metrics"
  )
  testthat::expect_true(all(vapply(
    cv_fit$candidate_fits,
    function(candidate) {
      all(required_candidate_fields %in% names(candidate))
    },
    logical(1)
  )))
  testthat::expect_identical(
    names(cv_fit$cv_comparison),
    c("model", "lambda", "mean_rmse", "sd_rmse")
  )
  testthat::expect_true(all(c(
    "additive_ridge", "season_space_ridge"
  ) %in% names(cv_fit$test_predictions)))
  cv_selected_model <- cv_fit$cv_comparison$model[
    which.min(cv_fit$cv_comparison$mean_rmse)
  ]
  testthat::expect_identical(cv_fit$primary_model, cv_selected_model)
  testthat::expect_identical(
    cv_fit$primary_fit$model,
    cv_fit$primary_model
  )
  test_metrics <- purrr::map_dfr(
    cv_fit$candidate_fits,
    function(candidate) candidate$metrics
  )
  test_selected_model <- test_metrics$model[
    which.min(test_metrics$RMSE)
  ]
  testthat::expect_identical(cv_fit$primary_model, "Season-space Ridge")
  testthat::expect_identical(test_selected_model, "Additive Ridge")
  testthat::expect_false(
    identical(cv_fit$primary_model, test_selected_model)
  )
})

testthat::test_that("annual season by spatial RBF interactions are explicit products", {
  base <- make_design_matrix(splits$train, recipe)
  interacted <- make_design_matrix(
    splits$train,
    recipe,
    include_interactions = TRUE
  )
  validation_interacted <- make_design_matrix(
    splits$validation,
    recipe,
    include_interactions = TRUE
  )

  expected_interactions <- c(
    paste0("sin1_x_space_rbf_", 1:16),
    paste0("cos1_x_space_rbf_", 1:16)
  )
  expected_columns <- c(colnames(base), expected_interactions)
  testthat::expect_identical(colnames(interacted), expected_columns)
  testthat::expect_identical(
    colnames(validation_interacted),
    expected_columns
  )
  testthat::expect_equal(ncol(interacted), ncol(base) + 32L)
  testthat::expect_equal(
    interacted[, "sin1_x_space_rbf_1"],
    interacted[, "sin1"] * interacted[, "space_rbf_1"]
  )
  testthat::expect_equal(
    interacted[, "cos1_x_space_rbf_16"],
    interacted[, "cos1"] * interacted[, "space_rbf_16"]
  )
})

testthat::test_that("rolling CV labels additive and interaction candidates", {
  tuning_panel <- dplyr::bind_rows(splits$train, splits$validation)
  lambda_grid <- c(0.1, 0.01)
  additive <- cross_validate_ridge(
    tuning_panel,
    lambda_grid,
    include_interactions = FALSE
  )
  interaction <- cross_validate_ridge(
    tuning_panel,
    lambda_grid,
    include_interactions = TRUE
  )

  testthat::expect_identical(additive$model_type, "Additive Ridge")
  testthat::expect_identical(interaction$model_type, "Season-space Ridge")
  testthat::expect_true(all(additive$summary$model == "Additive Ridge"))
  testthat::expect_true(all(interaction$summary$model == "Season-space Ridge"))
})

testthat::test_that("canonical model summary identifies one CV-selected model", {
  summary <- build_model_summary(fit)
  testthat::expect_identical(
    names(summary),
    c(
      "model", "role", "selected_by_cv", "selected_lambda",
      "mean_cv_rmse", "sd_cv_rmse", "test_mae", "test_rmse",
      "test_r2", "test_total_bias"
    )
  )
  testthat::expect_setequal(
    summary$model,
    c(
      "Global mean", "Neighborhood mean", "Basis OLS",
      "Additive Ridge", "Season-space Ridge"
    )
  )
  testthat::expect_identical(
    summary$role,
    c("baseline", "baseline", "benchmark", "candidate", "candidate")
  )
  testthat::expect_equal(sum(summary$selected_by_cv), 1L)
  testthat::expect_identical(
    summary$model[summary$selected_by_cv],
    fit$primary_model
  )
  testthat::expect_true(all(is.na(
    summary$selected_lambda[summary$role != "candidate"]
  )))
})

testthat::test_that("canonical total bias reconciles with 2023 predictions", {
  summary <- build_model_summary(fit)
  selected <- summary[summary$selected_by_cv, ]
  selected_column <- if (fit$primary_model == "Season-space Ridge") {
    "season_space_ridge"
  } else {
    "additive_ridge"
  }
  expected_bias <- (
    sum(fit$test_predictions[[selected_column]]) -
      sum(fit$test_predictions$actual)
  ) / sum(fit$test_predictions$actual)
  testthat::expect_equal(selected$test_total_bias, expected_bias)
  testthat::expect_error(
    calculate_total_bias(c(0, 0), c(0, 1)),
    "actual total must be positive"
  )
})
