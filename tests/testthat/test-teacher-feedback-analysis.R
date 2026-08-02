source(testthat::test_path("..", "..", "R", "config.R"))
source(testthat::test_path("..", "..", "R", "01_prepare_data.R"))
source(testthat::test_path("..", "..", "R", "03_model.R"))
source(testthat::test_path("..", "..", "R", "06_teacher_feedback_analysis.R"))

testthat::test_that("seasonal coefficients yield amplitude peak and ratio", {
  coefficients <- c(sin1 = 1, cos1 = 0, sin2 = 0, cos2 = 0)
  result <- summarise_seasonal_cycle(coefficients)

  testthat::expect_equal(result$summary$annual_amplitude, 1)
  testthat::expect_equal(result$summary$semiannual_amplitude, 0)
  testthat::expect_equal(result$summary$peak_month, 3L)
  testthat::expect_equal(result$summary$trough_month, 9L)
  testthat::expect_equal(result$summary$peak_to_trough_ratio, exp(2))
  testthat::expect_equal(nrow(result$monthly), 12L)
})
