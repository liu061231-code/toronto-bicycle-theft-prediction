# Usage: Rscript src/predict.R model.rds months output.csv
args <- commandArgs(FALSE)
script <- gsub("~+~"," ",sub("^--file=","",args[grepl("^--file=",args)][1]),fixed=TRUE)
ROOT <- dirname(dirname(normalizePath(script)))
for(f in c("features","models","artifacts")) source(file.path(ROOT,"src",paste0(f,".R")))
cli <- commandArgs(TRUE)
if(length(cli)!=3) stop("Usage: Rscript src/predict.R model.rds months output.csv")
a <- readRDS(cli[1])
n <- as.integer(cli[2])
if(is.na(n) || !n %in% 1:12) stop("months must be 1..12")
cutoff <- as.Date(a$training_cutoff)
months <- seq(cutoff,by="month",length.out=n+1)[-1]
if(!is.null(a$fitted)) {
  recipe <- a$fitted$recipe
  coords <- a$coordinates
} else {
  coords <- unique(a$train[c("neighborhood","lon","lat")])
}
if(is.null(coords)) stop("Artifact lacks reference coordinates; regenerate pipeline artifacts")
newdata <- merge(coords,data.frame(month=months),by=NULL)
newdata$month_of_year <- as.integer(format(newdata$month,"%m"))
newdata$year <- as.integer(format(newdata$month,"%Y"))
newdata$time_index <- (newdata$year-2014)*12+newdata$month_of_year
newdata$predicted <- predict_artifact(a,newdata)
newdata$model_id <- a$model_id
newdata$training_cutoff <- a$training_cutoff
newdata$data_hash <- a$data_hash
dir.create(dirname(cli[3]),recursive=TRUE,showWarnings=FALSE)
readr::write_csv(newdata,cli[3])
cat("Forecast is relative to artifact cutoff",a$training_cutoff,"not today's date.\n")
