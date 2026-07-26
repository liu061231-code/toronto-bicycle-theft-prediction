source("R/config.R")

p <- project_paths()
dir.create(p$analysis_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(p$figure_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(p$pdf_dir, recursive = TRUE, showWarnings = FALSE)
ensure_packages()
