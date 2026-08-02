# STAT3888 Teacher-Feedback Four-Slide Revision Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce a verified four-slide revision of the exact PPTX sent to Dr Liu that interprets fitted seasonal coefficients and reports a rolling-validated season-by-space interaction test.

**Architecture:** Start from the clean rolling-cross-validation branch in a new isolated worktree. Extend the R model through test-first seasonal-summary and interaction interfaces, generate source-backed figures and CSVs, then import the exact sent PPTX with artifact-tool and edit only inherited Slide 3 and Slide 4 elements while preserving Slides 1–2 and the embedded video.

**Tech Stack:** R, testthat, glmnet, tidyverse, ggplot2, sf, JavaScript ES modules, `@oai/artifact-tool`, PowerPoint OOXML inspection, WPS Office.

## Global Constraints

- Preserve `/Users/liumingyuan/Documents/TORONTO BICYCLE THEFT  from Mingyuan Liu.pptx` unchanged.
- Keep exactly four slides.
- Preserve the existing slide master, layout, typography, spacing, and embedded video.
- Interpret sine/cosine coefficients jointly; do not present an individual sign as a standalone seasonal effect.
- Interpret the peak-to-trough ratio on the `1 + count` scale while holding other model components fixed.
- Test only annual-season-by-spatial-RBF interactions.
- Select the displayed primary model by mean rolling-validation RMSE, never by the 2023 test score.
- Preserve the residual map and prediction-failure discussion.
- Build the final PPTX with artifact-tool; do not use `python-pptx` or direct OOXML mutation.
- Export the final file to `deliverables/STAT3888_Toronto_Bicycle_Theft_Presentation/STAT3888_Toronto_Bicycle_Theft_Teacher_Feedback_Revision.pptx`.

---

### Task 1: Create a clean implementation worktree

**Files:**
- Reference: `docs/superpowers/specs/2026-08-02-stat3888-teacher-feedback-four-slide-revision-design.md`
- Reference: `docs/superpowers/plans/2026-08-02-stat3888-teacher-feedback-four-slide-revision.md`

**Interfaces:**
- Consumes: branch `codex/stat3888-five-minute-speech` at commit `86ce3c9` and the two approved documentation commits on `main`.
- Produces: clean branch `codex/stat3888-teacher-feedback` in `.worktrees/stat3888-teacher-feedback`.

- [ ] **Step 1: Invoke the worktree skill and verify the target is unused**

Run the `using-git-worktrees` skill, then run:

```bash
git worktree list
git branch --list 'codex/stat3888-teacher-feedback'
test ! -e .worktrees/stat3888-teacher-feedback
```

Expected: no existing target branch or directory.

- [ ] **Step 2: Create the isolated branch from the rolling-CV branch**

```bash
git worktree add \
  -b codex/stat3888-teacher-feedback \
  .worktrees/stat3888-teacher-feedback \
  codex/stat3888-five-minute-speech
```

Expected: a clean worktree whose `R/03_model.R` contains `make_rolling_folds()`.

- [ ] **Step 3: Bring the approved design and plan into the worktree**

```bash
git -C .worktrees/stat3888-teacher-feedback cherry-pick 78bfea8
stat_plan_commit=$(git log -1 --format=%H main -- \
  docs/superpowers/plans/2026-08-02-stat3888-teacher-feedback-four-slide-revision.md)
test -n "$stat_plan_commit"
git -C .worktrees/stat3888-teacher-feedback cherry-pick "$stat_plan_commit"
```

Expected: the clean worktree contains both approved documents.

- [ ] **Step 4: Confirm clean baseline tests**

```bash
cd .worktrees/stat3888-teacher-feedback
Rscript -e 'testthat::test_dir("tests/testthat", reporter = "summary")'
```

Expected: all existing tests pass before feature work.

---

### Task 2: Add failing tests for seasonal interpretation and interaction columns

**Files:**
- Modify: `tests/testthat/test-model.R`
- Create: `tests/testthat/test-teacher-feedback-analysis.R`
- Modify later: `R/03_model.R`
- Create later: `R/06_teacher_feedback_analysis.R`

