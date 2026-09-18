# Toronto Bicycle Theft Prediction

A spatio-temporal machine learning project that forecasts monthly bicycle theft
counts across Toronto neighbourhoods, combining spline-based temporal trend
modelling, seasonal harmonics, and radial-basis-function spatial smoothing
inside a regularised linear model — plus an hourly hotspot analysis that turns
the same data into directly actionable patrol-planning insight.

## Overview

This repository builds a predictive model for **monthly reported bicycle thefts
per neighbourhood** in the City of Toronto over 2014–2025. The data are a
balanced panel (141 neighbourhood units × 144 months) with strong temporal
autocorrelation, a pronounced annual cycle, and heavy over-dispersion in the
count target. The goal is a model that generalises to *unseen future months*
rather than one that merely fits the past.

The panel has 140 named neighbourhoods plus one `NSA` ("Not Specified Area")
bucket that the publisher uses for records with no known location. `NSA` is
treated as an *unknown area*: it is retained for count reconciliation but
excluded from all spatial features (its coordinates are missing/zero and would
otherwise distort the spatial scale ~65×). See `data_dictionary.md` for the full
counting and geography calibre.

The project originated as a hands-on exercise in a spatio-temporal data science
course, and has since been reworked into a standalone predictive-modelling
project: a rigorous time-aware validation strategy, fair baseline and
multi-model comparison, hyperparameter tuning, and interpretable diagnostics.
The dataset was subsequently refreshed from the official open-data source
(40,583 incident records, now spanning 2014–2026), which extended the study
period through 2025 and unlocked two new signal fields — **hour of day** and
**premises type** — used in the operational hotspot analysis.

The final model is a **ridge-penalised Poisson regression** on a hand-crafted
design matrix (temporal B-splines + seasonal harmonics + spatial radial basis
functions + neighbourhood fixed effects). It reaches an out-of-sample R² of
**0.74** on the held-out 2025 test year, and its log link predicts the
conditional count mean directly, avoiding the `log1p` back-transform bias that
makes the earlier ridge-on-log model under-predict the citywide total. The
project also retains the ridge-on-log model (R² 0.67) as a strong, interpretable
baseline; the two are compared fairly in the model-comparison section.

## Problem Definition

- **Task type**: supervised regression (count prediction).
- **Prediction target**: `theft_count` — the number of bicycle thefts reported
  in a given neighbourhood during a given calendar month.
- **Features**: temporal position (month index), calendar month (seasonality),
  neighbourhood identity and centroid coordinates (spatial structure), and
  neighbourhood-level context (historical share of outdoor and commercial
  thefts, learned from training data only).
- **Evaluation objective**: minimise out-of-sample prediction error on future
  months, measured by MAE, RMSE, and R². Because the target is a skewed count,
  MAE is emphasised alongside RMSE.

## Dataset

