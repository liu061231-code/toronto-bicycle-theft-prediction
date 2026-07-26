# STAT3888 Handbook Core Path Expansion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Expand the existing STAT3888 PDF into a compact beginner-facing lab manual whose core path explains what to do, why each R command is entered, what it produces, and how to verify and troubleshoot it.

**Architecture:** Keep the verified R analysis pipeline and numerical results unchanged. Add structured teaching content to the handbook source, introduce compact reusable block styles for purpose/code/explanation/check/troubleshooting, then rebuild and validate the PDF through content tests, text extraction, full-page rendering, and WPS Office preview.

**Tech Stack:** Python 3, ReportLab, pytest, pypdf, Poppler, R 4.6.1, testthat, WPS Office.

## Global Constraints

- Keep the selected dataset and method as `bicycle.csv`, Task 1, and Task 4.
- Explain from a learner background of higher algebra and probability only.
- Use “core code line by line, supporting code by block”.
- Keep a compact single-column layout with no oversized gaps.
- Do not change verified model results unless the underlying analysis is intentionally rerun and produces different evidence.
- Preserve the final filename `output/pdf/STAT3888_自行车盗窃时空基函数回归_完整项目手册.pdf`.
- Inspect every rendered page before delivery.

---

### Task 1: Add Testable Teaching-Path Requirements

**Files:**
- Modify: `tests/test_handbook.py`
- Modify: `handbook/content.py`

**Interfaces:**
- Consumes: `handbook.content.CHAPTERS`, the structured handbook chapter list.
- Produces: Core-path chapters containing purpose, reason, code, explanation, expected result, check, troubleshooting, and rubric linkage.

- [ ] **Step 1: Write failing content tests**

Add assertions that extracted handbook content contains all 15 core steps and the required teaching labels:

```python
required_labels = [
    "这一步解决什么问题", "为什么现在运行", "输入对象",
    "逐行解释", "运行后应该看到", "检查命令", "常见错误", "评分连接",
]
for label in required_labels:
    assert label in handbook_text
```

Add assertions for beginner explanations of `<-`, `readr::`, `show_col_types`, pipes, `mutate`, `count`, `complete`, `ggplot`, `filter`, `model.matrix`, `lm.fit`, `glmnet`, MAE, RMSE, and R².

- [ ] **Step 2: Run the focused test and verify failure**

Run:

```bash
/Users/liumingyuan/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3 -m pytest tests/test_handbook.py -q
```

Expected: failure because the current core route does not contain the full teaching labels and command explanations.

- [ ] **Step 3: Add structured teaching blocks**

Extend `handbook/content.py` with compact blocks for every core step. Each block must name the input object, show executable R code, explain core lines, state expected dimensions or outputs, provide a check command, and describe a realistic error and repair.

- [ ] **Step 4: Run the focused test**

Run the same pytest command.

Expected: all tests in `tests/test_handbook.py` pass.

- [ ] **Step 5: Commit**

```bash
git add tests/test_handbook.py handbook/content.py
git commit -m "docs: expand STAT3888 core analysis path"
```

### Task 2: Implement Compact Teaching Layout

**Files:**
- Modify: `handbook/styles.py`
- Modify: `handbook/components.py`
- Modify: `handbook/build_pdf.py`
- Modify: `tests/test_handbook.py`

**Interfaces:**
- Consumes: structured teaching blocks from `handbook/content.py`.
- Produces: ReportLab flowables with compact spacing and visually distinct purpose, explanation, check, and troubleshooting sections.

- [ ] **Step 1: Add layout assertions**

Add tests that the PDF builder exposes compact styles and that paragraph spacings remain within the intended range:

```python
styles = build_styles()
assert styles["BodyText"].spaceAfter <= 6
assert styles["Code"].spaceAfter <= 6
assert styles["StepLabel"].spaceBefore <= 6
```

- [ ] **Step 2: Verify the layout test fails**

Run:

```bash
/Users/liumingyuan/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3 -m pytest tests/test_handbook.py -q
```

Expected: failure because `StepLabel` and the compact teaching block styles do not yet exist.

- [ ] **Step 3: Implement compact styles and block rendering**

Create styles with restrained `spaceBefore` and `spaceAfter`, compact table padding, readable 8–9 point code, and colored labels. Render teaching blocks without forcing whole steps onto new pages.

- [ ] **Step 4: Run the layout tests**

Run the focused pytest command.

Expected: pass.

- [ ] **Step 5: Commit**

```bash
git add handbook/styles.py handbook/components.py handbook/build_pdf.py tests/test_handbook.py
git commit -m "style: compact STAT3888 teaching layout"
```

### Task 3: Rebuild and Verify the Expanded PDF

**Files:**
- Modify: `output/pdf/STAT3888_自行车盗窃时空基函数回归_完整项目手册.pdf`
- Modify: `tests/test_handbook.py`

**Interfaces:**
- Consumes: handbook content, styles, components, figures, and verified analysis CSVs.
- Produces: final compact instructional PDF.

- [ ] **Step 1: Rebuild the PDF**

Run:

```bash
/Users/liumingyuan/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3 handbook/build_pdf.py
```

Expected: the stable final PDF path is written successfully.

- [ ] **Step 2: Run all automated tests**

Run:

```bash
Rscript -e 'testthat::test_dir("tests/testthat")'
/Users/liumingyuan/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3 -m pytest tests -q
```

Expected: R reports 26 passes and Python reports no failures.

- [ ] **Step 3: Extract and validate PDF text**

Use `pypdf` to require the 15-step core route, the teaching labels, model metrics, and Task 1–4 explanations in the generated PDF.

- [ ] **Step 4: Render every page**

Run:

```bash
zsh scripts/verify_pdf.sh
```

Expected: one PNG per PDF page with no Poppler errors.

- [ ] **Step 5: Inspect all pages visually**

Create contact sheets and inspect every page at readable scale. Confirm compact spacing, readable code, no clipping, no overlapping Chinese glyphs, no black squares, consistent headers and footers, and sensible page breaks.

- [ ] **Step 6: Preview with WPS Office**

Run:

```bash
open -a /Applications/wpsoffice.app output/pdf/STAT3888_自行车盗窃时空基函数回归_完整项目手册.pdf
```

Expected: WPS opens the revised PDF.

- [ ] **Step 7: Commit**

```bash
git add output/pdf/STAT3888_自行车盗窃时空基函数回归_完整项目手册.pdf tests/test_handbook.py
git commit -m "docs: rebuild expanded STAT3888 handbook"
```
