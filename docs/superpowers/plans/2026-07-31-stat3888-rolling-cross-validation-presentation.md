# STAT3888 Rolling Cross-Validation Presentation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace single-year Ridge tuning with five-fold rolling-origin cross-validation, regenerate the model evidence, and update the four-slide embedded-video PowerPoint plus the English five-minute speech guide.

**Architecture:** Extend the existing R basis-regression pipeline with isolated rolling-fold and Ridge-tuning helpers, then regenerate CSV and PNG evidence from one reproducible run. Preserve the current PowerPoint package by replacing only slide-3/4 raster media and editable XML text/notes, leaving slide 2's embedded MP4 relationships untouched. Update the existing tested speech-content module and rebuild its DOCX/PDF outputs from the regenerated metrics.

**Tech Stack:** R 4.6, testthat, tidyverse, splines, glmnet, ggplot2, grid, JavaScript/Node OOXML ZIP editing, Python unittest/python-docx, bundled PowerPoint and Word renderers, WPS Office.

## Global Constraints

- The final deck must contain exactly four slides.
- The formal presentation and formal speech must remain entirely in English.
- Use five expanding-window folds: 2014–2017→2018 through 2014–2021→2022.
- Rebuild every fold's basis recipe from its training observations only.
- Keep 2023 completely absent from tuning and use it once for final testing.
- Basis Ridge remains the cross-validated primary predictive model; Basis OLS remains the unpenalised Task 4 benchmark.
- Preserve slide 2's embedded MP4, poster, click-to-full-screen action, and Escape-to-return behaviour.
- Preserve the current visual hierarchy and use a single composite R raster in slide 3's existing right-hand image frame.
- Populate lambda, MAE, RMSE, R², and improvement percentages from regenerated CSV outputs only.
- Keep the formal speech approximately 630–700 English words and within the existing 300-second slide timings.
- Do not remove or overwrite unrelated untracked user files.

---

### Task 1: Align the Existing Isolated Worktree and Baseline

**Files:**
- Use: `.worktrees/stat3888-five-minute-speech/`
- Import: `deliverables/STAT3888_Toronto_Bicycle_Theft_Presentation/STAT3888_Toronto_Bicycle_Theft_Corrected_Embedded_Video.pptx`
- Verify: `tests/testthat/`
- Verify: `tmp/stat3888-presentation/test_five_minute_speech_guide.py`

**Interfaces:**
- Consumes: main-branch design commit and the current embedded-video deck.
- Produces: an isolated branch containing the speech builder, approved design, source deck copy, and passing baseline tests.

- [ ] **Step 1: Merge the approved design into the existing worktree**

Run:

```bash
cd "/Users/liumingyuan/Documents/project of stat38888/.worktrees/stat3888-five-minute-speech"
git merge main
```

Expected: a clean merge that adds the 2026-07-31 design specification without changing the existing speech commits.

- [ ] **Step 2: Copy the embedded-video source deck into the worktree**

Run:

```bash
mkdir -p deliverables/STAT3888_Toronto_Bicycle_Theft_Presentation
cp -p \
  "/Users/liumingyuan/Documents/project of stat38888/deliverables/STAT3888_Toronto_Bicycle_Theft_Presentation/STAT3888_Toronto_Bicycle_Theft_Corrected_Embedded_Video.pptx" \
  "deliverables/STAT3888_Toronto_Bicycle_Theft_Presentation/STAT3888_Toronto_Bicycle_Theft_Corrected_Embedded_Video.pptx"
```

Expected: the worktree contains a non-empty four-slide PPTX with `ppt/media/media1.mp4`.

- [ ] **Step 3: Run the current R tests**

Run:

```bash
Rscript -e 'testthat::test_dir("tests/testthat")'
```

Expected: all current tests pass before cross-validation changes.

- [ ] **Step 4: Run the current speech tests**

Run:

```bash
PY="/Users/liumingyuan/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3"
PYTHONPATH=tmp/stat3888-presentation \
  "$PY" -m unittest tmp/stat3888-presentation/test_five_minute_speech_guide.py -v
```

Expected: 8 tests pass.

---

### Task 2: Implement Rolling-Origin Ridge Tuning with TDD

**Files:**
- Modify: `tests/testthat/test-model.R`
- Modify: `R/03_model.R`

