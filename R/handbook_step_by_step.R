handbook_project_root <- local({
  source_files <- vapply(
    sys.frames(),
    function(frame) {
      if (is.null(frame$ofile)) NA_character_ else as.character(frame$ofile)
    },
    character(1)
  )
  source_files <- source_files[!is.na(source_files)]
  if (!length(source_files)) {
    stop(
      "Source this file with source('R/handbook_step_by_step.R') ",
      "or an absolute path."
    )
  }
  source_file <- normalizePath(tail(source_files, 1), mustWork = TRUE)
  normalizePath(file.path(dirname(source_file), ".."), mustWork = TRUE)
})

source(file.path(handbook_project_root, "R", "config.R"))
source(file.path(handbook_project_root, "R", "01_prepare_data.R"))
source(file.path(handbook_project_root, "R", "02_visualize.R"))
source(file.path(handbook_project_root, "R", "03_model.R"))

write_handbook_outputs <- function(result) {
  p <- result$paths
  readr::write_csv(
    result$audit,
    file.path(p$analysis_dir, "data_audit.csv")
  )
  readr::write_csv(
    result$panel,
    file.path(p$analysis_dir, "bicycle_monthly_panel.csv")
  )
  readr::write_csv(
    result$prepared$coordinates,
    file.path(p$analysis_dir, "neighborhood_coordinates.csv")
  )
  readr::write_csv(
    result$model_fit$metrics,
    file.path(p$analysis_dir, "model_metrics.csv")
  )
  readr::write_csv(
    result$model_fit$test_predictions,
    file.path(p$analysis_dir, "test_predictions.csv")
  )
  fold_table <- purrr::map_dfr(
    result$model_fit$cv_folds,
    function(fold_data) {
      tibble::tibble(
        fold = fold_data$fold,
        train_start = min(fold_data$train$year),
        train_end = fold_data$train_end,
        validation_year = fold_data$validation_year,
        training_rows = nrow(fold_data$train),
        validation_rows = nrow(fold_data$validation)
      )
    }
  )
  readr::write_csv(
    fold_table,
    file.path(p$analysis_dir, "cross_validation_folds.csv")
  )
  readr::write_csv(
    result$model_fit$cv_results,
    file.path(p$analysis_dir, "cross_validation_results.csv")
  )
  readr::write_csv(
    tibble::tibble(
      parameter = c(
        "selected_lambda", "mean_cv_rmse", "cv_folds",
        "time_basis_knots", "spatial_rbf_centers", "rbf_sigma"
      ),
      value = c(
        result$model_fit$selected_lambda,
        result$model_fit$validation_rmse,
        length(result$model_fit$cv_folds),
        length(result$model_fit$recipe$time_knots),
        nrow(result$model_fit$recipe$rbf_centers),
        result$model_fit$recipe$rbf_sigma
      )
    ),
    file.path(p$analysis_dir, "basis_metadata.csv")
  )
  invisible(result)
}

run_handbook_steps <- function(
    write_outputs = TRUE,
    workspace_root = handbook_project_root) {
  paths <- project_paths(workspace_root)
  ensure_packages()
  dir.create(paths$analysis_dir, recursive = TRUE, showWarnings = FALSE)
  dir.create(paths$figure_dir, recursive = TRUE, showWarnings = FALSE)
  dir.create(paths$pdf_dir, recursive = TRUE, showWarnings = FALSE)

  raw <- read_bicycle(paths$source_csv)
  audit <- audit_bicycle(raw)
  prepared <- make_monthly_panel(raw)
  panel <- prepared$panel

  stopifnot(nrow(raw) == 31833L)
  stopifnot(nrow(panel) == 16800L)
  stopifnot(all(c("lon", "lat") %in% names(panel)))
  stopifnot(all(table(panel$neighborhood) == 120L))

  figure_dir <- if (write_outputs) {
    paths$figure_dir
  } else {
    tempfile("stat3888-handbook-figures-")
  }
  task1_paths <- make_task1_plots(panel, figure_dir)
  stopifnot(all(file.exists(task1_paths)))

  splits <- split_panel(panel)
  stopifnot(identical(
    vapply(splits, nrow, integer(1)),
    c(train = 13440L, validation = 1680L, test = 1680L)
  ))
  model_fit <- fit_models(splits)
  basis_recipe <- model_fit$recipe
  x_train <- make_design_matrix(splits$train, basis_recipe)
  x_validation <- make_design_matrix(splits$validation, basis_recipe)
  x_test <- make_design_matrix(splits$test, basis_recipe)
  stopifnot(nrow(basis_recipe$rbf_centers) == 16L)
  stopifnot(identical(
    c(nrow(x_train), nrow(x_validation), nrow(x_test)),
    c(13440L, 1680L, 1680L)
  ))

  model_paths <- make_model_plots(
    model_fit, panel, basis_recipe, figure_dir
  )
  stopifnot(all(file.exists(model_paths)))

  result <- list(
    paths = paths,
    raw = raw,
    audit = audit,
    prepared = prepared,
    panel = panel,
    task1_paths = task1_paths,
    splits = splits,
    basis_recipe = basis_recipe,
    x_train = x_train,
    x_validation = x_validation,
    x_test = x_test,
    rolling_folds = model_fit$cv_folds,
    cv_results = model_fit$cv_results,
    cv_summary = model_fit$cv_summary,
    model_fit = model_fit,
    model_paths = model_paths
  )
  if (write_outputs) {
    write_handbook_outputs(result)
  }
  result
}
