# STAT3888 Model Evidence Foundation Design

## Purpose

Establish one trustworthy, reproducible evidence contract for the advanced
STAT3888 model branch before adding negative-binomial models or prediction
intervals. The selected model, fold-level validation evidence, untouched 2023
test metrics, aggregate bias, metadata, plots, and narrative must all identify
the same model and use the same generated results.

This is the first of three bounded improvements:

1. model evidence foundation and output consistency (this design);
2. fair count-model comparison;
3. time-dependence-aware prediction intervals.

## Current State

The `model-improvement` branch already provides:

- five expanding-window validation folds for 2018--2022;
- an untouched 2023 test set;
- Additive Ridge and Season-space Ridge candidates;
- candidate selection by mean rolling-validation RMSE;
- a passing R test suite.

The selected candidate is Season-space Ridge, but the exported
`model_metrics.csv`, `cross_validation_results.csv`, and `basis_metadata.csv`
still primarily describe Additive Ridge. This makes the repository capable of
producing individually correct values that tell different model stories.

The source contains one exact longitude/latitude pair for each of the 140
neighbourhoods. Consequently, using the full source to recover those static
coordinates has no numerical look-ahead effect in this dataset. The pipeline
must nevertheless assert that invariant instead of silently taking full-period
medians if a future dataset contains changing event coordinates.

## Scope

### Included

- Define a canonical model-summary table covering baselines and both Ridge
  candidates.
- Export fold-by-lambda results for both Ridge candidates.
- Make metadata identify the CV-selected primary model and its parameters.
- Preserve the untouched 2023 test set and select models only from 2018--2022
  rolling validation.
- Add citywide 2023 total bias for each predictive model.
- Assert that source coordinates are static within neighbourhood before they
  are treated as neighbourhood attributes.
- Update tests and generated analytical CSVs.
- Keep compatibility outputs where practical, but remove ambiguous generic
  labels such as `Basis Ridge` when they actually mean Additive Ridge.

### Excluded

- Poisson, negative-binomial, hurdle, or zero-inflated models.
- Conformal or bootstrap prediction intervals.
- New external covariates.
- PPTX, DOCX, PDF, or visual redesign.
- Merging the feature branch into `main` or publishing externally.

## Alternatives Considered

### A. Patch only `model_metrics.csv`

This is the smallest change, but it leaves fold results and metadata describing
another candidate. It reduces one symptom without establishing a reliable
evidence contract.

### B. Create a canonical summary while retaining focused supporting files

This is the selected approach. A new `model_summary.csv` becomes the reader-
facing source of truth. Existing focused files remain available, but their
labels and contents are made explicit and internally consistent.

### C. Delete every existing metric file and replace them with one large table

This maximizes normalization but creates unnecessary breakage in handbook and
presentation consumers. It also mixes fold-level and model-level grains.

## Architecture

### Model result contract

`fit_models()` will continue to return fitted candidates and predictions. It
will additionally expose model-level comparison data through a single helper:

```r
build_model_summary(model_fit)
```

The returned tibble has one row per model and these columns:

- `model`
- `role` (`baseline`, `benchmark`, or `candidate`)
- `selected_by_cv`
- `selected_lambda`
- `mean_cv_rmse`
- `sd_cv_rmse`
- `test_mae`
- `test_rmse`
- `test_r2`
- `test_total_bias`

Metrics that do not apply to baselines are represented as `NA`, not zero.
`test_total_bias` is `(sum(predicted) - sum(actual)) / sum(actual)`.

### Cross-validation evidence

`cross_validation_results.csv` will contain both Additive Ridge and
Season-space Ridge at the existing fold-by-lambda grain. The explicit `model`
column is mandatory. Model selection remains based solely on mean validation
RMSE across the five 2018--2022 folds.

### Metadata

`basis_metadata.csv` remains a two-column parameter/value file for compatibility
but will describe the selected primary model with explicit keys:

- `primary_model`
- `primary_selected_lambda`
- `primary_mean_cv_rmse`
- `primary_sd_cv_rmse`
- `cv_folds`
- existing basis-dimension parameters

No unqualified `selected_lambda` field will remain.

### Coordinate invariant

`make_monthly_panel()` will accept neighbourhood coordinates only when every
neighbourhood has exactly one distinct `(long, lat)` pair in the source. It will
fail with a clear message when this invariant is violated. A future project can
then supply official static centroids or a training-only coordinate recipe
instead of silently constructing future-informed medians.

## Data Flow

1. Read and audit the source dataset.
2. Verify the static-coordinate invariant and construct the monthly panel.
3. Reserve 2023 as the untouched test set.
4. Run both Ridge candidates through identical expanding-window validation
   folds using candidate-specific selected lambdas.
5. Select the primary candidate using validation RMSE only.
6. Compute all candidates and baselines on the untouched 2023 set.
7. Build the canonical model summary and write supporting fold and metadata
   files from the same in-memory `model_fit` object.

## Error Handling

- A neighbourhood with more than one coordinate pair stops panel construction
  and identifies the affected neighbourhoods.
- A summary cannot contain zero or more than one `selected_by_cv = TRUE` row.
- The selected summary row must match `model_fit$primary_model`.
- Candidate fold exports must contain the same validation years and lambda grid.
- Aggregate bias fails clearly when the actual test total is zero.

## Testing Strategy

Tests will be written before implementation and must demonstrate:

1. coordinate-invariant validation fails on a deliberately changed coordinate;
2. the canonical summary contains five expected models and one selected row;
3. the selected row matches the primary model and its CV/test metrics;
4. total bias independently reconciles against test predictions;
5. fold results include both candidates with identical fold years and lambda
   grids;
6. metadata uses qualified primary-model keys;
7. the complete R suite remains green.

Generated CSVs will then be regenerated from the real source data and checked
against the tested contract.

## Success Criteria

- One canonical CSV answers which model was selected, why it was selected, and
  how every candidate performed on 2023.
- Supporting CSVs agree with the canonical selected model and parameters.
- Model selection never uses 2023 test performance.
- Static coordinates are an enforced data invariant rather than an assumption.
- All automated R tests pass with no warnings or skips.
- No user-owned untracked presentation or temporary files are changed.
