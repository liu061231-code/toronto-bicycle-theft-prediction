# Network-free integration test: prepare -> tune -> fit -> reload -> predict.
args <- commandArgs(FALSE)
script <- gsub("~+~"," ",sub("^--file=","",args[grepl("^--file=",args)][1]),fixed=TRUE)
ROOT <- dirname(dirname(normalizePath(script)))
for(f in c("config","prepare_data","features","models","validation","evaluate","backtest","artifacts"))
  source(file.path(ROOT,"src",paste0(f,".R")))
source(file.path(ROOT,"test","helper.R"))
raw <- make_synthetic_raw(n_years=7)
panel <- make_monthly_panel(raw,make_neighborhood_coordinates(raw))$panel
panel$theft_count <- (seq_len(nrow(panel))*7 + panel$time_index) %% 9
train <- panel[panel$time_index<=72,]
test <- panel[panel$time_index>72 & panel$time_index<=84,]
tuning <- tune_lambda_time_cv(train,c(.1,1),model_ridge_log,path_model=ridge_log_path_model)
a <- fit_artifact(train,"Basis Ridge (tuned)",tuning$best_lambda,"smearing")
p <- predict_artifact(a,test)
file <- tempfile(fileext=".rds")
save_artifact(a,file)
stopifnot(length(p)==nrow(test),all(is.finite(p)),all(p>=0),
          isTRUE(all.equal(p,predict_artifact(readRDS(file),test))))
print(backtest_fold_metrics(test,p))
unlink(c(file,sub("\\.rds$","_metadata.json",file)))
cat("Smoke pipeline passed\n")
