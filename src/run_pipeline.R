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
  models <- list(
    "Global mean"           = baseline_global_mean,
    "Neighbourhood mean"    = baseline_neighborhood_mean,
    "Recent 12-mo mean"     = baseline_recent_seasonal_mean(12),
    "Seasonal naive"        = baseline_seasonal_naive,
    "Basis OLS (log)"       = model_ols_log(),
    "Basis Ridge (log)"     = model_ridge_log(),
    "Poisson (compact)"     = model_poisson_glm(
                                alpha = 0, lambda = NULL, with_area = FALSE),
    "Poisson (area, ridge)" = model_poisson_glm(
                                alpha = 0, lambda = NULL, with_area = TRUE),
    "Negative-binomial"     = model_negbin_glm(with_area = FALSE)
  )
  cv_results <- compare_models_cv(train_val, folds, models)
  cv_summary <- summarise_cv(cv_results)

  message("5/7 Tuning Ridge regularisation strength (lambda) ...")
  lambda_grid <- exp(seq(log(1e-1), log(1e-4), length.out = 12))
  lambda_cv <- lapply(lambda_grid, function(lam) {
    m <- model_ridge_log(lambda = lam)
    cv <- cross_validate(train_val, folds, m)
    dplyr::summarise(
      cv, lambda = lam,
      cv_MAE = mean(MAE), cv_RMSE = mean(RMSE), cv_R2 = mean(R2)
    )
  }) |>
    dplyr::bind_rows()
  best_lambda <- lambda_cv$lambda[which.min(lambda_cv$cv_RMSE)]
  message("  Best lambda = ", format(best_lambda, digits = 4))

  message("6/7 Final hold-out evaluation on 2025 ...")
  # Refit the tuned Ridge model on train+validation and score the test set.
  final_model <- model_ridge_log(lambda = best_lambda)
  holdout <- dplyr::bind_rows(lapply(names(models), function(nm) {
    final_holdout_evaluate(train, validation, test, models[[nm]], nm)
  }))
  # Add the tuned Ridge as an explicit row so the final model is visible,
  # attaching its CV score directly from the lambda grid search.
  tuned_cv <- lambda_cv |>
    dplyr::filter(lambda == best_lambda)
  holdout_tuned <- final_holdout_evaluate(
    train, validation, test, final_model, "Basis Ridge (tuned)"
  ) |>
    dplyr::mutate(
      cv_MAE = tuned_cv$cv_MAE,
      cv_RMSE = tuned_cv$cv_RMSE,
      cv_R2 = tuned_cv$cv_R2
    )
  holdout <- dplyr::bind_rows(holdout, holdout_tuned)
  comparison <- build_comparison_table(cv_summary, holdout) |>
    dplyr::arrange(test_RMSE)

  # Generate final-model predictions for error analysis.
  final_pred <- final_model(train_val, test)
  predictions <- test |>
    dplyr::transmute(
      month = as.Date(month),
      neighborhood,
      lon, lat,
      actual = theft_count,
      predicted = final_pred,
      residual = actual - predicted
    )

  # Also produce predictions for the best count model (Poisson with area
  # fixed effects + ridge penalty), which outperforms the ridge-on-log model
  # under a fair comparison (see model_comparison.csv / README). Its count-link
  # prediction is the conditional mean directly, avoiding the log1p
  # back-transform bias.
  poisson_final <- model_poisson_glm(
    alpha = 0, lambda = NULL, with_area = TRUE
  )
  poisson_pred <- poisson_final(train_val, test)
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
    lambda_cv, file.path(paths$table_dir, "lambda_tuning.csv")
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
    lambda_cv = lambda_cv,
    best_lambda = best_lambda,
    predictions = predictions,
    poisson_predictions = poisson_predictions,
    error_report = error_report,
    poisson_error_report = poisson_error_report
  ))
}

if (sys.nframe() == 0L) {
  main()
}
