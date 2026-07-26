# STAT3888 Teaching Project Handbook Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and verify a 25–35 page Chinese teaching handbook PDF that explains every project task, teaches modern spatiotemporal basis-function regression from the user's algebra and probability background, and provides a reproducible R workflow on the real bicycle dataset.

**Architecture:** A tested R pipeline produces audited monthly panel data, Task 1 visualizations, basis-function models, metrics, and diagnostic figures. A separate ReportLab builder consumes those verified artifacts and structured handbook content to create the PDF, which is then checked by text extraction, page rendering, and WPS Office preview.

**Tech Stack:** R 4.6.1, tidyverse, lubridate, ggplot2, splines, glmnet, mgcv, sf, testthat, Python 3, ReportLab, pypdf, pdfplumber, Poppler, WPS Office.

## Global Constraints

- Use `/Users/liumingyuan/Downloads/four_dataset/bicycle.csv` as the source dataset and never modify it.
- Keep the project mainline to Task 1 plus Task 4; explain Task 2 and Task 3 fully but do not present them as completed electives.
- Derive month and quarter from `date`; do not trust the supplied `quarter` column.
- Preserve potentially repeated theft events because the dataset has no incident identifier; disclose this limitation.
- Use a training period of 2014–2021, validation period of 2022, and final test period of 2023.
- Never randomly split rows across time for the primary evaluation.
- Do not report any model score or conclusion until it has been generated from the real data.
- The handbook must explain each formula through symbols, dimensions, intuition, R-code correspondence, assumptions, and failure modes.
- Use a Chinese-capable local font and render every final PDF page for inspection.
- Preview the final PDF with `/Applications/wpsoffice.app`; do not use LibreOffice.
- Final PDF path: `output/pdf/STAT3888_自行车盗窃时空基函数回归_完整项目手册.pdf`.

---

### Task 1: Reproducible Project Skeleton and Dependency Check

**Files:**
- Create: `R/config.R`
- Create: `R/run_all.R`
- Create: `tests/testthat.R`
- Create: `tests/testthat/test-config.R`
- Create: `output/analysis/.gitkeep`
- Create: `output/figures/.gitkeep`
- Create: `output/pdf/.gitkeep`
- Create: `tmp/pdfs/.gitkeep`

**Interfaces:**
- Consumes: source CSV at the global-constraint path.
- Produces: `project_paths()` returning a named list with `source_csv`, `analysis_dir`, `figure_dir`, `pdf_dir`, and `pdf_file`; `ensure_packages()` returning invisibly after dependency validation.

- [ ] **Step 1: Write the failing configuration test**

```r
source("R/config.R")

testthat::test_that("project paths are absolute and the source exists", {
  p <- project_paths()
  testthat::expect_true(file.exists(p$source_csv))
  testthat::expect_true(startsWith(p$source_csv, "/"))
  testthat::expect_match(p$pdf_file, "STAT3888_自行车盗窃时空基函数回归_完整项目手册.pdf$")
})
```

- [ ] **Step 2: Run the test and verify it fails**

Run:

```bash
Rscript -e 'testthat::test_file("tests/testthat/test-config.R")'
```

Expected: FAIL because `R/config.R` or `project_paths()` does not exist.

- [ ] **Step 3: Implement configuration and dependency validation**

```r
project_paths <- function() {
  root <- normalizePath(".", mustWork = TRUE)
  list(
    root = root,
    source_csv = "/Users/liumingyuan/Downloads/four_dataset/bicycle.csv",
    analysis_dir = file.path(root, "output", "analysis"),
    figure_dir = file.path(root, "output", "figures"),
    pdf_dir = file.path(root, "output", "pdf"),
    pdf_file = file.path(
      root, "output", "pdf",
      "STAT3888_自行车盗窃时空基函数回归_完整项目手册.pdf"
    )
  )
}

ensure_packages <- function() {
  required <- c(
    "tidyverse", "lubridate", "ggplot2", "splines",
    "glmnet", "mgcv", "sf", "testthat"
  )
  missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing)) {
    stop(
      "Missing R packages: ", paste(missing, collapse = ", "),
      ". Install with install.packages(c(",
      paste(sprintf('"%s"', missing), collapse = ", "), "))."
    )
  }
  invisible(TRUE)
}
```

