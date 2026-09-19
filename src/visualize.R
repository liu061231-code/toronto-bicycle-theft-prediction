# visualize.R ------------------------------------------------------------
# Diagnostic and EDA figures for the prediction project.
#
# Figures are kept minimal and directly tied to an analytical conclusion:
#   - monthly citywide trend + seasonality (EDA)
#   - spatial hotspot distribution (EDA)
#   - observed vs predicted (final model)
#   - residual distribution (final model)

project_theme <- function() {
  ggplot2::theme_minimal(base_size = 12) +
    ggplot2::theme(
      plot.title = ggplot2::element_text(face = "bold", size = 15),
      plot.subtitle = ggplot2::element_text(color = "#425466"),
      panel.grid.minor = ggplot2::element_blank(),
      legend.position = "right"
    )
}

# EDA: monthly citywide totals with a trailing 12-month mean.
plot_monthly_trend <- function(panel) {
  monthly <- panel |>
    dplyr::mutate(month = as.Date(month)) |>
    dplyr::group_by(month) |>
    dplyr::summarise(thefts = sum(theft_count), .groups = "drop") |>
    dplyr::arrange(month) |>
    dplyr::mutate(
      trend_12 = as.numeric(stats::filter(thefts, rep(1 / 12, 12), sides = 1))
    )
  ggplot2::ggplot(monthly, ggplot2::aes(month, thefts)) +
    ggplot2::geom_line(color = "#7A8A99", linewidth = 0.55) +
    ggplot2::geom_line(
      ggplot2::aes(y = trend_12), color = "#0B6E75", linewidth = 1.2,
      na.rm = TRUE
    ) +
    ggplot2::labs(
      title = "Reported bicycle thefts in Toronto, 2014\u20132025",
      subtitle = "Monthly citywide totals with a trailing 12-month mean",
      x = NULL, y = "Reported thefts"
    ) +
    project_theme()
}

# EDA: seasonal boxplot of thefts by calendar month.
plot_seasonality <- function(panel) {
  seasonal <- panel |>
    dplyr::group_by(year, month_of_year) |>
    dplyr::summarise(thefts = sum(theft_count), .groups = "drop")
  ggplot2::ggplot(
    seasonal,
    ggplot2::aes(factor(month_of_year, levels = 1:12), thefts)
  ) +
    ggplot2::geom_boxplot(
      fill = "#8FD3C7", color = "#0B6E75", outlier.alpha = 0.45
    ) +
    ggplot2::labs(
      title = "Seasonal pattern of bicycle thefts",
      subtitle = "Each box summarises the same calendar month across 12 years",
      x = "Month", y = "Reported thefts"
    ) +
    ggplot2::scale_x_discrete(labels = month.abb) +
    project_theme()
}

# EDA: spatial distribution of long-run mean monthly thefts.
# Unknown-area (NSA) rows have NA coordinates and are excluded so the map is
# not distorted by a single (0,0) point.
plot_spatial_hotspots <- function(panel) {
  hotspots <- panel |>
    dplyr::filter(!is.na(.data$lon), !is.na(.data$lat)) |>
    dplyr::group_by(neighborhood, lon, lat) |>
    dplyr::summarise(mean_monthly = mean(theft_count), .groups = "drop")
  ggplot2::ggplot(
    hotspots, ggplot2::aes(lon, lat, size = mean_monthly, color = mean_monthly)
  ) +
    ggplot2::geom_point(alpha = 0.82) +
    ggplot2::scale_color_viridis_c(option = "C", end = 0.92) +
    ggplot2::scale_size_continuous(range = c(1.5, 10)) +
    ggplot2::coord_equal() +
    ggplot2::labs(
      title = "Long-run neighbourhood theft hotspots",
      subtitle = "Points are neighbourhood centroids; colour/size show mean monthly count",
      x = "Longitude", y = "Latitude",
      color = "Mean monthly", size = "Mean monthly"
    ) +
    project_theme()
}

# Selected model: observed vs predicted in the 2025 retrospective window.
plot_observed_vs_predicted <- function(predictions) {
  ggplot2::ggplot(
    predictions, ggplot2::aes(predicted, actual)
  ) +
    ggplot2::geom_abline(slope = 1, intercept = 0, color = "#D95F02",
                         linewidth = 0.8) +
    ggplot2::geom_point(alpha = 0.35, size = 1.6, color = "#1B4965") +
    ggplot2::coord_equal() +
    ggplot2::labs(
      title = "Observed vs predicted (2025 retrospective)",
      subtitle = "Each point is one neighbourhood-month; the solid line is perfect prediction",
      x = "Predicted record rows", y = "Observed record rows"
    ) +
    project_theme()
}

# Final model: residual distribution (histogram) to check for bias.
plot_residual_distribution <- function(predictions) {
  ggplot2::ggplot(predictions, ggplot2::aes(residual)) +
    ggplot2::geom_histogram(
      fill = "#8FD3C7", color = "#0B6E75", bins = 60
    ) +
    ggplot2::geom_vline(xintercept = 0, color = "#D95F02", linewidth = 0.8) +
    ggplot2::labs(
      title = "Distribution of prediction residuals (2025)",
      subtitle = "Residual = observed \u2212 predicted; centred near zero indicates low bias",
      x = "Residual (record rows)", y = "Count"
    ) +
    project_theme()
}
