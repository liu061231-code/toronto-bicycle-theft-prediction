# Toronto Residual Map Overlay Design

**Date:** 2026-07-31  
**Status:** Approved visual direction; awaiting written-spec review

## Objective

Replace the slide-4 residual scatterplot background with Toronto's historical
140-neighbourhood geography so that the residual evidence corresponds visually
to the earlier Toronto hotspot map.

## Visual Design

- Reuse the historical 140-neighbourhood GeoJSON reader already implemented in
  `R/04_neighbourhood_hotspot_map.R`.
- Draw all neighbourhood polygons with a very light neutral fill and thin white
  internal boundaries.
- Draw a restrained grey Toronto city outline above the internal boundaries.
- Overlay one residual bubble per neighbourhood at the existing representative
  longitude and latitude.
- Preserve the diverging residual encoding:
  - red means the observed count exceeded the prediction, so the model
    under-predicted;
  - blue means the prediction exceeded the observed count, so the model
    over-predicted.
- Preserve bubble size as the magnitude of the neighbourhood's mean residual,
  `abs(mean_residual)`.
- Use a zero-centred symmetric colour scale so equal positive and negative
  residuals receive equal visual emphasis.
- Remove longitude and latitude tick labels and axis titles. The Toronto
  geography provides the spatial reference.
- Keep the existing plot title and positive-residual subtitle unless a small
  wording adjustment is required for clarity.
- Rename legends to make the two encodings explicit: colour communicates mean
  residual and size communicates error magnitude.

## Data and Statistical Meaning

For neighbourhood \(i\) and 2023 month \(t\), retain

`residual_it = observed_it - predicted_it`.

The mapped colour is

`mean_residual_i = mean_t(residual_it)`.

The mapped bubble size is

`abs(mean_residual_i)`.

This edit changes only the geographic presentation. It does not change the
model, predictions, residual calculation, validation procedure, or test
metrics.

## Implementation Scope

1. Extend the residual-plot path in `R/03_model.R` to accept or load the
   historical neighbourhood boundaries and join them to the 140 residual
   summaries by parsed neighbourhood ID.
2. Add a regression test that checks the boundary join covers all 140
   neighbourhoods and that the residual plot contains an `sf` basemap layer.
3. Regenerate `output/figures/08_residual_map.png`.
4. Replace only the slide-4 residual image in the corrected embedded-video
   PowerPoint, preserving the four-slide structure and embedded MP4.
5. Update the Word speech/principles guide only where the right-hand figure is
   described. Preserve the existing layout and all unrelated content.

## Verification

- The residual table contains exactly 140 unique neighbourhoods.
- Every residual neighbourhood joins to one historical boundary.
- The map preserves red/blue direction and absolute-size magnitude encodings.
- The regenerated image has no clipped title, subtitle, map, bubbles, or
  legends.
- Slide 4 retains its existing image frame and remains readable at presentation
  size.
- The final PPTX still contains exactly four slides and its embedded MP4.
- The edited DOCX is rendered and visually inspected before delivery.
- WPS Office opens the final PPTX and DOCX without a repair prompt.

## Deliverables

- regenerated `output/figures/08_residual_map.png`;
- updated corrected embedded-video PPTX;
- updated five-minute speech/principles DOCX;
- associated R test and reproducible source change.

