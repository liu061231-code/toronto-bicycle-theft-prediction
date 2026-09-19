# GitHub Portfolio Publication Implementation Plan

> **For agentic workers:** Execute this plan task-by-task with review checkpoints.

**Goal:** Publish the STAT3888-inspired bicycle-theft forecasting project as a bilingual, reproducible GitHub research portfolio.

**Architecture:** Keep executable code and generated evidence in the existing R/Python pipeline. Add a focused bilingual introduction document and two Mermaid diagrams in README so GitHub renders the project story without binary diagram maintenance. Finish with repository hygiene, validation, commits, push, and remote verification.

**Tech Stack:** Markdown, GitHub Mermaid, R, Python, Git, GitHub Actions.

## Global Constraints

- Do not change the original course project outside this copy.
- Do not expose secrets, private paths, raw credentials, or files larger than the repository publishing threshold.
- Describe 2025 as a repeatedly viewed retrospective window, not an untouched holdout.
- Describe the target as published record rows, not verified theft cases or bicycles.
- Do not claim causal patrol effects or production readiness.

### Task 1: Add bilingual project narrative

**Files:**
- Create: `docs/project_introduction.md`
- Modify: `README.md`

- [ ] Write Chinese and English introductions covering STAT3888 origin, project evolution, methodology, results, limitations, and future work.
- [ ] Add README links to the bilingual document and preserve concise quick-start content.
- [ ] Check every metric and claim against current output tables.

### Task 2: Add architecture and research-process diagrams

**Files:**
- Modify: `README.md`
- Modify: `docs/project_introduction.md`

- [ ] Add a Mermaid architecture diagram whose nodes map to existing scripts and outputs.
- [ ] Add a Mermaid flowchart from course assignment through initial model, audit, leakage repair, data refresh, horizon-specific selection, and publishable artifact.
- [ ] Confirm Mermaid syntax and file references are valid.

### Task 3: Prepare repository for publication

**Files:**
- Modify: `.gitignore`, if required
- Modify: `README.md`, if required

- [ ] Scan for secrets, private absolute paths, `.DS_Store`, `.Rhistory`, caches, raw-data policy violations, and large files.
- [ ] Ensure ignored RDS/archive files remain recoverable locally but are not accidentally added.
- [ ] Add a concise GitHub-facing release checklist and link the completion report.

### Task 4: Validate, commit, and publish

**Files:**
- All intended tracked/untracked publication files.

- [ ] Run `git diff --check`, R tests, Python tests, smoke pipeline, and documentation checks.
- [ ] Commit design/narrative and repository cleanup in reviewable commits.
- [ ] Push `main` to the verified `origin` remote.
- [ ] Verify remote branch and GitHub Actions status; report any external limitation explicitly.
