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

# Sentinel value marking the "Not Specified Area" (NSA) pseudo-neighbourhood.
# The publisher assigns ~370 records to NSA, whose coordinates are missing
# (encoded as 0). NSA is NOT a real neighbourhood: it must never receive a
# synthetic centroid or enter any spatial-distance / RBF computation, otherwise
# a single (0,0) point dominates the spatial scale and collapses the map.
UNKNOWN_AREA <- "NSA"

# Availability filter, not a reconstruction of historical revisions.
# Missing report dates cannot establish that a record was known at cutoff.
records_as_of <- function(raw, cutoff) {
  if(!"report_date" %in% names(raw)) stop("report_date is required for as-of filtering")
  cutoff <- as.Date(cutoff)
  report <- as.Date(raw$report_date)
  raw[!is.na(report) & report<=cutoff & raw$date<=cutoff, ,drop=FALSE]
}

# Read the raw CSV and validate its schema, then parse date columns.
read_bicycle <- function(path) {
  validate_conversion(path)
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

validate_conversion <- function(path) {
  dir <- dirname(path)
  if(file.exists(file.path(dir,".conversion-in-progress"))) stop("Conversion incomplete; rerun convert_data.py")
  manifest <- file.path(dir,"conversion_manifest.json")
  if(file.exists(manifest)) {
    hashes <- jsonlite::read_json(manifest,simplifyVector=TRUE)
    for(name in names(hashes)) {
      file <- file.path(dir,name)
      if(!file.exists(file) || digest::digest(file=file,algo="sha256") != hashes[[name]])
        stop("Converted data hash mismatch: ",name)
    }
  }
  invisible(TRUE)
}

# Produce a small audit table summarising basic data-quality indicators.
audit_bicycle <- function(raw) {
  tibble::tibble(
    metric = c(
      "rows", "input_columns", "missing_model_cells", "duplicate_rows_on_model_columns",
      "neighborhoods", "unique_dates", "quarter_mismatch_rows",
      "zero_or_negative_bike_cost", "bike_cost_over_10000",
      "unknown_area_rows", "zero_coordinate_rows"
    ),
    value = c(
      nrow(raw),
      ncol(raw) - sum(c("derived_quarter", "supplied_quarter_date", "supplied_quarter") %in% names(raw)),
      sum(is.na(raw[, raw_columns])),
      sum(duplicated(raw[, raw_columns])),
      dplyr::n_distinct(raw$neighborhood),
      dplyr::n_distinct(raw$date),
      sum(raw$derived_quarter != raw$supplied_quarter),
      sum(raw$bike_cost <= 0, na.rm = TRUE),
      sum(raw$bike_cost > 10000, na.rm = TRUE),
      sum(raw$neighborhood == UNKNOWN_AREA, na.rm = TRUE),
      sum(
        (!is.na(raw$long) & raw$long == 0) |
          (!is.na(raw$lat) & raw$lat == 0),
        na.rm = TRUE
      )
    )
  ) |>
    dplyr::bind_rows(tibble::tibble(
      metric=c("duplicate_full_rows", "distinct_objectid", "distinct_event_unique_id", "late_report_rows"),
      value=c(sum(duplicated(raw)),
        if("objectid" %in% names(raw)) dplyr::n_distinct(raw$objectid, na.rm=TRUE) else NA,
        if("event_unique_id" %in% names(raw)) dplyr::n_distinct(raw$event_unique_id, na.rm=TRUE) else NA,
        if("report_date" %in% names(raw)) sum(as.Date(raw$report_date)>raw$date, na.rm=TRUE) else NA)))
}

# The study period: from the first stable reporting year (2014) through the
# last complete year available. 2026 is excluded from the modelling span
# because it is still in progress (only ~6 months of records).
# START_YEAR and END_YEAR are defined in config.R. END_YEAR may be overridden
# by scheduled annual jobs through STAT3888_END_YEAR.

# Median event coordinates per neighbourhood.
#
# SCOPE: this helper exists ONLY to build the frozen reference table
# (scripts/build_reference_coordinates.R) and to construct test fixtures.
# The main pipeline must NEVER call it on the full raw series: doing so lets
# post-cutoff (future) events move historical training features. In
# production, coordinates come from the versioned file
# data/reference/neighborhood_coordinates.csv via load_reference_coordinates().
#
# NSA is excluded entirely: it receives NA coordinates and never enters the
# spatial design matrix. Only neighbourhoods with valid (non-zero)
# coordinates participate in spatial modelling.
make_neighborhood_coordinates <- function(raw) {
  raw |>
    dplyr::filter(.data$neighborhood != UNKNOWN_AREA) |>
    dplyr::filter(!is.na(.data$long), !is.na(.data$lat),
                  .data$long != 0, .data$lat != 0) |>
    dplyr::group_by(.data$neighborhood) |>
    dplyr::summarise(
      lon = stats::median(.data$long),
      lat = stats::median(.data$lat),
      .groups = "drop"
    )
}

# Load the frozen, versioned neighbourhood coordinate reference table.
#
# The table (data/reference/neighborhood_coordinates.csv) is built ONCE from
# a fixed historical training period by scripts/build_reference_coordinates.R
# and committed to the repository. It is a TRAINING-PERIOD ESTIMATE of each
# neighbourhood's location, not an official geographic constant; see the
# builder script and data_dictionary.md for provenance. The pipeline reads
# this file blindly so that future raw events can never move historical
# features.
load_reference_coordinates <- function(
    path = project_paths()$reference_coordinates) {
  if (!file.exists(path)) {
    stop(
      "Coordinate reference table not found: ", path, "\n",
      "Build it once with: Rscript scripts/build_reference_coordinates.R"
    )
  }
  ref <- readr::read_csv(path, show_col_types = FALSE, na = c("", "NA"))
  required <- c("neighborhood", "lon", "lat")
  if (!all(required %in% names(ref))) {
    stop(
      "Reference table ", path, " is missing columns: ",
      paste(setdiff(required, names(ref)), collapse = ", ")
    )
  }
  if (anyDuplicated(ref$neighborhood)) {
    stop("Reference table has duplicated neighbourhood keys: ", path)
  }
  dplyr::select(ref, neighborhood, lon, lat)
}

# Aggregate raw incidents into a balanced monthly panel.
#
# The panel has one row per (neighbourhood, month) combination. Months with
# no recorded thefts are filled with 0 so every neighbourhood has the same
# number of monthly observations (START_YEAR-01 through END_YEAR-12).
#
# COORDINATES (feedback2.0 P0 Task 1): spatial coordinates come from the
# frozen, versioned reference table, NEVER from the raw events passed here.
# `coordinates` may be:
#   - NULL (default): load data/reference/neighborhood_coordinates.csv
#   - a data frame with columns neighborhood/lon/lat (used by tests and by
#     the reference-table builder)
# This guarantees that perturbing or appending post-cutoff raw events cannot
# change any historical panel row.
#
# NSA (unknown area) records are kept for count auditing but excluded from
# spatial features; their coordinates are NA and they carry a flag.
#
# Contextual features aggregated per (neighbourhood, month):
#   - outside_share     : proportion of thefts occurring outdoors
#   - commercial_share  : proportion of thefts in commercial premises
make_monthly_panel <- function(raw, coordinates = NULL) {
  if (is.null(coordinates)) {
    coordinates <- load_reference_coordinates()
  }
  # A future-only area must not add zero rows to every historical month.
  # The versioned reference defines the closed geography; unfamiliar labels
  # are reconciled into the existing unknown bucket.
  roster <- union(coordinates$neighborhood, UNKNOWN_AREA)
  unknown <- is.na(raw$neighborhood) | !raw$neighborhood %in% roster
  if(any(unknown)) warning("Labels missing from the coordinate reference mapped to NSA")
  raw$neighborhood[unknown] <- UNKNOWN_AREA

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
      neighborhood = roster,
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
      year = lubridate::year(month),
      # Flag unknown-area records; they carry NA coordinates and must never
      # enter spatial (RBF) features. They remain in the panel so the total
      # count reconciles against the raw data.
      is_unknown = .data$neighborhood == UNKNOWN_AREA
    )

  # Non-NSA neighbourhoods missing from the reference table degrade silently
  # to "spatially unknown"; surface that loudly instead.
  missing_ref <- panel |>
    dplyr::filter(!is_unknown, is.na(lon) | is.na(lat)) |>
    dplyr::distinct(neighborhood) |>
    dplyr::pull(neighborhood)
  if (length(missing_ref) > 0) {
    warning(
      length(missing_ref), " neighbourhood(s) missing from the coordinate ",
      "reference table; they receive NA spatial coordinates: ",
      paste(missing_ref, collapse = ", ")
    )
  }

  list(panel = panel, coordinates = coordinates)
}
