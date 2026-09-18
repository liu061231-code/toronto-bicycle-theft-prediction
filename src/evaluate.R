# evaluate.R --------------------------------------------------------------
# Model comparison, final evaluation, and reporting.
#
# This module ties the validation and model modules together: it runs every
# candidate (baselines and models) through the same expanding-window CV, then
# produces a final hold-out evaluation on the untouched 2023 test set.

# Run a named set of models through expanding-window CV and return per-fold
# metrics for each model. `models` is a named list of `fit_predict`
# functions.
compare_models_cv <- function(
    train_val_data, folds, models, seed = random_seed) {
  set.seed(seed)
  all_folds <- lapply(names(models), function(model_name) {
    m <- cross_validate(
      train_val_data, folds, models[[model_name]]
    )
    m |>
      dplyr::mutate(model = model_name) |>
      dplyr::relocate(model, .before = 1)
  })
  dplyr::bind_rows(all_folds)
}

# Summarise per-fold metrics into a mean (+/- sd) comparison table.
summarise_cv <- function(cv_results) {
  cv_results |>
    dplyr::group_by(model) |>
    dplyr::summarise(
      cv_MAE = mean(MAE),
      cv_RMSE = mean(RMSE),
      cv_R2 = mean(R2),
      .groups = "drop"
    ) |>
    dplyr::arrange(cv_RMSE)
}

# Fit a model on train+validation and evaluate on the final hold-out test
# set. `fit_predict` receives the combined train+validation data and the
# test data.
final_holdout_evaluate <- function(
    train_data, validation_data, test_data, fit_predict, model_name) {
  train_val <- dplyr::bind_rows(train_data, validation_data)
  pred <- fit_predict(train_val, test_data)
  m <- regression_metrics(test_data$theft_count, pred)
  tibble::tibble(
    model = model_name,
    MAE = m$MAE, RMSE = m$RMSE, R2 = m$R2
  )
}

# Produce the final model comparison table: CV performance plus hold-out
# test performance side by side. Rows without a CV entry (e.g. the tuned
# final model) keep their own cv_* values if already present, otherwise NA.
build_comparison_table <- function(cv_summary, holdout_results) {
  # Strip any cv_* columns from holdout_results to avoid name collisions,
  # then join on the shared cv_summary.
  holdout_clean <- holdout_results
  extra_cv <- holdout_results |>
    dplyr::select(dplyr::any_of(c("cv_MAE", "cv_RMSE", "cv_R2")))
  holdout_clean <- holdout_results |>
    dplyr::select(-dplyr::any_of(c("cv_MAE", "cv_RMSE", "cv_R2"))) |>
    dplyr::rename(test_MAE = MAE, test_RMSE = RMSE, test_R2 = R2)
  joined <- holdout_clean |>
    dplyr::left_join(cv_summary, by = "model")
  # Re-inject per-row CV values where they were supplied (tuned model).
  if (ncol(extra_cv) > 0L) {
    idx <- which(!is.na(extra_cv[[1]]))
    for (j in idx) {
      if ("cv_MAE" %in% names(extra_cv)) joined$cv_MAE[j] <- extra_cv$cv_MAE[j]
      if ("cv_RMSE" %in% names(extra_cv)) joined$cv_RMSE[j] <- extra_cv$cv_RMSE[j]
      if ("cv_R2" %in% names(extra_cv)) joined$cv_R2[j] <- extra_cv$cv_R2[j]
    }
  }
  joined |>
    dplyr::relocate(model, cv_MAE, cv_RMSE, cv_R2, test_MAE, test_RMSE, test_R2)
}
