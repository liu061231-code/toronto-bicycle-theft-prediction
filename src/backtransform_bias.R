# Training-only back-transform correction experiment; no causal decomposition.
args <- commandArgs(FALSE)
script <- gsub("~+~"," ",sub("^--file=","",args[grepl("^--file=",args)][1]),fixed=TRUE)
ROOT <- dirname(dirname(normalizePath(script)))
for (f in c("config","prepare_data","features","models","validation","evaluate","backtest","artifacts"))
  source(file.path(ROOT,"src",paste0(f,".R")))
paths <- project_paths(ROOT)
raw <- read_bicycle(paths$raw_data)
panel <- make_monthly_panel(raw,load_reference_coordinates(paths$reference_coordinates))$panel
development <- panel[panel$year<=2024,]
grid <- exp(seq(log(4),log(1e-4),length.out=14))
results <- correction_backtest(development,make_rolling_folds(development,12),grid)
dir.create(paths$table_dir,recursive=TRUE,showWarnings=FALSE)
readr::write_csv(results,file.path(paths$table_dir,"backtransform_corrections.csv"))
print(results)
