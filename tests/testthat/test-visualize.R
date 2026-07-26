source(testthat::test_path("..", "..", "R", "config.R"))
source(testthat::test_path("..", "..", "R", "02_visualize.R"))

p <- project_paths()
panel <- readr::read_csv(
  file.path(p$analysis_dir, "bicycle_monthly_panel.csv"),
  show_col_types = FALSE
)
paths <- make_task1_plots(panel, p$figure_dir)

testthat::test_that("all Task 1 figures are generated", {
  testthat::expect_setequal(
    names(paths),
    c("trend", "seasonality", "hotspots", "heatmap")
  )
  testthat::expect_true(all(file.exists(paths)))
  testthat::expect_true(all(file.info(paths)$size > 20000))
})