Create directories inside `R/run_all.R` before sourcing later pipeline scripts:

```r
source("R/config.R")
p <- project_paths()
dir.create(p$analysis_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(p$figure_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(p$pdf_dir, recursive = TRUE, showWarnings = FALSE)
ensure_packages()
```

- [ ] **Step 4: Install only the missing required package**

Run:

```bash
Rscript -e 'if (!requireNamespace("glmnet", quietly=TRUE)) install.packages("glmnet", repos="https://cloud.r-project.org")'
```

Expected: `glmnet` is installed and `Rscript -e 'library(glmnet)'` exits 0.

- [ ] **Step 5: Run the configuration test**

Run:

```bash
Rscript -e 'testthat::test_file("tests/testthat/test-config.R")'
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add R tests output tmp
git commit -m "build: scaffold reproducible STAT3888 analysis"
```

---

### Task 2: Data Audit and Monthly Spatiotemporal Panel

**Files:**
- Create: `R/01_prepare_data.R`
- Create: `tests/testthat/test-prepare-data.R`
- Modify: `R/run_all.R`
- Produce: `output/analysis/data_audit.csv`
- Produce: `output/analysis/bicycle_monthly_panel.csv`
- Produce: `output/analysis/neighborhood_coordinates.csv`

**Interfaces:**
- Consumes: `project_paths()` and raw `bicycle.csv`.
- Produces: `read_bicycle(path)`, `audit_bicycle(raw)`, and `make_monthly_panel(raw)`.
- `make_monthly_panel()` returns a list with `panel` and `coordinates`; `panel` contains `month`, `neighborhood`, `theft_count`, `lon`, `lat`, `time_index`, `month_of_year`, and `year`.

- [ ] **Step 1: Write failing data tests**

```r
source("R/config.R")
source("R/01_prepare_data.R")
p <- project_paths()
raw <- read_bicycle(p$source_csv)
result <- make_monthly_panel(raw)

testthat::test_that("raw data has the documented grain and range", {
  testthat::expect_equal(nrow(raw), 31833)
  testthat::expect_equal(length(unique(raw$neighborhood)), 140)
  testthat::expect_equal(range(raw$date), as.Date(c("2014-01-01", "2023-12-31")))
})

testthat::test_that("monthly panel is complete", {
  panel <- result$panel
  testthat::expect_equal(nrow(panel), 140 * 120)
  testthat::expect_equal(length(unique(panel$month)), 120)
  testthat::expect_equal(length(unique(panel$neighborhood)), 140)
  testthat::expect_false(anyNA(panel$theft_count))
  testthat::expect_true(all(panel$theft_count >= 0))
})

testthat::test_that("derived quarters expose source-field mismatch", {
  audit <- audit_bicycle(raw)
  mismatch <- audit$value[audit$metric == "quarter_mismatch_rows"]
  testthat::expect_equal(mismatch, 15751)
})
```

- [ ] **Step 2: Run the tests and verify failure**

Run:

```bash
Rscript -e 'testthat::test_file("tests/testthat/test-prepare-data.R")'
```

Expected: FAIL because `R/01_prepare_data.R` does not exist.

- [ ] **Step 3: Implement strict import and audit**

