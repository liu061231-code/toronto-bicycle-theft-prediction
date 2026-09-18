# CODEX_HANDOFF — 项目交接与审计指南

> 本文档面向 **Codex**（或任何接手本项目的 AI / 协作者），用于快速建立对项目的完整认知，
> 了解当前进度、运行方式、已知问题与后续可开展的方向。
>
> 面向**人类读者/评审**的正式说明见 [`README.md`](./README.md)。本文档是**工程交接**视角，
> 内容比 README 更偏向"如何继续开发、如何审计、有哪些坑"。

---

## 1. 项目是什么（30 秒概览）

- **目标**：预测多伦多 141 个社区**每个月的自行车盗窃报案数**（`theft_count`），
  并做小时级热点分析，最终服务于"巡逻资源布防"的实用场景。
- **数据**：多伦多警方官方开放数据（ArcGIS），40,583 条报案记录，2014–2026。
  聚合为平衡面板：**141 社区 × 144 个月 = 20,304 行**（2014-01 至 2025-12）。
- **任务类型**：监督回归（计数预测）。目标**零膨胀（~55% 为零）+ 过度离散（方差/均值比 ≈ 12.8）**。
- **最终模型**：`log1p(theft_count)` 上的**岭回归**，设计矩阵 = 时间 B-spline + 季节谐波
  + 空间 RBF + 社区 one-hot + 社区级 context 特征。
- **当前成绩**：2025 留出测试集 **R²=0.665 / MAE=0.833 / RMSE=1.97**（详见 §5 关于分数为何"下降"）。

---

## 2. 仓库结构与文件地图

```
.
├── README.md               # 面向外部的正式文档（已完整，数字已核对）
├── CODEX_HANDOFF.md        # 本文档
├── requirements.txt        # R 包依赖清单（含 scales）
├── .gitignore              # 已配置：排除数据、课程遗留、OS/Python 产物
├── data/raw/               # 数据文件（本地存在，但不进 git）
│   ├── bicycle.csv             # 月级模型用（旧 schema，2014–2026）
│   ├── bicycle_enhanced.csv    # 热点分析用（含 hour/premises_type 等）
│   └── bicycle_raw_latest.csv  # 原始下载（ArcGIS 原始 40,583 条）
├── scripts/
│   ├── download_data.py    # 从 ArcGIS API 分页下载最新数据（Python 标准库）
│   └── convert_data.py     # 对齐 schema → 产出上面两个 CSV
├── src/                    # ★ 核心代码（R）
│   ├── config.R            # 路径注册、包依赖、random_seed=2023、find_project_root
│   ├── prepare_data.R      # 读取/审计/聚合月度 panel
│   ├── features.R          # 基函数设计矩阵（spline/RBF/seasonal/context）
│   ├── validation.R        # 时间切分 + expanding-window CV
│   ├── models.R            # 3 个 baseline + 4 个候选模型
│   ├── evaluate.R          # 对比表 + 最终评估
│   ├── visualize.R         # EDA + 诊断图（01–05）
│   ├── hotspot_analysis.R  # 小时级/场所级热点分析（06–07）
│   └── run_pipeline.R      # ★ 端到端入口
└── output/
    ├── figures/            # 生成的图（01–07，新 pipeline 产出）
    ├── tables/             # 结果表（cv_folds/data_audit/lambda_tuning/model_comparison/test_predictions）
    └── models/             # （空，预留）
```

### ⚠️ 目录里还存在的"课程遗留"（关键！）

以下目录**在本地磁盘上仍然存在**，但已被 `.gitignore` 排除、**不属于当前项目**，是早期课程作业的残留：

```
R/  handbook/  deliverables/  docs/  tests/  tmp/  .worktrees/  .pytest_cache/
```

- 它们是**历史遗留**，与当前 `src/` 的干净实现**无关**。
- **不要**去改动、也不要基于它们理解项目逻辑；请以 `src/` 为准。
- 除非用户明确要求，否则**不要删除**这些目录（用户此前已明确表示保留本地文件）。

---

## 3. 如何运行（从零复现）

### 3.1 环境
- **R >= 4.2**，依赖包见 `requirements.txt` / `src/config.R` 的 `required_packages`。
  安装：`install.packages(scan("requirements.txt", what = "character"))`
- **Python 3**（仅标准库，用于下载/转换数据脚本，非建模核心）。

### 3.2 数据获取（数据不随仓库分发）
```bash
python3 scripts/download_data.py   # 下载 ArcGIS 原始数据 → data/raw/bicycle_raw_latest.csv
python3 scripts/convert_data.py    # 转成 bicycle.csv + bicycle_enhanced.csv
```

### 3.3 跑模型（从项目根目录运行，脚本用 `--file=` 定位 root）
```bash
Rscript src/run_pipeline.R         # 月级建模：audit → 聚合 → CV → 调参 → 测试评估 → 出图表
Rscript src/hotspot_analysis.R     # 小时级热点分析（依赖 enhanced 数据）
```

---

