# prepare_data.R ----------------------------------------------------------
# Data loading, quality auditing, and monthly panel construction.
#
# The raw dataset records individual bicycle theft incidents with their
# date, neighbourhood, cost, location type, and coordinates. We aggregate
# these incidents into a balanced monthly panel of theft counts per
# neighbourhood, which is the modelling unit.
#
# Since the dataset was refreshed (now spanning 2014-2026), the panel also
# carries derived contextual features -- the share of thefts occurring
# outdoors and in commercial premises, and the number of police divisions
# involved -- which are aggregated per (neighbourhood, month) and used as
# extra predictors.

# Read the raw CSV and validate its schema, then parse date columns.
read_bicycle <- function(path) {
  x <- readr::read_csv(path, show_col_types = FALSE, na = c("", "NA"))
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
      sum(raw$bike_cost <= 0, na.rm = TRUE),
      sum(raw$bike_cost > 10000, na.rm = TRUE)
    )
  )
}

# The study period: from the first stable reporting year (2014) through the
# last complete year available. 2026 is excluded from the modelling span
# because it is still in progress (only ~6 months of records).
START_YEAR <- 2014L
END_YEAR   <- 2025L

# Aggregate raw incidents into a balanced monthly panel.
#
# The panel has one row per (neighbourhood, month) combination. Months with
# no recorded thefts are filled with 0 so every neighbourhood has the same
# number of monthly observations (2014-01 through 2025-12). Neighbourhood
# centroid coordinates are attached for spatial modelling.
#
# Contextual features aggregated per (neighbourhood, month):
#   - outside_share     : proportion of thefts occurring outdoors
#   - commercial_share  : proportion of thefts in commercial premises
#   - n_divisions       : number of distinct police divisions affected
make_monthly_panel <- function(raw) {
  coordinates <- raw |>
    dplyr::group_by(neighborhood) |>
    dplyr::summarise(
      lon = stats::median(long),
      lat = stats::median(lat),
      .groups = "drop"
    )

  months <- seq(
    as.Date(sprintf("%d-01-01", START_YEAR)),
    as.Date(sprintf("%d-12-01", END_YEAR)),
    by = "month"
  )

  # Per (neighbourhood, month) aggregates, including contextual shares.
  # We restrict to the study period (through END_YEAR) so the in-progress
  # 2026 records do not create an unbalanced tail in the panel.
  counts <- raw |>
    dplyr::mutate(month = lubridate::floor_date(date, "month")) |>
    dplyr::filter(month >= months[1], month <= months[length(months)]) |>
    dplyr::group_by(neighborhood, month) |>
    dplyr::summarise(
      theft_count = dplyr::n(),
      outside_share = mean(location == "Open/Public Spaces"),
      commercial_share = mean(location == "Commercial Areas"),
      .groups = "drop"
    )

  panel <- counts |>
    tidyr::complete(
      neighborhood = unique(raw$neighborhood),
      month = months,
      fill = list(
        theft_count = 0L, outside_share = 0, commercial_share = 0
      )
    ) |>
    dplyr::left_join(coordinates, by = "neighborhood") |>
    dplyr::arrange(month, neighborhood) |>
    dplyr::mutate(
      # Integer month index from 1 (2014-01) onward.
      time_index = as.integer(
        (lubridate::year(month) - START_YEAR) * 12 + lubridate::month(month)
      ),
      month_of_year = lubridate::month(month),
      year = lubridate::year(month)
    )

  list(panel = panel, coordinates = coordinates)
}