```r
read_bicycle <- function(path) {
  x <- readr::read_csv(path, show_col_types = FALSE)
  required <- c(
    "date", "quarter", "day_of_week", "neighborhood",
    "bike_cost", "location", "long", "lat"
  )
  stopifnot(all(required %in% names(x)))
  x |>
    dplyr::mutate(
      date = as.Date(date),
      derived_quarter = paste0(
        lubridate::year(date), "Q", lubridate::quarter(date)
      ),
      supplied_quarter_date = as.Date(quarter),
      supplied_quarter = paste0(
        lubridate::year(supplied_quarter_date), "Q",
        lubridate::quarter(supplied_quarter_date)
      )
    )
}

audit_bicycle <- function(raw) {
  tibble::tibble(
    metric = c(
      "rows", "columns", "missing_cells", "exact_duplicate_rows",
      "neighborhoods", "unique_dates", "quarter_mismatch_rows",
      "zero_or_negative_bike_cost", "bike_cost_over_10000"
    ),
    value = c(
      nrow(raw), ncol(raw), sum(is.na(raw)),
      sum(duplicated(raw[, c(
        "date", "quarter", "day_of_week", "neighborhood",
        "bike_cost", "location", "long", "lat"
      )])),
      dplyr::n_distinct(raw$neighborhood),
      dplyr::n_distinct(raw$date),
      sum(raw$derived_quarter != raw$supplied_quarter),
      sum(raw$bike_cost <= 0),
      sum(raw$bike_cost > 10000)
    )
  )
}
```

- [ ] **Step 4: Implement complete monthly panel construction**

```r
make_monthly_panel <- function(raw) {
  coordinates <- raw |>
    dplyr::group_by(neighborhood) |>
    dplyr::summarise(
      lon = stats::median(long),
      lat = stats::median(lat),
      .groups = "drop"
    )

  months <- seq(as.Date("2014-01-01"), as.Date("2023-12-01"), by = "month")
  panel <- raw |>
    dplyr::mutate(month = lubridate::floor_date(date, "month")) |>
    dplyr::count(neighborhood, month, name = "theft_count") |>
    tidyr::complete(
      neighborhood = unique(raw$neighborhood),
      month = months,
      fill = list(theft_count = 0L)
    ) |>
    dplyr::left_join(coordinates, by = "neighborhood") |>
    dplyr::arrange(month, neighborhood) |>
    dplyr::mutate(
      time_index = as.integer((lubridate::year(month) - 2014) * 12 +
        lubridate::month(month)),
      month_of_year = lubridate::month(month),
      year = lubridate::year(month)
    )
  list(panel = panel, coordinates = coordinates)
}
```

- [ ] **Step 5: Export audit and panel**

Append to `R/run_all.R`:

```r
source("R/01_prepare_data.R")
raw <- read_bicycle(p$source_csv)
prepared <- make_monthly_panel(raw)
readr::write_csv(audit_bicycle(raw), file.path(p$analysis_dir, "data_audit.csv"))
readr::write_csv(prepared$panel, file.path(p$analysis_dir, "bicycle_monthly_panel.csv"))
readr::write_csv(
  prepared$coordinates,
  file.path(p$analysis_dir, "neighborhood_coordinates.csv")
)
```

- [ ] **Step 6: Run tests and pipeline**

Run:

```bash
Rscript -e 'testthat::test_file("tests/testthat/test-prepare-data.R")'
Rscript R/run_all.R
```

Expected: tests PASS; three non-empty CSV files appear in `output/analysis/`.

- [ ] **Step 7: Commit**

```bash
git add R tests output/analysis
git commit -m "feat: audit bicycle data and build monthly panel"
```

---

### Task 3: Task 1 Spatiotemporal Visualizations

**Files:**
- Create: `R/02_visualize.R`
- Create: `tests/testthat/test-visualize.R`
- Modify: `R/run_all.R`
- Produce: `output/figures/01_monthly_trend.png`
- Produce: `output/figures/02_seasonality.png`
- Produce: `output/figures/03_spatial_hotspots.png`
- Produce: `output/figures/04_spacetime_heatmap.png`

**Interfaces:**
- Consumes: `prepared$panel`.
- Produces: `make_task1_plots(panel, figure_dir)` returning a named character vector of four absolute PNG paths.

- [ ] **Step 1: Write the failing figure test**

```r
source("R/config.R")
source("R/02_visualize.R")
p <- project_paths()
panel <- readr::read_csv(
  file.path(p$analysis_dir, "bicycle_monthly_panel.csv"),
  show_col_types = FALSE
)
paths <- make_task1_plots(panel, p$figure_dir)

testthat::test_that("all Task 1 figures are generated", {
  testthat::expect_setequal(
    names(paths), c("trend", "seasonality", "hotspots", "heatmap")
  )
  testthat::expect_true(all(file.exists(paths)))
  testthat::expect_true(all(file.info(paths)$size > 20000))
})
```