## 4. 核心设计决策（Codex 必须理解）

### 4.1 验证策略（本项目最重要的正确性保证）
- 面板有**强时序自相关**（lag-1 ≈ 0.83）和**年周期**（lag-12 ≈ 0.85），
  因此**严禁随机 train_test_split**（会泄漏未来信息、虚高分数）。
- 采用**纯时间顺序**：
  - **留出测试集 = 2025 全年**（只在最终评估时触碰）。
  - **expanding-window CV**（2014–2024）：train 到某截止点 → 预测接下来 12 个月 → 滚动前移。
- **泄漏安全的关键实现**：`make_basis_recipe()` 在每个 CV fold 内**基于该 fold 的训练数据重建**
  （B-spline 边界 knots、空间中心、context 先验都是 fold 内学习的），
  而不是用全量数据学一次再复用。
  > 早期版本曾把 `time_boundary` 硬编码为 `c(1, 120)`，导致早期 fold 疯狂外推发散
  > （fold-1 RMSE 高达几十万）。**这是本项目修掉的最重要 bug**，切勿改回。

### 4.2 模型接口约定
- 所有模型都是 `function(train_data, test_data) -> numeric(预测值)` 的闭包工厂形式。
- 工厂函数（如 `model_ridge_log(lambda=...)`）负责 `force()` 参数、内部重建 recipe。
- baseline 在 `models.R` 顶部，候选模型在后；`run_pipeline.R` 用一个 `list(name = fn)` 统一注册。

### 4.3 特征选择结论（踩过的坑，勿重蹈）
- **neighborhood 固定效应是预测最强信号**：Poisson/NB GLM 因使用 compact 设计矩阵
  （去掉社区哑变量）而崩坏。这是**有意保留的实验对照**，用于证明"匹配数据结构 > 堆复杂模型"。
- **lag 特征被证明有害**：实验验证 `lag_1`/`lag_12` 让 test R² 从 0.78 掉到 0.63（过拟合近期噪声）。
  结论是**不采用 lag**，但可作为一个"试过并放弃"的诚实记录。
- **context 特征微弱但真实有用**：`context_outside_share`/`context_commercial_share`
  （社区历史户外/商业盗窃占比，仅训练集学习）消融实验 +0.013 R²。已保留。

### 4.4 调参
- 仅对 Ridge 的 λ 做 expanding-window CV 网格搜索（`lambda_tuning.csv` 记录过程）。
- 结论：模型对 λ **不敏感**（1e-4~1e-1 区间 test 分数几乎持平），这是稳健性证据，不是缺陷。

---

## 5. 当前结果与"分数为何下降"（重要，别误判为退化）

**最终对比表**（2025 留出测试集；CV 列是 2014–2024 expanding 均值）：

| 模型 | CV R² | Test MAE | Test RMSE | Test R² |
|---|---|---|---|---|
| Global mean | −0.005 | 2.12 | 3.49 | −0.051 |
| Neighbourhood mean | 0.570 | 1.30 | 2.52 | 0.449 |
| Seasonal naive | 0.605 | 1.08 | 2.09 | 0.622 |
| Poisson GLM | −0.559 | 1.40 | 3.38 | 0.014 |
| Negative-binomial GLM | −3.62 | 1.13 | 3.10 | 0.168 |
| Basis OLS (log) | 0.615 | 0.839 | 2.01 | 0.652 |
| Basis Ridge (log) | 0.618 | 0.835 | 1.99 | 0.659 |
| **Basis Ridge (tuned)** | **0.623** | **0.833** | **1.97** | **0.665** |

**关键事实**：
- 旧版本在 2023 测试集上 R²≈0.78；现在 2025 测试集 R²=0.665，**不是退化**。
- 原因：**分布漂移**——多伦多自行车盗窃量持续下降，2018 峰值 ~3,990/年 → 2025 ~2,125/年
  （十年新低），零值比例升至 ~62%。任何"历史训练"的模型都会系统性高估这个下降年份。
- 我用相同框架在旧 2023 测试集复测得 **R²=0.788**（比原来还略升），证明新特征+泄漏修复是有效提升。
- 这个"分布漂移"本身就是有价值的发现，已写进 README 的 Error Analysis / Limitations。

---

## 6. 已知问题 / 技术债（Codex 接手时需注意）

1. **负二项 GLM 在 CV 早期 fold 不收敛**：`glm.fit: algorithm did not converge` 警告（约 50+ 条）。
   根因是早期 fold 训练样本不足 + 无惩罚。**不阻塞主流程**（最终模型是 Ridge），但属已知噪声。
2. **注释/文档遗留**：`validation.R` 顶部注释曾残留旧年份（已修复）；如发现其他注释与代码
   不一致（如 `visualize.R` 里的年份字样），请以**代码实际行为**为准并顺手修正注释。
