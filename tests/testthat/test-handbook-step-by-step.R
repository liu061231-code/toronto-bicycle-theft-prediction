script_path <- testthat::test_path(
  "..", "..", "R", "handbook_step_by_step.R"
)

testthat::test_that("handbook workflow exposes verified intermediate objects", {
  testthat::expect_true(file.exists(script_path))
  if (!file.exists(script_path)) {
    return(invisible())
  }
  source(script_path)
  testthat::expect_true(
    "workspace_root" %in% names(formals(run_handbook_steps))
  )

  result <- run_handbook_steps(write_outputs = FALSE)

  testthat::expect_equal(nrow(result$raw), 31833)
  testthat::expect_equal(nrow(result$panel), 16800)
  testthat::expect_true(all(c("lon", "lat") %in% names(result$panel)))
  testthat::expect_true(all(table(result$panel$neighborhood) == 120))
  testthat::expect_equal(
    vapply(result$splits, nrow, integer(1)),
    c(train = 13440L, validation = 1680L, test = 1680L)
  )
  testthat::expect_equal(
    length(result$basis_recipe$time_knots),
    4
  )
  testthat::expect_equal(nrow(result$basis_recipe$rbf_centers), 16)
  testthat::expect_equal(nrow(result$x_train), 13440)
  testthat::expect_equal(nrow(result$x_validation), 1680)
  testthat::expect_equal(nrow(result$x_test), 1680)
  testthat::expect_equal(
    sort(unique(result$model_fit$cv_results$validation_year)),
    2018:2022
  )
  testthat::expect_equal(nrow(result$model_fit$cv_results), 500)
  testthat::expect_equal(nrow(result$model_fit$cv_summary), 100)
  testthat::expect_equal(
    length(result$model_fit$recipe$time_knots),
    4
  )
  testthat::expect_true(all(
    diff(result$model_fit$recipe$time_knots) > 0
  ))
  testthat::expect_lte(
    max(result$model_fit$recipe$time_knots),
    108
  )
  testthat::expect_true(
    "cross_validation" %in% names(result$model_paths)
  )

  output_result <- result
  output_result$paths$analysis_dir <- tempfile(
    "stat3888-cv-analysis-"
  )
  dir.create(output_result$paths$analysis_dir)
  write_handbook_outputs(output_result)
  expected_files <- c(
    "cross_validation_folds.csv",
    "cross_validation_results.csv",
    "model_metrics.csv",
    "test_predictions.csv",
    "basis_metadata.csv",
    "seasonal_coefficients.csv",
    "seasonal_cycle_summary.csv",
    "seasonal_cycle_monthly.csv",
    "interaction_model_comparison.csv"
  )
  testthat::expect_true(all(file.exists(file.path(
    output_result$paths$analysis_dir,
    expected_files
  ))))
})

testthat::test_that("handbook and saved pipeline metrics are identical", {
  testthat::expect_true(file.exists(script_path))
  if (!file.exists(script_path)) {
    return(invisible())
  }
  source(script_path)
  result <- run_handbook_steps(write_outputs = FALSE)
  expected <- readr::read_csv(
    file.path(result$paths$analysis_dir, "model_metrics.csv"),
    show_col_types = FALSE
  )

  testthat::expect_equal(
    as.data.frame(result$model_fit$metrics),
    as.data.frame(expected),
    tolerance = 1e-8
  )
})

testthat::test_that("teacher feedback outputs are written from fitted models", {
  result <- run_handbook_steps(write_outputs = FALSE)
  testthat::expect_true(all(c(
    "seasonal_analysis",
    "interaction_comparison",
    "teacher_feedback_paths"
  ) %in% names(result)))
  testthat::expect_equal(nrow(result$seasonal_analysis$coefficients), 4L)
  testthat::expect_equal(nrow(result$seasonal_analysis$monthly), 12L)
  testthat::expect_equal(nrow(result$interaction_comparison), 2L)
  testthat::expect_true(all(file.exists(result$teacher_feedback_paths)))

  candidate_names <- vapply(
    result$model_fit$candidate_fits,
    function(candidate) candidate$model,
    character(1)
  )
  additive_fit <- result$model_fit$candidate_fits[[
    match("Additive Ridge", candidate_names)
  ]]
  expected_coefficients <- extract_seasonal_coefficients(
    additive_fit$ridge_model,
    additive_fit$selected_lambda
  )
  testthat::expect_equal(
    result$seasonal_analysis$coefficients$estimate,
    unname(expected_coefficients)
  )
})
