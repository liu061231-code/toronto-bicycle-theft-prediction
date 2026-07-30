# STAT3888 Five-Minute Speech Guide Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a verified Chinese five-minute speech script synchronized with the final four-slide STAT3888 deck, plus a beginner-friendly principles and viva guide in editable Word and PDF formats.

**Architecture:** Keep factual content in a dedicated Python content module and keep Word layout generation in a separate builder. Validate timings, model metrics, Task 1/Task 4 scope, and terminology before generating the document; then render the DOCX to page images and PDF for visual inspection.

**Tech Stack:** Bundled Python 3, `python-docx`, WordprocessingML helpers, bundled `render_docx.py`, `pytest`, WPS Office for final local preview.

## Global Constraints

- Use the final four-slide deck `deliverables/STAT3888_Toronto_Bicycle_Theft_Presentation/STAT3888_Toronto_Bicycle_Theft_Corrected_Embedded_Video.pptx`.
- Formal speech duration is five minutes and covers Task 1 plus Task 4 only.
- Explain concepts from high algebra and probability prerequisites; do not assume time-series, spatial-statistics, GIS, regression-regularization, or basis-function knowledge.
- Identify Basis OLS as the required Task 4 model and Basis Ridge as its stability-oriented extension.
- Use the verified 2023 test results: Basis OLS RMSE 2.05 and R² 0.757; Basis Ridge RMSE 2.06 and R² 0.754.
- Do not describe R² as prediction accuracy and do not interpret associations as causal effects.
- Keep detailed proofs and viva preparation outside the timed speech.
- Deliver both DOCX and PDF with blank name and student-ID fields.

## File Structure

- Create `tmp/stat3888-presentation/five_minute_speech_content.py`: authoritative speech, timings, principle explanations, metrics, and viva answers.
- Create `tmp/stat3888-presentation/build_five_minute_speech_guide.py`: compact-reference DOCX builder.
- Create `tmp/stat3888-presentation/test_five_minute_speech_guide.py`: content and artifact checks.
- Create `deliverables/STAT3888_Toronto_Bicycle_Theft_Presentation/STAT3888_五分钟演讲稿与原理解析.docx`: editable deliverable.
- Create `deliverables/STAT3888_Toronto_Bicycle_Theft_Presentation/STAT3888_五分钟演讲稿与原理解析.pdf`: printable deliverable.
- Create `tmp/stat3888-presentation/five-minute-guide-render/`: internal page-render QA output.

---

### Task 1: Lock the Evidence and Five-Minute Narrative

**Files:**
- Create: `tmp/stat3888-presentation/five_minute_speech_content.py`
- Create: `tmp/stat3888-presentation/test_five_minute_speech_guide.py`
- Read: `output/analysis/model_metrics.csv`
- Read: `R/03_model.R`

**Interfaces:**
- Produces: `PROJECT_FACTS: dict`, `SPEECH_SECTIONS: list[dict]`, `PRINCIPLE_SECTIONS: list[dict]`, and `VIVA_QA: list[dict]`.
- `SPEECH_SECTIONS` entries contain `slide`, `start_seconds`, `end_seconds`, `script`, `pointing_cues`, and `core_sentence`.
- `PRINCIPLE_SECTIONS` entries contain `title`, `intuition`, `formula`, `project_use`, and `why_suitable`.

- [ ] **Step 1: Write failing factual and scope tests**

```python
from five_minute_speech_content import PROJECT_FACTS, SPEECH_SECTIONS


def test_verified_metrics_and_scope():
    assert PROJECT_FACTS["basis_ols_rmse"] == 2.05
    assert PROJECT_FACTS["basis_ols_r2"] == 0.757
    assert PROJECT_FACTS["basis_ridge_rmse"] == 2.06
    assert PROJECT_FACTS["basis_ridge_r2"] == 0.754
    assert PROJECT_FACTS["required_tasks"] == ["Task 1", "Task 4"]


def test_speech_timing_and_slide_order():
    assert [item["slide"] for item in SPEECH_SECTIONS] == [1, 2, 3, 4]
    assert SPEECH_SECTIONS[0]["start_seconds"] == 0
    assert SPEECH_SECTIONS[-1]["end_seconds"] == 300
    assert all(
        left["end_seconds"] == right["start_seconds"]
        for left, right in zip(SPEECH_SECTIONS, SPEECH_SECTIONS[1:])
    )


def test_required_terminology():
    speech = " ".join(item["script"] for item in SPEECH_SECTIONS)
    assert "Basis OLS" in speech
    assert "Basis Ridge" in speech
    assert "准确率" not in speech
    assert "因果" in speech
```

