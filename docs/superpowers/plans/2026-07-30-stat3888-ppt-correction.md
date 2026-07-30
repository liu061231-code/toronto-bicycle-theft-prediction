# STAT3888 PowerPoint Correction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce a corrected four-slide STAT3888 PowerPoint with one consistent Ridge evidence chain, clearer spatial evidence, academic wording, portable notes, and blank identity fields.

**Architecture:** Import the user-provided PPTX through `@oai/artifact-tool`, duplicate all four source slides through the template-following starter-deck workflow, and edit inherited objects by stable IDs. Preserve the existing master, layout, typography, embedded evidence images, and slide order; export a new PPTX and verify it through structural inspection, full-slide rendering, overflow checks, fidelity checks, and WPS Office.

**Tech Stack:** JavaScript ES modules, `@oai/artifact-tool`, bundled template-following utilities, bundled PowerPoint render/overflow tools, WPS Office.

## Global Constraints

- The source file `/Users/liumingyuan/Documents/STAT3888 Toronto bicycle theft.pptx` must remain unchanged.
- The corrected deck must contain exactly four slides.
- All audience-facing text must remain English.
- Preserve the imported master, layout, typography, colors, and slide order.
- Select Basis Ridge as the primary model: RMSE 2.06, R² 0.754, and 24.4% lower RMSE than the neighbourhood-mean baseline.
- Keep OLS visible in the comparison chart and state that its RMSE is only 0.01 lower.
- Leave editable blank fields for name and student ID; do not invent personal information.
- Replace machine-only note citations with portable source labels.
- Do not modify or delete unrelated user-owned untracked files.

---

### Task 1: Prepare the Template-Following Starter Deck

**Files:**
- Create: `tmp/ppt-correction/template-frame-map.json`
- Create: `tmp/ppt-correction/template-audit.txt`
- Create: `tmp/ppt-correction/deviation-log.txt`
- Create: `tmp/ppt-correction/template-starter.pptx`

**Interfaces:**
- Consumes: source PPTX and `tmp/ppt-review/template-inspect/template-inspect.ndjson`.
- Produces: a four-slide starter deck whose slides map 1:1 to the source.

- [ ] **Step 1: Initialize the artifact-tool workspace**

Run:

```bash
/Users/liumingyuan/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node \
  /Users/liumingyuan/.codex/plugins/cache/openai-primary-runtime/presentations/26.727.11326/skills/presentations/container_tools/setup_artifact_tool_workspace.mjs \
  --workspace "/Users/liumingyuan/Documents/project of stat38888/tmp/ppt-correction"
```

Expected: `tmp/ppt-correction/package.json` exists.

- [ ] **Step 2: Inspect the source deck in the correction workspace**

Run:

```bash
/Users/liumingyuan/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node \
  /Users/liumingyuan/.codex/plugins/cache/openai-primary-runtime/presentations/26.727.11326/skills/presentations/template_following_scripts/inspect_template_deck.mjs \
  --workspace "/Users/liumingyuan/Documents/project of stat38888/tmp/ppt-correction" \
  --pptx "/Users/liumingyuan/Documents/STAT3888 Toronto bicycle theft.pptx"
```

Expected: four source-slide PNGs and `template-inspect.ndjson`.

- [ ] **Step 3: Define the exact frame map**

Create a `template-frame-map.json` with four `duplicate-slide` mappings and
these inherited edit targets:

```json
{
  "outputSlides": [
    {
      "outputSlide": 1,
      "sourceSlide": 1,
      "narrativeRole": "correct temporal claim and add blank identity line",
      "reuseMode": "duplicate-slide",
      "editTargets": [
        {"sourceElementId": "sh/k3yl0zql", "action": "rewrite"},
        {"sourceElementId": "sh/hofulsf2", "action": "rewrite"}
      ]
    },
    {
      "outputSlide": 2,
      "sourceSlide": 2,
      "narrativeRole": "replace static spatial evidence and correct interpretation",
      "reuseMode": "duplicate-slide",
      "editTargets": [
        {"sourceElementId": "im/b2lwnql4", "action": "replace"},
        {"sourceElementId": "sh/nu58f2hs", "action": "rewrite"},
        {"sourceElementId": "sh/do3q9szq", "action": "rewrite"}
      ]
    },
    {
      "outputSlide": 3,
      "sourceSlide": 3,
      "narrativeRole": "select Ridge and explain stability tradeoff",
      "reuseMode": "duplicate-slide",
      "editTargets": [
        {"sourceElementId": "sh/943mhgre", "action": "rewrite"},
        {"sourceElementId": "sh/n2l4fq98", "action": "rewrite"}
      ]
    },
    {
      "outputSlide": 4,
      "sourceSlide": 4,
      "narrativeRole": "align prediction conclusions with Ridge metrics",
      "reuseMode": "duplicate-slide",
      "editTargets": [
        {"sourceElementId": "sh/ih8ju9sn", "action": "rewrite"}
      ]
    }
  ],
  "omittedSourceSlides": []
}
```

- [ ] **Step 4: Build the starter deck**

Run:

