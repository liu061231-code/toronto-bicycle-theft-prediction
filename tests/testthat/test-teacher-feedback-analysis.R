source(testthat::test_path("..", "..", "R", "config.R"))
source(testthat::test_path("..", "..", "R", "01_prepare_data.R"))
source(testthat::test_path("..", "..", "R", "02_visualize.R"))
source(testthat::test_path("..", "..", "R", "03_model.R"))
source(testthat::test_path("..", "..", "R", "06_teacher_feedback_analysis.R"))

testthat::test_that("seasonal coefficients are extracted from a fitted Ridge model", {
  month <- rep(1:12, 2)
  x <- cbind(
    sin1 = sin(2 * pi * month / 12),
    cos1 = cos(2 * pi * month / 12),
    sin2 = sin(4 * pi * month / 12),
    cos2 = cos(4 * pi * month / 12),
    trend = seq_along(month)
  )
  y <- 0.6 * x[, "sin1"] - 0.3 * x[, "cos1"] +
    0.2 * x[, "sin2"] + 0.1 * x[, "cos2"]
  ridge <- glmnet::glmnet(
    x,
    y,
    alpha = 0,
    lambda = c(0.1, 0.01),
    standardize = TRUE
  )

  extracted <- extract_seasonal_coefficients(ridge, 0.1)
  fitted <- as.matrix(stats::coef(ridge, s = 0.1))[, 1]
  wanted <- c("sin1", "cos1", "sin2", "cos2")

  testthat::expect_identical(names(extracted), wanted)
  testthat::expect_true(all(is.finite(extracted)))
  testthat::expect_equal(
    unname(extracted),
    unname(fitted[wanted])
  )
})

testthat::test_that("seasonal coefficients yield amplitude peak and ratio", {
  coefficients <- c(sin1 = 1, cos1 = 0, sin2 = 0, cos2 = 0)
  result <- summarise_seasonal_cycle(coefficients)

  testthat::expect_equal(result$summary$annual_amplitude, 1)
  testthat::expect_equal(result$summary$semiannual_amplitude, 0)
  testthat::expect_equal(result$summary$peak_month, 3L)
  testthat::expect_equal(result$summary$trough_month, 9L)
  testthat::expect_equal(result$summary$peak_to_trough_ratio, exp(2))
  testthat::expect_equal(nrow(result$monthly), 12L)
})

testthat::test_that("seasonal summary combines non-axis-aligned harmonics", {
  coefficients <- c(sin1 = 1, cos1 = 1, sin2 = 0.5, cos2 = -0.25)
  result <- summarise_seasonal_cycle(coefficients)
  month <- 1:12
  expected_log <-
    sin(2 * pi * month / 12) +
    cos(2 * pi * month / 12) +
    0.5 * sin(4 * pi * month / 12) -
    0.25 * cos(4 * pi * month / 12)

  testthat::expect_equal(result$summary$annual_amplitude, sqrt(2))
  testthat::expect_equal(
    result$summary$semiannual_amplitude,
    sqrt(0.5^2 + 0.25^2)
  )
  testthat::expect_equal(result$summary$peak_month, 2L)
  testthat::expect_equal(result$summary$trough_month, 6L)
  testthat::expect_equal(result$monthly$seasonal_log, expected_log)
  expected_ratio <- exp(max(expected_log) - min(expected_log))
  testthat::expect_equal(
    result$summary$peak_to_trough_ratio,
    expected_ratio
  )
  testthat::expect_true(all(coefficients != 0))
})

testthat::test_that("candidate comparison is selected by CV RMSE only", {
  model_fit <- list(
    cv_comparison = tibble::tibble(
      model = c("Additive Ridge", "Season-space Ridge"),
      lambda = c(0.1, 0.2),
      mean_rmse = c(2, 1),
      sd_rmse = c(0.2, 0.1)
    ),
    candidate_fits = list(
      list(metrics = metric_frame(c(1, 2), c(1, 2), "Additive Ridge")),
      list(metrics = metric_frame(c(1, 2), c(1, 3), "Season-space Ridge"))
    )
  )

  comparison <- build_interaction_model_comparison(model_fit)

  testthat::expect_identical(
    comparison$model[comparison$selected_by_cv],
    "Season-space Ridge"
  )
  testthat::expect_identical(
    comparison$model[which.min(comparison$test_rmse)],
    "Additive Ridge"
  )
})

testthat::test_that("teacher feedback plots use auditable source tables", {
  seasonal_analysis <- summarise_seasonal_cycle(
    c(sin1 = 1, cos1 = 0, sin2 = 0, cos2 = 0)
  )
  comparison <- tibble::tibble(
    model = c("Additive Ridge", "Season-space Ridge"),
    selected_lambda = c(0.1, 0.2),
    mean_cv_rmse = c(2, 1),
    sd_cv_rmse = c(0.2, 0.1),
    test_mae = c(0, 0.5),
    test_rmse = c(0, 1 / sqrt(2)),
    test_r2 = c(1, 0),
    selected_by_cv = c(FALSE, TRUE)
  )

  testthat::expect_s3_class(
    make_fitted_seasonal_cycle_plot(seasonal_analysis),
    "ggplot"
  )
  testthat::expect_s3_class(
    make_interaction_model_comparison_plot(comparison),
    "ggplot"
  )
})
