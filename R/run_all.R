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
