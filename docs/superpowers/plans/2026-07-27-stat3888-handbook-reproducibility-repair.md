# STAT3888 Handbook Reproducibility Repair Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the PDF's step-by-step R route and `R/run_all.R` use one computation pipeline and produce identical data shapes, figures, predictions, and metrics.

**Architecture:** Add a validated data-path resolver to `R/config.R`, then add a teaching orchestrator that exposes intermediate objects while delegating all calculations to the existing production functions. Rewrite the PDF core path to call that orchestrator and label internal code excerpts as non-executable explanations. Validate equality with R tests, PDF text tests, rendering, and WPS preview.

**Tech Stack:** R 4.6.1, testthat, tidyverse, lubridate, glmnet, Python 3, ReportLab, pytest, pypdf, pdfplumber, Poppler, WPS Office.

## Global Constraints

- Keep `bicycle.csv`, Task 1, and Task 4 unchanged.
- Keep verified model structure and results unchanged.
- Use production R functions as the only computation source.
- Support both `/Users/liumingyuan/sta pj` step-by-step use and project-root one-click use.
- Keep compact single-column PDF layout.
- All executable PDF blocks must run in order from a clean R session.
- Internal implementation excerpts must be labeled `函数内部原理展开（不单独运行）`.
- Preserve the final PDF filename.

---

### Task 1: Resolve the Dataset Without a Stale Absolute Path

**Files:**
- Modify: `R/config.R`
- Modify: `tests/testthat/test-config.R`

**Interfaces:**
- Consumes: optional environment variable `STAT3888_BICYCLE_CSV`, current project root, and known local fallback paths.
- Produces: `resolve_bicycle_csv(root = find_project_root()) -> normalized existing file path`.

- [ ] **Step 1: Write failing path-resolution tests**

Add tests that create a temporary `data/bicycle.csv`, require project-local data to win over fallback paths, require an existing environment-variable path to have highest priority, and require a missing-data error to list checked candidates.

```r
testthat::test_that("project-local bicycle data is resolved", {
  root <- withr::local_tempdir()
  dir.create(file.path(root, "data"))
  source <- file.path(root, "data", "bicycle.csv")
  writeLines("date,quarter,day_of_week,neighborhood,bike_cost,location,long,lat", source)
  testthat::expect_equal(resolve_bicycle_csv(root), normalizePath(source))
})
```

- [ ] **Step 2: Run the focused test and verify failure**

Run:

```bash
Rscript -e 'testthat::test_file("tests/testthat/test-config.R")'
```

Expected: failure because `resolve_bicycle_csv()` does not exist.

- [ ] **Step 3: Implement the resolver**

Add `resolve_bicycle_csv()` with the approved priority order. Validate existence and the eight CSV headers before returning. Update `project_paths()` to call the resolver.

- [ ] **Step 4: Run the focused test**

Expected: all config tests pass.

- [ ] **Step 5: Commit**

```bash
git add R/config.R tests/testthat/test-config.R
git commit -m "fix: resolve STAT3888 bicycle data path"
```

### Task 2: Add a Step-by-Step Orchestrator Using Production Functions

**Files:**
- Create: `R/handbook_step_by_step.R`
- Create: `tests/testthat/test-handbook-step-by-step.R`
- Modify: `R/run_all.R`

**Interfaces:**
- Consumes: `project_paths()`, `read_bicycle()`, `audit_bicycle()`, `make_monthly_panel()`, `make_task1_plots()`, `split_panel()`, `make_basis_recipe()`, `make_design_matrix()`, `fit_models()`, and `make_model_plots()`.
- Produces: `run_handbook_steps(write_outputs = TRUE) -> list` containing `paths`, `raw`, `audit`, `prepared`, `panel`, `task1_paths`, `splits`, `basis_recipe`, `x_train`, `x_validation`, `x_test`, `model_fit`, and `model_paths`.

- [ ] **Step 1: Write the failing orchestrator test**

Require:

```r
result <- run_handbook_steps(write_outputs = FALSE)
testthat::expect_equal(nrow(result$raw), 31833)
testthat::expect_equal(nrow(result$panel), 16800)
testthat::expect_true(all(c("lon", "lat") %in% names(result$panel)))
testthat::expect_equal(vapply(result$splits, nrow, integer(1)), c(13440L, 1680L, 1680L))
testthat::expect_equal(result$basis_recipe$time_knots, c(20, 39, 58, 77))
testthat::expect_equal(nrow(result$basis_recipe$rbf_centers), 16)
```

Also compare `result$model_fit$metrics` with `output/analysis/model_metrics.csv` using tolerance `1e-8`.

- [ ] **Step 2: Verify the test fails**

Run:

```bash
Rscript -e 'testthat::test_file("tests/testthat/test-handbook-step-by-step.R")'
```

Expected: failure because the orchestrator file and function do not exist.

- [ ] **Step 3: Implement the orchestrator**

