# STAT3888 Statistical Principles LaTeX Word Guide Design

**Date:** 2026-07-29  
**Output:** Standalone editable Microsoft Word document  
**Language:** Chinese explanations with English statistical terminology  
**Formula format:** Editable Word equations plus copyable LaTeX source

## 1. Purpose

Create a standalone teaching document that explains the statistical principles
used in the Toronto bicycle-theft project. The document must not depend on the
previous speech guide. Its main quality requirement is that every mathematical
expression remains readable in Microsoft Word and WPS Office without relying on
fragile Unicode mathematical symbols.

## 2. Audience and Teaching Approach

The reader is a statistics beginner who understands basic algebra and
probability but may not yet understand basis-function regression. Each section
will therefore use the sequence:

1. explain the practical question;
2. define the notation;
3. show the editable Word equation;
4. provide the exact LaTeX source;
5. connect the equation to the project's R implementation;
6. explain interpretation, assumptions, and limitations.

## 3. Formula Representation

Every important formula will appear twice:

- an editable Word equation encoded as Office Math Markup Language (OMML);
- a shaded monospace block containing the corresponding LaTeX source.

LaTeX source will use ASCII commands such as `\hat{y}`, `\beta`, `\sum`,
`\sqrt`, `\lambda`, and `\sigma`, rather than directly typed mathematical
Unicode glyphs. The Word equation is the reading version; the LaTeX block is
the portable and reusable source version.

## 4. Document Structure

### Part I - Data and Descriptive Spatiotemporal Statistics

1. Event records and the neighbourhood-month panel
2. Monthly and annual aggregation
3. Twelve-month trailing moving average
4. Boxplot components: median, quartiles, IQR, whiskers, and outliers
5. Spatial centroids and hotspot counts
6. Space-time heatmap and square-root colour transformation

### Part II - Basis-Function Regression

7. Why a straight-line time effect is insufficient
8. Response transformation using `log(1+y)`
9. Cubic B-spline time basis
10. Fourier seasonal basis
11. Gaussian radial basis functions for space
12. Neighbourhood indicator variables
13. Complete design matrix and regression equation

### Part III - Estimation, Validation, and Evaluation

14. Ordinary least squares objective and coefficient estimate
15. Ridge objective and the role of the penalty parameter
16. Chronological train-validation-test split
17. Back-transformation and Jensen bias
18. Residual definition and interpretation
19. MAE, RMSE, and test-set R-squared
20. Comparison with global-mean and neighbourhood-mean baselines

### Part IV - Project Results and Statistical Boundaries

21. Interpretation of the 2023 model metrics
22. Why OLS and Ridge perform similarly
23. Why the model underestimates summer peaks
24. Spatial and temporal residual dependence
25. Reported counts versus true risk and missing exposure
26. Duplicate-record sensitivity
27. Count-model, hierarchical, and dependence-aware extensions

## 5. Project-Specific Facts

The guide will use only results verified from the project files:

- 31,833 incident rows;
- 140 neighbourhoods;
- 120 months from 2014 through 2023;
- 16,800 completed neighbourhood-month cells;
- training: 2014-2021;
- validation: 2022;
- test: 2023;
- four internal time knots and seven spline columns;
- four Fourier seasonal columns;
- sixteen spatial RBF columns with sigma equal to 0.8;
- selected Ridge lambda equal to 0.0001;
- Basis OLS test MAE 1.008, RMSE 2.048, and R-squared 0.757;
- Basis Ridge test MAE 1.006, RMSE 2.060, and R-squared 0.754.

The document will clearly distinguish the OLS metrics highlighted in the
presentation from the Ridge predictions used in the prediction and residual
figures.

## 6. Visual Design

Use the `compact_reference_guide` document preset:

- US Letter portrait;
- one-inch margins;
- restrained blue and teal hierarchy;
- compact but readable paragraph rhythm;
- clearly separated equation panels;
- pale grey LaTeX source blocks;
- exact-width comparison tables;
- page numbers and a concise running header.

The first page will use an editorial reference-guide header rather than a
decorative cover, keeping the document practical and compact.

## 7. Verification

The final document must pass all of the following:

1. every formula has both an OMML equation and a LaTeX source block;
2. LaTeX source contains no accidental smart punctuation or missing backslashes;
3. formulas match the implementation in `R/03_model.R`;
4. Word package integrity check passes;
5. table geometry audit passes;
6. accessibility audit reports no high- or medium-severity findings;
7. the document is rendered to page PNGs and every page is visually inspected;
8. no missing-glyph boxes, clipping, overflow, or empty pages remain;
9. the final DOCX is opened in WPS Office for compatibility review.

## 8. Deliverable

The final file will be saved beside the existing presentation deliverables as:

`STAT3888_Project_Statistical_Principles_LaTeX_Guide.docx`

Only the final DOCX will be delivered. Rendered pages and temporary conversion
artifacts remain internal QA files.