3. **`output/figures/` 里有旧版图残留**：`03b_*`、`04_spacetime_heatmap.png`、`05_basis_functions.png`、
   `06_model_comparison.png`、`07_observed_vs_predicted.png`、`08_residual_map.png`、
   `toronto_bicycle_theft_animation_poster.png` 是旧课程 pipeline 的产物，本地仍在，
   但已被 `.gitignore` 排除（`output/figures/` 下的一批 `*.png` 规则）。
   **新的编号是 01–07**（01–05 月级、06–07 热点）。请勿混淆新旧编号。
4. **GitHub 上传未完成**：`git remote origin` 当前指向 `https://github.com/jry/toronto-bicycle-theft-prediction.git`，
   但该 `jry` 账号**并非**用户 token 对应的账号（token 对应 `liu061231-code`）。
   上传前需先解决账号对应问题，且需用户提供可创建仓库的凭据。**详见 §9**。

---

## 7. 后续可开展的方向（按优先级，供 Codex 规划）

> 背景：用户目标是申请香港研究生，希望项目体现"方法论严谨 + 现实意义"。
> 已和用户确认过以下方向，其中 #1 最贴合数据、性价比最高。

1. **零膨胀负二项（ZINB）/ hurdle 模型**（最推荐）
   - 显式建模 ~55% 的零值，直接回应"数据性质 vs 模型选择"的方法论缺口。
   - R 可用 `pscl::zeroinfl` 或 `glmmTMB::glmmTMB(family=nbinom2, ziformula=~1)`。
   - 与现有 Ridge 在同一 validation 框架下公平对比即可。

2. **引入外部协变量**（把"预测"推向"解释"）
   - 天气（气温/降水）、节假日、社区人口/警务密度。
   - 卖点从"预测得准"升级为"理解什么驱动盗窃"。

3. **更细粒度的时空预测**
   - 数据现已支持**小时**和**场所类型**维度（`hotspot_analysis.R` 已做描述性分析），
     可进一步做"社区×天"甚至"网格×小时"的预测模型。

4. **预测不确定性**
   - bootstrap / conformal prediction 给出预测区间，量化"哪些社区/月份更没把握"。

5. **滚动重训练 / 在线学习**
   - 针对"盗窃量持续下降"的分布漂移，验证滚动重训练能否缓解高估。

6. **部署 demo**
   - 用现有模型输出做一张"多伦多风险热力图 + 高风险社区清单"，作为"预测→可操作"的可视化收尾。

---

## 8. 审计自查清单（Codex 接手/审查时逐项核对）

- [ ] `Rscript src/run_pipeline.R` 从零跑通（需先有 `data/raw/*.csv`）
- [ ] `Rscript src/hotspot_analysis.R` 从零跑通（依赖 `bicycle_enhanced.csv`）
- [ ] 无 hardcoded 绝对路径（`grep -rn "/Users/\|liumingyuan" src/ scripts/` 应无输出）
- [ ] 无敏感信息（API key / token / password；`grep -rni "token\|api_key\|secret" src/ scripts/ README.md`）
- [ ] `random_seed` 已设置（`src/config.R` 中 `random_seed <- 2023L`）
- [ ] README 中的数字与实际 `output/tables/model_comparison.csv` 一致
- [ ] 数据文件未被 commit（`git ls-files | grep -E "\.csv$"` 应为空）
- [ ] 无数据泄漏：B-spline boundary/knots、空间中心、context 先验都在 fold 内重建
- [ ] CV 与 test 的验证框架一致、公平

---

## 9. 交付状态与待办

**已完成** ✅
- 完整技术审计 + 数据泄漏 bug 修复
- time-aware validation（chronological split + expanding-window CV）
- baseline + 多模型公平对比
- Ridge 调参 + 消融实验（context 特征）
- 数据升级到 2026 + 小时级热点分析
- 模块化 `src/` 重构 + 专业 README + `.gitignore` + `requirements.txt`
- Git 历史重建为干净的 4 个 commit

**未完成 / 待办** ⏳
- **GitHub 上传**：本地已就绪，但远程 `origin` 账号指向错误（`jry` vs token 对应的 `liu061231-code`），
  且当前 token 无"创建仓库"权限。需要用户：① 在 GitHub 网页手动建空仓库并告知；或 ② 提供有
  `Administration` 权限的新 token。上传前请先和用户确认目标仓库 URL。
- **ZINB 模型**（§7 方向 #1，最高优先级，尚未实现）

---

## 10. 快速上手命令（复制即用）

```bash
cd "/Users/liumingyuan/Documents/project of stat38888_副本"

# 1. 确认环境
Rscript -e 'source("src/config.R"); ensure_packages()'

# 2. 跑月级主流程（数据已在 data/raw/ 时可直接跑）
Rscript src/run_pipeline.R

# 3. 跑小时级热点分析
Rscript src/hotspot_analysis.R

# 4. 查看最终结果
cat output/tables/model_comparison.csv
```

---

*本文档由 WorkBuddy 在完成"数据升级 + 模型打磨"后生成，供 Codex 接手与审计使用。*
*若与 `README.md` 冲突，以代码实际行为为准；发现注释与代码不一致处请随手修正。*
