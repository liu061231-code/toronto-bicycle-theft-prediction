# Toronto Residual Map Overlay Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Overlay the 2023 neighbourhood residual bubbles on Toronto's historical 140-neighbourhood map and propagate the revised visual into the rolling-cross-validation PowerPoint and five-minute Word guide.

**Architecture:** Add a focused historical-boundary reader and a residual-map preparation helper, keeping the residual definition and model outputs unchanged. Regenerate the R figure, replace only the residual raster and related explanatory text in the existing PPTX package, then rebuild the source-backed DOCX/PDF guide and verify both deliverables in WPS Office.

**Tech Stack:** R 4.x, `sf`, `dplyr`, `ggplot2`, `testthat`, Node.js OOXML ZIP editing, Python `python-docx`, Codex presentation/document renderers, WPS Office for final local preview.

## Global Constraints

- Work in `/Users/liumingyuan/Documents/project of stat38888/.worktrees/stat3888-five-minute-speech` on branch `codex/stat3888-five-minute-speech`.
- Preserve `residual = observed - predicted`, `mean_residual = mean(residual)`, and bubble size `abs(mean_residual)`.
- Do not change rolling-origin cross-validation, predictions, metrics, slide count, slide-2 video relationships, or unrelated Word content.
- Use the historical Toronto 140-neighbourhood boundary dataset and require a complete one-to-one ID join.
- Preserve red for under-prediction, blue for over-prediction, and a zero-centred symmetric colour scale.
- Use WPS Office for final local opening and visual confirmation.

---

### Task 1: Add a Tested Toronto Basemap Layer to the Residual Plot

**Files:**
- Create: `R/04_neighbourhood_hotspot_map.R`
- Modify: `R/03_model.R:394-424`
- Modify: `R/handbook_step_by_step.R:20-24`
- Modify: `tests/testthat/test-model.R:1-2,124-end`

**Interfaces:**
- Produces: `parse_neighbourhood_id(character) -> integer`, `read_historical_neighbourhoods(boundary_source) -> sf`, and `prepare_residual_map_data(predictions, boundaries) -> list(points, boundaries, outline)`.
- Consumes: `fit$test_predictions` with `neighborhood`, `lon`, `lat`, and `residual` columns.

- [ ] **Step 1: Write the failing residual-map data test**

Source `R/04_neighbourhood_hotspot_map.R` before `R/03_model.R`, create a network-free 140-feature `sf` fixture from the panel coordinates, and add:

```r
testthat::test_that("residual bubbles join all 140 Toronto neighbourhoods", {
  ids <- parse_neighbourhood_id(unique(fit$test_predictions$neighborhood))
  coords <- fit$test_predictions |>
    dplyr::distinct(neighborhood, lon, lat) |>
    dplyr::mutate(neighbourhood_id = parse_neighbourhood_id(neighborhood))
  fixture <- sf::st_as_sf(coords, coords = c("lon", "lat"), crs = 4326) |>
    dplyr::transmute(
      neighbourhood_id,
      boundary_name = neighborhood,
      geometry = geometry
    )
  mapped <- prepare_residual_map_data(fit$test_predictions, fixture)
  testthat::expect_s3_class(mapped$boundaries, "sf")
  testthat::expect_s3_class(mapped$outline, "sf")
  testthat::expect_equal(nrow(mapped$points), 140L)
  testthat::expect_equal(nrow(mapped$boundaries), 140L)
  testthat::expect_setequal(mapped$points$neighbourhood_id, ids)
  testthat::expect_false(anyNA(mapped$boundaries$mean_residual))
})
```

- [ ] **Step 2: Run the focused test and verify RED**

Run:

```bash
Rscript -e 'testthat::test_file("tests/testthat/test-model.R")'
```

Expected: FAIL because the historical-boundary helpers and `prepare_residual_map_data()` do not exist.

- [ ] **Step 3: Implement the historical boundary reader**

Create `R/04_neighbourhood_hotspot_map.R` with the approved Toronto Open Data URL and these validated helpers:

```r
historical_neighbourhoods_url <- paste0(
  "https://ckan0.cf.opendata.inter.prod-toronto.ca/dataset/",
  "fc443770-ef0a-4025-9c2c-2cb558bfab00/resource/",
  "9994da8e-5d35-438b-bfc4-eef14d09e035/download/",
  "neighbourhoods-historical-140-4326.geojson"
)

parse_neighbourhood_id <- function(neighbourhood) {
  matched <- grepl("\\([0-9]+\\)\\s*$", neighbourhood)
  parsed <- suppressWarnings(as.integer(
    sub("^.*\\(([0-9]+)\\)\\s*$", "\\1", neighbourhood)
  ))
  parsed[!matched] <- NA_integer_
  parsed
}

read_historical_neighbourhoods <- function(
    boundary_source = historical_neighbourhoods_url) {
  boundaries <- sf::st_read(boundary_source, quiet = TRUE) |>
    sf::st_make_valid()
  required <- c("AREA_SHORT_CODE", "AREA_NAME")
  if (!all(required %in% names(boundaries))) {
    stop("Historical boundary data is missing required ID or name columns.")
  }
  boundaries <- boundaries |>
    dplyr::transmute(
      neighbourhood_id = as.integer(AREA_SHORT_CODE),
      boundary_name = AREA_NAME,
      geometry = geometry
    )
  if (nrow(boundaries) != 140L ||
      dplyr::n_distinct(boundaries$neighbourhood_id) != 140L) {
    stop("Expected 140 unique historical Toronto neighbourhood boundaries.")
  }
  boundaries
}
```

- [ ] **Step 4: Implement the residual-map join and plot**

Add this preparation boundary to `R/03_model.R`:

```r
prepare_residual_map_data <- function(predictions, boundaries) {
  points <- predictions |>
    dplyr::group_by(neighborhood, lon, lat) |>
    dplyr::summarise(mean_residual = mean(residual), .groups = "drop") |>
    dplyr::mutate(
      neighbourhood_id = parse_neighbourhood_id(neighborhood),
      error_magnitude = abs(mean_residual)
    )
  if (nrow(points) != 140L || anyNA(points$neighbourhood_id)) {
    stop("Expected residual summaries for 140 identifiable neighbourhoods.")
  }
  mapped <- boundaries |>
    dplyr::left_join(
      dplyr::select(points, neighbourhood_id, mean_residual, error_magnitude),
      by = "neighbourhood_id"
    )
  if (nrow(mapped) != 140L || anyNA(mapped$mean_residual)) {
    stop("Every residual neighbourhood must match one Toronto boundary.")
  }
  list(points = points, boundaries = mapped, outline = dplyr::summarise(mapped))
}
```

Change `make_model_plots()` to accept `boundary_source = historical_neighbourhoods_url`, call the reader, and construct `p8` as:

```r
mapped_residuals <- prepare_residual_map_data(
  fit$test_predictions,
  read_historical_neighbourhoods(boundary_source)
)
limit <- max(abs(mapped_residuals$points$mean_residual))
p8 <- ggplot2::ggplot(mapped_residuals$boundaries) +
  ggplot2::geom_sf(fill = "#EEF2F4", color = "white", linewidth = 0.18) +
  ggplot2::geom_sf(
    data = mapped_residuals$outline,
    fill = NA, color = "#7B8790", linewidth = 0.5
  ) +
  ggplot2::geom_point(
    data = mapped_residuals$points,
    ggplot2::aes(
      x = lon, y = lat, color = mean_residual, size = error_magnitude
    ),
    alpha = 0.88
  ) +
  ggplot2::scale_color_gradient2(
    low = "#2166AC", mid = "white", high = "#B2182B",
    midpoint = 0, limits = c(-limit, limit)
  ) +
  ggplot2::scale_size_continuous(range = c(1, 8)) +
  ggplot2::coord_sf(datum = NA, expand = FALSE) +
  ggplot2::labs(
    title = "Where the 2023 model under- or over-predicts",
    subtitle = "Positive residuals mean observed thefts exceeded predictions",
    x = NULL, y = NULL,
    color = "Mean residual", size = "Error magnitude"
  ) +
  handbook_theme() +
  ggplot2::theme(
    axis.text = ggplot2::element_blank(),
    axis.ticks = ggplot2::element_blank(),
    panel.grid = ggplot2::element_blank()
  )
```