- [ ] **Step 2: Run the test and verify failure**

Run:

```bash
Rscript -e 'testthat::test_file("tests/testthat/test-visualize.R")'
```

Expected: FAIL because `make_task1_plots()` does not exist.

- [ ] **Step 3: Implement the plotting interface**

Use `ggplot2` with `theme_minimal(base_family = "Arial Unicode MS")`, a colorblind-safe viridis scale, explicit units, date ranges, and captions. The function must:

```r
make_task1_plots <- function(panel, figure_dir) {
  dir.create(figure_dir, recursive = TRUE, showWarnings = FALSE)
  monthly <- panel |>
    dplyr::group_by(month) |>
    dplyr::summarise(thefts = sum(theft_count), .groups = "drop")
  seasonal <- panel |>
    dplyr::group_by(year, month_of_year) |>
    dplyr::summarise(thefts = sum(theft_count), .groups = "drop")
  hotspots <- panel |>
    dplyr::group_by(neighborhood, lon, lat) |>
    dplyr::summarise(mean_monthly = mean(theft_count), .groups = "drop")
  top_names <- hotspots |>
    dplyr::slice_max(mean_monthly, n = 25) |>
    dplyr::pull(neighborhood)
  heat <- panel |>
    dplyr::filter(neighborhood %in% top_names)

  paths <- file.path(
    figure_dir,
    c(
      "01_monthly_trend.png", "02_seasonality.png",
      "03_spatial_hotspots.png", "04_spacetime_heatmap.png"
    )
  )
  # Build four ggplot objects named p1 through p4, then save:
  purrr::walk2(
    list(p1, p2, p3, p4), paths,
    ~ggplot2::ggsave(.y, .x, width = 9, height = 5.4, dpi = 180, bg = "white")
  )
  stats::setNames(normalizePath(paths), c("trend", "seasonality", "hotspots", "heatmap"))
}
```

The actual implementation must define `p1`–`p4` completely:

- `p1`: total monthly thefts over time with a 12-month rolling visual trend;
- `p2`: month-of-year seasonal boxplots with January–December labels;
- `p3`: longitude/latitude bubbles sized and colored by mean monthly theft count;
- `p4`: top-25 neighborhood × month heatmap.

- [ ] **Step 4: Add the visualization call to the pipeline**

```r
source("R/02_visualize.R")
task1_paths <- make_task1_plots(prepared$panel, p$figure_dir)
stopifnot(all(file.exists(task1_paths)))
```

- [ ] **Step 5: Run tests and inspect the four PNGs**

Run:

```bash
Rscript -e 'testthat::test_file("tests/testthat/test-visualize.R")'
Rscript R/run_all.R
```

Expected: PASS and four legible PNG files. Inspect each with the local image viewer; reject clipped labels, inconsistent scales, missing legends, or red-green palettes.

- [ ] **Step 6: Commit**

```bash
git add R tests output/figures
git commit -m "feat: add Task 1 spatiotemporal visualizations"
```

---

### Task 4: Basis Functions, Regularized Model, and Leakage-Safe Validation

**Files:**
- Create: `R/03_model.R`
- Create: `tests/testthat/test-model.R`
- Modify: `R/run_all.R`
- Produce: `output/analysis/model_metrics.csv`
- Produce: `output/analysis/test_predictions.csv`
- Produce: `output/analysis/basis_metadata.csv`
- Produce: `output/figures/05_basis_functions.png`
- Produce: `output/figures/06_model_comparison.png`
- Produce: `output/figures/07_observed_vs_predicted.png`
- Produce: `output/figures/08_residual_map.png`

**Interfaces:**
- Consumes: complete monthly panel.
- Produces:
  - `split_panel(panel)` with `train`, `validation`, `test`;
  - `make_basis_recipe(train)` containing fixed knots, centers, and scales;
  - `make_design_matrix(data, recipe)` with identical columns for every split;
  - `fit_models(splits, recipe)` containing baselines, ordinary basis model, ridge model, predictions, and metrics.

