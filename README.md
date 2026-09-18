# Toronto Bicycle Theft Prediction

A spatio-temporal machine learning project that forecasts monthly bicycle theft
counts across 140 Toronto neighbourhoods, combining spline-based temporal trend
modelling, seasonal harmonics, and radial-basis-function spatial smoothing
inside a regularised linear model.

## Overview

This repository builds a predictive model for **monthly reported bicycle thefts
per neighbourhood** in the City of Toronto over 2014–2023. The data are a
balanced panel (140 neighbourhoods × 120 months) with strong temporal
autocorrelation, a pronounced annual cycle, and heavy over-dispersion in the
count target. The goal is a model that generalises to *unseen future months*
rather than one that merely fits the past.

The project originated as a hands-on exercise in a spatio-temporal data science
course, and has since been reworked into a standalone predictive-modelling
project: a rigorous time-aware validation strategy, fair baseline and
multi-model comparison, hyperparameter tuning, and interpretable diagnostics.

The final model is a **ridge-regularised linear model on a log-transformed
target** using a hand-crafted design matrix (temporal B-splines + seasonal
harmonics + spatial radial basis functions + neighbourhood fixed effects). It
reaches an out-of-sample R² of **0.78** on the held-out 2023 test year,
substantially outperforming naive and mean baselines.

## Problem Definition

- **Task type**: supervised regression (count prediction).
- **Prediction target**: `theft_count` — the number of bicycle thefts reported
  in a given neighbourhood during a given calendar month.
- **Features**: temporal position (month index), calendar month (seasonality),
  neighbourhood identity and centroid coordinates (spatial structure).
- **Evaluation objective**: minimise out-of-sample prediction error on future
  months, measured by MAE, RMSE, and R². Because the target is a skewed count,
  MAE is emphasised alongside RMSE.

## Dataset

- **Source**: City of Toronto bicycle theft records (individual incidents with
  date, quarter, day of week, neighbourhood, cost, location type, and
  coordinates). The neighbourhood centroids are aggregated from the incident
  coordinates.
- **Scale**: 31,833 raw incident records → 16,800 neighbourhood-month
  observations (140 neighbourhoods × 120 months, 2014-01 to 2023-12).
- **Key variables**: `date`, `neighborhood`, `bike_cost`, `location` (7
  categories), `long`/`lat` (neighbourhood centroid).
- **Target**: `theft_count` (monthly count per neighbourhood).

The raw CSV is not redistributed in this repository. To reproduce, place
`bicycle.csv` (with columns `date, quarter, day_of_week, neighborhood,
bike_cost, location, long, lat`) under `data/raw/`. The pipeline reads it from
`data/raw/bicycle.csv`.

## Data Preparation

- **Schema validation**: the raw CSV is checked for the eight required columns.
- **Aggregation**: incidents are aggregated into monthly counts per
  neighbourhood; months with no thefts are filled with zero so every
  neighbourhood has a complete 120-month series (balanced panel).
- **Data-quality audit**: the pipeline reports missing cells, exact duplicate
  rows, quarter-field inconsistencies, and implausible `bike_cost` values.
- **Coordinates**: neighbourhood centroid is the median of incident
  coordinates.

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

## Validation Strategy

This is the most important design decision in the project.

The panel has **temporal dependence** (high autocorrelation and annual
periodicity) and **spatial dependence** (persistent neighbourhood-level
differences). A random `train_test_split` would leak future observations into
training and inflate scores, so the project uses a purely chronological scheme:

- **Hold-out test set**: calendar year **2023** (never touched until final
  evaluation).
- **Expanding-window cross-validation** on 2014–2022 for model selection and
  hyperparameter tuning: train on all data up to a cutoff, evaluate on the
  following 12-month window, then roll the cutoff forward. This mirrors how the
  model would be deployed — forecast the future from the past — and never
  evaluates on data preceding the training window.

Crucially, the spline boundary knots and spatial centres are **re-fit on each
fold's training data only**, so early folds do not silently assume knowledge of
the full timeline (which would otherwise cause explosive extrapolation and
leakage).

## Baseline Models

Three simple baselines establish a lower bound:

| Baseline | Description |
|---|---|
| Global mean | Predict the citywide mean theft count for every cell |
| Neighbourhood mean | Predict each neighbourhood's historical mean |
| Seasonal naive | Same neighbourhood, same month one year earlier |

The seasonal naive baseline is surprisingly strong (test R² ≈ 0.59),
underscoring how much signal lives in the annual cycle.

## Models

Candidate models, all evaluated under the same expanding-window CV and the same
held-out test set:

- **Basis OLS (log)** — ordinary least squares on `log1p(theft_count)`.
- **Basis Ridge (log)** — ridge-regularised least squares on `log1p(theft_count)`.
- **Poisson GLM** — penalised Poisson regression (log link) on the basis matrix.
- **Negative-binomial GLM** — NB regression to absorb over-dispersion.

The basis design matrix is shared by the linear/ridge models and contains:
temporal cubic B-splines, annual sine/cosine harmonics, spatial radial basis
functions over normalised coordinates, and neighbourhood one-hot indicators.

## Model Comparison

All metrics are on the **2023 hold-out test set** unless noted; CV columns are
the mean across expanding-window folds (2014–2022).

| Model | CV MAE | CV R² | Test MAE | Test RMSE | Test R² |
|---|---|---|---|---|---|
| Global mean | 2.41 | −0.003 | 2.17 | 4.16 | −0.006 |
| Neighbourhood mean | 1.54 | 0.543 | 1.39 | 2.70 | 0.577 |
| Seasonal naive | 1.45 | 0.606 | 1.26 | 2.66 | 0.589 |
| Poisson GLM | 2.25 | −0.678 | 1.66 | 3.04 | 0.465 |
| Negative-binomial GLM | 2.54 | −2.01 | 2.76 | 6.19 | −1.22 |
| Basis OLS (log) | 1.35 | 0.562 | 1.12 | 1.97 | 0.776 |
| **Basis Ridge (log)** | **1.34** | **0.561** | **1.10** | **1.96** | **0.777** |