**Interfaces:**
- Consumes: `make_design_matrix(data, recipe)` and fitted Ridge models.
- Produces: required APIs `make_design_matrix(data, recipe, include_interactions = FALSE)`, `extract_seasonal_coefficients(ridge_model, lambda)`, and `summarise_seasonal_cycle(coefficients)`.

- [ ] **Step 1: Write the interaction-column test**

Append to `tests/testthat/test-model.R`:

```r
testthat::test_that("annual season by spatial RBF interactions are explicit products", {
  base <- make_design_matrix(splits$train, recipe)
  interacted <- make_design_matrix(
    splits$train,
    recipe,
    include_interactions = TRUE
  )

  expected <- c(
    paste0("sin1_x_space_rbf_", 1:16),
    paste0("cos1_x_space_rbf_", 1:16)
  )
  testthat::expect_true(all(expected %in% colnames(interacted)))
  testthat::expect_equal(ncol(interacted), ncol(base) + 32L)
  testthat::expect_equal(
    interacted[, "sin1_x_space_rbf_1"],
    interacted[, "sin1"] * interacted[, "space_rbf_1"]
  )
  testthat::expect_equal(
    interacted[, "cos1_x_space_rbf_16"],
    interacted[, "cos1"] * interacted[, "space_rbf_16"]
  )
})
```

- [ ] **Step 2: Write the coefficient-summary test**

Create `tests/testthat/test-teacher-feedback-analysis.R` with:

```r
source("R/config.R")
source("R/01_prepare_data.R")
source("R/03_model.R")
source("R/06_teacher_feedback_analysis.R")

testthat::test_that("seasonal coefficients yield amplitude peak and ratio", {
  coefficients <- c(sin1 = 1, cos1 = 0, sin2 = 0, cos2 = 0)
  result <- summarise_seasonal_cycle(coefficients)

  testthat::expect_equal(result$summary$annual_amplitude, 1)
  testthat::expect_equal(result$summary$semiannual_amplitude, 0)
  testthat::expect_equal(result$summary$peak_month, 3L)
  testthat::expect_equal(result$summary$trough_month, 9L)
  testthat::expect_equal(result$summary$peak_to_trough_ratio, exp(2))
  testthat::expect_equal(nrow(result$monthly), 12L)
})
```

- [ ] **Step 3: Write the rolling-CV interaction result test**

Append to `tests/testthat/test-model.R`:

```r
testthat::test_that("rolling CV labels additive and interaction candidates", {
  tuning_panel <- dplyr::bind_rows(splits$train, splits$validation)
  lambda_grid <- c(0.1, 0.01)
  additive <- cross_validate_ridge(
    tuning_panel,
    lambda_grid,
    include_interactions = FALSE
  )
  interaction <- cross_validate_ridge(
    tuning_panel,
    lambda_grid,
    include_interactions = TRUE
  )

  testthat::expect_identical(additive$model_type, "Additive Ridge")
  testthat::expect_identical(interaction$model_type, "Season-space Ridge")
  testthat::expect_true(all(additive$summary$model == "Additive Ridge"))
  testthat::expect_true(all(interaction$summary$model == "Season-space Ridge"))
})
```

- [ ] **Step 4: Run tests and verify RED**

```bash
Rscript -e 'testthat::test_file("tests/testthat/test-model.R", reporter = "summary")'
Rscript -e 'testthat::test_file("tests/testthat/test-teacher-feedback-analysis.R", reporter = "summary")'
```

Expected: failures because `include_interactions`, `R/06_teacher_feedback_analysis.R`, and the new summary functions do not yet exist.

- [ ] **Step 5: Commit the failing tests**

```bash
git add tests/testthat/test-model.R tests/testthat/test-teacher-feedback-analysis.R
git commit -m "test: specify coefficient and interaction analysis"
```

---

### Task 3: Implement interaction-aware fitting and seasonal summaries