- [ ] **Step 1: Write failing split and design-matrix tests**

```r
source("R/03_model.R")
panel <- readr::read_csv(
  "output/analysis/bicycle_monthly_panel.csv",
  show_col_types = FALSE
)
splits <- split_panel(panel)
recipe <- make_basis_recipe(splits$train)
x_train <- make_design_matrix(splits$train, recipe)
x_test <- make_design_matrix(splits$test, recipe)

testthat::test_that("time split has no future leakage", {
  testthat::expect_lte(max(splits$train$year), 2021)
  testthat::expect_equal(unique(splits$validation$year), 2022)
  testthat::expect_equal(unique(splits$test$year), 2023)
})

testthat::test_that("basis columns are stable across splits", {
  testthat::expect_identical(colnames(x_train), colnames(x_test))
  testthat::expect_false(anyNA(x_train))
  testthat::expect_false(anyNA(x_test))
})
```

- [ ] **Step 2: Run tests and verify failure**

Run:

```bash
Rscript -e 'testthat::test_file("tests/testthat/test-model.R")'
```

Expected: FAIL because the model functions do not exist.

- [ ] **Step 3: Implement time split and training-only recipe**

```r
split_panel <- function(panel) {
  list(
    train = dplyr::filter(panel, year <= 2021),
    validation = dplyr::filter(panel, year == 2022),
    test = dplyr::filter(panel, year == 2023)
  )
}

make_basis_recipe <- function(train) {
  lon_center <- mean(train$lon)
  lat_center <- mean(train$lat)
  scale_value <- max(stats::sd(train$lon), stats::sd(train$lat))
  centers <- train |>
    dplyr::distinct(neighborhood, lon, lat) |>
    dplyr::arrange(neighborhood) |>
    dplyr::slice(round(seq(1, dplyr::n(), length.out = 16)))
  list(
    time_boundary = range(train$time_index),
    time_knots = as.numeric(stats::quantile(
      train$time_index, c(0.2, 0.4, 0.6, 0.8)
    )),
    lon_center = lon_center,
    lat_center = lat_center,
    spatial_scale = scale_value,
    rbf_centers = centers[, c("lon", "lat")],
    rbf_sigma = 0.8
  )
}
```

- [ ] **Step 4: Implement a fixed basis design matrix**

```r
make_design_matrix <- function(data, recipe) {
  time_basis <- splines::bs(
    data$time_index,
    knots = recipe$time_knots,
    Boundary.knots = recipe$time_boundary,
    degree = 3,
    intercept = FALSE,
    warn.outside = FALSE
  )
  seasonal <- cbind(
    sin1 = sin(2 * pi * data$month_of_year / 12),
    cos1 = cos(2 * pi * data$month_of_year / 12),
    sin2 = sin(4 * pi * data$month_of_year / 12),
    cos2 = cos(4 * pi * data$month_of_year / 12)
  )
  lon <- (data$lon - recipe$lon_center) / recipe$spatial_scale
  lat <- (data$lat - recipe$lat_center) / recipe$spatial_scale
  centers <- as.data.frame(recipe$rbf_centers)
  centers$lon <- (centers$lon - recipe$lon_center) / recipe$spatial_scale
  centers$lat <- (centers$lat - recipe$lat_center) / recipe$spatial_scale
  rbf <- vapply(
    seq_len(nrow(centers)),
    function(i) exp(
      -((lon - centers$lon[i])^2 + (lat - centers$lat[i])^2) /
        (2 * recipe$rbf_sigma^2)
    ),
    numeric(nrow(data))
  )
  x <- cbind(time_basis, seasonal, rbf)
  colnames(x) <- c(
    paste0("time_bs_", seq_len(ncol(time_basis))),
    colnames(seasonal),
    paste0("space_rbf_", seq_len(ncol(rbf)))
  )
  x
}
```

- [ ] **Step 5: Fit baselines, ordinary basis regression, and Ridge**

Implement:

