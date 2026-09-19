test_that("metrics define empty and constant targets", {
  expect_true(is.na(regression_metrics(c(1,1), c(1,2))$R2))
  expect_true(is.na(regression_metrics(numeric(), numeric())$RMSE))
  expect_error(regression_metrics(1:2, 1), "length")
  p <- tibble::tibble(month=as.Date("2025-01-01"), neighborhood="A",
                      actual=0, predicted=1)
  expect_true(is.na(summarise_forecast_errors(p)$by_neighborhood$rel_bias))
})

test_that("as-of filtering excludes late and unknown reports", {
  d <- data.frame(date=as.Date(rep("2025-12-30",3)),
                  report_date=c("2025-12-31","2026-01-03",NA))
  expect_equal(nrow(records_as_of(d,"2025-12-31")),1)
  expect_equal(nrow(records_as_of(d,"2026-01-31")),2)
})

test_that("new future geography cannot change historical rows", {
  source(file.path(TEST_ROOT,"test/helper.R"))
  raw <- make_synthetic_raw(n_years=5)
  ref <- make_neighborhood_coordinates(raw[raw$date<=as.Date("2017-12-31"),])
  a <- make_monthly_panel(raw,ref)$panel
  extra <- raw[1,];extra$date <- as.Date("2025-01-01");extra$neighborhood <- "NEW"
  expect_warning(b <- make_monthly_panel(dplyr::bind_rows(raw,extra),ref)$panel,"mapped to NSA")
  expect_equal(a[a$year<=2017,],b[b$year<=2017,])
})

test_that("folds require a full validation horizon", {
  d <- data.frame(time_index=1:65)
  expect_length(make_expanding_folds(d, 60, 12, 12), 0)
  expect_length(make_rolling_folds(d, 12, 60), 0)
})

test_that("incomplete solver paths cannot win on fewer folds", {
  d <- data.frame(time_index=1:72, theft_count=1:72)
  pm <- list(
    fit=function(tr, grid) list(recipe=NULL, fit=list(lambda=if(nrow(tr)==48) 1 else c(1,.1))),
    build_x=function(recipe, te) te,
    predict_x=function(fit, x, lambda) x$theft_count + if(lambda==1) 1 else 0)
  out <- tune_lambda_time_cv(d, c(1,.1), function(lam) NULL, path_model=pm)
  expect_equal(nrow(out$grid),4)
  expect_equal(out$best_lambda,1)
  expect_true(any(out$grid$status != "ok"))
})

test_that("reference predates every production inner origin", {
  ref <- readr::read_csv(file.path(TEST_ROOT,"data/reference/neighborhood_coordinates.csv"), show_col_types=FALSE)
  expect_true(all(as.Date(ref$period_end) <= as.Date("2017-12-31")))
})

test_that("saved correction artifacts predict without evaluation labels", {
  source(file.path(TEST_ROOT,"test/helper.R"))
  raw <- make_synthetic_raw()
  panel <- make_monthly_panel(raw,make_neighborhood_coordinates(raw))$panel
  panel$theft_count <- (seq_len(nrow(panel))*7) %% 11
  tr <- panel[panel$time_index<=48,]
  te <- panel[panel$time_index>48 & panel$time_index<=60,]
  for(method in c("naive","lognormal","smearing")) {
    a <- fit_artifact(tr,"Basis Ridge (tuned)",.1,method)
    pred <- predict_artifact(a,te)
    te$theft_count <- 9999
    expect_equal(pred,predict_artifact(a,te))
    expect_true(all(is.finite(pred) & pred>=0))
    expect_true(is.finite(a$factor) && a$factor>0)
    f <- tempfile(fileext=".rds")
    saveRDS(a,f)
    expect_equal(pred,predict_artifact(readRDS(f),te))
    unlink(f)
  }
})

test_that("ridge tuning handles a constant chronological response", {
  source(file.path(TEST_ROOT,"test/helper.R"))
  raw <- make_synthetic_raw(n_neighborhoods=2, n_years=6, with_nsa=FALSE)
  d <- make_monthly_panel(raw, make_neighborhood_coordinates(raw))$panel
  d$theft_count <- 0
  tuned <- tune_lambda_time_cv(
    d, c(1, .1), model_ridge_log, initial_months=36L,
    step_months=12L, horizon_months=12L, path_model=ridge_log_path_model
  )
  expect_true(is.finite(tuned$best_lambda))
  expect_true(all(is.finite(tuned$grid$RMSE)))
})
