extract_seasonal_coefficients <- function(ridge_model, lambda) {
  fitted <- as.matrix(stats::coef(ridge_model, s = lambda))[, 1]
  wanted <- c("sin1", "cos1", "sin2", "cos2")
  stats::setNames(as.numeric(fitted[wanted]), wanted)
}

summarise_seasonal_cycle <- function(coefficients) {
  required <- c("sin1", "cos1", "sin2", "cos2")
  stopifnot(all(required %in% names(coefficients)))
  month <- 1:12
  seasonal_log <-
    coefficients["sin1"] * sin(2 * pi * month / 12) +
    coefficients["cos1"] * cos(2 * pi * month / 12) +
    coefficients["sin2"] * sin(4 * pi * month / 12) +
    coefficients["cos2"] * cos(4 * pi * month / 12)
  monthly <- tibble::tibble(
    month = month,
    month_label = month.abb,
    seasonal_log = as.numeric(seasonal_log),
    seasonal_multiplier = exp(seasonal_log)
  )
  list(
    coefficients = tibble::tibble(
      term = required,
      estimate = as.numeric(coefficients[required])
    ),
    monthly = monthly,
    summary = tibble::tibble(
      annual_amplitude = as.numeric(sqrt(
        coefficients["sin1"]^2 + coefficients["cos1"]^2
      )),
      semiannual_amplitude = as.numeric(sqrt(
        coefficients["sin2"]^2 + coefficients["cos2"]^2
      )),
      peak_month = month[which.max(seasonal_log)],
      trough_month = month[which.min(seasonal_log)],
      peak_to_trough_ratio = exp(max(seasonal_log) - min(seasonal_log))
    )
  )
}

build_interaction_model_comparison <- function(model_fit) {
  cv_metrics <- model_fit$cv_comparison |>
    dplyr::transmute(
      model,
      selected_lambda = lambda,
      mean_cv_rmse = mean_rmse,
      sd_cv_rmse = sd_rmse
    )
  test_metrics <- purrr::map_dfr(
    model_fit$candidate_fits,
    function(candidate) {
      candidate$metrics |>
        dplyr::transmute(
          model,
          test_mae = MAE,
          test_rmse = RMSE,
          test_r2 = R2
        )
    }
  )
  cv_selected_model <- cv_metrics$model[which.min(cv_metrics$mean_cv_rmse)]
  cv_metrics |>
    dplyr::left_join(test_metrics, by = "model") |>
    dplyr::mutate(selected_by_cv = model == cv_selected_model)
}

make_fitted_seasonal_cycle_plot <- function(seasonal_analysis) {
  ggplot2::ggplot(
    seasonal_analysis$monthly,
    ggplot2::aes(month, seasonal_multiplier)
  ) +
    ggplot2::geom_hline(
      yintercept = 1,
      color = "#9AA5AA",
      linewidth = 0.4
    ) +
    ggplot2::geom_line(color = "#0B7C83", linewidth = 1.2) +
    ggplot2::geom_point(color = "#0B7C83", size = 2.2) +
    ggplot2::scale_x_continuous(breaks = 1:12, labels = month.abb) +
    ggplot2::labs(
      title = "Estimated coefficients imply a July seasonal peak",
      subtitle = paste(
        "Seasonal multiplier for 1 + count,",
        "holding other components fixed"
      ),
      x = NULL,
      y = "Seasonal multiplier"
    ) +
    handbook_theme()
}

