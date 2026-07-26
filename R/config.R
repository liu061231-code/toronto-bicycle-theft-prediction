find_project_root <- function(start = getwd()) {
  current <- normalizePath(start, mustWork = TRUE)
  repeat {
    if (file.exists(file.path(current, ".git"))) {
      return(current)
    }
    parent <- dirname(current)
    if (identical(parent, current)) {
      stop("Could not locate project root from: ", start)
    }
    current <- parent
  }
}

default_bicycle_paths <- function() {
  c(
    "/Users/liumingyuan/sta pj/data/bicycle.csv",
    "/Users/liumingyuan/Downloads/four_dataset/bicycle.csv",
    "/Users/liumingyuan/Downloads/four_dataset/bicycle_副本.csv"
  )
}

has_bicycle_schema <- function(path) {
  expected <- c(
    "date", "quarter", "day_of_week", "neighborhood",
    "bike_cost", "location", "long", "lat"
  )
  header <- tryCatch(
    readLines(path, n = 1L, warn = FALSE, encoding = "UTF-8"),
    error = function(...) character()
  )
  if (!length(header)) {
    return(FALSE)
  }
  fields <- strsplit(header[[1]], ",", fixed = TRUE)[[1]]
  fields <- trimws(gsub('^"|"$', "", fields))
  identical(fields, expected)
}

resolve_bicycle_csv <- function(
    root = find_project_root(),
    fallback_paths = default_bicycle_paths()) {
  env_path <- Sys.getenv("STAT3888_BICYCLE_CSV", unset = "")
  candidates <- unique(c(
    if (nzchar(env_path)) env_path else character(),
    file.path(root, "data", "bicycle.csv"),
    fallback_paths
  ))
  for (candidate in candidates) {
    if (file.exists(candidate) && has_bicycle_schema(candidate)) {
      return(normalizePath(candidate, mustWork = TRUE))
    }
  }
  stop(
    "Could not find a bicycle CSV with the required eight columns. ",
    "Checked paths: ", paste(candidates, collapse = "; "), ". ",
    "Set STAT3888_BICYCLE_CSV to the correct file."
  )
}

project_paths <- function() {
  root <- find_project_root()
  list(
    root = root,
    source_csv = resolve_bicycle_csv(root),
    analysis_dir = file.path(root, "output", "analysis"),
    figure_dir = file.path(root, "output", "figures"),
    pdf_dir = file.path(root, "output", "pdf"),
    pdf_file = file.path(
      root,
      "output",
      "pdf",
      "STAT3888_自行车盗窃时空基函数回归_完整项目手册.pdf"
    )
  )
}

ensure_packages <- function() {
  required <- c(
    "tidyverse", "lubridate", "ggplot2", "splines",
    "glmnet", "mgcv", "sf", "testthat"
  )
  missing <- required[
    !vapply(required, requireNamespace, logical(1), quietly = TRUE)
  ]
  if (length(missing)) {
    stop(
      "Missing R packages: ", paste(missing, collapse = ", "),
      ". Install with install.packages(c(",
      paste(sprintf('"%s"', missing), collapse = ", "), "))."
    )
  }
  invisible(TRUE)
}
