read_bicycle <- function(path) {
  x <- readr::read_csv(path, show_col_types = FALSE)
  required <- c(
    "date", "quarter", "day_of_week", "neighborhood",
    "bike_cost", "location", "long", "lat"
  )
  if (!all(required %in% names(x))) {
    stop("Missing required columns: ", paste(setdiff(required, names(x)), collapse = ", "))
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

audit_bicycle <- function(raw) {
  original_columns <- c(
    "date", "quarter", "day_of_week", "neighborhood",
    "bike_cost", "location", "long", "lat"
  )
  tibble::tibble(
    metric = c(
      "rows", "original_columns", "missing_cells", "exact_duplicate_rows",
      "neighborhoods", "unique_dates", "quarter_mismatch_rows",
      "zero_or_negative_bike_cost", "bike_cost_over_10000"
    ),
    value = c(
      nrow(raw),
      length(original_columns),
      sum(is.na(raw[, original_columns])),
      sum(duplicated(raw[, original_columns])),
      dplyr::n_distinct(raw$neighborhood),
      dplyr::n_distinct(raw$date),
      sum(raw$derived_quarter != raw$supplied_quarter),
      sum(raw$bike_cost <= 0),
      sum(raw$bike_cost > 10000)
    )
  )
}

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
      time_index = as.integer(
        (lubridate::year(month) - 2014) * 12 + lubridate::month(month)
      ),
      month_of_year = lubridate::month(month),
      year = lubridate::year(month)
    )
  list(panel = panel, coordinates = coordinates)
}