make_interaction_model_comparison_plot <- function(comparison) {
  selected_model <- comparison$model[comparison$selected_by_cv]
  stopifnot(length(selected_model) == 1L)
  plot_data <- comparison |>
    dplyr::select(model, mean_cv_rmse, test_rmse) |>
    tidyr::pivot_longer(
      c(mean_cv_rmse, test_rmse),
      names_to = "evaluation",
      values_to = "rmse"
    ) |>
    dplyr::mutate(
      evaluation = factor(
        evaluation,
        levels = c("mean_cv_rmse", "test_rmse"),
        labels = c("Mean rolling-CV", "Untouched 2023")
      )
    )

  ggplot2::ggplot(
    plot_data,
    ggplot2::aes(rmse, model, color = evaluation, shape = evaluation)
  ) +
    ggplot2::geom_point(size = 3.4) +
    ggplot2::scale_color_manual(values = c(
      "Mean rolling-CV" = "#0B7C83",
      "Untouched 2023" = "#D95F02"
    )) +
    ggplot2::scale_shape_manual(values = c(
      "Mean rolling-CV" = 16,
      "Untouched 2023" = 17
    )) +
    ggplot2::labs(
      title = "Candidate model RMSE comparison",
      subtitle = paste0(
        "Minimum rolling-CV RMSE and untouched 2023 RMSE; CV-selected: ",
        selected_model
      ),
      x = "RMSE in monthly neighborhood theft counts",
      y = NULL,
      color = NULL,
      shape = NULL,
      caption = "Model choice uses minimum mean rolling-CV RMSE only."
    ) +
    handbook_theme() +
    ggplot2::theme(legend.position = "top")
}

make_teacher_feedback_plots <- function(
    seasonal_analysis,
    interaction_comparison,
    figure_dir) {
  dir.create(figure_dir, recursive = TRUE, showWarnings = FALSE)
  paths <- file.path(
    figure_dir,
    c(
      "10_fitted_seasonal_cycle.png",
      "11_interaction_model_comparison.png"
    )
  )
  plots <- list(
    make_fitted_seasonal_cycle_plot(seasonal_analysis),
    make_interaction_model_comparison_plot(interaction_comparison)
  )
  purrr::walk2(
    plots,
    paths,
    ~ggplot2::ggsave(
      .y, .x, width = 9, height = 5.4, dpi = 180, bg = "white"
    )
  )
  stats::setNames(
    normalizePath(paths),
    c("seasonal_cycle", "interaction_comparison")
  )
}

prepare_primary_prediction_analysis <- function(model_fit, test_rows) {
  prediction <- as.numeric(model_fit$primary_fit$prediction)
  stopifnot(length(prediction) == nrow(test_rows))
  month_year <- as.integer(format(as.Date(test_rows$month), "%Y"))
  if (any(test_rows$year != 2023L) || any(month_year != 2023L)) {
    stop("Primary figure data must contain untouched 2023 rows only.")
  }
  stopifnot(identical(model_fit$primary_fit$model, model_fit$primary_model) ||
    is.null(model_fit$primary_fit$model))
  predictions <- test_rows |>
    dplyr::transmute(
      month = as.Date(month),
      year,
      neighborhood,
      lon,
      lat,
      actual = theft_count,
      predicted = prediction,
      residual = actual - predicted
    )
  monthly <- predictions |>
    dplyr::group_by(month) |>
    dplyr::summarise(
      Observed = sum(actual),
      Predicted = sum(predicted),
      .groups = "drop"
    ) |>
    tidyr::pivot_longer(
      c(Observed, Predicted),
      names_to = "series",
      values_to = "thefts"
    ) |>
    dplyr::mutate(
      series = factor(series, levels = c("Observed", "Predicted"))
    )
  residuals <- predictions |>
    dplyr::group_by(neighborhood, lon, lat) |>
    dplyr::summarise(
      mean_residual = mean(residual),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      error_magnitude = abs(mean_residual),
      residual_direction = dplyr::case_when(
        mean_residual > 0 ~ "Under-prediction",
        mean_residual < 0 ~ "Over-prediction",
        TRUE ~ "Exact"
      )
    )
  list(
    model = model_fit$primary_model,
    predictions = predictions,
    monthly = monthly,
    residuals = residuals
  )
}