**Files:**
- Modify: `R/03_model.R`
- Create: `R/06_teacher_feedback_analysis.R`
- Test: `tests/testthat/test-model.R`
- Test: `tests/testthat/test-teacher-feedback-analysis.R`

**Interfaces:**
- Consumes: panel data, basis recipe, `glmnet` fit, selected lambda.
- Produces: interaction-aware matrices and CV results plus a coefficient table, monthly seasonal table, and one-row interpretation summary.

- [ ] **Step 1: Extend the design matrix with annual-season-by-space products**

Change the signature to accept `include_interactions`, insert the interaction
block immediately after `neighborhood_basis` is constructed, and replace the
final matrix assembly with:

```r
make_design_matrix <- function(
    data,
    recipe,
    include_interactions = FALSE) {
```

```r
  interaction <- NULL
  if (include_interactions) {
    interaction <- cbind(
      sweep(rbf, 1, seasonal[, "sin1"], `*`),
      sweep(rbf, 1, seasonal[, "cos1"], `*`)
    )
    colnames(interaction) <- c(
      paste0("sin1_x_space_rbf_", seq_len(ncol(rbf))),
      paste0("cos1_x_space_rbf_", seq_len(ncol(rbf)))
    )
  }
  x <- cbind(time_basis, seasonal, rbf, neighborhood_basis, interaction)
  colnames(x) <- c(
    paste0("time_bs_", seq_len(ncol(time_basis))),
    colnames(seasonal),
    paste0("space_rbf_", seq_len(ncol(rbf))),
    paste0("area_", seq_len(ncol(neighborhood_basis))),
    colnames(interaction)
  )
  x
```

- [ ] **Step 2: Parameterise rolling cross-validation**

Update `cross_validate_ridge()` so every fold calls `make_design_matrix()` with the same `include_interactions` value and returns an explicit model label:

```r
cross_validate_ridge <- function(
    panel,
    lambda_grid = default_lambda_grid(),
    include_interactions = FALSE) {
  model_type <- if (include_interactions) {
    "Season-space Ridge"
  } else {
    "Additive Ridge"
  }
  folds <- make_rolling_folds(panel)
  fold_results <- purrr::map_dfr(folds, function(fold_data) {
    recipe <- make_basis_recipe(fold_data$train)
    x_train <- make_design_matrix(
      fold_data$train,
      recipe,
      include_interactions = include_interactions
    )
    x_validation <- make_design_matrix(
      fold_data$validation,
      recipe,
      include_interactions = include_interactions
    )
    y_train <- log1p(fold_data$train$theft_count)
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
      sqrt(mean((fold_data$validation$theft_count - prediction)^2))
    })
    tibble::tibble(
      fold = fold_data$fold,
      train_end = fold_data$train_end,
      validation_year = fold_data$validation_year,
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
    dplyr::mutate(model = model_type) |>
    dplyr::arrange(dplyr::desc(lambda))
  list(
    model_type = model_type,
    folds = folds,
    fold_results = dplyr::mutate(fold_results, model = model_type),
    summary = summary,
    selected_lambda = summary$lambda[which.min(summary$mean_rmse)]
  )
}
```

- [ ] **Step 3: Fit both candidates without test-set selection leakage**

Refactor `fit_models()` to fit additive and interaction candidates separately, retain both CV summaries and predictions, and set `primary_model` from minimum mean CV RMSE:

```r
candidate_specs <- tibble::tibble(
  model = c("Additive Ridge", "Season-space Ridge"),
  include_interactions = c(FALSE, TRUE)
)

candidate_fits <- purrr::map(
  seq_len(nrow(candidate_specs)),
  function(i) fit_ridge_candidate(
    tuning_panel,
    test,
    lambda_grid,
    include_interactions = candidate_specs$include_interactions[i]
  )
)

cv_comparison <- purrr::map_dfr(candidate_fits, function(x) {
  best <- x$cv$summary[which.min(x$cv$summary$mean_rmse), ]
  dplyr::select(best, model, lambda, mean_rmse, sd_rmse)
})
primary_model <- cv_comparison$model[which.min(cv_comparison$mean_rmse)]
```

