# STAT3888 Teacher-Feedback Four-Slide Revision Design

## Objective

Revise the exact four-slide PowerPoint sent to Dr Liu so that it visibly answers
the feedback to interpret estimated regression parameters, infer the seasonal
cycle from the fitted sine/cosine coefficients, and examine a defensible
interaction extension without removing the visual and residual evidence the
instructor already praised.

## Source and Output

- Source deck: `/Users/liumingyuan/Documents/TORONTO BICYCLE THEFT  from Mingyuan Liu.pptx`.
- Preserve the source deck unchanged.
- Export a new editable PPTX under
  `deliverables/STAT3888_Toronto_Bicycle_Theft_Presentation/` with a filename
  identifying it as the teacher-feedback revision.
- Keep exactly four slides and preserve the existing visual system, typography,
  spacing, and slide hierarchy.

## Communication Job

By the end of the presentation, the instructor should understand that the
seasonal conclusion is supported not only by descriptive plots but also by the
estimated regression coefficients, and should see a transparent test of whether
season-by-space interactions improve the model.

## Statistical Design

### Seasonal coefficient interpretation

Use the cross-validated final Ridge model trained on 2014-2022. Extract the four
fitted seasonal coefficients for the annual and semi-annual sine/cosine terms.
Combine the paired coefficients rather than interpreting their signs in
isolation.

For month `m`, compute the fitted seasonal component

`s(m) = b_s1 sin(2*pi*m/12) + b_c1 cos(2*pi*m/12) + b_s2 sin(4*pi*m/12) + b_c2 cos(4*pi*m/12)`.

Report:

- the four fitted coefficients;
- annual and semi-annual amplitudes;
- the fitted peak and trough months;
- the peak-to-trough ratio on the `1 + count` scale;
- the caveat that all interpretations hold other model components fixed.

### Interaction extension

Test one focused interaction family: annual seasonal terms multiplied by the 16
spatial RBF columns. This allows the annual cycle's amplitude and phase to vary
smoothly across Toronto while avoiding an unstructured interaction with all 140
neighbourhood indicators.

Fit the interaction Ridge model with the same five-fold rolling-origin procedure
used by the additive model. Rebuild all basis recipes within each fold, choose
lambda by minimum mean validation RMSE, refit on 2014-2022, and evaluate once on
the untouched 2023 test set.

Compare the additive and interaction models using MAE, RMSE, R-squared, citywide
peak behaviour, and residual concentration. Report the result honestly even if
the interaction model does not improve out-of-time performance. Do not select a
model solely because its 2023 test score is better.

## Slide Design

### Slide 1 - Temporal evidence

Preserve the current time-series and month-distribution evidence. Keep the
descriptive conclusion clearly labelled as observed-data evidence.

### Slide 2 - Spatial and space-time evidence

Preserve the heatmap, long-run hotspot map, embedded animation, and existing
conclusions. These are already aligned with the instructor's positive feedback.

### Slide 3 - Coefficients reveal the seasonal cycle

Retain the current slide-3 composition and inherited elements, but replace the
left basis-function example image with a model-derived seasonal-component plot.
The plot will show the twelve fitted monthly seasonal contributions with the peak
and trough labelled.

Use the lower-left inherited text area for a compact coefficient interpretation:
annual amplitude, semi-annual amplitude, peak month, trough month, and the
peak-to-trough ratio. The visible copy must explain meaning, not merely list
parameters.

Use the right evidence frame for a compact, source-generated comparison of the
additive and interaction Ridge models together with the rolling-CV tuning
evidence. Retain the final test metrics in the lower-right metric block.

### Slide 4 - What interactions change and what remains unexplained

Preserve the observed-versus-predicted curve and residual map. Use the selected
model only if selection was determined by rolling validation rather than by the
2023 test result. Update the conclusion block to state whether interactions
materially improve prediction or residual structure. Keep the limitations block
and explicitly distinguish prediction from causality.

## Speaker Notes

Update notes for Slides 3 and 4 so the presenter can state:

- the actual fitted seasonal coefficients;
- why sine and cosine must be interpreted jointly;
- the model-implied July peak and January trough;
- the peak-to-trough multiplier on the `1 + count` scale;
- the interaction specification and its rolling-validation result;
- whether the interaction improves the untouched 2023 results.

Preserve `[Sources]` blocks and add any new analysis CSVs and figures.

## Implementation Boundaries

- Do not change the source deck in place.
- Do not add a fifth slide.
- Do not remove the residual map or the prediction-failure discussion.
- Do not claim that a coefficient is causal.
- Do not describe R-squared as prediction accuracy.
- Do not interpret individual sine/cosine signs without combining them.
- Do not add other interaction families unless required to make the specified
  season-by-space interaction estimable.

## Verification

1. Add failing model tests for interaction-column construction, fold-local basis
   construction, coefficient extraction, and the 2023 prediction schema.
2. Run the tests before implementation and confirm the intended failures.
3. Implement the minimum model changes and rerun the focused and full R tests.
4. Regenerate numerical outputs and independently verify all displayed values.
5. Build the PPTX with artifact-tool by editing inherited source-slide elements.
6. Render all four slides and inspect each at full size.
7. Check for overflow, clipping, overlaps, unreadable chart labels, stale metrics,
   unresolved placeholders, and incorrect slide numbering.
8. Verify speaker-note sources and confirm the source deck hash is unchanged.

## Acceptance Criteria

- The final deck contains exactly four slides.
- Slide 3 visibly reports and interprets fitted seasonal coefficients.
- The coefficient-derived seasonal curve identifies its fitted peak and trough.
- An annual-season-by-spatial-RBF interaction model is tested with rolling CV.
- Interaction results are reported without test-set model-selection leakage.
- Slides 1, 2, and the residual evidence on Slide 4 remain intact.
- All displayed metrics match regenerated artifacts.
- The final editable PPTX passes structural and visual QA.
