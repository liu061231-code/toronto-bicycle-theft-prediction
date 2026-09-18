# build_reference_coordinates.R --------------------------------------------
# Build the frozen, versioned neighbourhood coordinate reference table.
#
# Output: data/reference/neighborhood_coordinates.csv
#
# WHY THIS FILE EXISTS (feedback2.0 P0 Task 1):
#   The modelling pipeline must never derive neighbourhood coordinates from
#   the raw events it is given -- doing so lets post-cutoff (future) records
#   move historical training features (demonstrated: 29,880 training cells
#   changed when 2024+ raw coordinates were perturbed). Instead, coordinates
#   come from this frozen reference table, computed ONCE from a fixed
#   historical training period and committed to the repository.
#
# IMPORTANT HONESTY NOTE:
#   These are TRAINING-PERIOD ESTIMATES (medians of event coordinates during
#   2014-2023), not official geographic constants. A neighbourhood's true
#   centroid is time-invariant, but this table is an estimate of it from a
#   specific data snapshot; the README and data dictionary describe it as
#   such. If an official City of Toronto neighbourhood-centroid table is
#   adopted later, replace this file (bumping source_version) -- the pipeline
#   reads it blindly.
#
# Run from the project root:
#   Rscript scripts/build_reference_coordinates.R

suppressMessages({
  library(dplyr)
  library(readr)
  library(lubridate)
})

# Resolve project root from this script's own path.
script_path <- (function() {
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- args[grepl("^--file=", args)]
  if (length(file_arg)) {
    return(normalizePath(sub("^--file=", "", file_arg[1])))
  }
  normalizePath(getwd())
})()
ROOT <- normalizePath(file.path(dirname(script_path), ".."), mustWork = TRUE)

source(file.path(ROOT, "src", "config.R"))
source(file.path(ROOT, "src", "prepare_data.R"))

# The frozen estimation window: the main training period. Post-2023 events
# never influence this table.
FREEZE_END <- as.Date("2023-12-31")

main <- function() {
  paths <- project_paths(ROOT)
  raw <- read_bicycle(paths$raw_data)

  frozen <- dplyr::filter(raw, date <= FREEZE_END)
  coords <- make_neighborhood_coordinates(frozen)

  # Reconciliation check: neighbourhoods present in the FULL dataset but
  # missing from the frozen table (they would get NA coordinates downstream).
  all_nb <- setdiff(unique(raw$neighborhood), UNKNOWN_AREA)
  missing_nb <- setdiff(all_nb, coords$neighborhood)

  # Per-neighbourhood event counts within the frozen window (provenance).
  n_events <- frozen |>
    dplyr::filter(
      neighborhood != UNKNOWN_AREA,
      !is.na(long), !is.na(lat), long != 0, lat != 0
    ) |>
    dplyr::count(neighborhood, name = "n_events")

  # Content hash of the input snapshot for versioning.
  data_hash <- digest_file(paths$raw_data)

  out <- coords |>
    dplyr::left_join(n_events, by = "neighborhood") |>
    dplyr::mutate(
      period_start = "2014-01-01",
      period_end = as.character(FREEZE_END),
      source = paste(
        "Toronto Police Service Bicycle Thefts Open Data;",
        "median of event coordinates within the frozen training period",
        "(training-period estimate, not an official centroid)"
      ),
      source_version = paste0("bicycle.csv ", data_hash)
    ) |>
    dplyr::select(
      neighborhood, lon, lat, n_events,
      period_start, period_end, source, source_version
    ) |>
    dplyr::arrange(neighborhood)

  out_path <- paths$reference_coordinates
  dir.create(dirname(out_path), recursive = TRUE, showWarnings = FALSE)
  readr::write_csv(out, out_path)

  message("Wrote ", out_path)
  message("Neighbourhoods in reference table: ", nrow(out))
  message("Frozen window: 2014-01-01 .. ", FREEZE_END)
  message("Input data hash (sha256): ", data_hash)
  if (length(missing_nb) > 0) {
    message(
      "WARNING: ", length(missing_nb),
      " neighbourhood(s) in the full data have no frozen-period coordinates ",
      "(they receive NA downstream): ", paste(missing_nb, collapse = ", ")
    )
  } else {
    message("All non-NSA neighbourhoods have frozen-period coordinates.")
  }
  invisible(out)
}

if (sys.nframe() == 0L) {
  main()
}