- [ ] **Step 2: Run the focused tests and confirm the module is missing**

Run:

```bash
PYTHONPATH=tmp/stat3888-presentation \
/Users/liumingyuan/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3 \
-m pytest tmp/stat3888-presentation/test_five_minute_speech_guide.py -q
```

Expected: collection fails because `five_minute_speech_content` does not exist.

- [ ] **Step 3: Implement the content module**

Create the four timed sections using these fixed boundaries:

```python
SPEECH_SECTIONS = [
    {
        "slide": 1,
        "start_seconds": 0,
        "end_seconds": 70,
        "script": (
            "本项目研究多伦多2014到2023年的自行车盗窃记录。我把每条事件整理成"
            "140个社区按月的计数，从而同时观察时间变化和空间差异。左图显示全市"
            "月度总量具有重复的夏季高峰，但不同年份的峰值不同；右图把月份合并后，"
            "进一步确认温暖季节的典型水平更高。因此第一个发现是：盗窃既有长期变化，"
            "也有稳定的年度季节循环。"
        ),
        "pointing_cues": "先指左侧时间序列的多个夏季尖峰，再指右侧月份分布的上升与回落。",
        "core_sentence": "Toronto bicycle theft has a repeating warm-season cycle superimposed on long-run change.",
    },
    {
        "slide": 2,
        "start_seconds": 70,
        "end_seconds": 135,
        "script": (
            "第二页加入空间维度。中间的时空热力图每一行代表一个高盗窃社区，每一列"
            "代表月份；颜色越亮，说明当月报告数越高。多行在相近月份同时变亮，说明"
            "季节高峰具有全市共同性，但高值长期集中在少数社区。右上地图进一步显示"
            "热点主要位于downtown，右下动画让我们看到这些热点随时间增强或减弱，"
            "但总体空间排序相对稳定。这完成了Task 1的时空可视化要求。"
        ),
        "pointing_cues": "沿热力图横向指时间、纵向指社区，再指右侧downtown热点与动画。",
        "core_sentence": "Seasonal intensity changes, but the spatial concentration in downtown persists.",
    },
    {
        "slide": 3,
        "start_seconds": 135,
        "end_seconds": 245,
        "script": (
            "Task 4要求使用基函数建立线性回归。我的响应变量是每个社区每月的盗窃次数，"
            "先做log one plus y变换，降低少数极端高峰对拟合的支配。模型仍然是线性模型，"
            "但输入不再只有原始时间和经纬度：B-spline把长期变化拆成几个平滑形状，"
            "sine和cosine表达十二个月的周期，RBF把某个社区与空间中心的距离转换成"
            "邻近程度。设计矩阵中的每一列就是一个这样的基函数。数据严格按时间切分："
            "2014到2021训练，2022选择Ridge惩罚，2023只用于最终测试。Basis OLS是"
            "Task 4的标准实现；Basis Ridge在同一设计矩阵上加入系数平方惩罚，以降低"
            "相关基函数造成的不稳定。测试中OLS的RMSE为2.05、R平方为0.757；Ridge"
            "分别为2.06和0.754，预测能力几乎相同。"
        ),
        "pointing_cues": "先指左侧三类基函数，再指右侧模型比较，最后指训练、验证、测试年份。",
        "core_sentence": "Basis functions keep the model linear while allowing nonlinear time, season, and space patterns.",
    },
    {
        "slide": 4,
        "start_seconds": 245,
        "end_seconds": 300,
        "script": (
            "最后检查预测与残差。模型能够重现年度起伏并明显优于全市均值和社区均值"
            "基线，但最高的夏季峰值仍被低估，说明平方误差下的平滑模型难以完全捕捉"
            "极端月份。综合来看，报告盗窃在夏季升高并持续集中于downtown，基函数"
            "回归能够把长期、季节和空间信号放进统一的可解释模型。这里分析的是"
            "reported theft counts及其相关模式，不能把这些关系解释为因果效应。"
        ),
        "pointing_cues": "指观测与预测曲线的共同周期，再指峰值差距和残差图。",
        "core_sentence": "The model captures the main structure, but extreme peaks remain the principal limitation.",
    },
]
```