```r
metric_frame <- function(actual, predicted, model, split) {
  tibble::tibble(
    model = model,
    split = split,
    MAE = mean(abs(actual - predicted)),
    RMSE = sqrt(mean((actual - predicted)^2)),
    R2 = 1 - sum((actual - predicted)^2) /
      sum((actual - mean(actual))^2)
  )
}
```

`fit_models()` must:

1. fit a global-mean baseline;
2. fit a neighborhood historical-mean baseline using training values only;
3. fit `lm(log1p(theft_count) ~ x_train)`;
4. choose Ridge `lambda` on 2022 validation RMSE from a fixed log-spaced grid;
5. refit the selected Ridge model on 2014–2022;
6. predict 2023 and apply `pmax(0, expm1(prediction))`;
7. return test predictions and a metric table for every model.

The lambda grid must be:

```r
lambda_grid <- exp(seq(log(1e-4), log(100), length.out = 100))
```

- [ ] **Step 6: Add validation-focused tests**

```r
fit <- fit_models(splits, recipe)

testthat::test_that("predictions are finite and non-negative", {
  testthat::expect_true(all(is.finite(fit$test_predictions$predicted)))
  testthat::expect_true(all(fit$test_predictions$predicted >= 0))
})

testthat::test_that("metrics include every planned baseline and model", {
  testthat::expect_setequal(
    fit$metrics$model,
    c("Global mean", "Neighborhood mean", "Basis OLS", "Basis Ridge")
  )
  testthat::expect_true(all(c("MAE", "RMSE", "R2") %in% names(fit$metrics)))
})
```

- [ ] **Step 7: Generate verified model figures**

Implement figure functions for:

- representative B-spline, Fourier, and RBF curves;
- model comparison dot plot with RMSE and MAE;
- observed versus predicted 2023 monthly totals;
- neighborhood residual map, where residual is observed minus predicted.

Every figure must use test data only when labeled as test performance.

- [ ] **Step 8: Run model tests and full pipeline**

Run:

```bash
Rscript -e 'testthat::test_file("tests/testthat/test-model.R")'
Rscript R/run_all.R
```

Expected: PASS; metrics and predictions contain no missing values; four model PNGs are non-empty.

- [ ] **Step 9: Commit**

```bash
git add R tests output/analysis output/figures
git commit -m "feat: add validated spatiotemporal basis regression"
```

---

### Task 5: Structured Pedagogical Content and Source Notes

**Files:**
- Create: `handbook/content.py`
- Create: `handbook/styles.py`
- Create: `handbook/sources.md`
- Create: `tests/test_handbook_content.py`

**Interfaces:**
- Consumes: original project requirements, approved design spec, local STAT3888 notes, verified analysis outputs, and official software documentation.
- Produces: `HANDBOOK_SECTIONS`, a list of section dictionaries with `title`, `level`, and `blocks`; `build_styles(font_regular, font_bold)`.

- [ ] **Step 1: Write failing content-coverage tests**

```python
from handbook.content import HANDBOOK_SECTIONS

def flattened_text():
    return "\n".join(
        section["title"] + "\n" +
        "\n".join(str(block) for block in section["blocks"])
        for section in HANDBOOK_SECTIONS
    )

def test_all_four_tasks_are_explained():
    text = flattened_text()
    for phrase in [
        "Task 1：时空可视化",
        "Task 2：EOF",
        "Task 3：IDW",
        "Task 4：基函数线性回归",
    ]:
        assert phrase in text

def test_teaching_bridges_are_present():
    text = flattened_text()
    for phrase in [
        "高等代数", "概率论", "设计矩阵", "B-spline",
        "Fourier", "径向基函数", "Ridge", "数据泄漏",
    ]:
        assert phrase in text
```

- [ ] **Step 2: Run tests and verify failure**

Run:

```bash
'/Users/liumingyuan/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3' -m pytest tests/test_handbook_content.py -q
```

Expected: FAIL because `handbook/content.py` does not exist.

- [ ] **Step 3: Implement content structure**

Create `HANDBOOK_SECTIONS` with all approved chapters. Each method block must include:

