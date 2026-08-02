source("R/handbook_step_by_step.R")
result <- run_handbook_steps(write_outputs = TRUE)
selected <- result$interaction_comparison |>
  dplyr::filter(selected_by_cv)
cat(sprintf(
  paste0(
    "Primary model selected by minimum mean rolling-CV RMSE: %s ",
    "(mean CV RMSE = %.6f).\n"
  ),
  selected$model,
  selected$mean_cv_rmse
))
