source("R/config.R")

p <- project_paths()
dir.create(p$analysis_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(p$figure_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(p$pdf_dir, recursive = TRUE, showWarnings = FALSE)
ensure_packages()

source("R/01_prepare_data.R")
raw <- read_bicycle(p$source_csv)
prepared <- make_monthly_panel(raw)
readr::write_csv(
  audit_bicycle(raw),
  file.path(p$analysis_dir, "data_audit.csv")
)
readr::write_csv(
  prepared$panel,
  file.path(p$analysis_dir, "bicycle_monthly_panel.csv")
)
readr::write_csv(
  prepared$coordinates,
  file.path(p$analysis_dir, "neighborhood_coordinates.csv")
)

source("R/02_visualize.R")
task1_paths <- make_task1_plots(prepared$panel, p$figure_dir)
stopifnot(all(file.exists(task1_paths)))

source("R/03_model.R")
splits <- split_panel(prepared$panel)
basis_recipe <- make_basis_recipe(splits$train)
model_fit <- fit_models(splits, basis_recipe)
readr::write_csv(
  model_fit$metrics,
  file.path(p$analysis_dir, "model_metrics.csv")
)
readr::write_csv(
  model_fit$test_predictions,
  file.path(p$analysis_dir, "test_predictions.csv")
)
readr::write_csv(
  tibble::tibble(
    parameter = c(
      "selected_lambda", "validation_rmse", "time_basis_knots",
      "spatial_rbf_centers", "rbf_sigma"
    ),
    value = c(
      model_fit$selected_lambda,
      model_fit$validation_rmse,
      length(basis_recipe$time_knots),
      nrow(basis_recipe$rbf_centers),
      basis_recipe$rbf_sigma
    )
  ),
  file.path(p$analysis_dir, "basis_metadata.csv")
)
model_paths <- make_model_plots(
  model_fit, prepared$panel, basis_recipe, p$figure_dir
)
stopifnot(all(file.exists(model_paths)))