Source `R/04_neighbourhood_hotspot_map.R` before `R/03_model.R` in `R/handbook_step_by_step.R` and the model test.

- [ ] **Step 5: Run R tests and verify GREEN**

Run:

```bash
Rscript -e 'testthat::test_file("tests/testthat/test-model.R")'
Rscript -e 'testthat::test_dir("tests/testthat")'
```

Expected: the new 140-neighbourhood join test and all existing R tests pass.

- [ ] **Step 6: Commit the tested R implementation**

```bash
git add R/03_model.R R/04_neighbourhood_hotspot_map.R \
  R/handbook_step_by_step.R tests/testthat/test-model.R
git commit -m "feat: overlay residuals on Toronto neighbourhood map"
```

---

### Task 2: Regenerate and Visually Verify the Residual Figure

**Files:**
- Update by execution: `output/figures/08_residual_map.png`
- Verify unchanged values: `output/analysis/model_metrics.csv`
- Verify unchanged values: `output/analysis/test_predictions.csv`

**Interfaces:**
- Consumes: the tested R plotting path and Toronto GeoJSON.
- Produces: a 1620-by-972 PNG suitable for the existing slide-4 image frame.

- [ ] **Step 1: Record model-output checksums before regeneration**

Run:

```bash
shasum -a 256 output/analysis/model_metrics.csv output/analysis/test_predictions.csv
```

Expected: two checksums retained for the post-run comparison.

- [ ] **Step 2: Regenerate the project outputs**

Run:

```bash
Rscript R/run_all.R
```

Expected: exit 0 and `output/figures/08_residual_map.png` is rewritten.

- [ ] **Step 3: Confirm statistical outputs did not change**

Run the same checksum command and compare it with Step 1.

Expected: both CSV checksums are identical; only the visual representation changed.

- [ ] **Step 4: Inspect the PNG at full resolution**

Open `output/figures/08_residual_map.png` and verify: visible Toronto outline, 140 light-grey neighbourhoods, legible red/blue bubbles, no longitude/latitude axes, complete legends, and no clipping.

- [ ] **Step 5: Commit the regenerated figure**

```bash
git add output/figures/08_residual_map.png
git commit -m "docs: regenerate mapped residual evidence"
```

---

### Task 3: Replace the Slide-4 Raster and Update Its Explanation

**Files:**
- Modify: `tmp/stat3888-cross-validation/update_embedded_deck.mjs:40-125`
- Modify: `tmp/stat3888-cross-validation/test_embedded_deck.mjs:45-80`
- Update by execution: `deliverables/STAT3888_Toronto_Bicycle_Theft_Presentation/STAT3888_Toronto_Bicycle_Theft_Cross_Validated_Embedded_Video.pptx`

**Interfaces:**
- Consumes: `output/figures/08_residual_map.png`.
- Produces: the same four-slide PPTX package with `ppt/media/image10.png` replaced and slide-4 notes describing the basemap.

- [ ] **Step 1: Add a failing package assertion**

Add:

```javascript
assert.match(notes4Text, /historical 140-neighbourhood Toronto basemap/i);
assert.deepEqual(
  unzipBytes(outputPath, "ppt/media/image10.png"),
  fs.readFileSync("output/figures/08_residual_map.png"),
);
```

- [ ] **Step 2: Run the package test and verify RED**

Run:

```bash
node tmp/stat3888-cross-validation/test_embedded_deck.mjs
```

Expected: FAIL because notes 4 do not yet identify the geographic basemap.

- [ ] **Step 3: Update slide-4 notes and rebuild the package**

Change the residual sentence in `newNotes4` to:

```text
The residual bubbles are overlaid on the historical 140-neighbourhood Toronto basemap: red indicates under-prediction, blue indicates over-prediction, and larger bubbles indicate a larger absolute mean residual.
```

Run:

```bash
node tmp/stat3888-cross-validation/update_embedded_deck.mjs
```

- [ ] **Step 4: Run package tests and slide structural QA**