```python
{
    "kind": "method",
    "problem": "...",
    "input_output": "...",
    "prior_knowledge": "...",
    "formula": "...",
    "dimensions": "...",
    "intuition": "...",
    "why_this_data": "...",
    "advantages": "...",
    "assumptions": "...",
    "failure_modes": "...",
    "r_code": "...",
    "trust_check": "...",
}
```

Task 1–4 must each use this full schema. Task 1 must additionally explain time-series plots, maps, facets, animation, and heatmaps. The chosen Task 4 must receive the deepest treatment; Task 2 and Task 3 must remain complete conceptual explanations without pretending they were executed.

- [ ] **Step 4: Implement Chinese document styles**

Register:

- regular: `/System/Library/Fonts/STHeiti Medium.ttc`;
- bold: `/System/Library/Fonts/STHeiti Medium.ttc`;
- code: `/System/Library/Fonts/Supplemental/Arial Unicode.ttf`.

`build_styles()` must define body, title, H1, H2, H3, callout, code, caption, table header, and footer styles with explicit leading and keep-with-next behavior.

- [ ] **Step 5: Record human-readable sources**

`handbook/sources.md` must list:

- local `project.pdf`;
- local `bicycle.csv`;
- the active STAT3888 notes used for algebra/probability/PCA/R/ggplot bridges;
- R `splines::bs` official documentation;
- `mgcv` smooth-term documentation;
- tidymodels time-resampling documentation;
- spatialsample spatial-block documentation.

Do not include internal tool reference tokens.

- [ ] **Step 6: Run content tests**

Run:

```bash
'/Users/liumingyuan/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3' -m pytest tests/test_handbook_content.py -q
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add handbook tests
git commit -m "docs: add pedagogical STAT3888 handbook content"
```

---

### Task 6: ReportLab PDF Builder

**Files:**
- Create: `handbook/build_pdf.py`
- Create: `handbook/components.py`
- Create: `tests/test_pdf_build.py`
- Produce: `output/pdf/STAT3888_自行车盗窃时空基函数回归_完整项目手册.pdf`

**Interfaces:**
- Consumes: `HANDBOOK_SECTIONS`, styles, source notes, R output CSVs, and eight PNG figures.
- Produces: `build_handbook(output_path: str) -> str`.

- [ ] **Step 1: Write the failing PDF test**

```python
from pathlib import Path
from pypdf import PdfReader
from handbook.build_pdf import build_handbook

OUTPUT = Path(
    "output/pdf/STAT3888_自行车盗窃时空基函数回归_完整项目手册.pdf"
)

def test_build_handbook_has_expected_pages_and_text():
    result = Path(build_handbook(str(OUTPUT)))
    assert result.exists()
    reader = PdfReader(str(result))
    assert 25 <= len(reader.pages) <= 35
    text = "\n".join(page.extract_text() or "" for page in reader.pages)
    for phrase in [
        "Task 1", "Task 2", "Task 3", "Task 4",
        "时空可视化", "基函数", "Ridge", "最终检查清单",
    ]:
        assert phrase in text
```

- [ ] **Step 2: Run the test and verify failure**

Run:

```bash
'/Users/liumingyuan/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3' -m pytest tests/test_pdf_build.py -q
```

Expected: FAIL because the PDF builder does not exist.

- [ ] **Step 3: Implement reusable PDF components**

`handbook/components.py` must provide:

```python
def paragraph(text, style_name, styles): ...
def callout(title, body, styles, color="#EAF2F8"): ...
def code_block(code, styles): ...
def figure(path, caption, max_width, max_height, styles): ...
def data_table(rows, widths, styles, repeat_rows=1): ...
def section_badge(level, styles): ...
def page_break(): ...
```

Every image function must preserve aspect ratio. Tables must repeat header rows and split only between rows.

- [ ] **Step 4: Implement document builder**

Use `BaseDocTemplate` with:

- A4 pages;
- 17 mm left/right margins;
- 16 mm top margin;
- 15 mm bottom margin;
- numbered footer;
- chapter name in header;
- table of contents;
- page breaks between major parts;
- `KeepTogether` only for small callouts, never entire multi-page sections.

The builder must insert:

