# Produce a forward annual forecast after a complete-year data refresh.
# Usage: STAT3888_END_YEAR=2026 Rscript src/forecast_next_year.R 2026

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1L || length(args) > 2L) stop("Usage: Rscript src/forecast_next_year.R COMPLETE_YEAR [OUTPUT_DIR]")
complete_year <- as.integer(args[[1]])
if (is.na(complete_year)) stop("COMPLETE_YEAR must be an integer")
all_args <- commandArgs(trailingOnly = FALSE)
file_arg <- all_args[grepl("^--file=", all_args)]
script_path <- normalizePath(sub("^--file=", "", file_arg[[1]]))
ROOT <- normalizePath(file.path(dirname(script_path), ".."), mustWork = TRUE)

source(file.path(ROOT, "src", "config.R"))
source(file.path(ROOT, "src", "prepare_data.R"))
source(file.path(ROOT, "src", "features.R"))
source(file.path(ROOT, "src", "validation.R"))
source(file.path(ROOT, "src", "models.R"))
source(file.path(ROOT, "src", "artifacts.R"))
if (!identical(END_YEAR, complete_year)) stop("Set STAT3888_END_YEAR to COMPLETE_YEAR before running this script")

paths <- project_paths(ROOT)
ensure_packages()
summary_path <- file.path(paths$table_dir, "backtest_summary.csv")
if (!file.exists(summary_path)) stop("Run src/run_pipeline.R before annual forecasting")
summary <- readr::read_csv(summary_path, show_col_types = FALSE)
chosen <- summary |>
  dplyr::filter(task_horizon == 12, selected) |>
  dplyr::slice_head(n = 1)
if (nrow(chosen) != 1L || !chosen$model %in% c("Basis Ridge (tuned)", "Poisson (area, tuned)")) stop("Annual forecast requires a selected tuned model")

raw <- read_bicycle(paths$raw_data)
prepared <- make_monthly_panel(raw, load_reference_coordinates(paths$reference_coordinates))
train <- prepared$panel |>
  dplyr::filter(year <= complete_year)
if (nrow(train) == 0L || max(train$year) != complete_year || length(unique(train$month[train$year == complete_year])) != 12L) stop("Training panel does not contain all 12 months of the complete year")

lambda_grid <- exp(seq(log(4), log(1e-4), length.out = 14))
if (identical(chosen$model, "Basis Ridge (tuned)")) {
  tuned <- tune_lambda_time_cv(train, lambda_grid, function(lambda) model_ridge_log(lambda = lambda), path_model = ridge_log_path_model)
} else {
  factory <- function(lambda) model_poisson_glm(alpha = 0, lambda = lambda, with_area = TRUE)
  tuned <- tune_lambda_time_cv(train, lambda_grid, factory, path_model = poisson_path_model(alpha = 0, with_area = TRUE))
}
artifact <- fit_artifact(train, chosen$model, tuned$best_lambda, data_hash = digest_file(paths$raw_data), reference_hash = digest_file(paths$reference_coordinates), intended_horizons = 12L)

target_year <- complete_year + 1L
months <- seq(as.Date(sprintf("%d-01-01", target_year)), by = "month", length.out = 12L)
future <- merge(artifact$coordinates, data.frame(month = months), by = NULL)
future$month_of_year <- as.integer(format(future$month, "%m"))
future$year <- as.integer(format(future$month, "%Y"))
future$time_index <- (future$year - START_YEAR) * 12L + future$month_of_year
future$predicted <- predict_artifact(artifact, future)
future <- future |>
  dplyr::transmute(model_id = artifact$model_id, training_cutoff = artifact$training_cutoff, lambda = artifact$lambda, data_hash = artifact$data_hash, reference_hash = artifact$reference_hash, month, neighborhood, lon, lat, predicted)

dir.create(file.path(ROOT, "output", "forecasts"), recursive = TRUE, showWarnings = FALSE)
slug <- gsub("[^A-Za-z0-9]+", "_", tolower(chosen$model))
artifact_path <- file.path(paths$model_dir, paste0("forecast_", target_year, "_", slug, ".rds"))
save_artifact(artifact, artifact_path)
forecast_path <- file.path(ROOT, "output", "forecasts", paste0("forecast_", target_year, ".csv"))
readr::write_csv(future, forecast_path)
manifest <- list(schema_version = 1, complete_year = complete_year, target_year = target_year, model_id = chosen$model, lambda = tuned$best_lambda, training_cutoff = artifact$training_cutoff, data_hash = artifact$data_hash, reference_hash = artifact$reference_hash, rows = nrow(future))
jsonlite::write_json(manifest, file.path(ROOT, "output", "forecasts", paste0("forecast_", target_year, "_manifest.json")), pretty = TRUE, auto_unbox = TRUE)
message("Wrote annual forecast: ", forecast_path)
