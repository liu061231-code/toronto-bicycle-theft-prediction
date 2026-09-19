# Serializable fit/predict contract. Never read evaluation labels at predict time.
fit_artifact <- function(train, model_id, lambda=NA_real_, correction="naive",
                         data_hash=NA_character_, reference_hash=NA_character_,
                         intended_horizons=integer()) {
  ridge <- identical(model_id, "Basis Ridge (tuned)")
  poisson <- identical(model_id, "Poisson (area, tuned)")
  a <- list(model_id=model_id, lambda=lambda, correction=correction,
            training_cutoff=as.character(max(train$month)),
            data_hash=data_hash, reference_hash=reference_hash,
            intended_horizons=as.integer(intended_horizons),
            session_info=capture.output(sessionInfo()), factor=1,
            coordinates=unique(as.data.frame(train[c("neighborhood","lon","lat")])) )
  if (ridge || poisson) {
    pm <- if(ridge) ridge_log_path_model else poisson_path_model(with_area=TRUE)
    a$fitted <- pm$fit(train, lambda)
    if(ridge) {
      x <- make_design_matrix(train, a$fitted$recipe)
      mu <- as.numeric(predict(a$fitted$fit, newx=x, s=lambda))
      residual <- log1p(train$theft_count)-mu
      a$factor <- switch(correction, naive=1,
        lognormal=exp(stats::var(residual)/2), smearing=mean(exp(residual)),
        stop("Unknown correction"))
      if(!is.finite(a$factor) || a$factor<=0) stop("Invalid correction factor")
    }
  } else {
    # Baselines and OLS retain training data for their deterministic closure.
    a$train <- train
  }
  class(a) <- "theft_artifact"
  a
}

predict_artifact <- function(a, new_data) {
  if (!requireNamespace("glmnet", quietly=TRUE)) stop("glmnet is required to load this artifact")
  if(identical(a$model_id,"Basis Ridge (tuned)")) {
    x <- make_design_matrix(new_data,a$fitted$recipe)
    mu <- as.numeric(predict(a$fitted$fit,newx=x,s=a$lambda))
    return(pmax(0, exp(mu)*a$factor-1))
  }
  if(identical(a$model_id,"Poisson (area, tuned)")) {
    x <- make_glm_design_matrix(new_data,a$fitted$recipe,with_area=TRUE)
    return(as.numeric(predict(a$fitted$fit,newx=x,s=a$lambda,type="response")))
  }
  fp <- switch(a$model_id,
    "Global mean"=baseline_global_mean,
    "Neighbourhood mean"=baseline_neighborhood_mean,
    "Recent 12-mo mean"=baseline_recent_seasonal_mean(12),
    "Seasonal naive"=baseline_seasonal_naive,
    "Basis OLS (log)"=model_ols_log(),
    "Poisson (compact)"=model_poisson_glm(lambda=.01,with_area=FALSE),
    "Negative-binomial"=model_negbin_glm(),stop("Unknown model"))
  fp(a$train,new_data)
}

save_artifact <- function(a, path) {
  saveRDS(a,path)
  metadata <- a[setdiff(names(a),c("fitted","train"))]
  jsonlite::write_json(metadata,sub("\\.rds$","_metadata.json",path),
                       auto_unbox=TRUE,pretty=TRUE,na="null")
}

# Training-residual corrections are predictive sensitivity experiments,
# not an identified decomposition of bias versus distribution shift.
correction_backtest <- function(data, folds, lambda_grid) {
  dplyr::bind_rows(lapply(seq_along(folds),function(i) {
    tr <- data[data$time_index %in% folds[[i]]$train,]
    te <- data[data$time_index %in% folds[[i]]$test,]
    tuning <- tune_lambda_time_cv(tr,lambda_grid,model_ridge_log,
                                  path_model=ridge_log_path_model)
    dplyr::bind_rows(lapply(c("naive","lognormal","smearing"),function(method) {
      a <- fit_artifact(tr,"Basis Ridge (tuned)",tuning$best_lambda,method)
      backtest_fold_metrics(te,predict_artifact(a,te)) |>
        dplyr::mutate(fold=i,correction=method,factor=a$factor,
                      lambda=a$lambda,training_cutoff=a$training_cutoff)
    }))
  }))
}
