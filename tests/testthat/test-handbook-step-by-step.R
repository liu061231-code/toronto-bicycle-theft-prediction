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
    as.numeric(result$basis_recipe$time_knots),
    c(20, 39, 58, 77)
  )
  testthat::expect_equal(nrow(result$basis_recipe$rbf_centers), 16)
  testthat::expect_equal(nrow(result$x_train), 13440)
  testthat::expect_equal(nrow(result$x_validation), 1680)
  testthat::expect_equal(nrow(result$x_test), 1680)
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