`fit_ridge_candidate()` must return `model`, `include_interactions`, `cv`, `recipe`, `ridge_model`, `selected_lambda`, `prediction`, and `metrics`. The existing OLS benchmark remains additive and unchanged.

- [ ] **Step 4: Add coefficient extraction and seasonal summary functions**

Create `R/06_teacher_feedback_analysis.R`:

```r
extract_seasonal_coefficients <- function(ridge_model, lambda) {
  fitted <- as.matrix(stats::coef(ridge_model, s = lambda))[, 1]
  wanted <- c("sin1", "cos1", "sin2", "cos2")
  stats::setNames(as.numeric(fitted[wanted]), wanted)
}

summarise_seasonal_cycle <- function(coefficients) {
  required <- c("sin1", "cos1", "sin2", "cos2")
  stopifnot(all(required %in% names(coefficients)))
  month <- 1:12
  seasonal_log <-
    coefficients["sin1"] * sin(2 * pi * month / 12) +
    coefficients["cos1"] * cos(2 * pi * month / 12) +
    coefficients["sin2"] * sin(4 * pi * month / 12) +
    coefficients["cos2"] * cos(4 * pi * month / 12)
  monthly <- tibble::tibble(
    month = month,
    month_label = month.abb,
    seasonal_log = as.numeric(seasonal_log),
    seasonal_multiplier = exp(seasonal_log)
  )
  list(
    coefficients = tibble::tibble(
      term = required,
      estimate = as.numeric(coefficients[required])
    ),
    monthly = monthly,
    summary = tibble::tibble(
      annual_amplitude = sqrt(coefficients["sin1"]^2 + coefficients["cos1"]^2),
      semiannual_amplitude = sqrt(coefficients["sin2"]^2 + coefficients["cos2"]^2),
      peak_month = month[which.max(seasonal_log)],
      trough_month = month[which.min(seasonal_log)],
      peak_to_trough_ratio = exp(max(seasonal_log) - min(seasonal_log))
    )
  )
}
```

- [ ] **Step 5: Run focused and full tests and verify GREEN**

```bash
Rscript -e 'testthat::test_file("tests/testthat/test-model.R", reporter = "summary")'
Rscript -e 'testthat::test_file("tests/testthat/test-teacher-feedback-analysis.R", reporter = "summary")'
Rscript -e 'testthat::test_dir("tests/testthat", reporter = "summary")'
```

Expected: all focused and full R tests pass with zero failures.

- [ ] **Step 6: Commit the model implementation**

```bash
git add R/03_model.R R/06_teacher_feedback_analysis.R tests/testthat/test-model.R tests/testthat/test-teacher-feedback-analysis.R
git commit -m "feat: add seasonal coefficient and interaction analysis"
```

---

### Task 4: Generate auditable outputs and figures

**Files:**
- Modify: `R/handbook_step_by_step.R`
- Modify: `R/run_all.R`
- Create: `output/analysis/seasonal_coefficients.csv`
- Create: `output/analysis/seasonal_cycle_summary.csv`
- Create: `output/analysis/seasonal_cycle_monthly.csv`
- Create: `output/analysis/interaction_model_comparison.csv`
- Create: `output/figures/10_fitted_seasonal_cycle.png`
- Create: `output/figures/11_interaction_model_comparison.png`
- Potentially regenerate: `output/figures/07_observed_vs_predicted.png`
- Potentially regenerate: `output/figures/08_residual_map.png`

**Interfaces:**
- Consumes: `fit_models()` result and `summarise_seasonal_cycle()`.
- Produces: exact source artifacts for Slides 3–4 and speaker-note citations.

- [ ] **Step 1: Write failing output assertions**

Add to `tests/testthat/test-handbook-step-by-step.R`:

```r
testthat::test_that("teacher feedback outputs are written from fitted models", {
  result <- run_handbook_steps(write_outputs = FALSE)
  testthat::expect_true(all(c(
    "seasonal_analysis",
    "interaction_comparison",
    "teacher_feedback_paths"
  ) %in% names(result)))
  testthat::expect_equal(nrow(result$seasonal_analysis$coefficients), 4L)
  testthat::expect_equal(nrow(result$seasonal_analysis$monthly), 12L)
  testthat::expect_equal(nrow(result$interaction_comparison), 2L)
})
```

