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
