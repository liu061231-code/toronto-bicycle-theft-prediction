# STAT3888 PowerPoint Correction Design

**Date:** 2026-07-30  
**Source deck:** `/Users/liumingyuan/Documents/STAT3888 Toronto bicycle theft.pptx`  
**Output:** A new corrected `.pptx`; the source deck remains unchanged  
**Slide limit:** Exactly 4 slides  
**Language:** English

## 1. Goal

Repair the existing four-slide presentation so that its visible claims, model
choice, figures, metrics, notes, and submission details form one consistent
evidence chain aligned with the STAT3888 rubric.

The corrected deck must retain the existing visual hierarchy and four-page
story:

1. temporal pattern;
2. spatial and space-time pattern;
3. basis-function regression;
4. out-of-time prediction, residuals, and limitations.

## 2. Model-Consistency Decision

Three viable approaches were considered:

1. **Use Ridge throughout (selected).** Ridge is already used by the prediction
   and residual figures, handles the highly correlated basis matrix more
   robustly, and differs from OLS by only about 0.01 RMSE.
2. **Use OLS throughout.** This would preserve the numerically lowest test RMSE
   but require regenerating both final prediction figures.
3. **Present OLS and Ridge as co-primary models.** This is statistically
   defensible but creates unnecessary ambiguity in a four-slide presentation.

The corrected deck will select **Basis Ridge** as the primary reported model:

- RMSE: 2.06;
- R²: 0.754;
- approximately 24.4% lower RMSE than the neighbourhood-mean baseline.

OLS remains visible in the comparison chart. The slide will state that OLS is
only about 0.01 RMSE lower, while Ridge is selected for stability.

## 3. Slide-Level Corrections

### Slide 1

- Retain the trend and seasonal-distribution figures.
- Replace the casual and behaviour-attributing conclusion with:
  `Reported bicycle thefts show strong seasonality: July has the highest
  average count, while winter months remain below 100 incidents.`
- Add a restrained editable identity line:
  `Name: ____________________    Student ID: ____________________`
- Keep all visible text in English.

### Slide 2

- Retain the dominant space-time heatmap.
- Replace the faint animation poster/static map region with the verified,
  high-contrast neighbourhood hotspot map
  `output/figures/03b_neighbourhood_hotspot_map.png`.
- Keep the embedded 30-second animation when the import/export pipeline
  preserves it; the static slide must remain complete without playback.
- Replace statements about thief behaviour with statements about reported
  incidents and spatial concentration.

### Slide 3

- Retain the basis-function and model-comparison figures.
- Change the primary callout to Basis Ridge:
  `Basis Ridge · RMSE 2.06 · R² 0.754`.
- Add a concise selection rationale:
  `OLS is 0.01 RMSE lower; Ridge is selected for stability.`
- Preserve the train/validation/test chronology and log1p transformation.

### Slide 4

- Retain the existing Ridge prediction and Ridge residual figures.
- Change the improvement claim from `24.9%` to `24.4%`.
- Make the model name explicit in the conclusion block.
- Preserve the non-causal interpretation and omitted-covariate limitations.

## 4. Sources and Notes

- Preserve the speaker notes and talk track structure.
- Replace machine-only local paths in `[Sources]` blocks with portable source
  labels where practical:
  - course-provided `bicycle.csv`;
  - project R analysis scripts;
  - generated figure names;
  - City of Toronto historical 140-neighbourhood boundary dataset URL.
- Notes must consistently describe Ridge as the selected prediction model.

## 5. Editing Method

- Import the existing PPTX with `@oai/artifact-tool`.
- Preserve the imported master, layout, typography, colors, and object
  positions.
- Edit existing text objects in place.
- Replace only the slide-2 static spatial visual while preserving its assigned
  frame.
- Export a new file named
  `STAT3888_Toronto_Bicycle_Theft_Corrected.pptx`.
- Do not overwrite `/Users/liumingyuan/Documents/STAT3888 Toronto bicycle theft.pptx`.

## 6. Verification

Before delivery:

- confirm exactly four slides;
- verify Ridge metrics against `output/analysis/model_metrics.csv`;
- render and inspect all four slides individually;
- confirm slide 2 remains understandable without video playback;
- run slide overflow detection;
- confirm the source deck remains unchanged;
- open the corrected deck in WPS Office;
- confirm no placeholder names or invented personal information are present.