1. cover;
2. how-to-use page;
3. project and scoring explanation;
4. Task 1–4 teaching chapters;
5. method-selection chapter;
6. algebra/probability bridge;
7. complete workflow;
8. verified figures and metrics;
9. four-slide presentation plan;
10. defense questions;
11. final checklist;
12. future learning path;
13. sources.

- [ ] **Step 5: Build and run automated PDF tests**

Run:

```bash
Rscript R/run_all.R
'/Users/liumingyuan/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3' -m pytest tests/test_pdf_build.py -q
```

Expected: PASS and a 25–35 page PDF.

- [ ] **Step 6: Commit**

```bash
git add handbook tests output/pdf
git commit -m "feat: build STAT3888 teaching handbook PDF"
```

---

### Task 7: PDF Rendering, Visual QA, and WPS Preview

**Files:**
- Create: `scripts/verify_pdf.sh`
- Create: `tests/test_pdf_quality.py`
- Produce: `tmp/pdfs/handbook_render/page-*.png`
- Modify only if defects are found: `handbook/build_pdf.py`, `handbook/components.py`, `handbook/content.py`

**Interfaces:**
- Consumes: final PDF.
- Produces: rendered page images and a passing quality test.

- [ ] **Step 1: Write quality checks**

```python
from pathlib import Path
import pdfplumber

PDF = Path("output/pdf/STAT3888_自行车盗窃时空基函数回归_完整项目手册.pdf")

def test_every_page_contains_visible_content():
    with pdfplumber.open(PDF) as doc:
        assert 25 <= len(doc.pages) <= 35
        for index, page in enumerate(doc.pages, 1):
            text = (page.extract_text() or "").strip()
            images = page.images
            assert text or images, f"page {index} is blank"

def test_no_internal_placeholders_or_tool_tokens():
    with pdfplumber.open(PDF) as doc:
        text = "\n".join(page.extract_text() or "" for page in doc.pages)
    forbidden = ["TBD", "TODO", "turn0search", "placeholder", "待补充"]
    for token in forbidden:
        assert token not in text
```

- [ ] **Step 2: Implement rendering script**

```bash
#!/bin/zsh
set -euo pipefail
pdf='output/pdf/STAT3888_自行车盗窃时空基函数回归_完整项目手册.pdf'
render_dir='tmp/pdfs/handbook_render'
mkdir -p "$render_dir"
find "$render_dir" -type f -name 'page-*.png' -delete
'/Users/liumingyuan/.cache/codex-runtimes/codex-primary-runtime/dependencies/native/poppler/bin/pdftoppm' \
  -png -r 130 "$pdf" "$render_dir/page"
```

- [ ] **Step 3: Run automated checks and render**

Run:

```bash
zsh scripts/verify_pdf.sh
'/Users/liumingyuan/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3' -m pytest tests/test_pdf_quality.py -q
```

Expected: PASS and one PNG per PDF page.

- [ ] **Step 4: Inspect all rendered pages**

Create contact sheets in batches of 6 pages for inspection. Check:

- no clipped Chinese text;
- no black-square glyphs;
- no code beyond margins;
- no broken tables;
- no orphaned headings;
- figures have readable axes and legends;
- page numbering is continuous;
- formulas and callouts are visually distinct;
- Task 1–4 explanations are easy to locate.

If any defect exists, patch the builder/content, rebuild, rerender, and repeat this step.

- [ ] **Step 5: Open final PDF with WPS Office**

Run:

```bash
open -a /Applications/wpsoffice.app \
  '/Users/liumingyuan/Documents/project of stat38888/output/pdf/STAT3888_自行车盗窃时空基函数回归_完整项目手册.pdf'
```

Expected: WPS opens the final PDF without conversion prompts or missing-font warnings.

- [ ] **Step 6: Run the full verification suite**

Run:

```bash
Rscript -e 'testthat::test_dir("tests/testthat")'
'/Users/liumingyuan/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3' -m pytest tests -q
git diff --check
```

Expected: all R and Python tests PASS; `git diff --check` produces no output.

- [ ] **Step 7: Commit final QA**

```bash
git add scripts tests handbook R output
git commit -m "test: verify STAT3888 handbook content and rendering"
```
