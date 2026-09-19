# hotspot_analysis.R ------------------------------------------------------
# Hourly hotspot analysis: when and where bicycle thefts concentrate.
#
# This is the "operational extension" of the monthly prediction model. It
# uses the fine-grained OCC_HOUR and PREMISES_TYPE fields (only present in
# the refreshed official dataset) for a descriptive question:
#
#   "At which hours of the day, and in which types of premises, are bicycle
#    thefts most likely?"
#
# Outputs (written to output/figures/):
#   - 06_hourly_pattern.png       : theft count by hour of day
#   - 07_premises_by_period.png   : premises-type mix by time-of-day period
#
# Run from the project root with:
#   Rscript src/hotspot_analysis.R

library(dplyr)
library(ggplot2)
library(readr)

# Locate the project root from this script's own path, then load config.
script_path <- (function() {
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- args[grepl("^--file=", args)]
  if (length(file_arg)) {
    return(normalizePath(gsub("~+~", " ", sub("^--file=", "", file_arg[1]), fixed=TRUE)))
  }
  normalizePath(getwd())
})()
ROOT <- normalizePath(file.path(dirname(script_path), ".."), mustWork = TRUE)
source(file.path(ROOT, "src", "config.R"))
source(file.path(ROOT, "src", "prepare_data.R"))

# --- Load the enhanced dataset ------------------------------------------
load_enhanced <- function(path) {
  validate_conversion(path)
  readr::read_csv(path, show_col_types = FALSE, na = c("", "NA")) |>
    dplyr::mutate(
      date = as.Date(date),
      hour = as.integer(hour),
      year = lubridate::year(date)
    ) |>
    dplyr::filter(hour >= 0, hour <= 23, year >= 2014, year <= 2025)
}

project_theme <- function() {
  ggplot2::theme_minimal(base_size = 12) +
    ggplot2::theme(
      plot.title = ggplot2::element_text(face = "bold", size = 15),
      plot.subtitle = ggplot2::element_text(color = "#425466"),
      panel.grid.minor = ggplot2::element_blank()
    )
}

# --- Figure 1: theft count by hour of day --------------------------------
plot_hourly_pattern <- function(d) {
  hourly <- d |> dplyr::count(hour)
  ggplot2::ggplot(hourly, ggplot2::aes(hour, n)) +
    ggplot2::geom_col(fill = "#1B4965", width = 0.85) +
    ggplot2::scale_x_continuous(breaks = seq(0, 23, by = 2)) +
    ggplot2::labs(
      title = "Bicycle-theft records by hour of day (2014\u20132025)",
      subtitle = "Occurrence-hour record counts; descriptive, not an intervention-effect estimate",
      x = "Hour of day", y = "Published record rows"
    ) +
    project_theme()
}

# --- Figure 2: premises-type mix by time-of-day period -------------------
plot_premises_by_period <- function(d) {
  d <- d |>
    dplyr::mutate(period = dplyr::case_when(
      hour %in% 0:5 ~ "00\u201305",
      hour %in% 6:11 ~ "06\u201311",
      hour %in% 12:17 ~ "12\u201317",
      hour %in% 18:23 ~ "18\u201323"
    )) |>
    dplyr::count(period, premises_type) |>
    dplyr::group_by(period) |>
    dplyr::mutate(pct = n / sum(n) * 100) |>
    dplyr::ungroup()

  ggplot2::ggplot(
    d, ggplot2::aes(period, pct, fill = premises_type)
  ) +
    ggplot2::geom_col(position = "fill", width = 0.7) +
    ggplot2::scale_y_continuous(labels = scales::percent) +
    ggplot2::scale_fill_viridis_d(option = "D", end = 0.9) +
    ggplot2::labs(
      title = "Premises type by time of day",
      subtitle = "Outdoor theft dominates by day; apartment/house theft dominates overnight",
      x = "Hour of day", y = "Share of thefts", fill = "Premises type"
    ) +
    project_theme()
}

main <- function() {
  paths <- project_paths(ROOT)
  dir.create(paths$figure_dir, recursive=TRUE, showWarnings=FALSE)
  d <- load_enhanced(paths$enhanced_data)

  ggplot2::ggsave(
    file.path(paths$figure_dir, "06_hourly_pattern.png"),
    plot_hourly_pattern(d), width = 9, height = 5.4, dpi = 180, bg = "white"
  )
  ggplot2::ggsave(
    file.path(paths$figure_dir, "07_premises_by_period.png"),
    plot_premises_by_period(d), width = 9, height = 5.4, dpi = 180, bg = "white"
  )

  # Print a concise operational summary to stdout.
  peak <- d |> dplyr::count(hour) |> dplyr::arrange(dplyr::desc(n)) |>
    dplyr::slice(1:3)
  message("Top hours (citywide):")
  message(paste0("  ", peak$hour, ":00  \u2014  ", peak$n, " thefts", collapse = "\n"))
  message("\nWritten: 06_hourly_pattern.png, 07_premises_by_period.png")
}

if (sys.nframe() == 0L) {
  main()
}
