# config.R -----------------------------------------------------------------
# Global configuration for the Toronto bicycle theft prediction project.
#
# Responsibilities:
#   - locate the project root and resolve relative paths
#   - declare package dependencies
#   - hold the random seed and shared constants
#
# Nothing in this file reads or writes model outputs; it only defines
# reusable configuration used across the rest of the pipeline.

# Locate the project root by walking up from the current directory until a
# directory containing "src/config.R" (the stable marker) is found.
find_project_root <- function(start = getwd()) {
  current <- normalizePath(start, mustWork = TRUE)
  repeat {
    if (file.exists(file.path(current, "src", "config.R"))) {
      return(current)
    }
    parent <- dirname(current)
    if (identical(parent, current)) {
      stop("Could not locate project root from: ", start)
    }
    current <- parent
  }
}

# Central path registry. All downstream code references paths through this
# function so that the project is portable across machines.
project_paths <- function(root = find_project_root()) {
  root <- normalizePath(root, mustWork = TRUE)
  list(
    root            = root,
    raw_data        = file.path(root, "data", "raw", "bicycle.csv"),
    figure_dir      = file.path(root, "output", "figures"),
    table_dir       = file.path(root, "output", "tables"),
    model_dir       = file.path(root, "output", "models")
  )
}

# Declare all R packages used by the project so a fresh environment can be
# set up in one place (see README "Reproducibility").
required_packages <- c(
  "dplyr", "tidyr", "readr", "purrr", "tibble", "stringr", "forcats",
  "lubridate", "ggplot2", "splines", "glmnet", "MASS", "mgcv"
)

ensure_packages <- function(packages = required_packages) {
  missing <- packages[!vapply(
    packages, requireNamespace, logical(1), quietly = TRUE
  )]
  if (length(missing)) {
    stop(
      "Missing R packages: ", paste(missing, collapse = ", "),
      ". Install with install.packages(c(",
      paste(sprintf('"%s"', missing), collapse = ", "), "))."
    )
  }
  invisible(TRUE)
}

# Fixed random seed for reproducibility of any stochastic step (e.g. CV
# fold assignment, stochastic model fits).
random_seed <- 2023L

# Column names expected in the raw dataset (schema check).
raw_columns <- c(
  "date", "quarter", "day_of_week", "neighborhood",
  "bike_cost", "location", "long", "lat"
)
