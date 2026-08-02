split_panel <- function(panel) {
  list(
    train = dplyr::filter(panel, year <= 2021),
    validation = dplyr::filter(panel, year == 2022),
    test = dplyr::filter(panel, year == 2023)
  )
}

make_rolling_folds <- function(
    panel,
    initial_train_end = 2017L,
    final_validation_year = 2022L) {
  validation_years <- seq.int(
    initial_train_end + 1L,
    final_validation_year
  )
  stats::setNames(
    lapply(validation_years, function(validation_year) {
      list(
        fold = validation_year - initial_train_end,
        train_end = validation_year - 1L,
        validation_year = validation_year,
        train = dplyr::filter(panel, year <= validation_year - 1L),
        validation = dplyr::filter(panel, year == validation_year)
      )
    }),
    paste0("validate_", validation_years)
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

make_design_matrix <- function(
    data,
    recipe,
    include_interactions = FALSE) {
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
  interaction <- NULL
  if (include_interactions) {
    interaction <- cbind(
      sweep(rbf, 1, seasonal[, "sin1"], `*`),
      sweep(rbf, 1, seasonal[, "cos1"], `*`)
    )
    colnames(interaction) <- c(
      paste0("sin1_x_space_rbf_", seq_len(ncol(rbf))),
      paste0("cos1_x_space_rbf_", seq_len(ncol(rbf)))
    )
  }
  x <- cbind(time_basis, seasonal, rbf, neighborhood_basis, interaction)
  colnames(x) <- c(
    paste0("time_bs_", seq_len(ncol(time_basis))),
    colnames(seasonal),
    paste0("space_rbf_", seq_len(ncol(rbf))),
    paste0("area_", seq_len(ncol(neighborhood_basis))),
    colnames(interaction)
  )
  x
}

default_lambda_grid <- function() {
  exp(seq(log(100), log(1e-4), length.out = 100))
}

cross_validate_ridge <- function(
    panel,
    lambda_grid = default_lambda_grid(),
    include_interactions = FALSE) {
  model_type <- if (include_interactions) {
    "Season-space Ridge"
  } else {
    "Additive Ridge"
  }
  folds <- make_rolling_folds(panel)
  fold_results <- purrr::map_dfr(folds, function(fold_data) {
    recipe <- make_basis_recipe(fold_data$train)
    x_train <- make_design_matrix(
      fold_data$train,
      recipe,
      include_interactions = include_interactions
    )
    x_validation <- make_design_matrix(
      fold_data$validation,
      recipe,
      include_interactions = include_interactions
    )
    y_train <- log1p(fold_data$train$theft_count)
    ridge <- glmnet::glmnet(
      x_train,
      y_train,
      alpha = 0,
      lambda = lambda_grid,
      standardize = TRUE
    )
    validation_log <- predict(
      ridge,
      newx = x_validation,
      s = lambda_grid
    )
    rmse <- apply(validation_log, 2, function(prediction) {
      prediction <- pmax(0, expm1(prediction))
      sqrt(mean((fold_data$validation$theft_count - prediction)^2))
    })
    tibble::tibble(
      fold = fold_data$fold,
      train_end = fold_data$train_end,
      validation_year = fold_data$validation_year,
      lambda = lambda_grid,
      RMSE = rmse
    )
  })
  summary <- fold_results |>
    dplyr::group_by(lambda) |>
    dplyr::summarise(
      mean_rmse = mean(RMSE),
      sd_rmse = stats::sd(RMSE),
      .groups = "drop"
    ) |>
    dplyr::mutate(model = model_type) |>
    dplyr::arrange(dplyr::desc(lambda))
  list(
    model_type = model_type,
    folds = folds,
    fold_results = dplyr::mutate(fold_results, model = model_type),
    summary = summary,
    selected_lambda = summary$lambda[which.min(summary$mean_rmse)]
  )
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

fit_ridge_candidate <- function(
    tuning_panel,
    test,
    lambda_grid = default_lambda_grid(),
    include_interactions = FALSE) {
  cv <- cross_validate_ridge(
    tuning_panel,
    lambda_grid,
    include_interactions = include_interactions
  )
  recipe <- make_basis_recipe(tuning_panel)
  x_final <- make_design_matrix(
    tuning_panel,
    recipe,
    include_interactions = include_interactions
  )
  x_test <- make_design_matrix(
    test,
    recipe,
    include_interactions = include_interactions
  )
  selected_lambda <- cv$selected_lambda
  ridge_model <- glmnet::glmnet(
    x_final,
    log1p(tuning_panel$theft_count),
    alpha = 0,
    lambda = selected_lambda,
    standardize = TRUE
  )
  prediction <- pmax(
    0,
    expm1(as.numeric(predict(
      ridge_model,
      newx = x_test,
      s = selected_lambda
    )))
  )
  list(
    model = cv$model_type,
    include_interactions = include_interactions,
    cv = cv,
    recipe = recipe,
    ridge_model = ridge_model,
    selected_lambda = selected_lambda,
    prediction = prediction,
    metrics = metric_frame(
      test$theft_count,
      prediction,
      cv$model_type
    )
  )
}

fit_models <- function(
    splits,
    recipe = NULL,
    lambda_grid = default_lambda_grid()) {
  train <- splits$train
  validation <- splits$validation
  test <- splits$test
  tuning_panel <- dplyr::bind_rows(train, validation)

  candidate_specs <- tibble::tibble(
    model = c("Additive Ridge", "Season-space Ridge"),
    include_interactions = c(FALSE, TRUE)
  )
  candidate_fits <- purrr::map(
    seq_len(nrow(candidate_specs)),
    function(i) fit_ridge_candidate(
      tuning_panel,
      test,
      lambda_grid,
      include_interactions = candidate_specs$include_interactions[i]
    )
  )
  cv_comparison <- purrr::map_dfr(candidate_fits, function(x) {
    best <- x$cv$summary[which.min(x$cv$summary$mean_rmse), ]
    dplyr::select(best, model, lambda, mean_rmse, sd_rmse)
  })
  primary_model <- cv_comparison$model[which.min(cv_comparison$mean_rmse)]
  primary_fit <- candidate_fits[[match(primary_model, candidate_specs$model)]]
  additive_fit <- candidate_fits[[1]]
  selected_lambda <- additive_fit$selected_lambda
  final_recipe <- make_basis_recipe(tuning_panel)
  x_final <- make_design_matrix(tuning_panel, final_recipe)
  x_test <- make_design_matrix(test, final_recipe)
  y_final <- log1p(tuning_panel$theft_count)
  actual_test <- test$theft_count

  global_prediction <- rep(
    mean(tuning_panel$theft_count),
    nrow(test)
  )
  neighborhood_means <- tuning_panel |>
    dplyr::group_by(neighborhood) |>
    dplyr::summarise(value = mean(theft_count), .groups = "drop")
  neighborhood_prediction <- test |>
    dplyr::select(neighborhood) |>
    dplyr::left_join(neighborhood_means, by = "neighborhood") |>
    dplyr::pull(value)

  ols_coefficients <- fit_ols(x_final, y_final)
  ols_prediction <- pmax(
    0,
    expm1(predict_ols(ols_coefficients, x_test))
  )

  ridge_final <- additive_fit$ridge_model
  ridge_prediction <- additive_fit$prediction

  metrics <- dplyr::bind_rows(
    metric_frame(actual_test, global_prediction, "Global mean"),
    metric_frame(actual_test, neighborhood_prediction, "Neighborhood mean"),
    metric_frame(actual_test, ols_prediction, "Basis OLS"),
    metric_frame(actual_test, ridge_prediction, "Basis Ridge")
  )
  predictions <- test |>
    dplyr::transmute(
      month = as.Date(month),
      year,
      neighborhood,
      lon,
      lat,
      actual = theft_count,
      predicted = ridge_prediction,
      residual = actual - predicted,
      global_mean = global_prediction,
      neighborhood_mean = neighborhood_prediction,
      basis_ols = ols_prediction,
      additive_ridge = candidate_fits[[1]]$prediction,
      season_space_ridge = candidate_fits[[2]]$prediction
    )
  list(
    metrics = metrics,
    test_predictions = predictions,
    selected_lambda = selected_lambda,
    validation_rmse = min(additive_fit$cv$summary$mean_rmse),
    cv_results = additive_fit$cv$fold_results,
    cv_summary = additive_fit$cv$summary,
    cv_folds = additive_fit$cv$folds,
    cv_comparison = cv_comparison,
    candidate_fits = candidate_fits,
    primary_model = primary_model,
    primary_fit = primary_fit,
    recipe = final_recipe,
    final_training_years = sort(unique(tuning_panel$year)),
    ridge_model = ridge_final,
    ols_coefficients = ols_coefficients
  )
}

save_stacked_plots <- function(
    top,
    bottom,
    path,
    width = 9,
    height = 5.4,
    dpi = 180) {
  grDevices::png(
    path,
    width = width,
    height = height,
    units = "in",
    res = dpi,
    bg = "white"
  )
  on.exit(grDevices::dev.off(), add = TRUE)
  grid::grid.newpage()
  layout <- grid::grid.layout(
    nrow = 2,
    ncol = 1,
    heights = grid::unit(c(0.46, 0.54), "null")
  )
  grid::pushViewport(grid::viewport(layout = layout))
  print(
    top,
    vp = grid::viewport(layout.pos.row = 1, layout.pos.col = 1)
  )
  print(
    bottom,
    vp = grid::viewport(layout.pos.row = 2, layout.pos.col = 1)
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

  p_cv <- ggplot2::ggplot(
    fit$cv_summary,
    ggplot2::aes(lambda, mean_rmse)
  ) +
    ggplot2::geom_ribbon(
      ggplot2::aes(
        ymin = mean_rmse - sd_rmse,
        ymax = mean_rmse + sd_rmse
      ),
      fill = "#BFE3E3",
      alpha = 0.55
    ) +
    ggplot2::geom_line(color = "#007F82", linewidth = 1) +
    ggplot2::geom_vline(
      xintercept = fit$selected_lambda,
      color = "#D95F02",
      linetype = "dashed"
    ) +
    ggplot2::scale_x_log10() +
    ggplot2::labs(
      title = "Rolling-origin Ridge tuning",
      subtitle = paste0(
        "Five expanding validation years; selected λ = ",
        format(signif(fit$selected_lambda, 3), scientific = FALSE),
        "; ribbon = ±1 SD"
      ),
      x = "Lambda (log scale)",
      y = "Mean validation RMSE"
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
      "08_residual_map.png",
      "09_rolling_cross_validation.png"
    )
  )
  purrr::walk2(
    list(p5, p7, p8, p_cv),
    paths[c(1, 3, 4, 5)],
    ~ggplot2::ggsave(
      .y, .x, width = 9, height = 5.4, dpi = 180, bg = "white"
    )
  )
  save_stacked_plots(p_cv, p6, paths[2])
  stats::setNames(
    normalizePath(paths),
    c(
      "basis", "comparison", "prediction", "residual",
      "cross_validation"
    )
  )
}
