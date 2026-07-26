handbook_theme <- function() {
  ggplot2::theme_minimal(base_size = 12) +
    ggplot2::theme(
      plot.title = ggplot2::element_text(face = "bold", size = 15),
      plot.subtitle = ggplot2::element_text(color = "#425466"),
      panel.grid.minor = ggplot2::element_blank(),
      legend.position = "right"
    )
}

make_task1_plots <- function(panel, figure_dir) {
  dir.create(figure_dir, recursive = TRUE, showWarnings = FALSE)
  panel <- panel |>
    dplyr::mutate(month = as.Date(month))

  monthly <- panel |>
    dplyr::group_by(month) |>
    dplyr::summarise(thefts = sum(theft_count), .groups = "drop") |>
    dplyr::arrange(month) |>
    dplyr::mutate(
      trend_12 = as.numeric(stats::filter(
        thefts, rep(1 / 12, 12), sides = 1
      ))
    )
  seasonal <- panel |>
    dplyr::group_by(year, month_of_year) |>
    dplyr::summarise(thefts = sum(theft_count), .groups = "drop")
  hotspots <- panel |>
    dplyr::group_by(neighborhood, lon, lat) |>
    dplyr::summarise(mean_monthly = mean(theft_count), .groups = "drop")
  top_names <- hotspots |>
    dplyr::slice_max(mean_monthly, n = 25) |>
    dplyr::pull(neighborhood)
  heat <- panel |>
    dplyr::filter(neighborhood %in% top_names) |>
    dplyr::mutate(
      neighborhood = stats::reorder(
        neighborhood, theft_count, FUN = mean
      )
    )

  p1 <- ggplot2::ggplot(monthly, ggplot2::aes(month, thefts)) +
    ggplot2::geom_line(color = "#7A8A99", linewidth = 0.55) +
    ggplot2::geom_line(
      ggplot2::aes(y = trend_12),
      color = "#0B6E75", linewidth = 1.2, na.rm = TRUE
    ) +
    ggplot2::labs(
      title = "Bicycle thefts over time",
      subtitle = "Monthly counts and trailing 12-month mean, 2014–2023",
      x = NULL, y = "Reported thefts",
      caption = "Source: bicycle.csv; quarter derived from date"
    ) +
    handbook_theme()

  p2 <- ggplot2::ggplot(
    seasonal,
    ggplot2::aes(factor(month_of_year, levels = 1:12), thefts)
  ) +
    ggplot2::geom_boxplot(
      fill = "#8FD3C7", color = "#0B6E75", outlier.alpha = 0.45
    ) +
    ggplot2::labs(
      title = "Seasonal distribution of bicycle thefts",
      subtitle = "Each box summarizes the same calendar month across 10 years",
      x = "Month of year", y = "Reported thefts"
    ) +
    ggplot2::scale_x_discrete(labels = month.abb) +
    handbook_theme()

  p3 <- ggplot2::ggplot(
    hotspots,
    ggplot2::aes(lon, lat, size = mean_monthly, color = mean_monthly)
  ) +
    ggplot2::geom_point(alpha = 0.82) +
    ggplot2::scale_color_viridis_c(option = "C", end = 0.92) +
    ggplot2::scale_size_continuous(range = c(1.5, 10)) +
    ggplot2::coord_equal() +
    ggplot2::labs(
      title = "Long-run neighborhood theft hotspots",
      subtitle = "Points are neighborhood centroids; size and color show mean monthly count",
      x = "Longitude", y = "Latitude",
      color = "Mean monthly", size = "Mean monthly"
    ) +
    handbook_theme()

  p4 <- ggplot2::ggplot(
    heat,
    ggplot2::aes(month, neighborhood, fill = theft_count)
  ) +
    ggplot2::geom_tile() +
    ggplot2::scale_fill_viridis_c(option = "B", trans = "sqrt") +
    ggplot2::labs(
      title = "Space–time heatmap for the 25 highest-count neighborhoods",
      subtitle = "Square-root color scaling preserves variation without hiding peaks",
      x = NULL, y = NULL, fill = "Monthly thefts"
    ) +
    handbook_theme() +
    ggplot2::theme(axis.text.y = ggplot2::element_text(size = 7))

  paths <- file.path(
    figure_dir,
    c(
      "01_monthly_trend.png",
      "02_seasonality.png",
      "03_spatial_hotspots.png",
      "04_spacetime_heatmap.png"
    )
  )
  purrr::walk2(
    list(p1, p2, p3, p4),
    paths,
    ~ggplot2::ggsave(
      .y, .x, width = 9, height = 5.4, dpi = 180, bg = "white"
    )
  )
  stats::setNames(
    normalizePath(paths),
    c("trend", "seasonality", "hotspots", "heatmap")
  )
}