- [ ] **Step 2: Run the assertion and verify RED**

```bash
Rscript -e 'testthat::test_file("tests/testthat/test-handbook-step-by-step.R", reporter = "summary")'
```

Expected: failure because the new result members do not exist.

- [ ] **Step 3: Add teacher-feedback output generation**

Source `R/06_teacher_feedback_analysis.R` from `R/handbook_step_by_step.R`. Build the additive seasonal analysis from the additive final Ridge candidate and write all four CSVs through `write_handbook_outputs()`.

Add figure functions to `R/06_teacher_feedback_analysis.R`:

```r
make_fitted_seasonal_cycle_plot <- function(seasonal_analysis) {
  ggplot2::ggplot(
    seasonal_analysis$monthly,
    ggplot2::aes(month, seasonal_multiplier)
  ) +
    ggplot2::geom_hline(yintercept = 1, color = "#9AA5AA", linewidth = 0.4) +
    ggplot2::geom_line(color = "#0B7C83", linewidth = 1.2) +
    ggplot2::geom_point(color = "#0B7C83", size = 2.2) +
    ggplot2::scale_x_continuous(breaks = 1:12, labels = month.abb) +
    ggplot2::labs(
      title = "Estimated coefficients imply a July seasonal peak",
      subtitle = "Seasonal multiplier for 1 + count, holding other components fixed",
      x = NULL,
      y = "Seasonal multiplier"
    ) +
    handbook_theme()
}
```

Create a second compact plot showing each candidate's minimum rolling-CV RMSE and untouched 2023 RMSE, with separate shapes and an explicit note that model choice uses CV RMSE.

- [ ] **Step 4: Run the full pipeline**

```bash
Rscript R/run_all.R
```

Expected: all analysis CSVs and both new PNGs exist; the pipeline prints the selected primary model and its rolling-CV basis.

- [ ] **Step 5: Independently audit displayed numbers**

```bash
Rscript - <<'RS'
coef <- read.csv("output/analysis/seasonal_coefficients.csv")
summary <- read.csv("output/analysis/seasonal_cycle_summary.csv")
monthly <- read.csv("output/analysis/seasonal_cycle_monthly.csv")
comparison <- read.csv("output/analysis/interaction_model_comparison.csv")
stopifnot(nrow(coef) == 4L)
stopifnot(nrow(monthly) == 12L)
stopifnot(summary$peak_month == monthly$month[which.max(monthly$seasonal_log)])
stopifnot(summary$trough_month == monthly$month[which.min(monthly$seasonal_log)])
stopifnot(nrow(comparison) == 2L)
stopifnot(sum(comparison$selected_by_cv) == 1L)
print(coef)
print(summary)
print(comparison)
RS
```

Expected: all `stopifnot()` checks pass and printed values match the figure annotations.

- [ ] **Step 6: Inspect both new figures at full resolution**

Open `output/figures/10_fitted_seasonal_cycle.png` and `output/figures/11_interaction_model_comparison.png` with the local image inspection tool. Confirm legible labels, no clipping, and no misleading scale.

- [ ] **Step 7: Commit generated analysis and source code**

```bash
git add R/handbook_step_by_step.R R/run_all.R R/06_teacher_feedback_analysis.R \
  tests/testthat/test-handbook-step-by-step.R \
  output/analysis/seasonal_coefficients.csv \
  output/analysis/seasonal_cycle_summary.csv \
  output/analysis/seasonal_cycle_monthly.csv \
  output/analysis/interaction_model_comparison.csv \
  output/figures/10_fitted_seasonal_cycle.png \
  output/figures/11_interaction_model_comparison.png \
  output/figures/07_observed_vs_predicted.png \
  output/figures/08_residual_map.png
git commit -m "feat: generate teacher feedback evidence"
```

---

### Task 5: Prepare the exact source deck for inherited-element editing

