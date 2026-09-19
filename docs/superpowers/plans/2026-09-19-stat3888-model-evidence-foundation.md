# STAT3888 Model Evidence Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce one canonical, internally consistent set of model-selection, rolling-validation, 2023 test, aggregate-bias, and coordinate-provenance evidence for the advanced STAT3888 branch.

**Architecture:** Keep fitting logic in `R/03_model.R`, add small pure helpers for candidate summaries and bias, and make `R/handbook_step_by_step.R` the single output writer. Preserve the untouched 2023 test set, select candidates only from 2018--2022 rolling validation, and fail panel construction when coordinates are not static neighbourhood attributes.

**Tech Stack:** R 4.6, tidyverse, glmnet, testthat, CSV analytical artifacts.

## Global Constraints

- Work only in the isolated `model-improvement` worktree.
- Do not modify untracked PPTX, `.DS_Store`, `.superpowers`, or `tmp/teacher-feedback-revision` content.
- Keep 2023 completely outside model selection.
- Write every behavior test first and observe the expected failure before implementation.
- Do not add count models, prediction intervals, or external covariates in this phase.
- Preserve focused legacy outputs while adding `model_summary.csv` as the canonical model-level artifact.

---

### Task 1: Enforce Static Neighbourhood Coordinates

**Files:**
- Modify: `tests/testthat/test-prepare-data.R`
- Modify: `R/01_prepare_data.R:49-76`

**Interfaces:**
- Consumes: raw bicycle tibble with `neighborhood`, `long`, and `lat`.
- Produces: `validate_static_neighborhood_coordinates(raw) -> invisible(TRUE)` or a descriptive error; `make_monthly_panel(raw)` calls it before constructing coordinates.

- [ ] **Step 1: Write the failing coordinate-invariant test**

Add a synthetic raw dataset, alter one row's longitude within an existing neighbourhood, and assert:

```r
testthat::expect_error(
  make_monthly_panel(changing_coordinates),
  "Coordinates must be static within neighbourhood"
)
```

Also assert that the real source has one coordinate pair per neighbourhood.

- [ ] **Step 2: Run the focused test and verify RED**

Run `Rscript -e 'testthat::test_file("tests/testthat/test-prepare-data.R")'`.
Expected: the new assertion fails because the current code silently takes medians.

- [ ] **Step 3: Implement the invariant**

Add a pure validator that counts distinct coordinate pairs, reports affected neighbourhoods, and returns invisibly on success. Call it at the start of `make_monthly_panel()`. Replace median aggregation with `distinct(neighborhood, lon = long, lat)` after validation.

- [ ] **Step 4: Run the focused test and verify GREEN**

Run the same `test_file()` command. Expected: all preparation tests pass.

- [ ] **Step 5: Commit**

```bash
git add R/01_prepare_data.R tests/testthat/test-prepare-data.R
git commit -m "fix: enforce static neighbourhood coordinates"
```

### Task 2: Build the Canonical Model Summary

**Files:**
- Modify: `tests/testthat/test-model.R`
- Modify: `R/03_model.R:185-355`

**Interfaces:**
- Consumes: the `fit_models()` result containing baselines, candidate fits, CV comparison, predictions, and primary-model identity.
- Produces: `calculate_total_bias(actual, predicted) -> numeric(1)` and `build_model_summary(model_fit) -> tibble` with the ten columns specified in the design.

- [ ] **Step 1: Write failing summary tests**

Test exact column names, the five expected models, exactly one selected row, agreement with `fit$primary_model`, independent total-bias reconciliation, and an error for zero actual totals.

```r
summary <- build_model_summary(fit)
testthat::expect_equal(sum(summary$selected_by_cv), 1L)
testthat::expect_identical(
  summary$model[summary$selected_by_cv],
  fit$primary_model
)
```

- [ ] **Step 2: Run the focused model tests and verify RED**

Run `Rscript -e 'testthat::test_file("tests/testthat/test-model.R")'`.
Expected: failure because the two helpers do not exist.

- [ ] **Step 3: Implement bias and summary helpers**

Implement zero-total validation in `calculate_total_bias()`. Build baseline and candidate rows from existing predictions and CV summaries without refitting or consulting 2023 for selection. Use explicit candidate names and `NA_real_` for non-applicable baseline CV fields.

