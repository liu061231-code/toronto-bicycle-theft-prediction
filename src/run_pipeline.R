# run_pipeline.R ----------------------------------------------------------
# End-to-end pipeline for the Toronto bicycle theft prediction project.
#
# Run from the project root with:
#   Rscript src/run_pipeline.R
#
# Flow:
#   1. load & audit raw data
#   2. build monthly panel
#   3. time-aware split + expanding-window CV
#   4. compare baselines and candidate models fairly
#   5. tune the regularisation strength of the best model
#   6. final hold-out evaluation on 2025
#   7. write comparison tables and diagnostic figures

library(dplyr)

# Resolve the project root once and source all modules from it, so the
# script runs correctly regardless of the caller's working directory.
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
source(file.path(ROOT, "src", "features.R"))
source(file.path(ROOT, "src", "validation.R"))
source(file.path(ROOT, "src", "models.R"))
source(file.path(ROOT, "src", "evaluate.R"))
source(file.path(ROOT, "src", "visualize.R"))

main <- function() {
  paths <- project_paths()
  ensure_packages()

  dir.create(paths$figure_dir, recursive = TRUE, showWarnings = FALSE)
  dir.create(paths$table_dir, recursive = TRUE, showWarnings = FALSE)
  dir.create(paths$model_dir, recursive = TRUE, showWarnings = FALSE)

  message("1/7 Loading and auditing raw data ...")
  raw <- read_bicycle(paths$raw_data)
  audit <- audit_bicycle(raw)

  message("2/7 Building monthly panel ...")
  prepared <- make_monthly_panel(raw)
  panel <- prepared$panel

  message("3/7 Splitting data (time-aware) ...")
  splits <- split_panel(panel)
  train <- splits$train
  validation <- splits$validation
  test <- splits$test
  train_val <- dplyr::bind_rows(train, validation)
  folds <- make_expanding_folds(train_val)

  message("4/7 Comparing candidate models with expanding-window CV ...")
  # Unified tuning protocol (feedback2.0 P0 Task 2): both tuned models use
  # the SAME lambda grid and the SAME nested chronological tuning (inner
  # expanding-window folds inside each outer training window, RMSE primary
  # metric, 1% tie-break toward stronger regularisation). No random K-fold.
  #
  # Grid rationale (evidence-driven, then frozen): an earlier 8-point grid
  # spanning 1e-1..1e-4 put the Poisson selection on the UPPER boundary
  # (its inner-CV optimum sits near 1.0: mean RMSE falls monotonically from
  # 8 -> 1 and rises again below 0.5), while the ridge landscape is flat
  # down to 1e-4. The shared 14-point grid 4.0 -> 1e-4 brackets both optima
  # so neither model's selection is forced to a grid edge.
  lambda_grid <- exp(seq(log(4), log(1e-4), length.out = 14))
  trace_env <- new.env(parent = emptyenv())
  trace_env$traces <- list()

  ridge_factory <- function(lambda) model_ridge_log(lambda = lambda)
  poisson_factory <- function(lambda) {
    model_poisson_glm(alpha = 0, lambda = lambda, with_area = TRUE)
  }

  models <- list(
    "Global mean"            = baseline_global_mean,
    "Neighbourhood mean"     = baseline_neighborhood_mean,
    "Recent 12-mo mean"      = baseline_recent_seasonal_mean(12),
    "Seasonal naive"         = baseline_seasonal_naive,
    "Basis OLS (log)"        = model_ols_log(),
    "Basis Ridge (tuned)"    = make_tuned_model(
                                 "Basis Ridge (tuned)", ridge_factory,
                                 lambda_grid, trace_env = trace_env,
                                 path_model = ridge_log_path_model),
    "Poisson (compact)"      = model_poisson_glm(
                                 alpha = 0, lambda = 1e-2, with_area = FALSE),
    "Poisson (area, tuned)"  = make_tuned_model(
                                 "Poisson (area, tuned)", poisson_factory,
                                 lambda_grid, trace_env = trace_env,
                                 path_model = poisson_path_model(
                                   alpha = 0, with_area = TRUE)),
    "Negative-binomial"      = model_negbin_glm(with_area = FALSE)
  )
  cv_results <- compare_models_cv(train_val, folds, models)
  cv_summary <- summarise_cv(cv_results)

  # Consolidate the per-outer-fold tuning audit trail.
  tuning_traces <- dplyr::bind_rows(trace_env$traces)
  outer_ids <- sort(unique(tuning_traces$outer_train_end))
  tuning_traces <- tuning_traces |>
    dplyr::mutate(outer_fold = match(outer_train_end, outer_ids)) |>
    dplyr::select(
      outer_fold, model, inner_fold, lambda, MAE, RMSE, R2, selected
    ) |>
    dplyr::arrange(model, outer_fold, inner_fold, lambda)

  message("5/7 Final hold-out evaluation on 2025 (retrospective window) ...")
  # The tuned models are re-tuned once on the full train+validation window
  # through the same nested chronological protocol (trace recorded), then
  # scored on 2025. 2025 is a REPEATEDLY-VIEWED retrospective window: it is
  # reported descriptively and must not drive model selection.
  final_trace_env <- new.env(parent = emptyenv())
  final_trace_env$traces <- list()
  final_wrappers <- list(
    "Basis Ridge (tuned)"   = make_tuned_model(
                                "Basis Ridge (tuned)", ridge_factory,
                                lambda_grid, trace_env = final_trace_env,
                                path_model = ridge_log_path_model),
    "Poisson (area, tuned)" = make_tuned_model(
                                "Poisson (area, tuned)", poisson_factory,
                                lambda_grid, trace_env = final_trace_env,
                                path_model = poisson_path_model(
                                  alpha = 0, with_area = TRUE))
  )
  holdout <- dplyr::bind_rows(lapply(names(models), function(nm) {
    fp <- if (nm %in% names(final_wrappers)) final_wrappers[[nm]]
          else models[[nm]]
    final_holdout_evaluate(train, validation, test, fp, nm)
  }))
  comparison <- build_comparison_table(cv_summary, holdout) |>
    dplyr::arrange(test_RMSE)

  # Full tuning audit trail: outer-CV folds plus the final refit.
  final_traces <- dplyr::bind_rows(final_trace_env$traces) |>
    dplyr::mutate(outer_fold = "final") |>
    dplyr::select(
      outer_fold, model, inner_fold, lambda, MAE, RMSE, R2, selected
    )
  tuning_traces <- dplyr::bind_rows(
    tuning_traces |> dplyr::mutate(outer_fold = as.character(outer_fold)),
    final_traces
  )

  # Predictions on the 2025 retrospective window for both tuned models.
  final_ridge <- final_wrappers[["Basis Ridge (tuned)"]]
  final_poisson <- final_wrappers[["Poisson (area, tuned)"]]
  final_pred <- final_ridge(train_val, test)
  predictions <- test |>
    dplyr::transmute(
      month = as.Date(month),
      neighborhood,
      lon, lat,
      actual = theft_count,
      predicted = final_pred,
      residual = actual - predicted
    )

  poisson_pred <- final_poisson(train_val, test)
  poisson_predictions <- test |>
    dplyr::transmute(
      month = as.Date(month),
      neighborhood,
      actual = theft_count,
      predicted = poisson_pred,
      residual = actual - predicted
    )

  # Aggregate & stratified diagnostics (totals, monthly, non-zero, active).
  error_report <- summarise_forecast_errors(predictions)
  poisson_error_report <- summarise_forecast_errors(poisson_predictions)

  message("7/7 Writing outputs and figures ...")
  readr::write_csv(audit, file.path(paths$table_dir, "data_audit.csv"))
  readr::write_csv(
    comparison, file.path(paths$table_dir, "model_comparison.csv")
  )
  readr::write_csv(
    cv_results, file.path(paths$table_dir, "cv_folds.csv")
  )
  readr::write_csv(
    tuning_traces, file.path(paths$table_dir, "tuning_traces.csv")
  )
  readr::write_csv(
    predictions, file.path(paths$table_dir, "test_predictions.csv")
  )
  readr::write_csv(
    error_report$monthly, file.path(paths$table_dir, "monthly_errors.csv")
  )
  readr::write_csv(
    error_report$by_neighborhood,
    file.path(paths$table_dir, "neighborhood_errors.csv")
  )
  readr::write_csv(
    poisson_predictions,
    file.path(paths$table_dir, "poisson_test_predictions.csv")
  )
  readr::write_csv(
    poisson_error_report$monthly,
    file.path(paths$table_dir, "poisson_monthly_errors.csv")
  )

  # Diagnostic figures.
  ggplot2::ggsave(
    file.path(paths$figure_dir, "01_monthly_trend.png"),
    plot_monthly_trend(panel), width = 9, height = 5.4, dpi = 180, bg = "white"
  )
  ggplot2::ggsave(
    file.path(paths$figure_dir, "02_seasonality.png"),
    plot_seasonality(panel), width = 9, height = 5.4, dpi = 180, bg = "white"
  )
  ggplot2::ggsave(
    file.path(paths$figure_dir, "03_spatial_hotspots.png"),
    plot_spatial_hotspots(panel), width = 9, height = 5.4, dpi = 180,
    bg = "white"
  )
  ggplot2::ggsave(
    file.path(paths$figure_dir, "04_observed_vs_predicted.png"),
    plot_observed_vs_predicted(predictions),
    width = 9, height = 5.4, dpi = 180, bg = "white"
  )
  ggplot2::ggsave(
    file.path(paths$figure_dir, "05_residual_distribution.png"),
    plot_residual_distribution(predictions),
    width = 9, height = 5.4, dpi = 180, bg = "white"
  )

  message("Done. Final model comparison:")
  print(comparison, n = Inf)

  message("\nAggregate & stratified diagnostics (2025 hold-out):")
  message(sprintf(
    "  [Ridge tuned] total actual = %.1f, predicted = %.1f, rel. bias = %+.2f%%",
    error_report$total_actual, error_report$total_predicted,
    100 * error_report$total_rel_bias
  ))
  message(sprintf(
    "  [Ridge tuned] non-zero cells : MAE %.3f, RMSE %.3f",
    error_report$nonzero_metrics$MAE, error_report$nonzero_metrics$RMSE
  ))
  message(sprintf(
    "  [Ridge tuned] active neigh.  : MAE %.3f, RMSE %.3f",
    error_report$active_metrics$MAE, error_report$active_metrics$RMSE
  ))
  message(sprintf(
    "  [Poisson]     total actual = %.1f, predicted = %.1f, rel. bias = %+.2f%%",
    poisson_error_report$total_actual, poisson_error_report$total_predicted,
    100 * poisson_error_report$total_rel_bias
  ))
  message(sprintf(
    "  [Poisson]     non-zero cells : MAE %.3f, RMSE %.3f",
    poisson_error_report$nonzero_metrics$MAE,
    poisson_error_report$nonzero_metrics$RMSE
  ))
  message(sprintf(
    "  [Poisson]     active neigh.  : MAE %.3f, RMSE %.3f",
    poisson_error_report$active_metrics$MAE,
    poisson_error_report$active_metrics$RMSE
  ))

  invisible(list(
    paths = paths,
    audit = audit,
    panel = panel,
    splits = splits,
    comparison = comparison,
    cv_results = cv_results,
    tuning_traces = tuning_traces,
    predictions = predictions,
    poisson_predictions = poisson_predictions,
    error_report = error_report,
    poisson_error_report = poisson_error_report
  ))
}

if (sys.nframe() == 0L) {
  main()
}
