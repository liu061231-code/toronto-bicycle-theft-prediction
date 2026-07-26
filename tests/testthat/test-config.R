source(testthat::test_path("..", "..", "R", "config.R"))

testthat::test_that("project paths are absolute and the source exists", {
  p <- project_paths()
  testthat::expect_true(file.exists(p$source_csv))
  testthat::expect_true(startsWith(p$source_csv, "/"))
  testthat::expect_match(
    p$pdf_file,
    "STAT3888_自行车盗窃时空基函数回归_完整项目手册.pdf$"
  )
})