The scripts must cover:

- Slide 1: dataset, neighbourhood-month question, long-term change, and seasonal peaks.
- Slide 2: heatmap, downtown hotspots, and the embedded animation as Task 1 evidence.
- Slide 3: `log1p`, B-spline, sine/cosine, RBF, time split, Basis OLS, and Ridge extension.
- Slide 4: metrics, residual pattern, peak underprediction, conclusion, and non-causal limitation.

Add principle sections for panel construction, visualization, `log1p`, design matrices, B-splines, periodic bases, RBFs, OLS, Ridge, temporal validation, and MAE/RMSE/R².

- [ ] **Step 4: Run the content tests**

Run the command from Step 2.

Expected: all tests pass.

- [ ] **Step 5: Commit the verified content layer**

```bash
git add tmp/stat3888-presentation/five_minute_speech_content.py \
  tmp/stat3888-presentation/test_five_minute_speech_guide.py
git commit -m "docs: add verified STAT3888 speech content"
```

---

### Task 2: Build the Editable Word Guide

**Files:**
- Create: `tmp/stat3888-presentation/build_five_minute_speech_guide.py`
- Modify: `tmp/stat3888-presentation/test_five_minute_speech_guide.py`
- Create: `deliverables/STAT3888_Toronto_Bicycle_Theft_Presentation/STAT3888_五分钟演讲稿与原理解析.docx`

**Interfaces:**
- Consumes: the four content constants from Task 1.
- Produces: `build_document(output_path: Path) -> Path`.

- [ ] **Step 1: Add a failing DOCX structure test**

```python
from pathlib import Path
from docx import Document
from build_five_minute_speech_guide import build_document


def test_docx_contains_required_sections(tmp_path):
    output = build_document(tmp_path / "guide.docx")
    text = "\n".join(p.text for p in Document(output).paragraphs)
    assert "五分钟逐页演讲稿" in text
    assert "方法原理解析" in text
    assert "答辩速查" in text
    assert "姓名：" in text
    assert "学号：" in text
```

- [ ] **Step 2: Run the DOCX test and verify it fails**

Run:

```bash
PYTHONPATH=tmp/stat3888-presentation \
/Users/liumingyuan/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3 \
-m pytest tmp/stat3888-presentation/test_five_minute_speech_guide.py -q
```

Expected: import fails because the builder does not exist.

- [ ] **Step 3: Implement the compact-reference document**

Use:

- US Letter portrait, 1-inch margins, 0.492-inch header/footer distance.
- Arial Unicode MS for Chinese text and Calibri for Latin symbols.
- 11 pt body, 1.25 line spacing, 6 pt paragraph spacing.
- Heading colors `#2E74B5` and `#1F4D78`.
- Fixed-width tables only for genuine timing and metric comparisons.
- First section: one page per slide where practical, with time range, thumbnail, direct speech, pointing cue, and core sentence.
- Second section: repeated “直觉 → 数学表达 → 本项目如何实现 → 为什么适合” blocks.
- Final section: ten likely questions with a 20-second answer and a deeper follow-up.

Reuse the rendered slide PNGs from:

```text
deliverables/STAT3888_Toronto_Bicycle_Theft_Presentation/STAT3888_Toronto_Bicycle_Theft_Embedded_Video/slide-1.png
deliverables/STAT3888_Toronto_Bicycle_Theft_Presentation/STAT3888_Toronto_Bicycle_Theft_Embedded_Video/slide-2.png
deliverables/STAT3888_Toronto_Bicycle_Theft_Presentation/STAT3888_Toronto_Bicycle_Theft_Embedded_Video/slide-3.png
deliverables/STAT3888_Toronto_Bicycle_Theft_Presentation/STAT3888_Toronto_Bicycle_Theft_Embedded_Video/slide-4.png
```