- [ ] **Step 4: Run focused tests and verify GREEN**

Run the same `test_file()` command. Expected: all model tests pass.

- [ ] **Step 5: Commit**

```bash
git add R/03_model.R tests/testthat/test-model.R
git commit -m "feat: add canonical model evidence summary"
```

### Task 3: Export Both Candidates and Primary Metadata

**Files:**
- Modify: `tests/testthat/test-handbook-step-by-step.R`
- Modify: `R/03_model.R:339-355`
- Modify: `R/handbook_step_by_step.R:45-111`

**Interfaces:**
- Consumes: `fit_models()` with `candidate_fits`, `primary_model`, and `build_model_summary()`.
- Produces: `model_summary.csv`; two-candidate `cross_validation_results.csv`; qualified-primary `basis_metadata.csv`; explicit five-row `model_metrics.csv`.

- [ ] **Step 1: Write failing output-contract tests**

Extend expected files with `model_summary.csv`. Assert both candidate labels in CV results, validation years 2018--2022, one selected summary row, qualified primary metadata keys, absence of unqualified `selected_lambda`, and both explicit Ridge names in `model_metrics.csv`.

- [ ] **Step 2: Run focused handbook tests and verify RED**

Run `Rscript -e 'testthat::test_file("tests/testthat/test-handbook-step-by-step.R")'`.
Expected: failures for the missing summary, additive-only CV export, and legacy metadata keys.

- [ ] **Step 3: Implement the unified output writer**

Expose combined candidate fold results from `fit_models()`. Write the canonical summary, explicit five-model metrics, combined fold evidence, and metadata derived from the primary candidate's CV row.

- [ ] **Step 4: Run focused tests and verify GREEN**

Run the same `test_file()` command. Expected: all handbook-step tests pass.

- [ ] **Step 5: Commit**

```bash
git add R/03_model.R R/handbook_step_by_step.R tests/testthat/test-handbook-step-by-step.R
git commit -m "feat: unify model evidence exports"
```

### Task 4: Regenerate and Verify Real Analytical Outputs

**Files:**
- Create: `output/analysis/model_summary.csv`
- Modify: `output/analysis/model_metrics.csv`
- Modify: `output/analysis/cross_validation_results.csv`
- Modify: `output/analysis/basis_metadata.csv`
- Modify as generated: `output/analysis/test_predictions.csv`
- Modify as generated: applicable `output/figures/*.png`

**Interfaces:**
- Consumes: the configured bicycle CSV and tested pipeline.
- Produces: regenerated analytical artifacts matching the canonical contract.

- [ ] **Step 1: Run the full analysis pipeline**

Run `Rscript R/run_all.R`. Expected: exit 0 and a printed CV-selected primary model.

- [ ] **Step 2: Independently verify generated evidence**

Use a read-only R command to assert one selected row, two CV candidates, 2018--2022 folds, matching primary metadata, and selected-model bias reconciliation against `test_predictions.csv`.

- [ ] **Step 3: Run the complete R suite**

Run `Rscript tests/testthat.R`. Expected: zero failures, warnings, and skips.

- [ ] **Step 4: Run repository hygiene checks**

Run `git diff --check` and `git status --short`. Expected: no whitespace errors; only intended tracked artifacts plus pre-existing user-owned untracked files.

- [ ] **Step 5: Commit regenerated evidence**

Stage only intended generated artifacts and commit with `data: regenerate canonical model evidence`.

### Task 5: Final Requirement Audit

**Files:**
- Review: `docs/superpowers/specs/2026-09-19-stat3888-model-evidence-foundation-design.md`
- Review: all files changed by Tasks 1--4

**Interfaces:**
- Consumes: final branch diff and fresh verification output.
- Produces: an evidence-backed completion report with remaining limitations.

- [ ] **Step 1: Map every design success criterion to code, test, or generated output**

Record any unmet criterion as incomplete rather than weakening the criterion.

- [ ] **Step 2: Run final fresh verification**

Run `Rscript tests/testthat.R`, `git diff --check HEAD~1..HEAD`, and `git status --short`.

- [ ] **Step 3: Review branch history and final diff**

Run `git log --oneline --decorate -8` and `git diff --stat a720fd6..HEAD`. Confirm no presentation or temporary user files were modified.
