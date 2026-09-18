# backtransform_bias.R ----------------------------------------------------
# Verify whether the log1p back-transform bias is a plausible cause of the
# 2025 under-prediction (handoff 4.D).
#
# The final model fits  y = log1p(Y)  and predicts  expm1( E[y | X] ).
# Jensen's inequality gives  expm1( E[log1p(Y)] ) <= E[Y]  when the
# conditional distribution of Y is non-degenerate. If the model's residual
# variance on the log scale is large, the back-transformed mean is a downward-
# biased estimate of the conditional count mean, and that bias compounds into
# a systematic citywide under-prediction.
#
# This script quantifies the bias empirically WITHOUT touching the 2025 test
# totals: it fits the ridge model on train+validation, computes in-sample
# (train+val) log-scale residuals, estimates the expected correction under a
# log-normal approximation, and reports the implied total under-prediction.
# It never uses 2025 labels to calibrate, so the estimate is honest.

suppressMessages({
  library(dplyr)
  library(readr)
})

source("src/config.R")
source("src/prepare_data.R")
source("src/features.R")
source("src/validation.R")
source("src/models.R")

paths <- project_paths()

cat("Loading data and building panel ...\n")
raw <- read_bicycle(paths$raw_data)
panel <- make_monthly_panel(raw)$panel
splits <- split_panel(panel)
train_val <- bind_rows(splits$train, splits$validation)

cat("Fitting ridge model on train+validation ...\n")
lambda <- 0.02848  # the previously tuned value (kept fixed for this analysis)
fit_closure <- model_ridge_log(lambda = lambda)
pred_log <- fit_closure(train_val, train_val)  # in-sample log predictions

# In-sample log-scale residuals:  e_i = log1p(Y_i) - E[log1p(Y_i)|X_i]
y_log <- log1p(train_val$theft_count)
resid <- y_log - log1p(pmax(0, pred_log))
resid_sd <- sd(resid)

cat(sprintf("In-sample log-scale residual SD: %.4f\n", resid_sd))

# Log-normal back-transform correction. If the conditional distribution of
# log1p(Y) is approximately normal with variance sigma^2, then
#   E[Y] = E[exp(log1p(Y)) - 1]
#        ~ exp(mu + sigma^2/2) - 1
# whereas the current predictor uses  exp(mu) - 1 = expm1(mu).
# The multiplicative correction on the count scale is therefore roughly
#   exp(sigma^2 / 2)  for the non-degenerate component.
correction <- exp(resid_sd^2 / 2)
cat(sprintf("Implied multiplicative correction: %.4f\n", correction))

# A more direct empirical check: compare the mean of expm1(y_log) against the
# mean of Y on the training data, using the fitted mu's. This is the realized
# Jensen gap on the training distribution.
mu <- log1p(pmax(0, pred_log))
naive_mean <- mean(expm1(mu))
actual_mean <- mean(train_val$theft_count)
cat(sprintf(
  "Training mean of expm1(mu): %.4f  vs actual mean %.4f  (gap %.4f)\n",
  naive_mean, actual_mean, actual_mean - naive_mean
))

cat("\n--- Interpretation ---\n")
cat("If the log-scale residual SD is small, the back-transform bias is a\n")
cat("minor contributor and the 35%% under-prediction must come from elsewhere\n")
cat("(e.g. genuine distribution shift / trend extrapolation). If it is large,\n")
cat("a log-normal correction could recover much of the missing total.\n")

# Quantify the decomposition more precisely.
# 1. In-sample (train+val) realized Jensen gap as a fraction of the mean:
insample_gap_frac <- (actual_mean - naive_mean) / actual_mean
cat(sprintf("\nIn-sample Jensen gap as fraction of mean: %.1f%%\n",
            100 * insample_gap_frac))

# 2. The 2025 test under-prediction is ~35%. The portion attributable to the
#    back-transform bias is at most the in-sample gap (it is structural and
#    present even with perfect calibration on the training distribution). The
#    remainder reflects genuine distribution shift (the 2025 level being lower
#    than the historical conditional mean).
cat("The back-transform bias is STRUCTURAL: it is present even if the model\n")
cat("were perfectly calibrated on the training distribution. It explains a\n")
cat("floor of under-prediction equal to the in-sample gap above. Only the\n")
cat("residual (beyond that floor) can be attributed to genuine distribution\n")
cat("shift of the 2025 level relative to history.\n")
