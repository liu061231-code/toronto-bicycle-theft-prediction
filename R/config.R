project_paths <- function() {
  root <- normalizePath(".", mustWork = TRUE)
  list(
    root = root,
    source_csv = "/Users/liumingyuan/Downloads/four_dataset/bicycle.csv",
    analysis_dir = file.path(root, "output", "analysis"),
    figure_dir = file.path(root, "output", "figures"),
    pdf_dir = file.path(root, "output", "pdf"),
    pdf_file = file.path(
      root,
      "output",
      "pdf",
      "STAT3888_自行车盗窃时空基函数回归_完整项目手册.pdf"
    )
  )
}

ensure_packages <- function() {
  required <- c(
    "tidyverse", "lubridate", "ggplot2", "splines",
    "glmnet", "mgcv", "sf", "testthat"
  )
  missing <- required[
    !vapply(required, requireNamespace, logical(1), quietly = TRUE)
  ]
  if (length(missing)) {
    stop(
      "Missing R packages: ", paste(missing, collapse = ", "),
      ". Install with install.packages(c(",
      paste(sprintf('"%s"', missing), collapse = ", "), "))."
    )
  }
  invisible(TRUE)
}
