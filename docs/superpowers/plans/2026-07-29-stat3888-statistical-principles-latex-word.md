# STAT3888 Statistical Principles LaTeX Word Guide Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a standalone Chinese Word guide that explains the Toronto bicycle-theft project's statistical principles using editable Word equations and matching LaTeX source.

**Architecture:** A focused Python builder will define verified project facts, equation specifications, document styles, OMML equation conversion, and section content. A separate test module will verify formula coverage, LaTeX preservation, project-number accuracy, and DOCX package structure. The final workflow renders every page, visually inspects the PNGs, runs structural audits, and opens the DOCX in WPS Office.

**Tech Stack:** Bundled Python 3, `python-docx`, `lxml`, `latex2mathml` when available, Word OMML, bundled LibreOffice renderer, WPS Office.

## Global Constraints

- Output is a standalone editable Microsoft Word document.
- Chinese explanations retain English statistical terminology.
- Every important formula has both an editable Word equation and copyable LaTeX source.
- Formula content must match `R/03_model.R`.
- Use the `compact_reference_guide` design preset.
- Final filename is `STAT3888_Project_Statistical_Principles_LaTeX_Guide.docx`.
- Final delivery must pass package, formula, table, accessibility, render, and WPS checks.

---

### Task 1: Equation Conversion and Formula Tests

**Files:**
- Create: `tmp/stat3888-statistics-guide/equations.py`
- Create: `tmp/stat3888-statistics-guide/test_equations.py`

**Interfaces:**
- Consumes: LaTeX formula strings from the document builder.
- Produces: `latex_to_omml(latex: str) -> OxmlElement` and `append_equation(paragraph, latex: str) -> None`.

- [ ] **Step 1: Write failing conversion tests**

```python
def test_latex_to_omml_contains_office_math():
    node = latex_to_omml(r"\mathrm{MAE}=\frac{1}{n}\sum_{i=1}^{n}|y_i-\hat{y}_i|")
    assert node.tag.endswith("oMathPara")

def test_all_required_formula_commands_are_preserved():
    latex = REQUIRED_FORMULAS["ridge"]
    for token in (r"\lambda", r"\sum", r"\beta"):
        assert token in latex
```

- [ ] **Step 2: Run tests and confirm the conversion function is missing**

Run:

```bash
/Users/liumingyuan/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3 -m pytest tmp/stat3888-statistics-guide/test_equations.py -v
```

Expected: failure because `equations.py` does not yet provide the conversion functions.

- [ ] **Step 3: Implement deterministic LaTeX-to-OMML conversion**

Use `latex2mathml.converter.convert()` to create MathML, then apply the bundled
Microsoft `MML2OMML.XSL` transform with `lxml.etree.XSLT`. Wrap the resulting
`m:oMath` node in `m:oMathPara`. Reject empty input and preserve the original
LaTeX string separately for the source block.

- [ ] **Step 4: Run conversion tests**

Expected: all equation tests pass.

### Task 2: Build the Standalone Statistical Guide

**Files:**
- Create: `tmp/stat3888-statistics-guide/build_statistical_guide.py`
- Create: `tmp/stat3888-statistics-guide/test_content.py`
- Create: `deliverables/STAT3888_Toronto_Bicycle_Theft_Presentation/STAT3888_Project_Statistical_Principles_LaTeX_Guide.docx`

**Interfaces:**
- Consumes: `append_equation()`, verified project CSV outputs, and `R/03_model.R`.
- Produces: a DOCX containing the four planned parts and all required formula pairs.

- [ ] **Step 1: Write content tests**

The tests must open the generated DOCX and assert that it contains the headings
`时空数据结构`, `基函数回归`, `估计、验证与评价`, and `统计解释边界`;
the verified values `31,833`, `16,800`, `0.0001`, `2.048`, and `0.757`; and
LaTeX blocks for moving average, IQR, square-root colour transform, log response,
B-spline expansion, Fourier terms, Gaussian RBF, complete regression equation,
OLS, Ridge, back-transformation, residuals, MAE, RMSE, and R-squared.

- [ ] **Step 2: Run the content tests and confirm the document is absent**

Expected: failure because the final DOCX has not been built.

- [ ] **Step 3: Implement the document builder**

Apply US Letter portrait geometry, one-inch margins, compact-reference styles,
an editorial first-page header, numbered headings, shaded equation panels,
monospace LaTeX blocks, explicit-width comparison tables, a running header, and
page-number footer. Write beginner-oriented Chinese explanations that connect
each formula to the exact R implementation and project result.

- [ ] **Step 4: Generate the DOCX and run content tests**

Expected: the builder writes the final DOCX and all content tests pass.

### Task 3: Structural and Visual Verification

**Files:**
- Read: `deliverables/STAT3888_Toronto_Bicycle_Theft_Presentation/STAT3888_Project_Statistical_Principles_LaTeX_Guide.docx`
- Create only in QA directory: `tmp/stat3888-statistics-guide/rendered/page-*.png`

**Interfaces:**
- Consumes: the generated DOCX.
- Produces: verified final document and internal rendered evidence.

- [ ] **Step 1: Run package and table audits**

```bash
unzip -t deliverables/STAT3888_Toronto_Bicycle_Theft_Presentation/STAT3888_Project_Statistical_Principles_LaTeX_Guide.docx
python scripts/table_geometry.py deliverables/STAT3888_Toronto_Bicycle_Theft_Presentation/STAT3888_Project_Statistical_Principles_LaTeX_Guide.docx
```

Expected: no ZIP errors and all table widths agree.

- [ ] **Step 2: Run the accessibility audit**

Expected: zero high- and medium-severity findings.

- [ ] **Step 3: Render the DOCX to page PNGs**

Use the bundled `render_docx.py` with a writable `TMPDIR` and `--emit_pdf`.

- [ ] **Step 4: Inspect every rendered page**

Confirm that all equations are visible, all LaTeX backslashes remain intact,
Chinese text has no missing-glyph boxes, tables do not clip, no heading is
orphaned, and no empty page exists.

- [ ] **Step 5: Fix and repeat until the render is clean**

Adjust equation font, spacing, table width, page breaks, or paragraph keeping in
the builder; regenerate and rerender after every layout-sensitive change.

- [ ] **Step 6: Open the final DOCX in WPS Office**

```bash
open -a /Applications/wpsoffice.app deliverables/STAT3888_Toronto_Bicycle_Theft_Presentation/STAT3888_Project_Statistical_Principles_LaTeX_Guide.docx
```

Expected: the standalone guide opens with readable equations and intact LaTeX source.