make_primary_observed_vs_predicted_plot <- function(primary_analysis) {
  ggplot2::ggplot(
    primary_analysis$monthly,
    ggplot2::aes(
      month,
      thefts,
      color = series,
      linetype = series,
      shape = series
    )
  ) +
    ggplot2::geom_line(linewidth = 1.15) +
    ggplot2::geom_point(size = 2.2) +
    ggplot2::scale_color_manual(values = c(
      Observed = "#1B4965",
      Predicted = "#D95F02"
    )) +
    ggplot2::scale_linetype_manual(values = c(
      Observed = "solid",
      Predicted = "dashed"
    )) +
    ggplot2::scale_shape_manual(values = c(
      Observed = 16,
      Predicted = 17
    )) +
    ggplot2::labs(
      title = "Observed and CV-selected predictions in 2023",
      subtitle = paste0(
        primary_analysis$model,
        "; selected by minimum mean rolling-CV RMSE"
      ),
      x = NULL,
      y = "Reported thefts",
      color = NULL,
      linetype = NULL,
      shape = NULL,
      caption = paste(
        "Predictions are summed from neighborhood-level estimates;",
        "2023 is used only for evaluation."
      )
    ) +
    handbook_theme() +
    ggplot2::theme(legend.position = "top")
}

make_primary_residual_map_plot <- function(
    primary_analysis,
    boundaries = NULL) {
  residuals <- primary_analysis$residuals
  limit <- max(abs(residuals$mean_residual))
  plot <- ggplot2::ggplot(
    residuals,
    ggplot2::aes(
      lon,
      lat,
      color = mean_residual,
      size = error_magnitude,
      shape = residual_direction
    )
  )
  if (!is.null(boundaries)) {
    plot <- plot +
      ggplot2::geom_sf(
        data = boundaries,
        fill = "#EEF2F4",
        color = "white",
        linewidth = 0.18,
        inherit.aes = FALSE
      ) +
      ggplot2::geom_sf(
        data = dplyr::summarise(boundaries),
        fill = NA,
        color = "#7B8790",
        linewidth = 0.5,
        inherit.aes = FALSE
      )
  }
  plot +
    ggplot2::geom_point(alpha = 0.88) +
    ggplot2::scale_color_gradient2(
      low = "#2166AC",
      mid = "white",
      high = "#B2182B",
      midpoint = 0,
      limits = c(-limit, limit)
    ) +
    ggplot2::scale_size_continuous(range = c(1, 8)) +
    ggplot2::scale_shape_manual(values = c(
      "Over-prediction" = 17,
      "Exact" = 4,
      "Under-prediction" = 16
    )) +
    ggplot2::coord_sf(datum = NA, expand = FALSE) +
    ggplot2::labs(
      title = "2023 residuals for the CV-selected model",
      subtitle = paste0(
        primary_analysis$model,
        "; positive residuals mean observed thefts exceeded predictions"
      ),
      x = NULL,
      y = NULL,
      color = "Mean residual",
      size = "Absolute residual",
      shape = "Direction",
      caption = paste(
        "Selected by minimum mean rolling-CV RMSE;",
        "City of Toronto historical 140-neighbourhood boundaries."
      )
    ) +
    handbook_theme() +
    ggplot2::theme(
      axis.text = ggplot2::element_blank(),
      axis.ticks = ggplot2::element_blank(),
      panel.grid = ggplot2::element_blank()
    )
}

make_primary_model_plots <- function(
    primary_analysis,
    figure_dir,
    boundaries = NULL) {
  dir.create(figure_dir, recursive = TRUE, showWarnings = FALSE)
  paths <- file.path(
    figure_dir,
    c(
      "12_primary_observed_vs_predicted.png",
      "13_primary_residual_map.png"
    )
  )
  plots <- list(
    make_primary_observed_vs_predicted_plot(primary_analysis),
    make_primary_residual_map_plot(primary_analysis, boundaries)
  )
  purrr::walk2(
    plots,
    paths,
    ~ggplot2::ggsave(
      .y, .x, width = 9, height = 5.4, dpi = 180, bg = "white"
    )
  )
  stats::setNames(
    normalizePath(paths),
    c("prediction", "residual")
  )
}
