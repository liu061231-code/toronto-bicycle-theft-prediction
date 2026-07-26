split_panel <- function(panel) {
  list(
    train = dplyr::filter(panel, year <= 2021),
    validation = dplyr::filter(panel, year == 2022),
    test = dplyr::filter(panel, year == 2023)
  )
}

make_basis_recipe <- function(train) {
  unique_coordinates <- train |>
    dplyr::distinct(neighborhood, lon, lat) |>
    dplyr::arrange(neighborhood)
  center_index <- unique(round(seq(
    1, nrow(unique_coordinates), length.out = 16
  )))
  list(
    time_boundary = c(1, 120),
    time_knots = as.numeric(stats::quantile(
      train$time_index, c(0.2, 0.4, 0.6, 0.8)
    )),
    lon_center = mean(train$lon),
    lat_center = mean(train$lat),
    spatial_scale = max(stats::sd(train$lon), stats::sd(train$lat)),
    rbf_centers = unique_coordinates[center_index, c("lon", "lat")],
    rbf_sigma = 0.8,
    neighborhood_levels = unique_coordinates$neighborhood
  )
}

make_design_matrix <- function(data, recipe) {
  time_basis <- splines::bs(
    data$time_index,
    knots = recipe$time_knots,
    Boundary.knots = recipe$time_boundary,
    degree = 3,
    intercept = FALSE,
    warn.outside = FALSE
  )
  seasonal <- cbind(
    sin1 = sin(2 * pi * data$month_of_year / 12),
    cos1 = cos(2 * pi * data$month_of_year / 12),
    sin2 = sin(4 * pi * data$month_of_year / 12),
    cos2 = cos(4 * pi * data$month_of_year / 12)
  )
  lon <- (data$lon - recipe$lon_center) / recipe$spatial_scale
  lat <- (data$lat - recipe$lat_center) / recipe$spatial_scale
  centers <- as.data.frame(recipe$rbf_centers)
  centers$lon <- (centers$lon - recipe$lon_center) / recipe$spatial_scale
  centers$lat <- (centers$lat - recipe$lat_center) / recipe$spatial_scale
  rbf <- vapply(
    seq_len(nrow(centers)),
    function(i) {
      exp(
        -((lon - centers$lon[i])^2 + (lat - centers$lat[i])^2) /
          (2 * recipe$rbf_sigma^2)
      )
    },
    numeric(nrow(data))
  )
  neighborhood_basis <- stats::model.matrix(
    ~ neighborhood - 1,
    data = data.frame(
      neighborhood = factor(
        data$neighborhood,
        levels = recipe$neighborhood_levels
      )
    )
  )
  x <- cbind(time_basis, seasonal, rbf, neighborhood_basis)
  colnames(x) <- c(
    paste0("time_bs_", seq_len(ncol(time_basis))),
    colnames(seasonal),
    paste0("space_rbf_", seq_len(ncol(rbf))),
    paste0("area_", seq_len(ncol(neighborhood_basis)))
  )
  x
}

metric_frame <- function(actual, predicted, model, split = "Test 2023") {
  tibble::tibble(
    model = model,
    split = split,
    MAE = mean(abs(actual - predicted)),
    RMSE = sqrt(mean((actual - predicted)^2)),
    R2 = 1 - sum((actual - predicted)^2) /
      sum((actual - mean(actual))^2)
  )
}

fit_ols <- function(x, y) {
  fit <- stats::lm.fit(cbind(Intercept = 1, x), y)
  coefficients <- fit$coefficients
  coefficients[is.na(coefficients)] <- 0
  coefficients
}

predict_ols <- function(coefficients, x) {
  as.numeric(cbind(Intercept = 1, x) %*% coefficients)
}

fit_models <- function(splits, recipe) {
  train <- splits$train
  validation <- splits$validation
  test <- splits$test
  train_validation <- dplyr::bind_rows(train, validation)

  x_train <- make_design_matrix(train, recipe)
  x_validation <- make_design_matrix(validation, recipe)
  x_train_validation <- make_design_matrix(train_validation, recipe)
  x_test <- make_design_matrix(test, recipe)

  y_train <- log1p(train$theft_count)
  y_train_validation <- log1p(train_validation$theft_count)
  actual_test <- test$theft_count

  global_prediction <- rep(mean(train$theft_count), nrow(test))
  neighborhood_means <- train |>
    dplyr::group_by(neighborhood) |>
    dplyr::summarise(value = mean(theft_count), .groups = "drop")
  neighborhood_prediction <- test |>
    dplyr::select(neighborhood) |>
    dplyr::left_join(neighborhood_means, by = "neighborhood") |>
    dplyr::pull(value)

  ols_coefficients <- fit_ols(x_train_validation, y_train_validation)
  ols_prediction <- pmax(
    0,
    expm1(predict_ols(ols_coefficients, x_test))
  )

  lambda_grid <- exp(seq(log(100), log(1e-4), length.out = 100))
  ridge_train <- glmnet::glmnet(
    x_train, y_train,
    alpha = 0, lambda = lambda_grid, standardize = TRUE
  )
  validation_log <- predict(
    ridge_train, newx = x_validation, s = lambda_grid
  )
  validation_rmse <- apply(
    validation_log,
    2,
    function(prediction) {
      prediction <- pmax(0, expm1(prediction))
      sqrt(mean((validation$theft_count - prediction)^2))
    }
  )
  selected_lambda <- lambda_grid[which.min(validation_rmse)]
  ridge_final <- glmnet::glmnet(
    x_train_validation, y_train_validation,
    alpha = 0, lambda = selected_lambda, standardize = TRUE
  )
  ridge_prediction <- pmax(
    0,
    expm1(as.numeric(predict(
      ridge_final, newx = x_test, s = selected_lambda
    )))
  )

  metrics <- dplyr::bind_rows(
    metric_frame(actual_test, global_prediction, "Global mean"),
    metric_frame(actual_test, neighborhood_prediction, "Neighborhood mean"),
    metric_frame(actual_test, ols_prediction, "Basis OLS"),
    metric_frame(actual_test, ridge_prediction, "Basis Ridge")
  )
  predictions <- test |>
    dplyr::transmute(
      month = as.Date(month),
      neighborhood,
      lon,
      lat,
      actual = theft_count,
      predicted = ridge_prediction,
      residual = actual - predicted,
      global_mean = global_prediction,
      neighborhood_mean = neighborhood_prediction,
      basis_ols = ols_prediction
    )
  list(
    metrics = metrics,
    test_predictions = predictions,
    selected_lambda = selected_lambda,
    validation_rmse = min(validation_rmse),
    recipe = recipe,
    ridge_model = ridge_final,
    ols_coefficients = ols_coefficients
  )
}

