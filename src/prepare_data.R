# prepare_data.R ----------------------------------------------------------
# Data loading, quality auditing, and monthly panel construction.
#
# The raw dataset records individual bicycle theft incidents with their
# date, quarter, day of week, neighbourhood, cost, location type, and
# coordinates. We aggregate these incidents into a balanced monthly panel
# of theft counts per neighbourhood, which is the modelling unit.

# Read the raw CSV and validate its schema, then parse date columns and
# derive a "derived_quarter" to cross-check the supplied quarter field.
read_bicycle <- function(path) {
  x <- readr::read_csv(path, show_col_types = FALSE)
  if (!all(raw_columns %in% names(x))) {
    stop(
      "Missing required columns: ",
      paste(setdiff(raw_columns, names(x)), collapse = ", ")
    )
  }
  x |>
    dplyr::mutate(
      date = as.Date(date),
      derived_quarter = paste0(
        lubridate::year(date), "Q", lubridate::quarter(date)
      ),
      supplied_quarter_date = as.Date(quarter),
      supplied_quarter = paste0(
        lubridate::year(supplied_quarter_date), "Q",
        lubridate::quarter(supplied_quarter_date)
      )
    )
}

# Produce a small audit table summarising basic data-quality indicators.
# Values of interest: missing cells, exact duplicate rows, quarter
# inconsistencies, and implausible bike_cost values.
audit_bicycle <- function(raw) {
  tibble::tibble(
    metric = c(
      "rows", "original_columns", "missing_cells", "exact_duplicate_rows",
      "neighborhoods", "unique_dates", "quarter_mismatch_rows",
      "zero_or_negative_bike_cost", "bike_cost_over_10000"
    ),
    value = c(
      nrow(raw),
      length(raw_columns),
      sum(is.na(raw[, raw_columns])),
      sum(duplicated(raw[, raw_columns])),
      dplyr::n_distinct(raw$neighborhood),
      dplyr::n_distinct(raw$date),
      sum(raw$derived_quarter != raw$supplied_quarter),
      sum(raw$bike_cost <= 0),
      sum(raw$bike_cost > 10000)
    )
  )
}

# Aggregate raw incidents into a balanced monthly panel.
#
# The panel has one row per (neighbourhood, month) combination. Months with
# no recorded thefts are filled with 0 so every neighbourhood has the same
# 120 monthly observations (2014-01 through 2023-12). Neighbourhood centroid
# coordinates are attached for spatial modelling.
make_monthly_panel <- function(raw) {
  coordinates <- raw |>
    dplyr::group_by(neighborhood) |>
    dplyr::summarise(
      lon = stats::median(long),
      lat = stats::median(lat),
      .groups = "drop"
    )

  months <- seq(as.Date("2014-01-01"), as.Date("2023-12-01"), by = "month")
  panel <- raw |>
    dplyr::mutate(month = lubridate::floor_date(date, "month")) |>
    dplyr::count(neighborhood, month, name = "theft_count") |>
    tidyr::complete(
      neighborhood = unique(raw$neighborhood),
      month = months,
      fill = list(theft_count = 0L)
    ) |>
    dplyr::left_join(coordinates, by = "neighborhood") |>
    dplyr::arrange(month, neighborhood) |>
    dplyr::mutate(
      # Integer month index from 1 (2014-01) to 120 (2023-12).
      time_index = as.integer(
        (lubridate::year(month) - 2014) * 12 + lubridate::month(month)
      ),
      month_of_year = lubridate::month(month),
      year = lubridate::year(month)
    )
  list(panel = panel, coordinates = coordinates)
}