```bash
node tmp/stat3888-cross-validation/test_embedded_deck.mjs
PY="/Users/liumingyuan/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3"
PRES="/Users/liumingyuan/.codex/plugins/cache/openai-primary-runtime/presentations/26.730.11710/skills/presentations"
"$PY" "$PRES/container_tools/render_slides.py" \
  deliverables/STAT3888_Toronto_Bicycle_Theft_Presentation/STAT3888_Toronto_Bicycle_Theft_Cross_Validated_Embedded_Video.pptx
"$PY" "$PRES/container_tools/slides_test.py" \
  deliverables/STAT3888_Toronto_Bicycle_Theft_Presentation/STAT3888_Toronto_Bicycle_Theft_Cross_Validated_Embedded_Video.pptx
```

Expected: four slides, embedded `media1.mp4`, byte-identical slide-2 video parts, image10 byte-identical to the regenerated PNG, and no overflow errors.

- [ ] **Step 5: Visually inspect slide 4**

Inspect the rendered slide-4 PNG at 100% and confirm that Toronto geography, residual bubbles, both legends, title, and subtitle are readable within the existing image frame.

- [ ] **Step 6: Commit the PPTX update**

```bash
git add tmp/stat3888-cross-validation/update_embedded_deck.mjs \
  tmp/stat3888-cross-validation/test_embedded_deck.mjs \
  deliverables/STAT3888_Toronto_Bicycle_Theft_Presentation/STAT3888_Toronto_Bicycle_Theft_Cross_Validated_Embedded_Video.pptx
git commit -m "docs: map slide four residual evidence"
```

---

### Task 4: Update and Rebuild the Rolling-CV Word Guide

**Files:**
- Modify: `tmp/stat3888-presentation/five_minute_speech_content.py:129-150`
- Modify: `tmp/stat3888-presentation/test_five_minute_speech_guide.py:30-50`
- Update by execution: `deliverables/STAT3888_Toronto_Bicycle_Theft_Presentation/STAT3888_五分钟演讲稿与原理解析_滚动交叉验证版.docx`
- Update by execution: `deliverables/STAT3888_Toronto_Bicycle_Theft_Presentation/STAT3888_五分钟演讲稿与原理解析_滚动交叉验证版.pdf`

**Interfaces:**
- Consumes: the final slide-4 image and unchanged model facts.
- Produces: the same five-minute guide with a precise explanation of the mapped residual encoding.

- [ ] **Step 1: Add the failing wording assertion**

Add to `test_required_terminology()`:

```python
self.assertIn("historical Toronto neighbourhood map", speech)
self.assertIn("red bubbles indicate under-prediction", speech)
self.assertIn("blue bubbles indicate over-prediction", speech)
self.assertIn("bubble size shows error magnitude", speech)
```

- [ ] **Step 2: Run the speech tests and verify RED**

```bash
PY="/Users/liumingyuan/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3"
PYTHONPATH=tmp/stat3888-presentation \
  "$PY" -m unittest tmp/stat3888-presentation/test_five_minute_speech_guide.py -v
```

Expected: FAIL because the slide-4 speech does not yet describe the basemap encoding.

- [ ] **Step 3: Update the slide-4 script without changing its timing**

Replace the existing residual-map sentence with:

```text
On the historical Toronto neighbourhood map, red bubbles indicate under-prediction, blue bubbles indicate over-prediction, and bubble size shows error magnitude. Most neighbourhood errors are modest, while a small number of downtown hotspots remain the main difficulty.
```

Keep slide 4 at 245–300 seconds and the complete formal speech within 630–700 English words.

- [ ] **Step 4: Run speech tests and rebuild the DOCX**

```bash
PYTHONPATH=tmp/stat3888-presentation \
  "$PY" -m unittest tmp/stat3888-presentation/test_five_minute_speech_guide.py -v
PYTHONPATH=tmp/stat3888-presentation \
  "$PY" tmp/stat3888-presentation/build_five_minute_speech_guide.py
```

Expected: all tests pass and the rolling-cross-validation DOCX is regenerated.

- [ ] **Step 5: Render the DOCX for automated layout QA**