## Final Model

The **Basis Ridge (log)** model is selected as final. The choice is not driven
by score alone:

- **Generalisation**: it achieves the best (or tied-best) held-out RMSE and R².
- **Stability**: hyperparameter tuning over a wide λ grid (1e-4 to 1e-1) shows
  the test score is essentially flat — the model is robust to the regularisation
  strength, not fragile.
- **Interpretability**: linear coefficients and a known basis make the model
  transparent (seasonality and neighbourhood effects are directly readable).
- **Simplicity**: it outperforms the count GLMs, which — lacking neighbourhood
  fixed effects and being poorly suited to the zero-inflated log-scale target —
  underfit the spatial structure.

## Results

On the untouched 2023 test year, the final model achieves:

- **MAE** = 1.10 thefts per neighbourhood-month
- **RMSE** = 1.96 thefts
- **R²** = 0.777

This means the model explains ~78% of the variance in monthly neighbourhood
theft counts out-of-sample, roughly a 32% relative RMSE reduction versus the
best naive baseline (2.66 → 1.96).

## Interpretation

- **Neighbourhood identity is the single most informative signal.** Models that
  omit neighbourhood fixed effects (the count GLMs) collapse, confirming that
  theft risk is strongly and persistently localised.
- **Seasonality is the second key driver.** The seasonal naive baseline already
  reaches R² ≈ 0.59, and the model's sine/cosine harmonics capture the annual
  cycle cleanly.
- **The long-term trend is smooth and mild** — captured by low-degree
  B-splines rather than a sharp regime shift.

## Error Analysis

- **Residuals are approximately centred** near zero, indicating low systematic
  bias on average.
- **Largest errors occur at high-count cells**: because the target is a skewed
  count, the model's absolute error grows with the magnitude of the true count
  (a hallmark of modelling the log-scale, where a multiplicative error on large
  counts is a large absolute error).
- **The model tends to smooth peaks** — extremely high months are under-predicted,
  a known limitation of ridge shrinkage on the log target.

## Limitations

- **Count distribution**: the target is zero-inflated and over-dispersed; the
  chosen log-linear model does not model zero-inflation explicitly, and the
  penalised GLMs were not competitive. A zero-inflated NB model is a natural
  future extension.
- **Feature depth**: only temporal, seasonal, and spatial-structural features
  are used. External covariates (weather, population density, policing) are
  absent from the dataset.
- **Validation horizon**: the hold-out is a single year (2023). A single
  test year is a thinner generalisation guarantee than multi-year rolling
  evaluation.
- **Possible distribution shift**: theft-reporting behaviour or policing may
  have drifted over the decade; the model does not explicitly correct for this.

## Future Improvements

- **Zero-inflated negative-binomial** model to explicitly handle the ~55% zeros.
- **External covariates**: weather, holidays, and neighbourhood demographics.
- **Multi-year rolling test** for a stronger generalisation estimate.
- **Deployment**: retrain on a rolling window and forecast the next month for
  city resource planning.
- **Uncertainty quantification**: prediction intervals via bootstrap or
  conformal methods.

## Repository Structure

```
├── README.md
├── requirements.txt
├── .gitignore
├── data/
│   └── raw/            # bicycle.csv (place the raw CSV here; not committed)
├── src/
│   ├── config.R        # paths, package deps, seed
│   ├── prepare_data.R  # load, audit, monthly panel
│   ├── features.R      # basis-function design matrix
│   ├── validation.R    # time-aware split + expanding-window CV
│   ├── models.R        # baselines and candidate models
│   ├── evaluate.R      # comparison & final evaluation
│   ├── visualize.R     # EDA and diagnostic figures
│   └── run_pipeline.R  # end-to-end entry point
└── output/
    ├── figures/        # generated figures
    └── tables/         # audit, CV, comparison, predictions
```

## Reproducibility

- **Language**: R (>= 4.2).
- **Dependencies**: see `requirements.txt` (or `required_packages` in
  `src/config.R`). Install with
  `install.packages(scan("requirements.txt", what = "character"))`.
- **Run the pipeline** from the project root:
  ```bash
  Rscript src/run_pipeline.R
  ```
  It loads `data/raw/bicycle.csv`, audits the data, builds the monthly panel,
  runs the time-aware CV and tuning, and writes figures and tables to `output/`.
- **Random seed**: a fixed seed (`2023`) is set in `src/config.R` for
  reproducible fold assignment and any stochastic fitting.

## Key Takeaways

1. **Validation must respect the data's structure.** With strong temporal and
   spatial dependence, chronological expanding-window CV is essential; random
   splits would leak information and overstate performance.
2. **Neighbourhood and seasonality dominate the signal.** The final model's
   predictive power comes chiefly from spatial fixed effects and the annual
   cycle, not from complex non-linearities.
3. **A regularised linear model on a log-transformed target beats count GLMs**
   on this zero-inflated, over-dispersed data — a reminder to match the method
   to the data rather than defaulting to a "fancier" model.
4. **Baselines matter.** A seasonal naive model already explains ~59% of
   variance; any candidate model must convincingly beat it to justify its
   complexity.
5. **Stability is a feature.** The final model's performance is flat across a
   1000× range of regularisation strengths, giving confidence that the result is
   not a hyperparameter fluke.