- [ ] **Step 4: Generate the final DOCX**

Run:

```bash
/Users/liumingyuan/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3 \
tmp/stat3888-presentation/build_five_minute_speech_guide.py
```

Expected: prints the final DOCX path and creates a non-empty file.

- [ ] **Step 5: Run all guide tests**

Run the Task 1 pytest command.

Expected: all tests pass.

- [ ] **Step 6: Commit the DOCX builder and deliverable**

```bash
git add tmp/stat3888-presentation/build_five_minute_speech_guide.py \
  tmp/stat3888-presentation/test_five_minute_speech_guide.py \
  deliverables/STAT3888_Toronto_Bicycle_Theft_Presentation/STAT3888_五分钟演讲稿与原理解析.docx
git commit -m "docs: build STAT3888 five-minute speech guide"
```

---

### Task 3: Render, Inspect, and Deliver the PDF

**Files:**
- Read: `deliverables/STAT3888_Toronto_Bicycle_Theft_Presentation/STAT3888_五分钟演讲稿与原理解析.docx`
- Create: `tmp/stat3888-presentation/five-minute-guide-render/page-*.png`
- Create: `deliverables/STAT3888_Toronto_Bicycle_Theft_Presentation/STAT3888_五分钟演讲稿与原理解析.pdf`
- Modify if needed: `tmp/stat3888-presentation/build_five_minute_speech_guide.py`

**Interfaces:**
- Consumes: the final DOCX from Task 2.
- Produces: visually verified DOCX and PDF deliverables.

- [ ] **Step 1: Render the DOCX and emit PDF**

Run:

```bash
/Users/liumingyuan/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3 \
/Users/liumingyuan/.codex/plugins/cache/openai-primary-runtime/documents/26.727.11326/skills/documents/render_docx.py \
deliverables/STAT3888_Toronto_Bicycle_Theft_Presentation/STAT3888_五分钟演讲稿与原理解析.docx \
--output_dir tmp/stat3888-presentation/five-minute-guide-render \
--emit_pdf
```

Expected: page PNG files plus a PDF, with a zero exit code.

- [ ] **Step 2: Inspect every rendered page at full resolution**

Verify:

- no clipped Chinese characters or missing mathematical symbols;
- no split timing labels, isolated headings, or broken tables;
- no large unintended blank areas;
- slide images remain readable;
- formulas stay with their explanations;
- page numbers and running headers are consistent.

- [ ] **Step 3: Correct and re-render any layout defect**

Adjust spacing, image width, page breaks, or table geometry in the builder. Re-run the builder and Step 1 until all rendered pages are clean.

- [ ] **Step 4: Copy the verified PDF to the deliverables directory**

Copy the emitted PDF as:

```text
deliverables/STAT3888_Toronto_Bicycle_Theft_Presentation/
STAT3888_五分钟演讲稿与原理解析.pdf
```

- [ ] **Step 5: Run final structural verification**

```bash
PYTHONPATH=tmp/stat3888-presentation \
/Users/liumingyuan/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3 \
-m pytest tmp/stat3888-presentation/test_five_minute_speech_guide.py -q
```

Expected: all tests pass.

Also verify both final files exist and are non-empty.

- [ ] **Step 6: Preview final artifacts in WPS Office**

Open the DOCX and PDF with `/Applications/wpsoffice.app` and confirm the title page, speech section, formulas, and final answer page display correctly.

- [ ] **Step 7: Commit the verified PDF and final adjustments**

```bash
git add tmp/stat3888-presentation/build_five_minute_speech_guide.py \
  tmp/stat3888-presentation/test_five_minute_speech_guide.py \
  deliverables/STAT3888_Toronto_Bicycle_Theft_Presentation/STAT3888_五分钟演讲稿与原理解析.docx \
  deliverables/STAT3888_Toronto_Bicycle_Theft_Presentation/STAT3888_五分钟演讲稿与原理解析.pdf
git commit -m "docs: verify STAT3888 speech guide deliverables"
```