**Files:**
- Create under `tmp/teacher-feedback-revision/`: `source-notes.txt`, `template-audit.txt`, `template-frame-map.json`, `deviation-log.txt`, and template inspection artifacts.
- Reference: `/Users/liumingyuan/Documents/TORONTO BICYCLE THEFT  from Mingyuan Liu.pptx`

**Interfaces:**
- Consumes: exact source deck and new R-generated figures.
- Produces: validated `template-starter.pptx` with four duplicated source slides and explicit edit targets.

- [ ] **Step 1: Read the required presentation implementation references**

Read completely:

```text
artifact_tool_docs/API_QUICK_START.md
artifact_tool_docs/api/API_DOCS.md
artifact_tool_docs/api/references/master.spec.md
artifact_tool_docs/api/references/layout.spec.md
artifact_tool_docs/api/references/inspect.md
artifact_tool_docs/api/references/speaker-notes.spec.md
artifact_tool_docs/api/references/cookbook/imported-deck.md
references/template-following.md
style_guidelines.md
```

- [ ] **Step 2: Initialise the artifact-tool workspace and inspect every slide**

```bash
SKILL_DIR=/Users/liumingyuan/.codex/plugins/cache/openai-primary-runtime/presentations/26.801.11242/skills/presentations
TMP_DIR="$PWD/tmp/teacher-feedback-revision"
mkdir -p "$TMP_DIR"
/Users/liumingyuan/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node \
  "$SKILL_DIR/container_tools/setup_artifact_tool_workspace.mjs" \
  --workspace "$TMP_DIR"
/Users/liumingyuan/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node \
  "$SKILL_DIR/template_following_scripts/inspect_template_deck.mjs" \
  --workspace "$TMP_DIR" \
  --pptx '/Users/liumingyuan/Documents/TORONTO BICYCLE THEFT  from Mingyuan Liu.pptx'
```

Expected: four source-slide PNGs, layout JSON for every slide, notes anchors, media inventory including the MP4, and no truncated inspection output.

- [ ] **Step 3: Create the source audit files**

Use `apply_patch` to create:

- `source-notes.txt` listing the source deck, four analysis CSVs, two new figures, model scripts, and City of Toronto boundary source already present in the deck;
- `template-audit.txt` recording slide dimensions, fonts, inherited shape names, notes anchors, image frames, placeholders, and embedded-video preservation requirements;
- `deviation-log.txt` recording that Slides 1–2 are preserved and only specified Slide 3–4 inherited elements change.

- [ ] **Step 4: Create and validate the frame map**

Create `template-frame-map.json` with four output slides mapped one-to-one to source slides. Slides 1 and 2 use `editTargets: []`. Slide 3 rewrites the inherited title/method/component/metric text, replaces both inherited image elements, and rewrites its notes anchor. Slide 4 rewrites the inherited title/conclusion text, replaces the two inherited images only if the CV-selected model changes them, and rewrites its notes anchor. Every edit target uses exact anchor IDs from the fresh inspection.

Run:

```bash
/Users/liumingyuan/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node \
  "$SKILL_DIR/template_following_scripts/prepare_template_starter_deck.mjs" \
  --workspace "$TMP_DIR" \
  --pptx '/Users/liumingyuan/Documents/TORONTO BICYCLE THEFT  from Mingyuan Liu.pptx' \
  --map "$TMP_DIR/template-frame-map.json" \
  --out "$TMP_DIR/template-starter.pptx" \
  --preview-dir "$TMP_DIR/template-starter-preview" \
  --layout-dir "$TMP_DIR/template-starter-layout" \
  --contact-sheet "$TMP_DIR/template-starter-contact-sheet.png"
```

Expected: frame-map validation succeeds with no unclassified inherited placeholders.

---

### Task 6: Build the revised four-slide PPTX with artifact-tool

**Files:**
- Create: `tmp/teacher-feedback-revision/build_teacher_feedback_revision.mjs`
- Create: `deliverables/STAT3888_Toronto_Bicycle_Theft_Presentation/STAT3888_Toronto_Bicycle_Theft_Teacher_Feedback_Revision.pptx`
- Test: `tmp/teacher-feedback-revision/test_teacher_feedback_revision.mjs`