The function must source or require the established pipeline components and call them in order. It must not duplicate transformation, plotting, or modeling logic. Add the approved `stopifnot()` checks after each stage.

- [ ] **Step 4: Make `run_all.R` call the same orchestrator**

Replace the duplicated orchestration body with:

```r
source("R/handbook_step_by_step.R")
result <- run_handbook_steps(write_outputs = TRUE)
```

This makes one-click and step-by-step execution share the same object graph.

- [ ] **Step 5: Run R tests and the full pipeline**

Run:

```bash
Rscript -e 'testthat::test_dir("tests/testthat")'
Rscript R/run_all.R
```

Expected: all tests pass and analysis/figure outputs are regenerated.

- [ ] **Step 6: Commit**

```bash
git add R/handbook_step_by_step.R R/run_all.R tests/testthat/test-handbook-step-by-step.R output/analysis output/figures
git commit -m "feat: add reproducible handbook R workflow"
```

### Task 3: Rewrite the PDF Core Route Against the Orchestrator

**Files:**
- Modify: `handbook/core_path.py`
- Modify: `handbook/components.py`
- Modify: `handbook/styles.py`
- Modify: `tests/test_handbook_content.py`
- Modify: `tests/test_pdf_build.py`

**Interfaces:**
- Consumes: object names and commands defined by `run_handbook_steps()`.
- Produces: PDF chapters whose executable blocks exactly call production functions and whose internal excerpts are visually marked non-executable.

- [ ] **Step 1: Write failing content tests**

Require the PDF source to contain:

```python
required = [
    "resolve_bicycle_csv",
    "make_monthly_panel(raw)",
    "make_task1_plots(panel",
    "fit_models(splits, basis_recipe)",
    "model_fit$test_predictions",
    "函数内部原理展开（不单独运行）",
]
```

Forbid the incorrect seasonal block:

```python
assert "panel, ggplot2::aes(factor(month_of_year), theft_count)" not in text
```

Require explicit construction of `seasonal`, `hotspots`, and `heat` in the internal explanation.

- [ ] **Step 2: Verify the focused tests fail**

Run:

```bash
/Users/liumingyuan/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3 -m pytest tests/test_handbook_content.py -q
```

Expected: failure on the old path and simplified visualization snippets.

- [ ] **Step 3: Rewrite executable blocks**

Make the executable path source `R/config.R`, `R/01_prepare_data.R`, `R/02_visualize.R`, and `R/03_model.R`; create exactly the production objects; and show checks after each stage. Replace direct Ridge reconstruction with `model_fit <- fit_models(splits, basis_recipe)`.

- [ ] **Step 4: Add a distinct internal-excerpt component**

Add a caption/tone for `函数内部原理展开（不单独运行）` with a different background from `可直接运行`. Keep compact spacing.

- [ ] **Step 5: Run content and build tests**

Run:

```bash
/Users/liumingyuan/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3 -m pytest tests/test_handbook_content.py tests/test_pdf_build.py -q
```

Expected: all focused tests pass.

- [ ] **Step 6: Commit**

```bash
git add handbook/core_path.py handbook/components.py handbook/styles.py tests/test_handbook_content.py tests/test_pdf_build.py
git commit -m "docs: align handbook code with R pipeline"
```

### Task 4: Rebuild and Verify the Corrected PDF

**Files:**
- Modify: `output/pdf/STAT3888_自行车盗窃时空基函数回归_完整项目手册.pdf`
- Modify: `tests/test_pdf_quality.py`

**Interfaces:**
- Consumes: corrected handbook content and verified R outputs.
- Produces: stable final PDF with executable and explanatory code visibly separated.

- [ ] **Step 1: Build the PDF**

Run:

```bash
/Users/liumingyuan/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3 handbook/build_pdf.py
```

Expected: the final PDF is written successfully.

- [ ] **Step 2: Run all tests**

Run:

```bash
Rscript -e 'testthat::test_dir("tests/testthat")'
/Users/liumingyuan/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3 -m pytest tests -q
```

Expected: zero failures.

- [ ] **Step 3: Verify extracted PDF text**

Require all 15 steps, executable labels, non-executable internal labels, the resolved path explanation, exact object names, and the four model metrics.

- [ ] **Step 4: Render and inspect every page**

Run:

```bash
zsh scripts/verify_pdf.sh
```

Require rendered page count to equal PDF page count. Inspect all contact sheets and full-resolution code-heavy pages for clipping, overlap, black squares, or ambiguous block labels.

- [ ] **Step 5: Open with WPS Office**

Run:

```bash
open -a /Applications/wpsoffice.app output/pdf/STAT3888_自行车盗窃时空基函数回归_完整项目手册.pdf
```

- [ ] **Step 6: Commit**

```bash
git add tests/test_pdf_quality.py output/pdf/STAT3888_自行车盗窃时空基函数回归_完整项目手册.pdf
git commit -m "docs: rebuild reproducible STAT3888 handbook"
```