```bash
/Users/liumingyuan/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node \
  /Users/liumingyuan/.codex/plugins/cache/openai-primary-runtime/presentations/26.727.11326/skills/presentations/template_following_scripts/prepare_template_starter_deck.mjs \
  --workspace "/Users/liumingyuan/Documents/project of stat38888/tmp/ppt-correction" \
  --pptx "/Users/liumingyuan/Documents/STAT3888 Toronto bicycle theft.pptx" \
  --map "/Users/liumingyuan/Documents/project of stat38888/tmp/ppt-correction/template-frame-map.json" \
  --out "/Users/liumingyuan/Documents/project of stat38888/tmp/ppt-correction/template-starter.pptx" \
  --preview-dir "/Users/liumingyuan/Documents/project of stat38888/tmp/ppt-correction/template-starter-preview" \
  --layout-dir "/Users/liumingyuan/Documents/project of stat38888/tmp/ppt-correction/template-starter-layout" \
  --contact-sheet "/Users/liumingyuan/Documents/project of stat38888/tmp/ppt-correction/template-starter-contact-sheet.png"
```

Expected: validation passes and the four-slide starter deck is created.

### Task 2: Edit the Imported Slides and Notes

**Files:**
- Create: `tmp/ppt-correction/edit_deck.mjs`
- Create: `deliverables/STAT3888_Toronto_Bicycle_Theft_Presentation/STAT3888_Toronto_Bicycle_Theft_Corrected.pptx`

**Interfaces:**
- Consumes: starter PPTX, high-contrast map PNG, and imported speaker notes.
- Produces: corrected deck with the inherited slide structure.

- [ ] **Step 1: Write a focused imported-deck editor**

The editor must:

1. import `template-starter.pptx`;
2. inspect all text, images, and notes;
3. resolve objects by their unique inherited names;
4. replace the slide-1 question with:

```text
Name: ____________________    Student ID: ____________________
```

5. replace the slide-1 takeaway with:

```text
Reported bicycle thefts show strong seasonality: July has the highest average count, while winter months remain below 100 incidents.
```

6. replace slide-2 static hotspot image bytes with
`output/figures/03b_neighbourhood_hotspot_map.png`, preserving its original
frame and fit properties;
7. replace slide-2 interpretation with statements about reported incidents,
not thief behaviour;
8. replace slide-3 metric text with:

```text
Basis Ridge
RMSE 2.06   ·   R² 0.754
```

9. add the Ridge selection rationale inside the existing components text box:

```text
B-splines: long-run change   ·   sine/cosine: annual cycle
16 spatial RBFs: proximity   ·   Ridge selected for stability; OLS RMSE is only 0.01 lower
```

10. replace slide-4 conclusions with:

```text
Basis Ridge: 24.4% lower RMSE vs neighbourhood-mean baseline
Seasonal rise and fall are reproduced
Largest positive errors remain near downtown hotspots
```

11. rewrite all four notes `[Sources]` sections with portable labels and update
the slide-3/4 talk tracks to Ridge;
12. export `STAT3888_Toronto_Bicycle_Theft_Corrected.pptx`.

- [ ] **Step 2: Run the editor**

Run:

```bash
cd "/Users/liumingyuan/Documents/project of stat38888/tmp/ppt-correction" &&
/Users/liumingyuan/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node edit_deck.mjs
```

Expected: the corrected PPTX exists and is non-empty.

### Task 3: Verify Structure, Content, Rendering, and Compatibility

**Files:**
- Create: `tmp/ppt-correction/final-render/`
- Create: `tmp/ppt-correction/final-layout/`
- Create: `tmp/ppt-correction/final-inspect.ndjson`
- Create: `deliverables/STAT3888_Toronto_Bicycle_Theft_Presentation/STAT3888_Toronto_Bicycle_Theft_Corrected_review.png`

**Interfaces:**
- Consumes: corrected PPTX.
- Produces: verified four-slide deliverable and QA evidence.

- [ ] **Step 1: Inspect the corrected deck**

Require:

```text
4 slides
Basis Ridge
RMSE 2.06
R² 0.754
24.4% lower RMSE
Name and Student ID blank fields
no "So basically"
no "The thieves"
no visible 24.9% claim
```

- [ ] **Step 2: Render all slides and create a montage**

Run the bundled `render_slides.py` and `create_montage.py`. Expected: four PNG
slides and one montage.

- [ ] **Step 3: Run overflow and template-fidelity checks**

Run:

```bash
/Users/liumingyuan/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3 \
  /Users/liumingyuan/.codex/plugins/cache/openai-primary-runtime/presentations/26.727.11326/skills/presentations/container_tools/slides_test.py \
  "/Users/liumingyuan/Documents/project of stat38888/deliverables/STAT3888_Toronto_Bicycle_Theft_Presentation/STAT3888_Toronto_Bicycle_Theft_Corrected.pptx"
```

Then run `check_template_fidelity.mjs` against the starter and corrected deck.
Expected: no overflow and no unexplained template deviations.

- [ ] **Step 4: Inspect every slide at full size**

Check title wrapping, chart labels, identity-line readability, spatial-map
contrast, Ridge consistency, sources, and absence of clipping or overlap.

- [ ] **Step 5: Open the final deck in WPS Office**

Run:

```bash
open -a /Applications/wpsoffice.app \
  "/Users/liumingyuan/Documents/project of stat38888/deliverables/STAT3888_Toronto_Bicycle_Theft_Presentation/STAT3888_Toronto_Bicycle_Theft_Corrected.pptx"
```

Expected: WPS opens the deck without repair prompts.