**Interfaces:**
- Consumes: `template-starter.pptx`, exact inspected anchors, and verified CSV/PNG artifacts.
- Produces: final editable four-slide deck with updated notes.

- [ ] **Step 1: Write a failing structural deck test**

Create `test_teacher_feedback_revision.mjs` to import the expected final path and assert:

```js
assert.equal(presentation.slides.items.length, 4);
assert.match(slide3Title, /coefficients reveal/i);
assert.match(slide3Text, /July/i);
assert.match(slide3Text, /January/i);
assert.match(slide3Text, /peak.to.trough/i);
assert.match(slide3Notes, /sin1/i);
assert.match(slide3Notes, /holding other components fixed/i);
assert.match(slide4Text, /interaction/i);
assert.match(slide4Notes, /rolling/i);
```

Also assert that the output package contains `ppt/media/media1.mp4` and exactly four slide XML parts.

- [ ] **Step 2: Run the test and verify RED**

```bash
/Users/liumingyuan/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node \
  tmp/teacher-feedback-revision/test_teacher_feedback_revision.mjs
```

Expected: failure because the final PPTX does not exist.

- [ ] **Step 3: Implement inherited-element edits**

Create `build_teacher_feedback_revision.mjs` as an ES module that:

1. imports `template-starter.pptx` with `PresentationFile.importPptx()`;
2. resolves only the anchor IDs authorised by `template-frame-map.json`;
3. replaces the Slide 3 left image with `10_fitted_seasonal_cycle.png`;
4. replaces the Slide 3 right image with `11_interaction_model_comparison.png`;
5. sets the Slide 3 title to `Estimated coefficients imply a July seasonal peak`;
6. writes compact, generated copy from the CSVs into the inherited lower-left and lower-right text frames without changing template font sizes;
7. updates Slide 4 copy and model figures from the CV-selected candidate;
8. updates `slide.speakerNotes.textFrame` for Slides 3–4 with coefficient values, joint interpretation, interaction method/result, and `[Sources]` blocks;
9. exports with `PresentationFile.exportPptx()` to the required final path.

All numeric strings must be formatted from parsed CSV values inside the module; no manually duplicated metrics are permitted.

- [ ] **Step 4: Build and run the structural test**

```bash
/Users/liumingyuan/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node \
  tmp/teacher-feedback-revision/build_teacher_feedback_revision.mjs
/Users/liumingyuan/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node \
  tmp/teacher-feedback-revision/test_teacher_feedback_revision.mjs
```

Expected: build exit 0 and all structural assertions pass.

- [ ] **Step 5: Verify the source deck is unchanged**

```bash
shasum -a 256 '/Users/liumingyuan/Documents/TORONTO BICYCLE THEFT  from Mingyuan Liu.pptx'
```

Expected: `77b50259f3dad996902cbc560166342d9a3e6a4e4685c820af6c3424962beae9`.

---

### Task 7: Run template fidelity and visual QA

**Files:**
- Final: `deliverables/STAT3888_Toronto_Bicycle_Theft_Presentation/STAT3888_Toronto_Bicycle_Theft_Teacher_Feedback_Revision.pptx`
- QA only: `tmp/teacher-feedback-revision/final-render/`, `tmp/teacher-feedback-revision/final-layout/`, and `tmp/teacher-feedback-revision/qa-ledger.txt`

**Interfaces:**
- Consumes: final PPTX, template starter, frame map, and analysis sources.
- Produces: fresh evidence that content, fidelity, media, and layout satisfy the design.

- [ ] **Step 1: Render and inspect the final artifact**

Use the artifact-tool export/inspection workflow to render all four final slides and write final layout JSON. Open every slide PNG individually at original detail. Check title wrapping, coefficient legibility, chart labels, data consistency, image crops, slide numbering, and the unchanged Slides 1–2.

- [ ] **Step 2: Run template fidelity validation**

