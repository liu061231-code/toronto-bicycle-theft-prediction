# run_pipeline.R ----------------------------------------------------------
# End-to-end pipeline for the Toronto bicycle theft prediction project.
#
# Run from the project root with:
#   Rscript src/run_pipeline.R
#
# Flow:
#   1. load & audit raw data
#   2. build monthly panel
#   3. time-aware split (train / validation / retrospective END_YEAR)
#   4. rolling-origin backtests for TWO separate forecast tasks
#      (horizon = 1 and horizon = 12) on the training span
#   5. predeclared model selection per horizon (backtest metrics only)
#   6. retrospective evaluation on END_YEAR (descriptive, never used for selection)
#   7. write comparison tables and diagnostic figures
#
# Model-selection rule (predeclared; keep README.md "Validation Strategy" in
# sync): primary metric = mean outer-fold RMSE; tie-break = lower mean MAE
# when mean RMSE differs by less than 1%; selection is made PER HORIZON.
# END_YEAR retrospective scores are descriptive and do not change selection.

library(dplyr)

# Resolve the project root once and source all modules from it, so the
# script runs correctly regardless of the caller's working directory.
script_path <- (function() {
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- args[grepl("^--file=", args)]
  if (length(file_arg)) {
    return(normalizePath(gsub("~+~", " ", sub("^--file=", "", file_arg[1]), fixed=TRUE)))
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
source(file.path(ROOT, "src", "backtest.R"))
source(file.path(ROOT, "src", "visualize.R"))
source(file.path(ROOT, "src", "artifacts.R"))

main <- function() {
  paths <- project_paths(ROOT)
  ensure_packages()
  retro_year <- END_YEAR

  dir.create(paths$figure_dir, recursive = TRUE, showWarnings = FALSE)
  dir.create(paths$table_dir, recursive = TRUE, showWarnings = FALSE)
  dir.create(paths$model_dir, recursive = TRUE, showWarnings = FALSE)

  message("1/7 Loading and auditing raw data ...")
  raw <- read_bicycle(paths$raw_data)
  audit <- audit_bicycle(raw)
  data_hash <- digest_file(paths$raw_data)

  message("2/7 Building monthly panel ...")
  prepared <- make_monthly_panel(raw, load_reference_coordinates(paths$reference_coordinates))
  panel <- prepared$panel

  message("3/7 Splitting data (time-aware) ...")
  splits <- split_panel(panel, retrospective_year = retro_year)
  train <- splits$train
  validation <- splits$validation
  test <- splits$test
  train_val <- dplyr::bind_rows(train, validation)

  message("4/7 Rolling backtests (horizon = 12 and horizon = 1) ...")
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

  # --- Task A: horizon = 12 (annual-ahead planning) -----------------------
  # Expanding annual origins over the training span (first test year follows
  # a 60-month initial window).
  folds_h12 <- make_rolling_folds(
    train_val, horizon_months = 12L, min_train_months = 60L
  )
  bt12 <- run_backtest(train_val, models, folds_h12, horizon_months = 12L)

  # --- Task B: horizon = 1 (monthly updating) -----------------------------
  # Monthly rolling origins over the LAST 12 months of the training span
  # (calendar END_YEAR - 1): each origin refits on everything before it and predicts
  # the next month. 12 origins keep the per-origin tuning cost bounded while
  # still sampling all seasons.
  first_h1 <- min(train_val$time_index[train_val$year == retro_year - 1L])
  folds_h1 <- make_rolling_folds(
    train_val, horizon_months = 1L, min_train_months = 60L,
    first_test_index = first_h1
  )
  bt1 <- run_backtest(train_val, models, folds_h1, horizon_months = 1L)

  backtest_results <- dplyr::bind_rows(bt12, bt1)
  backtest_summary <- summarise_backtest(backtest_results)

  # Consolidate the per-outer-fold tuning audit trail.
  tuning_traces <- dplyr::bind_rows(trace_env$traces)
  tuning_traces <- tuning_traces |>
    dplyr::group_by(model, task_horizon) |>
    dplyr::mutate(outer_fold = match(outer_train_end, sort(unique(outer_train_end)))) |>
    dplyr::ungroup() |>
    dplyr::select(
      task_horizon, outer_fold, model, outer_train_end, test_start, test_end,
      inner_fold, lambda, MAE, RMSE, R2, status, selected
    ) |>
    dplyr::arrange(model, outer_fold, inner_fold, lambda)

  message("5/7 Model selection from backtests (predeclared rule) ...")
  selected <- backtest_summary |>
    dplyr::filter(selected) |>
    dplyr::select(task_horizon, model, mean_RMSE, mean_MAE)
  print(selected, n = Inf)
  selected_h12 <- selected$model[selected$task_horizon == 12][1]
  selected_h1 <- selected$model[selected$task_horizon == 1][1]
  message("  horizon=12 selects: ", selected_h12)
  message("  horizon=1  selects: ", selected_h1)

  message("6/7 Retrospective evaluation on ", retro_year, " (descriptive only) ...")
  # END_YEAR is a REPEATEDLY-VIEWED retrospective window: every score here is
  # descriptive and played no role in model selection. All candidate models
  # are refit on train+validation; tuned models re-tune on train_val through
  # the same nested chronological protocol (trace recorded separately).
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
  retrospective_predictions <- list()
  retrospective_lambdas <- list()
  retrospective <- dplyr::bind_rows(lapply(names(models), function(nm) {
    fp <- if (nm %in% names(final_wrappers)) final_wrappers[[nm]]
          else models[[nm]]
    pred <- fp(train_val, test)
    retrospective_predictions[[nm]] <<- pred
    if (nm %in% names(final_wrappers)) {
      retrospective_lambdas[[nm]] <<- final_trace_env$last_lambda
    }
    fm <- backtest_fold_metrics(test, pred)
    fm |>
      dplyr::mutate(
        model = nm,
        selected_h12 = nm == selected_h12,
        selected_h1 = nm == selected_h1,
        .before = 1
      )
  })) |>
    dplyr::relocate(model, MAE, RMSE, R2, total_bias) |>
    dplyr::arrange(RMSE)

  final_traces <- dplyr::bind_rows(final_trace_env$traces) |>
    dplyr::mutate(outer_fold = "retrospective_refit", task_horizon = 12L) |>
    dplyr::select(
      task_horizon, outer_fold, model, outer_train_end, test_start, test_end,
      inner_fold, lambda, MAE, RMSE, R2, status, selected
    )
  tuning_traces <- dplyr::bind_rows(
    tuning_traces |> dplyr::mutate(outer_fold = as.character(outer_fold)),
    final_traces
  )

  # Predictions on the retrospective window for the selected model of
  # each horizon (if the horizons agree, one set is produced once).
  selected_models <- unique(c(selected_h12, selected_h1))
  artifacts <- list()
  prediction_sets <- lapply(selected_models, function(nm) {
    lam <- if(nm %in% names(final_wrappers)) retrospective_lambdas[[nm]] else NA_real_
    artifact <- fit_artifact(train_val,nm,lam,data_hash=data_hash,
      reference_hash=digest_file(paths$reference_coordinates),
      intended_horizons=c(if(nm==selected_h1) 1L, if(nm==selected_h12) 12L))
    artifacts[[nm]] <<- artifact
    pred <- retrospective_predictions[[nm]]
    stopifnot(isTRUE(all.equal(pred, predict_artifact(artifact, test))))
    test |>
      dplyr::transmute(
        model_id = nm,
        training_cutoff = artifact$training_cutoff,
        lambda = lam,
        data_hash = data_hash,
        month = as.Date(month),
        neighborhood,
        lon, lat,
        actual = theft_count,
        predicted = pred,
        residual = actual - predicted
      )
  })
  names(prediction_sets) <- selected_models
  error_reports <- lapply(prediction_sets, summarise_forecast_errors)

  message("7/7 Writing outputs, artifacts, correction experiment and figures ...")
  corrections <- correction_backtest(train_val,folds_h12,lambda_grid)
  readr::write_csv(corrections,file.path(paths$table_dir,"backtransform_corrections.csv"))
  readr::write_csv(audit, file.path(paths$table_dir, "data_audit.csv"))
  readr::write_csv(
    backtest_results, file.path(paths$table_dir, "backtest_folds.csv")
  )
  readr::write_csv(
    backtest_summary, file.path(paths$table_dir, "backtest_summary.csv")
  )
  readr::write_csv(
    retrospective, file.path(paths$table_dir, paste0("retrospective_", retro_year, ".csv"))
  )
  readr::write_csv(
    tuning_traces, file.path(paths$table_dir, "tuning_traces.csv")
  )
  for (nm in selected_models) {
    slug <- gsub("[^A-Za-z0-9]+", "_", tolower(nm))
    save_artifact(artifacts[[nm]],file.path(paths$model_dir,paste0(slug,".rds")))
    restored <- readRDS(file.path(paths$model_dir,paste0(slug,".rds")))
    stopifnot(isTRUE(all.equal(predict_artifact(restored,test),prediction_sets[[nm]]$predicted)))
    readr::write_csv(
      prediction_sets[[nm]],
      file.path(paths$table_dir, paste0("predictions_", slug, ".csv"))
    )
    readr::write_csv(
      error_reports[[nm]]$monthly,
      file.path(paths$table_dir, paste0("monthly_errors_", slug, ".csv"))
    )
    readr::write_csv(
      error_reports[[nm]]$by_neighborhood,
      file.path(paths$table_dir, paste0("neighborhood_errors_", slug, ".csv"))
    )
  }

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
  for (nm in selected_models) {
    slug <- gsub("[^A-Za-z0-9]+", "_", tolower(nm))
    ggplot2::ggsave(
      file.path(
        paths$figure_dir, paste0("04_observed_vs_predicted_", slug, ".png")
      ),
      plot_observed_vs_predicted(prediction_sets[[nm]]) + ggplot2::labs(subtitle=paste(nm, "|", retro_year, "annual-batch retrospective")),
      width = 9, height = 5.4, dpi = 180, bg = "white"
    )
    ggplot2::ggsave(
      file.path(
        paths$figure_dir, paste0("05_residual_distribution_", slug, ".png")
      ),
      plot_residual_distribution(prediction_sets[[nm]]) + ggplot2::labs(subtitle=paste(nm, "|", retro_year, "annual-batch retrospective")),
      width = 9, height = 5.4, dpi = 180, bg = "white"
    )
  }

  message("Done. Backtest summary (selection basis):")
  print(backtest_summary, n = Inf)
  message("\nRetrospective ", retro_year, " (descriptive only):")
  print(retrospective, n = Inf)
  for (nm in selected_models) {
    er <- error_reports[[nm]]
    message(sprintf(
      "  [%s] total actual = %.1f, predicted = %.1f, rel. bias = %+.2f%%",
      nm, er$total_actual, er$total_predicted, 100 * er$total_rel_bias
    ))
  }

  files <- c(list.files(paths$table_dir,full.names=TRUE),list.files(paths$figure_dir,full.names=TRUE),
    list.files(paths$model_dir,full.names=TRUE))
  files <- substring(files, nchar(paths$root) + 2L)
  manifest <- list(generated_at=format(Sys.time(),tz="UTC"),data_hash=data_hash,
    reference_hash=digest_file(paths$reference_coordinates),
    selected_h1=selected_h1,selected_h12=selected_h12,
    retrospective_protocol = sprintf(
      "Fit through %d; predict all 12 months of %d without updating",
      retro_year - 1L, retro_year
    ),
    files=files, session_info=capture.output(sessionInfo()))
  jsonlite::write_json(manifest,file.path(paths$root,"output","run_manifest.json"),pretty=TRUE,auto_unbox=TRUE)
  invisible(list(
    paths = paths,
    audit = audit,
    panel = panel,
    splits = splits,
    backtest_results = backtest_results,
    backtest_summary = backtest_summary,
    retrospective = retrospective,
    tuning_traces = tuning_traces,
    selected_h12 = selected_h12,
    selected_h1 = selected_h1,
    prediction_sets = prediction_sets,
    error_reports = error_reports
  ))
}

if (sys.nframe() == 0L) {
  main()
}
