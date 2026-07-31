# STAT3888 Rolling Cross-Validation Presentation Update

**Date:** 2026-07-31  
**Status:** Approved approach A; awaiting written-spec review  
**Primary deck:** `deliverables/STAT3888_Toronto_Bicycle_Theft_Presentation/STAT3888_Toronto_Bicycle_Theft_Corrected_Embedded_Video.pptx`  
**Slide limit:** Exactly 4 slides  
**Formal presentation language:** English  
**Target duration:** 5 minutes

## 1. Objective

Replace the current single 2022 validation split with rolling-origin
time-series cross-validation, then update the R outputs, the four-slide
PowerPoint, and the five-minute speech guide so that all three deliverables
describe the same verified method and results.

The update must:

- preserve 2023 as an untouched final out-of-time test set;
- keep the Task 4 basis-function explanation visible;
- show concrete evidence that rolling cross-validation was executed;
- keep the existing slide count, visual hierarchy, and embedded video;
- update every metric, model-selection statement, chart, note, and speech line
  affected by the new Ridge tuning procedure;
- avoid calling ordinary random K-fold validation appropriate for this data.

## 2. Cross-Validation Design

Use five expanding-window validation folds:

| Fold | Training years | Validation year |
| ---: | --- | ---: |
| 1 | 2014–2017 | 2018 |
| 2 | 2014–2018 | 2019 |
| 3 | 2014–2019 | 2020 |
| 4 | 2014–2020 | 2021 |
| 5 | 2014–2021 | 2022 |

For every fold:

1. construct the basis recipe from that fold's training data only;
2. generate training and validation design matrices from that recipe;
3. fit Ridge models across the existing logarithmic lambda grid;
4. transform predictions back to the original theft-count scale;
5. calculate validation RMSE for every lambda.

Select the lambda with the lowest mean validation RMSE across all five folds:

`selected_lambda = argmin(mean_fold_RMSE(lambda))`.

After selection:

1. rebuild the basis recipe using 2014–2022;
2. refit Basis Ridge on all 2014–2022 observations;
3. fit Basis OLS on the same 2014–2022 design matrix;
4. evaluate both models once on the untouched 2023 test set.

The basis recipe, coordinate scaling, RBF centres, design matrix, and any model
standardisation must not use validation or test observations before their
respective evaluation step.

## 3. Statistical Model Scope

The response remains:

`log(1 + monthly neighbourhood theft count)`.

The design matrix remains:

- cubic B-splines for smooth long-term change;
- annual and semi-annual sine/cosine terms;
- 16 spatial radial basis functions;
- neighbourhood indicators.

Basis Ridge remains the primary predictive model because rolling
cross-validation directly tunes its regularisation strength and Ridge
stabilises correlated basis coefficients. Basis OLS remains the required
unpenalised Task 4 benchmark. The final 2023 test set will report both models,
but it will not be used to choose lambda or retroactively select the primary
model.

## 4. Required R Outputs

Update `R/03_model.R` with bounded helpers for:

- defining the five rolling folds;
- evaluating a lambda grid within each fold;
- aggregating fold RMSE;
- selecting the minimum-mean-RMSE lambda;
- refitting the final 2014–2022 models.

Write or update:

- `output/analysis/cross_validation_folds.csv`;
- `output/analysis/cross_validation_results.csv`;
- `output/analysis/basis_metadata.csv`;
- `output/analysis/model_metrics.csv`;
- `output/analysis/test_predictions.csv`;
- `output/figures/05_basis_functions.png`;
- `output/figures/06_model_comparison.png`;
- `output/figures/07_observed_vs_predicted.png`;
- `output/figures/08_residual_map.png`;
- `output/figures/09_rolling_cross_validation.png`.

The slide-3 right-hand evidence image will be a single R-generated composite
with:

- a compact rolling-CV tuning panel showing mean RMSE against lambda and the
  selected lambda;
- an updated 2023 MAE/RMSE model-comparison panel.

Using one composite raster preserves the existing slide frame and simplifies
safe PowerPoint media replacement.

## 5. PowerPoint Update

Keep all four slides and preserve slide 2's embedded video, click-to-full-screen
behaviour, and Escape-to-return behaviour.

### Slide 1

No methodological layout change. Retain the verified temporal evidence and
blank name/student-ID fields.

### Slide 2

No layout change. Preserve the heatmap, hotspot evidence, and embedded MP4.

### Slide 3

Retain the left basis-function figure.

Replace the right model-comparison image with the R-generated composite
cross-validation and final-test figure.

Change the timing line to:

`Rolling validation 2018–2022  →  Final test 2023`

Change the explanatory method copy to state that:

- each validation fold trains only on earlier years;
- lambda is chosen by the lowest mean validation RMSE;
- Basis Ridge is the cross-validated model;
- Basis OLS remains the unpenalised comparison.

Populate the metric callout only from regenerated CSV outputs.

### Slide 4

Regenerate the observed-versus-predicted and residual figures using the
cross-validated final Ridge model. Update improvement percentages and
interpretation text from the new results. Preserve the non-causal conclusion
and omitted-variable limitations.

### Safe media-editing strategy

Use the current corrected embedded-video deck as the structural source.
Replace only the affected raster image media and editable slide text/notes.
Do not rebuild or remove the slide-2 video relationships, media part, poster,
play action, or presentation settings. Verify that the final PPTX still
contains the MP4 media part and opens in WPS without repair prompts.

## 6. Five-Minute Speech Update

The formal speech remains entirely in English.

Revise the slide-3 section to explain:

- why random K-fold validation would leak temporal information;
- how the five expanding-window folds work;
- that each basis recipe is learned from past data only;
- how mean validation RMSE selects lambda;
- why 2023 remains untouched until final evaluation.

Revise slide 4 with regenerated test metrics and residual conclusions.

Keep the total formal speech within a practical five-minute range of
approximately 630–700 English words. Update the Chinese principles and viva
sections with:

- holdout validation versus cross-validation;
- rolling-origin cross-validation;
- leakage prevention;
- lambda selection;
- the distinction between model tuning and final testing.

## 7. Testing and Verification

### R behaviour

- five folds exist with exactly the approved training and validation years;
- validation years are strictly later than every corresponding training year;
- each fold rebuilds its basis recipe from training data only;
- 2023 is absent from all tuning folds;
- selected lambda minimises mean fold RMSE;
- final models train on 2014–2022 and test on 2023;
- all predictions are finite and non-negative;
- output tables and plots are reproducible.

### PowerPoint

- exactly four slides;
- all visible copy is English;
- slide 3 states rolling validation rather than a single 2022 validation;
- slide 3 contains both basis-function and cross-validation evidence;
- slide 4 metrics match the regenerated CSV;
- embedded MP4 remains inside the PPTX;
- video still opens full-screen on click and Escape returns to the slide;
- no overflow, overlap, stretched image, or unreadable chart labels;
- WPS opens the deck without repair prompts.

### Speech guide

- formal script is English;
- total length remains appropriate for five minutes;
- no obsolete “2022 is the validation set” wording remains;
- all reported metrics and lambda values match the regenerated outputs;
- Word and PDF versions render without clipping or broken figures.

## 8. Deliverables

- updated four-slide embedded-video PPTX;
- updated editable English speech/principles DOCX;
- updated fixed-layout PDF;
- regenerated R charts and analysis CSV files;
- reproducible R code and tests.

The source files and previous deliverables remain recoverable; no unrelated
user files will be removed.