```bash
/Users/liumingyuan/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node \
  "$SKILL_DIR/template_following_scripts/check_template_fidelity.mjs" \
  --workspace "$TMP_DIR" \
  --starter-pptx "$TMP_DIR/template-starter.pptx" \
  --final-pptx "$PWD/deliverables/STAT3888_Toronto_Bicycle_Theft_Presentation/STAT3888_Toronto_Bicycle_Theft_Teacher_Feedback_Revision.pptx" \
  --map "$TMP_DIR/template-frame-map.json" \
  --starter-layout-dir "$TMP_DIR/template-starter-layout" \
  --final-layout-dir "$TMP_DIR/final-layout" \
  --edit-dir "$TMP_DIR"
```

Expected: fidelity check passes with only the documented Slide 3–4 deviations.

- [ ] **Step 3: Run overflow and package checks**

```bash
/Users/liumingyuan/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3 \
  "$SKILL_DIR/container_tools/slides_test.py" \
  deliverables/STAT3888_Toronto_Bicycle_Theft_Presentation/STAT3888_Toronto_Bicycle_Theft_Teacher_Feedback_Revision.pptx
unzip -l deliverables/STAT3888_Toronto_Bicycle_Theft_Presentation/STAT3888_Toronto_Bicycle_Theft_Teacher_Feedback_Revision.pptx | \
  rg 'ppt/media/media1.mp4|ppt/slides/slide[1-4].xml'
```

Expected: no overflow failures, four slide parts, and the embedded MP4 present.

- [ ] **Step 4: Re-run full model and deck verification**

```bash
Rscript -e 'testthat::test_dir("tests/testthat", reporter = "summary")'
/Users/liumingyuan/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node \
  tmp/teacher-feedback-revision/test_teacher_feedback_revision.mjs
git diff --check
```

Expected: zero test failures, structural deck test passes, and no whitespace errors.

- [ ] **Step 5: Preview the final PPTX in WPS Office**

```bash
open -a /Applications/wpsoffice.app \
  "$PWD/deliverables/STAT3888_Toronto_Bicycle_Theft_Presentation/STAT3888_Toronto_Bicycle_Theft_Teacher_Feedback_Revision.pptx"
```

Confirm the embedded video object remains available and Slides 3–4 match the verified renders.

- [ ] **Step 6: Record the QA ledger and commit the final deliverable**

Use `apply_patch` to write `tmp/teacher-feedback-revision/qa-ledger.txt` with the exact commands, test counts, fidelity result, source hash, slide count, media result, and visual inspection outcome. Then commit only intentional source, test, analysis, figure, and final-deck files:

```bash
git add R tests/testthat output/analysis output/figures \
  deliverables/STAT3888_Toronto_Bicycle_Theft_Presentation/STAT3888_Toronto_Bicycle_Theft_Teacher_Feedback_Revision.pptx
git commit -m "feat: revise STAT3888 deck for instructor feedback"
```

Expected: commit succeeds without staging temporary artifact-tool workspaces or unrelated files.

---

### Task 8: Final handoff

**Files:**
- Deliver: `deliverables/STAT3888_Toronto_Bicycle_Theft_Presentation/STAT3888_Toronto_Bicycle_Theft_Teacher_Feedback_Revision.pptx`

**Interfaces:**
- Consumes: the final verification evidence from Task 7.
- Produces: concise user handoff with one output citation and the successful git directives.

- [ ] **Step 1: Check final repository state and artifact metadata**

```bash
git status --short
ls -lT deliverables/STAT3888_Toronto_Bicycle_Theft_Presentation/STAT3888_Toronto_Bicycle_Theft_Teacher_Feedback_Revision.pptx
git log -3 --oneline
```

Expected: no unintended staged files, final PPTX exists, and the implementation commits are visible.

- [ ] **Step 2: Deliver the result**

Report the CV-selected interaction conclusion, the coefficient-derived seasonal conclusion, the four-slide constraint, and completed verification. Cite the final deck exactly once with `purpose="output"` and emit the branch/commit directives only for actions that actually succeeded.
