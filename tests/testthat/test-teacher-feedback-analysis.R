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

  seasonal_plot <- make_fitted_seasonal_cycle_plot(seasonal_analysis)
  testthat::expect_s3_class(seasonal_plot, "ggplot")
  testthat::expect_match(seasonal_plot$labels$title, "March")
  testthat::expect_s3_class(
    make_interaction_model_comparison_plot(comparison),
    "ggplot"
  )
})

testthat::test_that("primary figure data use the CV-selected fit predictions", {
  test_rows <- tibble::tibble(
    month = as.Date(c("2023-01-01", "2023-01-01", "2023-02-01")),
    year = 2023L,
    neighborhood = c("Area A (1)", "Area B (2)", "Area A (1)"),
    lon = c(-79.4, -79.3, -79.4),
    lat = c(43.7, 43.8, 43.7),
    theft_count = c(3, 4, 5)
  )
  model_fit <- list(
    primary_model = "Season-space Ridge",
    primary_fit = list(prediction = c(2.5, 4.5, 6))
  )

  analysis <- prepare_primary_prediction_analysis(model_fit, test_rows)

  testthat::expect_equal(
    analysis$predictions$predicted,
    model_fit$primary_fit$prediction
  )
  testthat::expect_equal(
    analysis$predictions$residual,
    test_rows$theft_count - model_fit$primary_fit$prediction
  )
  testthat::expect_identical(analysis$model, "Season-space Ridge")
  testthat::expect_equal(
    make_primary_observed_vs_predicted_plot(analysis)$data,
    analysis$monthly
  )
  offline_residual_plot <- make_primary_residual_map_plot(analysis)
  testthat::expect_equal(offline_residual_plot$data, analysis$residuals)
  testthat::expect_false(grepl(
    "City of Toronto",
    offline_residual_plot$labels$caption,
    fixed = TRUE
  ))
})

testthat::test_that("primary figure data reject rows outside untouched 2023", {
  non_test_rows <- tibble::tibble(
    month = as.Date("2022-12-01"),
    year = 2022L,
    neighborhood = "Area A (1)",
    lon = -79.4,
    lat = 43.7,
    theft_count = 3
  )
  model_fit <- list(
    primary_model = "Season-space Ridge",
    primary_fit = list(prediction = 2.5)
  )

  testthat::expect_error(
    prepare_primary_prediction_analysis(model_fit, non_test_rows),
    "untouched 2023"
  )
})

testthat::test_that("primary model figure files are produced separately", {
  test_rows <- tibble::tibble(
    month = as.Date(c("2023-01-01", "2023-01-01", "2023-02-01")),
    year = 2023L,
    neighborhood = c("Area A (1)", "Area B (2)", "Area A (1)"),
    lon = c(-79.4, -79.3, -79.4),
    lat = c(43.7, 43.8, 43.7),
    theft_count = c(3, 4, 5)
  )
  model_fit <- list(
    primary_model = "Season-space Ridge",
    primary_fit = list(prediction = c(2.5, 4.5, 6))
  )
  analysis <- prepare_primary_prediction_analysis(model_fit, test_rows)
  figure_dir <- tempfile("stat3888-primary-model-figures-")

  paths <- make_primary_model_plots(analysis, figure_dir)

  testthat::expect_identical(
    names(paths),
    c("prediction", "residual")
  )
  testthat::expect_true(all(file.exists(paths)))
  testthat::expect_true(all(file.info(paths)$size > 20000))
  testthat::expect_match(paths[["prediction"]], "12_primary_")
  testthat::expect_match(paths[["residual"]], "13_primary_")
})