The document skill requires deterministic render QA. Because WPS has no suitable headless batch-render interface, use the bundled renderer only for this automated check and use WPS for the final user-visible preview:

```bash
DOCX="deliverables/STAT3888_Toronto_Bicycle_Theft_Presentation/STAT3888_五分钟演讲稿与原理解析_滚动交叉验证版.docx"
OUT="tmp/stat3888-presentation/residual-map-guide-render"
RENDER="/Users/liumingyuan/.codex/plugins/cache/openai-primary-runtime/documents/26.730.11710/skills/documents/render_docx.py"
"$PY" "$RENDER" "$DOCX" --output_dir "$OUT" --emit_pdf
```

Copy the emitted PDF to `deliverables/STAT3888_Toronto_Bicycle_Theft_Presentation/STAT3888_五分钟演讲稿与原理解析_滚动交叉验证版.pdf` using the approved file-editing workflow, then inspect every rendered page for clipping, overlaps, broken Chinese glyphs, and stale residual wording.

- [ ] **Step 6: Commit the guide update**

```bash
git add tmp/stat3888-presentation/five_minute_speech_content.py \
  tmp/stat3888-presentation/test_five_minute_speech_guide.py \
  deliverables/STAT3888_Toronto_Bicycle_Theft_Presentation/STAT3888_五分钟演讲稿与原理解析_滚动交叉验证版.docx \
  deliverables/STAT3888_Toronto_Bicycle_Theft_Presentation/STAT3888_五分钟演讲稿与原理解析_滚动交叉验证版.pdf
git commit -m "docs: explain mapped residuals in speech guide"
```

---

### Task 5: Integrated Verification in WPS Office

**Files:**
- Verify: `output/figures/08_residual_map.png`
- Verify: `deliverables/STAT3888_Toronto_Bicycle_Theft_Presentation/STAT3888_Toronto_Bicycle_Theft_Cross_Validated_Embedded_Video.pptx`
- Verify: `deliverables/STAT3888_Toronto_Bicycle_Theft_Presentation/STAT3888_五分钟演讲稿与原理解析_滚动交叉验证版.docx`

**Interfaces:**
- Consumes: all completed artifacts.
- Produces: a verified, internally consistent submission bundle.

- [ ] **Step 1: Run the complete automated suite**

```bash
Rscript -e 'testthat::test_dir("tests/testthat")'
node tmp/stat3888-cross-validation/test_embedded_deck.mjs
PY="/Users/liumingyuan/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3"
PYTHONPATH=tmp/stat3888-presentation \
  "$PY" -m unittest tmp/stat3888-presentation/test_five_minute_speech_guide.py -v
```

Expected: all R, PPTX-package, and Word-content tests pass.

- [ ] **Step 2: Confirm model metrics remain unchanged**

```bash
rg 'Basis Ridge|Basis OLS|Neighborhood mean' output/analysis/model_metrics.csv
```

Expected: Basis Ridge remains MAE 1.05, RMSE 1.98, R-squared 0.774 after display rounding; no model values changed because of the map edit.

- [ ] **Step 3: Open the PowerPoint in WPS Office**

```bash
open -a /Applications/wpsoffice.app \
  deliverables/STAT3888_Toronto_Bicycle_Theft_Presentation/STAT3888_Toronto_Bicycle_Theft_Cross_Validated_Embedded_Video.pptx
```

Verify that WPS shows no repair prompt, slide 4 is readable, slide 2 video still launches full-screen, and Escape returns to the slide.

- [ ] **Step 4: Open the Word guide in WPS Office**

```bash
open -a /Applications/wpsoffice.app \
  deliverables/STAT3888_Toronto_Bicycle_Theft_Presentation/STAT3888_五分钟演讲稿与原理解析_滚动交叉验证版.docx
```

Verify that WPS shows no repair prompt and the slide-4 explanation describes the same red/blue/size encoding shown in the PPTX.

- [ ] **Step 5: Confirm the worktree contains no unintended tracked changes**

```bash
git status --short
git diff --check
```

Expected: only pre-existing WPS lock files, render directories, and other previously untracked artifacts remain; no unrelated tracked file is modified.