**Interfaces:**
- Consumes: the 2014–2022 monthly neighbourhood panel and a numeric lambda grid.
- Produces:
  - `make_rolling_folds(panel, initial_train_end = 2017L, final_validation_year = 2022L) -> list`
  - `cross_validate_ridge(panel, lambda_grid) -> list(folds, fold_results, summary, selected_lambda)`
  - `fit_models(splits, lambda_grid = default_lambda_grid()) -> list`

- [ ] **Step 1: Add the failing rolling-fold test**

Append to `tests/testthat/test-model.R`:

```r
tuning_panel <- dplyr::bind_rows(splits$train, splits$validation)

testthat::test_that("rolling folds use past years only and never include 2023", {
  folds <- make_rolling_folds(tuning_panel)
  testthat::expect_equal(
    vapply(folds, `[[`, integer(1), "validation_year"),
    2018:2022
  )
  testthat::expect_true(all(vapply(
    folds,
    function(fold) max(fold$train$year) < fold$validation_year,
    logical(1)
  )))
  testthat::expect_true(all(vapply(
    folds,
    function(fold) all(fold$validation$year == fold$validation_year),
    logical(1)
  )))
  testthat::expect_false(any(vapply(
    folds,
    function(fold) any(c(fold$train$year, fold$validation$year) == 2023),
    logical(1)
  )))
})
```

- [ ] **Step 2: Run the test and verify RED**

Run:

```bash
Rscript -e 'testthat::test_file("tests/testthat/test-model.R")'
```

Expected: FAIL because `make_rolling_folds()` does not exist.

- [ ] **Step 3: Implement the minimal fold constructor**

Add near the top of `R/03_model.R`:

```r
make_rolling_folds <- function(
    panel,
    initial_train_end = 2017L,
    final_validation_year = 2022L) {
  validation_years <- seq.int(initial_train_end + 1L, final_validation_year)
  stats::setNames(
    lapply(validation_years, function(validation_year) {
      list(
        fold = validation_year - initial_train_end,
        train_end = validation_year - 1L,
        validation_year = validation_year,
        train = dplyr::filter(panel, year <= validation_year - 1L),
        validation = dplyr::filter(panel, year == validation_year)
      )
    }),
    paste0("validate_", validation_years)
  )
}
```

- [ ] **Step 4: Run the fold test and verify GREEN**

Run:

```bash
Rscript -e 'testthat::test_file("tests/testthat/test-model.R")'
```

Expected: the new rolling-fold test passes and existing model tests remain green.

- [ ] **Step 5: Add the failing Ridge CV aggregation test**

Append:

```r
testthat::test_that("Ridge lambda minimises mean rolling validation RMSE", {
  lambda_grid <- c(1, 0.1, 0.01)
  cv <- cross_validate_ridge(tuning_panel, lambda_grid)

  testthat::expect_equal(nrow(cv$fold_results), 5L * length(lambda_grid))
  testthat::expect_equal(sort(unique(cv$fold_results$validation_year)), 2018:2022)
  testthat::expect_equal(nrow(cv$summary), length(lambda_grid))
  testthat::expect_equal(
    cv$selected_lambda,
    cv$summary$lambda[which.min(cv$summary$mean_rmse)]
  )
  testthat::expect_true(all(is.finite(cv$fold_results$RMSE)))
})
```

- [ ] **Step 6: Run the CV test and verify RED**

Run:

```bash
Rscript -e 'testthat::test_file("tests/testthat/test-model.R")'
```

Expected: FAIL because `cross_validate_ridge()` does not exist.

- [ ] **Step 7: Implement fold-local basis construction and CV aggregation**

Add to `R/03_model.R`:

```r
default_lambda_grid <- function() {
  exp(seq(log(100), log(1e-4), length.out = 100))
}

cross_validate_ridge <- function(
    panel,
    lambda_grid = default_lambda_grid()) {
  folds <- make_rolling_folds(panel)
  fold_results <- purrr::map_dfr(folds, function(fold) {
    recipe <- make_basis_recipe(fold$train)
    x_train <- make_design_matrix(fold$train, recipe)
    x_validation <- make_design_matrix(fold$validation, recipe)
    y_train <- log1p(fold$train$theft_count)
    ridge <- glmnet::glmnet(
      x_train,
      y_train,
      alpha = 0,
      lambda = lambda_grid,
      standardize = TRUE
    )
    validation_log <- predict(
      ridge,
      newx = x_validation,
      s = lambda_grid
    )
    rmse <- apply(validation_log, 2, function(prediction) {
      prediction <- pmax(0, expm1(prediction))
      sqrt(mean((fold$validation$theft_count - prediction)^2))
    })
    tibble::tibble(
      fold = fold$fold,
      train_end = fold$train_end,
      validation_year = fold$validation_year,
      lambda = lambda_grid,
      RMSE = rmse
    )
  })
  summary <- fold_results |>
    dplyr::group_by(lambda) |>
    dplyr::summarise(
      mean_rmse = mean(RMSE),
      sd_rmse = stats::sd(RMSE),
      .groups = "drop"
    ) |>
    dplyr::arrange(dplyr::desc(lambda))
  selected_lambda <- summary$lambda[which.min(summary$mean_rmse)]
  list(
    folds = folds,
    fold_results = fold_results,
    summary = summary,
    selected_lambda = selected_lambda
  )
}
```

- [ ] **Step 8: Run the model tests and verify GREEN**

Run:

```bash
Rscript -e 'testthat::test_file("tests/testthat/test-model.R")'
```

Expected: all model tests pass.

- [ ] **Step 9: Add a failing final-fit test**

Add:

```r
testthat::test_that("final models tune before the untouched 2023 test", {
  fit <- fit_models(splits, lambda_grid = c(1, 0.1, 0.01))
  testthat::expect_equal(sort(unique(fit$cv_results$validation_year)), 2018:2022)
  testthat::expect_false(any(fit$cv_results$validation_year == 2023))
  testthat::expect_equal(max(fit$final_training_years), 2022)
  testthat::expect_equal(unique(fit$test_predictions$year), 2023)
  testthat::expect_equal(
    fit$selected_lambda,
    fit$cv_summary$lambda[which.min(fit$cv_summary$mean_rmse)]
  )
})
```

- [ ] **Step 10: Run the final-fit test and verify RED**

Run:

```bash
Rscript -e 'testthat::test_file("tests/testthat/test-model.R")'
```

Expected: FAIL because the current `fit_models()` exposes single-year validation fields and does not return CV metadata or prediction year.

- [ ] **Step 11: Refactor `fit_models()` around rolling CV**

Implement these exact behaviours:

```r
fit_models <- function(
    splits,
    lambda_grid = default_lambda_grid()) {
  train <- splits$train
  validation <- splits$validation
  test <- splits$test
  tuning_panel <- dplyr::bind_rows(train, validation)

  cv <- cross_validate_ridge(tuning_panel, lambda_grid)
  selected_lambda <- cv$selected_lambda
  final_recipe <- make_basis_recipe(tuning_panel)
  x_final <- make_design_matrix(tuning_panel, final_recipe)
  x_test <- make_design_matrix(test, final_recipe)
  y_final <- log1p(tuning_panel$theft_count)
  actual_test <- test$theft_count

  global_prediction <- rep(mean(tuning_panel$theft_count), nrow(test))
  neighborhood_means <- tuning_panel |>
    dplyr::group_by(neighborhood) |>
    dplyr::summarise(value = mean(theft_count), .groups = "drop")
  neighborhood_prediction <- test |>
    dplyr::select(neighborhood) |>
    dplyr::left_join(neighborhood_means, by = "neighborhood") |>
    dplyr::pull(value)

  ols_coefficients <- fit_ols(x_final, y_final)
  ols_prediction <- pmax(
    0,
    expm1(predict_ols(ols_coefficients, x_test))
  )
  ridge_final <- glmnet::glmnet(
    x_final,
    y_final,
    alpha = 0,
    lambda = selected_lambda,
    standardize = TRUE
  )
  ridge_prediction <- pmax(
    0,
    expm1(as.numeric(predict(
      ridge_final,
      newx = x_test,
      s = selected_lambda
    )))
  )
```

Retain the existing four-model metrics and return:

```r
list(
  metrics = metrics,
  test_predictions = predictions,
  selected_lambda = selected_lambda,
  cv_results = cv$fold_results,
  cv_summary = cv$summary,
  cv_folds = cv$folds,
  recipe = final_recipe,
  final_training_years = sort(unique(tuning_panel$year)),
  ridge_model = ridge_final,
  ols_coefficients = ols_coefficients
)
```

Include `year = year` in `test_predictions`.

- [ ] **Step 12: Run all R tests**

Run:

```bash
Rscript -e 'testthat::test_dir("tests/testthat")'
```

Expected: all R tests pass.

- [ ] **Step 13: Commit the cross-validation model**

```bash
git add R/03_model.R tests/testthat/test-model.R
git commit -m "feat: add rolling-origin Ridge cross-validation"
```

---

### Task 3: Persist CV Evidence and Regenerate R Figures

**Files:**
- Modify: `R/handbook_step_by_step.R`
- Modify: `tests/testthat/test-handbook-step-by-step.R`
- Modify: `R/03_model.R`
- Create by execution: `output/analysis/cross_validation_folds.csv`
- Create by execution: `output/analysis/cross_validation_results.csv`
- Create by execution: `output/figures/09_rolling_cross_validation.png`
- Update by execution: `output/analysis/model_metrics.csv`
- Update by execution: `output/analysis/basis_metadata.csv`
- Update by execution: `output/analysis/test_predictions.csv`
- Update by execution: `output/figures/05_basis_functions.png`
- Update by execution: `output/figures/06_model_comparison.png`
- Update by execution: `output/figures/07_observed_vs_predicted.png`
- Update by execution: `output/figures/08_residual_map.png`

**Interfaces:**
- Consumes: `fit_models()` CV metadata and final predictions.
- Produces: CSV evidence and slide-ready 9×5.4-inch PNGs.

- [ ] **Step 1: Add failing output-contract assertions**

Extend `tests/testthat/test-handbook-step-by-step.R`:

```r
testthat::expect_equal(
  sort(unique(result$model_fit$cv_results$validation_year)),
  2018:2022
)
testthat::expect_equal(nrow(result$model_fit$cv_results), 500)
testthat::expect_equal(nrow(result$model_fit$cv_summary), 100)
testthat::expect_equal(length(result$model_fit$recipe$time_knots), 4)
testthat::expect_true(all(diff(result$model_fit$recipe$time_knots) > 0))
testthat::expect_lte(max(result$model_fit$recipe$time_knots), 108)
testthat::expect_true("cross_validation" %in% names(result$model_paths))
```

Add a temporary-output test that runs `write_handbook_outputs()` against a
temporary `analysis_dir` and requires:

```r
c(
  "cross_validation_folds.csv",
  "cross_validation_results.csv",
  "model_metrics.csv",
  "test_predictions.csv",
  "basis_metadata.csv"
)
```

- [ ] **Step 2: Run handbook tests and verify RED**

Run:

```bash
Rscript -e 'testthat::test_file("tests/testthat/test-handbook-step-by-step.R")'
```

Expected: FAIL because CV output files and plot path do not exist.

- [ ] **Step 3: Update output writing**

In `write_handbook_outputs()` write:

```r
fold_table <- purrr::map_dfr(result$model_fit$cv_folds, function(fold) {
  tibble::tibble(
    fold = fold$fold,
    train_start = min(fold$train$year),
    train_end = fold$train_end,
    validation_year = fold$validation_year,
    training_rows = nrow(fold$train),
    validation_rows = nrow(fold$validation)
  )
})
readr::write_csv(
  fold_table,
  file.path(p$analysis_dir, "cross_validation_folds.csv")
)
readr::write_csv(
  result$model_fit$cv_results,
  file.path(p$analysis_dir, "cross_validation_results.csv")
)
```

Change basis metadata to include:

```r
c(
  "selected_lambda",
  "mean_cv_rmse",
  "cv_folds",
  "time_basis_knots",
  "spatial_rbf_centers",
  "rbf_sigma"
)
```

- [ ] **Step 4: Update handbook intermediate objects**

Use `model_fit$recipe` as the final 2014–2022 basis recipe and construct the
final design matrices from that recipe. Keep the original train/validation/test
row-count checks, but expose `rolling_folds`, `cv_results`, and `cv_summary` in
the returned result.

- [ ] **Step 5: Add the CV tuning plot and composite**

In `make_model_plots()` create:

```r
p_cv <- ggplot2::ggplot(
  fit$cv_summary,
  ggplot2::aes(lambda, mean_rmse)
) +
  ggplot2::geom_ribbon(
    ggplot2::aes(
      ymin = mean_rmse - sd_rmse,
      ymax = mean_rmse + sd_rmse
    ),
    fill = "#BFE3E3",
    alpha = 0.55
  ) +
  ggplot2::geom_line(color = "#007F82", linewidth = 1) +
  ggplot2::geom_vline(
    xintercept = fit$selected_lambda,
    color = "#D95F02",
    linetype = "dashed"
  ) +
  ggplot2::scale_x_log10() +
  ggplot2::labs(
    title = "Rolling-origin Ridge tuning",
    subtitle = "Mean RMSE across five expanding validation years; ribbon = ±1 SD",
    x = "Lambda (log scale)",
    y = "Mean validation RMSE"
  ) +
  handbook_theme()
```

Save `p_cv` as `09_rolling_cross_validation.png`.

Create `save_stacked_plots(top, bottom, path)` with `grid::grid.layout(2, 1)`
and render `p_cv` above the existing final-test comparison plot into
`06_model_comparison.png`.

Use:

```r
save_stacked_plots <- function(
    top,
    bottom,
    path,
    width = 9,
    height = 5.4,
    dpi = 180) {
  grDevices::png(
    path,
    width = width,
    height = height,
    units = "in",
    res = dpi,
    bg = "white"
  )
  on.exit(grDevices::dev.off(), add = TRUE)
  grid::grid.newpage()
  layout <- grid::grid.layout(
    nrow = 2,
    ncol = 1,
    heights = grid::unit(c(0.46, 0.54), "null")
  )
  grid::pushViewport(grid::viewport(layout = layout))
  print(
    top,
    vp = grid::viewport(layout.pos.row = 1, layout.pos.col = 1)
  )
  print(
    bottom,
    vp = grid::viewport(layout.pos.row = 2, layout.pos.col = 1)
  )
}
```

- [ ] **Step 6: Run handbook tests and verify GREEN**

Run:

```bash
Rscript -e 'testthat::test_file("tests/testthat/test-handbook-step-by-step.R")'
```

Expected: all handbook tests pass.

- [ ] **Step 7: Regenerate the complete analysis**

Run:

```bash
Rscript -e '
  source("R/handbook_step_by_step.R")
  result <- run_handbook_steps(write_outputs = TRUE, workspace_root = getwd())
  print(result$model_fit$selected_lambda)
  print(result$model_fit$metrics)
'
```

Expected: five CV folds, one selected lambda, four 2023 model rows, and all
required CSV/PNG files.

- [ ] **Step 8: Verify output consistency**

Run an R check requiring:

```r
stopifnot(
  nrow(readr::read_csv("output/analysis/cross_validation_folds.csv")) == 5,
  nrow(readr::read_csv("output/analysis/cross_validation_results.csv")) == 500,
  all(file.exists(file.path(
    "output/figures",
    c(
      "05_basis_functions.png",
      "06_model_comparison.png",
      "07_observed_vs_predicted.png",
      "08_residual_map.png",
      "09_rolling_cross_validation.png"
    )
  )))
)
```

- [ ] **Step 9: Commit the reproducible outputs**

```bash
git add \
  R/03_model.R \
  R/handbook_step_by_step.R \
  tests/testthat/test-handbook-step-by-step.R \
  output/analysis/model_metrics.csv \
  output/analysis/basis_metadata.csv \
  output/analysis/test_predictions.csv \
  output/analysis/cross_validation_folds.csv \
  output/analysis/cross_validation_results.csv \
  output/figures/05_basis_functions.png \
  output/figures/06_model_comparison.png \
  output/figures/07_observed_vs_predicted.png \
  output/figures/08_residual_map.png \
  output/figures/09_rolling_cross_validation.png
git commit -m "docs: regenerate cross-validated model evidence"
```

---

### Task 4: Update the Embedded-Video PowerPoint Without Rebuilding Slide 2

**Files:**
- Create: `tmp/stat3888-cross-validation/update_embedded_deck.mjs`
- Create: `tmp/stat3888-cross-validation/test_embedded_deck.mjs`
- Modify by generation: `deliverables/STAT3888_Toronto_Bicycle_Theft_Presentation/STAT3888_Toronto_Bicycle_Theft_Cross_Validated_Embedded_Video.pptx`

**Interfaces:**
- Consumes: current corrected embedded-video PPTX, regenerated figures, metrics CSV, and basis metadata CSV.
- Produces: a four-slide cross-validated PPTX with unchanged video package parts.

- [ ] **Step 1: Write the failing package-level test**

The test must use Node's `child_process.execFileSync("unzip", ...)` to read
both source and output PPTX ZIP packages and require:

```javascript
assert.equal(slideCount, 4);
assert.ok(entries.has("ppt/media/media1.mp4"));
assert.deepEqual(
  unzipBytes(outputPath, "ppt/media/media1.mp4"),
  unzipBytes(sourcePath, "ppt/media/media1.mp4"),
);
assert.match(slide3Text, /Rolling validation 2018–2022/);
assert.match(slide3Text, /Final test 2023/);
assert.doesNotMatch(slide3Text, /Validate 2022/);
assert.match(notes3Text, /rolling-origin cross-validation/i);
assert.match(slide4Text, /Basis Ridge/);
```

It must also compare source and output bytes for:

- `ppt/slides/slide2.xml`;
- `ppt/slides/_rels/slide2.xml.rels`;
- `ppt/media/media1.mp4`.

- [ ] **Step 2: Run the package test and verify RED**

Run:

```bash
node tmp/stat3888-cross-validation/test_embedded_deck.mjs
```

Expected: FAIL because the cross-validated output PPTX does not exist.

- [ ] **Step 3: Implement focused OOXML media and text replacement**

Use Node's built-in `fs`, `os`, `path`, and `child_process` modules:

```javascript
const staging = await fs.mkdtemp(path.join(os.tmpdir(), "stat3888-cv-pptx-"));
execFileSync("unzip", ["-qq", sourcePath, "-d", staging]);
// Replace only the approved files and XML text in staging.
execFileSync("zip", ["-X", "-q", "-r", outputPath, "."], { cwd: staging });
```

The updater must:

1. load the current corrected embedded-video PPTX;
2. replace:
   - `ppt/media/image7.png` with `05_basis_functions.png`;
   - `ppt/media/image8.png` with `06_model_comparison.png`;
   - `ppt/media/image9.png` with `07_observed_vs_predicted.png`;
   - `ppt/media/image10.png` with `08_residual_map.png`;
3. replace slide-3 timing text with:

```text
Rolling validation 2018–2022  →  Final test 2023
```

4. replace the slide-3 component text with:

```text
B-splines + sine/cosine + 16 spatial RBFs + neighbourhood indicators
Ridge λ selected by the lowest mean RMSE across five rolling folds
```

5. populate the slide-3 Ridge callout from the regenerated metric CSV;
6. populate slide-4 improvement, prediction, and residual statements from the
   regenerated metrics and residual summary;
7. rewrite notes 3 and 4 to explain rolling validation and the regenerated
   results;
8. leave slide 2 XML, relationships, video bytes, poster, and media actions
   unchanged;
9. export `STAT3888_Toronto_Bicycle_Theft_Cross_Validated_Embedded_Video.pptx`.

- [ ] **Step 4: Run the package test and verify GREEN**

Run:

```bash
node tmp/stat3888-cross-validation/test_embedded_deck.mjs
```

Expected: all structural, text, metric, and video-preservation assertions pass.

- [ ] **Step 5: Render and inspect all four slides**

Run the bundled PowerPoint renderer, montage generator, and overflow checker:

```bash
PY="/Users/liumingyuan/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3"
PRES="/Users/liumingyuan/.codex/plugins/cache/openai-primary-runtime/presentations/26.730.11710/skills/presentations"
"$PY" "$PRES/container_tools/render_slides.py" \
  deliverables/STAT3888_Toronto_Bicycle_Theft_Presentation/STAT3888_Toronto_Bicycle_Theft_Cross_Validated_Embedded_Video.pptx
"$PY" "$PRES/container_tools/slides_test.py" \
  deliverables/STAT3888_Toronto_Bicycle_Theft_Presentation/STAT3888_Toronto_Bicycle_Theft_Cross_Validated_Embedded_Video.pptx
```

Expected: four readable slides and no overflow errors.

- [ ] **Step 6: Commit the PowerPoint updater and deck**

```bash
git add \
  tmp/stat3888-cross-validation/update_embedded_deck.mjs \
  tmp/stat3888-cross-validation/test_embedded_deck.mjs \
  deliverables/STAT3888_Toronto_Bicycle_Theft_Presentation/STAT3888_Toronto_Bicycle_Theft_Cross_Validated_Embedded_Video.pptx
git commit -m "docs: update embedded-video deck for rolling validation"
```

---

### Task 5: Update and Rebuild the English Five-Minute Speech Guide

**Files:**
- Modify: `tmp/stat3888-presentation/five_minute_speech_content.py`
- Modify: `tmp/stat3888-presentation/test_five_minute_speech_guide.py`
- Modify if required: `tmp/stat3888-presentation/build_five_minute_speech_guide.py`
- Update by generation: `deliverables/STAT3888_Toronto_Bicycle_Theft_Presentation/STAT3888_五分钟演讲稿与原理解析.docx`
- Update by generation: `deliverables/STAT3888_Toronto_Bicycle_Theft_Presentation/STAT3888_五分钟演讲稿与原理解析.pdf`

**Interfaces:**
- Consumes: regenerated metrics, selected lambda, fold definitions, and final slide images.
- Produces: English 300-second script plus Chinese principles and viva guide.

- [ ] **Step 1: Replace fixed-metric tests with source-backed CV assertions**

Update the speech tests to load:

- `output/analysis/model_metrics.csv`;
- `output/analysis/basis_metadata.csv`;
- `output/analysis/cross_validation_folds.csv`.

Require:

```python
self.assertEqual(PROJECT_FACTS["cv_validation_years"], [2018, 2019, 2020, 2021, 2022])
self.assertEqual(PROJECT_FACTS["final_test_year"], 2023)
self.assertEqual(PROJECT_FACTS["cv_folds"], 5)
self.assertAlmostEqual(
    PROJECT_FACTS["selected_lambda"],
    selected_lambda_from_csv,
)
```

Require formal speech to contain:

```text
rolling-origin cross-validation
five expanding-window folds
untouched 2023 test set
```

and reject:

```text
2022 is used for Ridge tuning
Validate 2022
random cross-validation
```

- [ ] **Step 2: Run the speech tests and verify RED**

Run:

```bash
PY="/Users/liumingyuan/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3"
PYTHONPATH=tmp/stat3888-presentation \
  "$PY" -m unittest tmp/stat3888-presentation/test_five_minute_speech_guide.py -v
```

Expected: failures from obsolete fixed facts and single-year validation wording.

- [ ] **Step 3: Update project facts and slide-3/4 scripts**

Load values from the regenerated CSV files when constructing
`PROJECT_FACTS`. Revise slide 3 to explain the five folds and lambda-selection
rule in approximately 110–125 words. Revise slide 4 to use the regenerated
Ridge metrics and residual conclusion. Preserve the existing slide timings and
keep the total formal script between 630 and 700 English words.

- [ ] **Step 4: Add Chinese principle and viva entries**

Add principle sections for:

- holdout validation versus cross-validation;
- rolling-origin expanding windows;
- leakage prevention inside basis construction;
- mean-fold RMSE lambda selection;
- tuning set versus untouched final test.

Add viva questions with short and deeper answers for:

```text
Why not random K-fold cross-validation?
Why must the basis recipe be rebuilt in every fold?
Why is 2023 not included in cross-validation?
```

- [ ] **Step 5: Run speech tests and verify GREEN**

Run:

```bash
PYTHONPATH=tmp/stat3888-presentation \
  "$PY" -m unittest tmp/stat3888-presentation/test_five_minute_speech_guide.py -v
```

Expected: all tests pass and formal speech remains English and within the
five-minute word budget.

- [ ] **Step 6: Rebuild DOCX and PDF**

Run:

```bash
PYTHONPATH=tmp/stat3888-presentation \
  "$PY" tmp/stat3888-presentation/build_five_minute_speech_guide.py
DOCX="deliverables/STAT3888_Toronto_Bicycle_Theft_Presentation/STAT3888_五分钟演讲稿与原理解析.docx"
OUT="tmp/stat3888-presentation/rolling-cv-guide-render"
RENDER="/Users/liumingyuan/.codex/plugins/cache/openai-primary-runtime/documents/26.730.11710/skills/documents/render_docx.py"
"$PY" "$RENDER" "$DOCX" --output_dir "$OUT" --emit_pdf
cp "$OUT/STAT3888_五分钟演讲稿与原理解析.pdf" \
  "deliverables/STAT3888_Toronto_Bicycle_Theft_Presentation/STAT3888_五分钟演讲稿与原理解析.pdf"
```

Expected: readable Word and PDF files with updated cross-validation content.

- [ ] **Step 7: Commit the revised speech guide**

```bash
git add \
  tmp/stat3888-presentation/five_minute_speech_content.py \
  tmp/stat3888-presentation/test_five_minute_speech_guide.py \
  tmp/stat3888-presentation/build_five_minute_speech_guide.py \
  deliverables/STAT3888_Toronto_Bicycle_Theft_Presentation/STAT3888_五分钟演讲稿与原理解析.docx \
  deliverables/STAT3888_Toronto_Bicycle_Theft_Presentation/STAT3888_五分钟演讲稿与原理解析.pdf
git commit -m "docs: explain rolling validation in five-minute speech"
```

---

### Task 6: Final Integrated Verification and WPS Playback Check

**Files:**
- Verify: all R tests and outputs
- Verify: cross-validated embedded-video PPTX
- Verify: updated speech DOCX/PDF

**Interfaces:**
- Consumes: all implementation outputs.
- Produces: a fully verified submission bundle.

- [ ] **Step 1: Run every automated test**

Run:

```bash
Rscript -e 'testthat::test_dir("tests/testthat")'
node tmp/stat3888-cross-validation/test_embedded_deck.mjs
PY="/Users/liumingyuan/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3"
PYTHONPATH=tmp/stat3888-presentation \
  "$PY" -m unittest tmp/stat3888-presentation/test_five_minute_speech_guide.py -v
```

Expected: all R, PowerPoint-package, and speech tests pass.

- [ ] **Step 2: Perform evidence consistency checks**

Require exact equality, within CSV precision, between:

- selected lambda in basis metadata, slide 3, and speech;
- Ridge MAE/RMSE/R² in model metrics, slide 3/4, and speech;
- rolling validation years in fold CSV, slide notes, and speech;
- 2023 improvement percentage in model metrics-derived calculation and slide 4.

- [ ] **Step 3: Inspect rendered slides and document pages**

Check every PPT slide and every DOCX-rendered page for:

- clipping or overlap;
- readable CV axes and lambda label;
- correct four-slide story;
- no obsolete single-2022 validation wording;
- no accidental Chinese text in the formal speech;
- no missing figures or large unexplained blank gaps.

- [ ] **Step 4: Open the final PPTX in WPS and test video playback**

Open:

```bash
open -a /Applications/wpsoffice.app \
  "/Users/liumingyuan/Documents/project of stat38888/.worktrees/stat3888-five-minute-speech/deliverables/STAT3888_Toronto_Bicycle_Theft_Presentation/STAT3888_Toronto_Bicycle_Theft_Cross_Validated_Embedded_Video.pptx"
```

Verify:

1. no repair prompt;
2. slide 2 video opens full-screen when clicked;
3. playback works;
4. Escape returns to slide 2;
5. slide 3 CV composite is readable;
6. slide 4 metrics match the regenerated evidence.

- [ ] **Step 5: Open the speech DOCX and PDF in WPS**

Verify both files open normally and display the updated English speech,
cross-validation principles, formulas, name fields, and viva answers.

- [ ] **Step 6: Commit any final QA-only corrections**

If visual QA required a correction, rerun the affected tests and commit only
the corrected source and regenerated deliverables:

```bash
git commit -m "docs: finalize cross-validated STAT3888 presentation"
```

- [ ] **Step 7: Finish the branch**

Invoke `superpowers:finishing-a-development-branch`, verify tests again, and
offer local merge, pull request, keep-as-is, or discard options. Do not remove
the worktree until a successful local merge or explicit discard choice.