- **Source**: [Toronto Police Service — Bicycle Thefts Open Data]
  (https://data.torontopolice.on.ca/datasets/TorontoPS::bicycle-thefts-open-data)
  (also listed on the [City of Toronto Open Data Portal]
  (https://open.toronto.ca/dataset/bicycle-thefts/)). Individual incident
  records with occurrence date, neighbourhood, cost, premises type, and
  coordinates. Location coordinates are deliberately offset to the nearest road
  intersection by the publisher for privacy; all analysis is therefore at
  neighbourhood, not address, granularity.
- **Scale**: 40,524 incident records (2014–2026) → 20,304 neighbourhood-month
  observations (141 neighbourhood units × 144 months, 2014-01 to 2025-12;
  140 named neighbourhoods + the `NSA` unknown area).
- **Key variables**: `date`, `neighborhood`, `bike_cost`, `location`
  (premises category), `long`/`lat` (neighbourhood centroid), plus `hour` and
  `premises_type` from the official feed (used in the hotspot analysis).
- **Target**: `theft_count` (monthly count per neighbourhood).

The raw CSV is not redistributed in this repository. To reproduce, run
`scripts/download_data.py` followed by `scripts/convert_data.py`, which fetch
the current official dataset and convert it to the two files the pipeline
expects under `data/raw/`:

- `bicycle.csv` — legacy schema used by the monthly model
  (`date, quarter, day_of_week, neighborhood, bike_cost, location, long, lat`);
- `bicycle_enhanced.csv` — additional fields (`hour`, `premises_type`,
  `location_type`, `division`) used by the hourly hotspot analysis.

## Data Preparation

- **Schema validation**: the raw CSV is checked for the required columns.
- **Aggregation**: incidents are aggregated into monthly counts per
  neighbourhood; months with no thefts are filled with zero so every
  neighbourhood has a complete 144-month series (balanced panel). The
  in-progress 2026 records are excluded so the panel stays balanced.
- **Data-quality audit**: the pipeline reports missing cells, exact duplicate
  rows, quarter-field inconsistencies, implausible `bike_cost` values, and the
  number of unknown-area (`NSA`) and zero-coordinate records.
- **Coordinates**: neighbourhood centroid is the median of *valid* incident
  coordinates, treated as a fixed geographic constant. Records in the `NSA`
  unknown area (which carry zero/missing coordinates) are excluded from the
  spatial basis so a synthetic `(0,0)` point cannot inflate the spatial scale.

## Exploratory Data Analysis

Key findings that motivated the modelling choices:

1. **Strong seasonality**: thefts peak in the warmer months and drop sharply in
   winter, with a clear annual cycle (lag-12 autocorrelation ≈ 0.85).
2. **Strong temporal autocorrelation**: month-to-month persistence is high
   (lag-1 autocorrelation ≈ 0.83), ruling out random train/test splits.
3. **Heavy over-dispersion**: the target's variance-to-mean ratio is ≈ 12.8,
   far above the Poisson assumption of 1, and ~55% of observations are zero.
4. **Clear spatial hotspots**: a small number of neighbourhoods (e.g. the
   waterfront and downtown corridors) account for a disproportionate share of
   thefts.
5. **A sustained citywide decline**: thefts peaked in 2018 (~3,990/year) and
   have fallen every year since, reaching ~2,125 in 2025 — a decade low. This
   structural drift directly affects how well any historically-trained model
   can predict the latest year (see Error Analysis).

## Validation Strategy

This is the most important design decision in the project.

The panel has **temporal dependence** (high autocorrelation and annual
periodicity) and **spatial dependence** (persistent neighbourhood-level
differences). A random `train_test_split` would leak future observations into
training and inflate scores, so the project uses a purely chronological scheme:

- **Hold-out test set**: calendar year **2025** (never touched until final
  evaluation).
- **Expanding-window cross-validation** on 2014–2024 for model selection and
  hyperparameter tuning: train on all data up to a cutoff, evaluate on the
  following 12-month window, then roll the cutoff forward. This mirrors how the
  model would be deployed — forecast the future from the past — and never
  evaluates on data preceding the training window.

Crucially, the spline boundary knots, spatial centres, and neighbourhood
context features are **re-fit on each fold's training data only**, so early
folds do not silently assume knowledge of the full timeline (which would
otherwise cause explosive extrapolation and leakage).

## Baseline Models

Three simple baselines establish a lower bound:

| Baseline | Description |
|---|---|
| Global mean | Predict the citywide mean theft count for every cell |
| Neighbourhood mean | Predict each neighbourhood's historical mean |
| Recent 12-mo mean | Predict each neighbourhood's mean over its most recent 12 training months |
| Seasonal naive | Same neighbourhood, same month one year earlier |

The seasonal naive baseline is again strong (test R² ≈ 0.62), underscoring how
much signal lives in the annual cycle. The recent-12-month mean is a realistic
deployment baseline that tracks the ongoing decline better than a full-history
mean (test R² 0.581).

## Models

Candidate models, all evaluated under the same expanding-window CV and the same
held-out test set:

- **Basis OLS (log)** — ordinary least squares on `log1p(theft_count)`.
- **Basis Ridge (log)** — ridge-regularised least squares on `log1p(theft_count)`.
- **Poisson (compact)** — penalised Poisson regression (log link) on the compact
  basis (time + seasonality + spatial RBF, no neighbourhood one-hot).
- **Poisson (area, ridge)** — penalised Poisson with the full basis including
  the neighbourhood one-hot block, λ selected per fold via `cv.glmnet`.
- **Negative-binomial** — NB regression (`MASS::glm.nb`) on the compact basis to
  absorb over-dispersion.

The basis design matrix contains: temporal cubic B-splines, annual sine/cosine
harmonics, spatial radial basis functions over normalised coordinates,
neighbourhood one-hot indicators, and two neighbourhood-level context features
(historical outdoor/commercial theft shares learned from training data only).

## Model Comparison

All metrics are on the **2025 hold-out test set** unless noted; CV columns are
the mean across expanding-window folds (2014–2024).

| Model | CV MAE | CV R² | Test MAE | Test RMSE | Test R² |
|---|---|---|---|---|---|
| Global mean | 2.48 | −0.005 | 2.12 | 3.49 | −0.051 |
| Neighbourhood mean | 1.55 | 0.570 | 1.30 | 2.52 | 0.449 |
| Recent 12-mo mean | 1.53 | 0.569 | 1.13 | 2.20 | 0.581 |
| Seasonal naive | 1.46 | 0.605 | 1.08 | 2.09 | 0.622 |
| Poisson (compact) | 1.94 | 0.246 | 1.16 | 2.72 | 0.360 |
| Negative-binomial | 3.82 | −5.08 | 1.06 | 2.83 | 0.307 |
| Basis OLS (log) | 1.39 | 0.609 | 0.838 | 2.00 | 0.653 |
| Basis Ridge (log) | 1.37 | 0.618 | 0.835 | 1.99 | 0.659 |
| Basis Ridge (tuned) | 1.34 | 0.623 | 0.832 | 1.96 | 0.667 |
| **Poisson (area, ridge)** | **1.55** | **0.411** | **0.846** | **1.73** | **0.741** |

**Fairness note**: the count GLMs (`Poisson (compact)`, `Negative-binomial`)
are fitted on the compact feature set (time + seasonality + spatial RBF, *no*
neighbourhood one-hot) because unpenalised MLE cannot handle the rank-deficient
one-hot block — `glmnet` 5.0 also has no negative-binomial family, so NB uses
`MASS::glm.nb` and cannot be penalised. `Poisson (area, ridge)` closes that gap
by adding the one-hot block *with a ridge penalty* and selecting λ per fold via
`cv.glmnet`, giving the count model the same spatial structure and a comparable
tuning budget as the ridge baseline. Under this fair comparison the penalised
Poisson is the strongest model on the 2025 hold-out (test R² 0.741 vs 0.667),
chiefly because its log link predicts the conditional mean `E[Y]` directly and
avoids the log1p back-transform bias (see Error Analysis).

## Final Model

The **Poisson (area, ridge)** model is selected as final. The choice follows
from the fair comparison above rather than from score alone:

- **Generalisation**: it achieves the best held-out RMSE, MAE, and R² on 2025.
- **Calibration**: its log link predicts the conditional count mean `E[Y]`
  directly, avoiding the `log1p` back-transform bias that makes the ridge-on-log
  model under-predict the citywide total by ~35%; Poisson's total is within
  ~14% of the observed total.
- **Appropriate distribution**: a count link is the natural fit for a heavily
  zero-inflated, over-dispersed non-negative target, and with a ridge penalty
  it is no longer disadvantaged by the rank-deficient one-hot block.
- **Fair tuning**: λ is selected per fold by `cv.glmnet` on training data only,
  giving it the same tuning budget as the ridge model's grid search.

**Honesty caveat**: the 2025 test year has been used across multiple diagnostic
rounds, so the 0.741 figure is not a clean, never-touched estimate. It should be
confirmed with a horizon-1 rolling backtest (or a genuinely unseen future
window) before being quoted as a deployment-grade result. The CV columns in the
comparison table still favour ridge (cv R² 0.623 vs 0.411), which reflects a
different, horizon-12 task; reconciling the two is pending work (see Future
Improvements).

## Results

On the 2025 test year, the two leading models achieve:

| Model | MAE | RMSE | R² | Total bias |
|---|---:|---:|---:|---:|
| **Poisson (area, ridge)** | **0.846** | **1.73** | **0.741** | **−13.6%** |
| Basis Ridge (tuned) | 0.832 | 1.96 | 0.667 | −35.1% |

For context, on the earlier (easier) 2023 test year the ridge framework reaches
R² ≈ 0.79. The 2025 year is harder because citywide theft has fallen to a
decade low (~2,125 vs a 2018 peak of ~3,990), and — as the error analysis now
shows — a large part of the ridge model's shortfall is the log1p back-transform
bias rather than genuine distribution shift alone.

## Hourly Hotspot Analysis (operational extension)

The refreshed dataset includes `OCC_HOUR` and `PREMISES_TYPE`, which the
monthly panel discards. `src/hotspot_analysis.R` turns them into directly
actionable findings:

- **Two daily peaks**: thefts concentrate at midnight and during the evening
  commute (17:00–18:00), with a deep trough before dawn (04:00–06:00).
- **Premises mix shifts by time of day**: outdoor theft dominates during
  daylight and evening hours (~30–33% of thefts), while apartment/house theft
  dominates overnight (~56% combined between 00:00–05:00).

Operationally this suggests *time-targeted* patrol allocation: street-level
patrols around transit corridors and commercial strips during the day and
evening, and residential-building focus overnight — a much more efficient
allocation than a uniform citywide sweep.

## Interpretation

- **Neighbourhood identity is the single most informative signal.** Models that
  omit neighbourhood fixed effects (`Poisson (compact)`, `Negative-binomial`)
  collapse (test R² 0.36 / 0.31), confirming that theft risk is strongly and
  persistently localised — this holds for count models too, not just linear ones.
- **Seasonality is the second key driver.** The seasonal naive baseline already
  reaches R² ≈ 0.62, and the model's sine/cosine harmonics capture the annual
  cycle cleanly.
- **The long-term trend is now explicitly downward** — captured by the
  B-splines, but a smooth trend cannot fully absorb a structural decline that
  steepens near the end of the training window.

## Error Analysis

- **The log1p back-transform bias is the dominant, structural cause of the
  ridge model's under-prediction.** The ridge model fits `log1p(Y)` and predicts
  `expm1(E[log1p(Y)|X])`, which by Jensen's inequality is *below* the conditional
  count mean `E[Y|X]` whenever the conditional distribution is non-degenerate.
  An independent check (`src/backtransform_bias.R`) quantifies this: the
  in-sample log-scale residual SD is ~0.50, and on the training distribution the
  mean of `expm1(mu)` is ~1.51 vs an actual mean of ~2.03 — a **~25% structural
  under-prediction** that exists even under perfect calibration. The penalised
  Poisson model eliminates this by predicting `E[Y]` directly, which is why its
  2025 total bias shrinks to ~−14% from the ridge's ~−35%.
- **The residual ~10% reflects genuine distribution shift** of the 2025 level
  relative to history (theft at a decade low), over and above the structural
  back-transform bias.
- **Residuals are approximately centred** near zero on the count scale,
  indicating low average bias once the back-transform issue is addressed.
- **Largest absolute errors occur at high-count cells**: the target is a skewed
  count, so absolute error grows with the magnitude of the true count.
- **The ridge model tends to smooth peaks** — extremely high months are
  under-predicted, a known limitation of shrinkage on the log target.

*Calibration note*: any calibration parameter (e.g. a multiplicative correction
to fix the citywide total) must be learned from training data or a time-ordered
hold-out only, never fitted on the 2025 totals and then evaluated on the same
year.

## Limitations

- **Count distribution**: the target is zero-inflated and over-dispersed. The
  penalised Poisson model does not model zero-inflation explicitly, and the
  over-dispersed NB model is not yet competitive under a fair feature/tuning
  budget (glmnet 5.0 lacks a negative-binomial family, so NB cannot use the
  same penalised one-hot block). A penalised zero-inflated NB model is a natural
  future extension.
- **Location precision**: the publisher offsets coordinates to the nearest
  intersection for privacy; the analysis is valid at neighbourhood granularity
  but not at address level.
- **External covariates**: weather, population density, policing effort, and
  bike-infrastructure changes are absent from the dataset.
- **Single-year hold-out**: one test year is a thinner generalisation guarantee
  than multi-year rolling evaluation; the 2025 year has also been reused across
  diagnostic rounds, so headline numbers need a horizon-1 rolling backtest to
  be treated as deployment-grade.
- **Structural decline**: theft volume has fallen ~47% from the 2018 peak.
  Models trained on history inherit that history's level; on 2025 the ridge
  model under-predicts the total by ~35%, of which ~25 points are the structural
  log1p back-transform bias and the remainder is genuine level shift.

## Future Improvements

- **Horizon-1 rolling backtest** to reconcile the CV (horizon-12) vs the 2025
  hold-out results and produce a deployment-grade estimate.
- **Penalised zero-inflated / negative-binomial** model to explicitly handle the
  ~55% zeros and over-dispersion (needs a package that penalises a NB/zio family).
- **Online/rolling retraining** to track the sustained decline in theft volume.
- **External covariates**: weather, holidays, and neighbourhood demographics.
- **Multi-year rolling test** for a stronger generalisation estimate.
- **Daily or hourly prediction granularity** — the dataset now supports it, and
  the hotspot analysis shows strong within-day structure worth modelling.
- **Uncertainty quantification**: prediction intervals via bootstrap or
  conformal methods.
- **Deployment**: retrain on a rolling window and forecast the next month for
  city resource planning.

## Repository Structure

```
├── README.md
├── data_dictionary.md   # counting / time / geography / duplication calibre
├── requirements.txt
├── .gitignore
├── data/
│   └── raw/            # place downloaded CSVs here (not committed)
├── scripts/
│   ├── download_data.py   # fetch the official dataset (ArcGIS API)
│   └── convert_data.py    # convert to the pipeline's schemas
├── src/
│   ├── config.R           # paths, package deps, seed
│   ├── prepare_data.R     # load, audit, monthly panel
│   ├── features.R         # basis-function design matrix
│   ├── validation.R       # time-aware split + expanding-window CV
│   ├── models.R           # baselines and candidate models
│   ├── evaluate.R         # comparison & final evaluation
│   ├── visualize.R        # EDA and diagnostic figures
│   ├── hotspot_analysis.R # hourly/premises operational analysis
│   ├── backtransform_bias.R # quantify log1p back-transform bias
│   └── run_pipeline.R     # end-to-end entry point
├── test/
│   ├── test_helper.R      # synthetic-data builders
│   ├── test-data-quality.R  # NSA / coordinate / panel tests
│   ├── test-leakage.R       # future-perturbation invariance
│   ├── test-validation.R    # expanding-window fold tests
│   └── test_scripts.py      # download/convert error-handling tests
└── output/
    ├── figures/        # generated figures
    └── tables/         # audit, CV, comparison, predictions
```

## Reproducibility

- **Language**: R (>= 4.2) for modelling; Python 3 for the data download and
  conversion scripts (standard library only).
- **Dependencies**: see `requirements.txt` (or `required_packages` in
  `src/config.R`). Install from R with
  `install.packages(read_requirements())` (after
  `source("src/config.R")`), or directly:
  `install.packages(scan("requirements.txt", what = "character", comment.char = "#"))`.
- **Tests**: run the full suite from the project root:
  ```bash
  Rscript test/run_tests.R                 # R data/leakage/validation tests
  python3 test/test_scripts.py             # download/convert error-handling tests
  ```
- **Fetch and prepare the data** (requires internet):
  ```bash
  python3 scripts/download_data.py   # writes data/raw/bicycle_raw_latest.csv
  python3 scripts/convert_data.py    # writes bicycle.csv + bicycle_enhanced.csv
  ```
- **Run the monthly pipeline** from the project root:
  ```bash
  Rscript src/run_pipeline.R
  ```
- **Run the hourly hotspot analysis**:
  ```bash
  Rscript src/hotspot_analysis.R
  ```
- **Random seed**: a fixed seed (`2023`) is set in `src/config.R` for
  reproducible fold assignment and any stochastic fitting.

## Key Takeaways

1. **Validation must respect the data's structure.** With strong temporal and
   spatial dependence, chronological expanding-window CV is essential; random
   splits would leak information and overstate performance.
2. **Neighbourhood and seasonality dominate the signal.** The final model's
   predictive power comes chiefly from spatial fixed effects and the annual
   cycle, not from complex non-linearities — this holds for count models too.
3. **Match the link function to the target.** A count link (Poisson, predicting
   `E[Y]` directly) beats least squares on `log1p(Y)` once the count model is
   given the same spatial structure and tuning budget — because the log1p
   back-transform is downward-biased by Jensen's inequality. The earlier
   "ridge-on-log wins" conclusion was an artefact of an unfair comparison.
4. **Baselines matter.** A seasonal naive model already explains ~62% of
   variance on the 2025 hold-out; any candidate model must convincingly beat it
   to justify its complexity.
5. **Separate structural bias from real shift.** The ~35% under-prediction on
   2025 was mostly the log1p back-transform bias (~25 points), not distribution
   shift (~10 points). Attributing error to the wrong cause leads to the wrong
   fix (trend extrapolation vs. a count link).