make_model_plots <- function(fit, panel, recipe, figure_dir) {
  dir.create(figure_dir, recursive = TRUE, showWarnings = FALSE)

  time_grid <- tibble::tibble(
    time_index = 1:120,
    month_of_year = ((1:120 - 1) %% 12) + 1,
    lon = recipe$lon_center,
    lat = recipe$lat_center,
    neighborhood = recipe$neighborhood_levels[1]
  )
  basis <- as.data.frame(make_design_matrix(time_grid, recipe)) |>
    dplyr::mutate(time_index = 1:120) |>
    tidyr::pivot_longer(
      dplyr::matches("^(time_bs_[1-4]|sin1|cos1)$"),
      names_to = "basis", values_to = "value"
    )
  p5 <- ggplot2::ggplot(
    basis, ggplot2::aes(time_index, value, color = basis)
  ) +
    ggplot2::geom_line(linewidth = 0.8) +
    ggplot2::facet_wrap(~basis, scales = "free_y", ncol = 3) +
    ggplot2::guides(color = "none") +
    ggplot2::labs(
      title = "Examples of temporal basis functions",
      subtitle = "B-splines represent smooth long-term change; sine/cosine terms represent seasonality",
      x = "Month index", y = "Basis value"
    ) +
    handbook_theme()

  comparison <- fit$metrics |>
    tidyr::pivot_longer(
      c("MAE", "RMSE"), names_to = "metric", values_to = "value"
    )
  p6 <- ggplot2::ggplot(
    comparison,
    ggplot2::aes(value, stats::reorder(model, value), color = metric)
  ) +
    ggplot2::geom_point(size = 3) +
    ggplot2::facet_wrap(~metric, scales = "free_x") +
    ggplot2::labs(
      title = "Out-of-time test performance",
      subtitle = "All scores use 2023 only; lower MAE and RMSE are better",
      x = "Error in monthly neighborhood theft counts", y = NULL
    ) +
    handbook_theme()

  monthly_prediction <- fit$test_predictions |>
    dplyr::group_by(month) |>
    dplyr::summarise(
      actual = sum(actual),
      predicted = sum(predicted),
      .groups = "drop"
    ) |>
    tidyr::pivot_longer(
      c("actual", "predicted"), names_to = "series", values_to = "thefts"
    )
  p7 <- ggplot2::ggplot(
    monthly_prediction,
    ggplot2::aes(month, thefts, color = series)
  ) +
    ggplot2::geom_line(linewidth = 1.15) +
    ggplot2::geom_point(size = 2) +
    ggplot2::scale_color_manual(values = c(
      actual = "#1B4965", predicted = "#D95F02"
    )) +
    ggplot2::labs(
      title = "Observed and predicted citywide totals in 2023",
      subtitle = "Predictions are summed from neighborhood-level Ridge estimates",
      x = NULL, y = "Reported thefts", color = NULL
    ) +
    handbook_theme()

  residual_map <- fit$test_predictions |>
    dplyr::group_by(neighborhood, lon, lat) |>
    dplyr::summarise(
      mean_residual = mean(residual),
      .groups = "drop"
    )
  limit <- max(abs(residual_map$mean_residual))
  p8 <- ggplot2::ggplot(
    residual_map,
    ggplot2::aes(
      lon, lat, color = mean_residual, size = abs(mean_residual)
    )
  ) +
    ggplot2::geom_point(alpha = 0.85) +
    ggplot2::scale_color_gradient2(
      low = "#2166AC", mid = "white", high = "#B2182B",
      midpoint = 0, limits = c(-limit, limit)
    ) +
    ggplot2::scale_size_continuous(range = c(1, 8)) +
    ggplot2::coord_equal() +
    ggplot2::labs(
      title = "Where the 2023 model under- or over-predicts",
      subtitle = "Positive residuals mean observed thefts exceeded predictions",
      x = "Longitude", y = "Latitude",
      color = "Mean residual", size = "Absolute residual"
    ) +
    handbook_theme()

  paths <- file.path(
    figure_dir,
    c(
      "05_basis_functions.png",
      "06_model_comparison.png",
      "07_observed_vs_predicted.png",
      "08_residual_map.png"
    )
  )
  purrr::walk2(
    list(p5, p6, p7, p8),
    paths,
    ~ggplot2::ggsave(
      .y, .x, width = 9, height = 5.4, dpi = 180, bg = "white"
    )
  )
  stats::setNames(
    normalizePath(paths),
    c("basis", "comparison", "prediction", "residual")
  )
}
