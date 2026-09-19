# Toronto Bicycle Theft Prediction

## 中文项目介绍

### 项目来源

本项目起源于 STAT3888 时空数据科学课程作业。最初的课程作业主要训练数据清洗、空间特征、季节性和基本预测模型。在课程作业的基础上，我将它扩展成一个完整的时序预测研究项目：重新审计数据口径，查找时间泄漏，设计嵌套时序回测，并将模型输出做成可重新加载的预测制品。

### 研究问题

项目预测多伦多 140 个已命名社区与一个 NSA（未知区域）单元的月度自行车盗窃**公开记录行数**。模型使用 2014–2025 的平衡社区-月份面板，并明确区分两个任务：每月更新后预测下一个月，以及年末一次性预测未来 12 个月。

目标是公平、可复现地比较基线、log-Ridge、惩罚 Poisson 和负二项模型，而不是追求一个脱离验证协议的最高分。

### 从初始模型到优化版本

1. **课程原型**：从事件表聚合月度计数，构建时间、季节和空间特征，并使用基本回归模型。
2. **问题复盘**：发现随机切分不适合高自相关时序，并识别全量事件计算坐标可能把未来信息带入历史特征。
3. **时序与空间修复**：冻结 2014–2017 训练期坐标参考表，并在每个外层折内重建训练派生特征。
4. **数据增强**：刷新官方开放数据，保留 OBJECTID、EVENT_UNIQUE_ID、发生日期和报告日期，增加下载集合对账、迟报过滤和转换回滚。
5. **模型优化**：Ridge 与 Poisson 共用 lambda 网格、嵌套扩展窗口时序折和 RMSE 选择规则，2025 只作重复查看后的 retrospective 描述窗口。
6. **可复现输出**：每个预测制品保留训练截止日期、lambda、数据哈希、坐标版本和依赖信息，使预测可被重新加载和核查。

### 当前结果

| 任务 | 选中模型 | 平均 MAE | 平均 RMSE | 平均 R² |
|---|---|---:|---:|---:|
| 每月更新，预测下个月 | Poisson (area, tuned) | 1.01 | 1.56 | 0.744 |
| 年末预测未来 12 个月 | Basis Ridge (tuned) | 1.38 | 2.93 | 0.613 |

2025 是已被开发过程多次查看的 retrospective 窗口，不是 untouched holdout。这种设计保留了诚实的证据边界：回测支持按预测时间范围选择模型，而不是用一个被重复调查的年份包装成独立测试。

### 研究限制与后续工作

目标是公开记录行数，不是经官方确认的案件数或自行车数。数据是当前快照，`report_date` 可以做可用性过滤，但无法完整重建历史修订状态。小时热点是描述性时间分布，不估计巡逻干预效果或成本效率。

下一步包括：使用时间序校准的预测区间、检验滚动重训对分布漂移的改善，以及在有可用快照时增加外部天气、人口或城市设施协变量。

## English project overview

### Origin and motivation

This project began as a STAT3888 spatio-temporal data science course assignment. The original exercise focused on cleaning an event table, constructing temporal and spatial features, and fitting a first predictive model. I extended that coursework into a reproducible research project by auditing the target definition, testing for future-derived leakage, rebuilding the validation protocol, refreshing the official open-data snapshot, and packaging forecasts with provenance metadata.

### Research question

The project forecasts monthly **published bicycle-theft record rows** for 140 named Toronto neighbourhoods plus an NSA (Not Specified Area) unit. It treats one-step monthly updating and twelve-month annual planning as different forecasting tasks. The primary goal is not to claim a universally best model, but to compare models under a transparent, chronological protocol.

### Methodological evolution

- The course prototype established the panel, seasonal features, spatial smoothing, and baseline regressions.
- A leakage audit showed why full-history coordinates and random splits were unsafe for a temporal forecasting problem.
- A frozen 2014–2017 coordinate reference and fold-local recipes remove future-derived spatial information.
- The refreshed download/conversion pipeline preserves source IDs and occurrence/report dates, validates complete ArcGIS ID sets, and rolls back partial conversions.
- Ridge and penalised Poisson candidates now use the same lambda grid, nested chronological folds, RMSE selection rule, and explicit convergence accounting.
- Saved artifacts record the model, feature recipe, training cutoff, hashes, coordinates, and session information so forecasts can be reloaded and audited.

### Current evidence

Predeclared rolling-origin backtests select penalised Poisson for the one-month updating task (mean RMSE 1.56) and tuned Basis Ridge for the twelve-month annual task (mean RMSE 2.93). The 2025 window is reported as a descriptive retrospective because it was viewed during development; it does not select the model. The repository also includes a training-only comparison of naive, log-normal, and Duan-smearing back-transform corrections.

### Scope and limitations

The target is a count of published rows, not a verified count of unique cases or bicycles. The current snapshot cannot reconstruct every historical revision state. Hourly and premises-type analysis is descriptive and does not estimate intervention effects. Production deployment would additionally require versioned data snapshots, uncertainty intervals, drift monitoring, scheduled retraining, and an operational interface.

### Why this is useful as a research portfolio piece

The main contribution is the full reasoning loop: start from a course model, identify where a plausible score can be misleading, design tests that expose the issue, repair the data and validation layers, and preserve both the improved result and its limitations. That workflow demonstrates statistical modelling, software engineering, reproducibility, and scientific communication together.

## Repository map

- Main pipeline: `src/run_pipeline.R`
- Data acquisition and conversion: `scripts/download_data.py`, `scripts/convert_data.py`
- Validation and models: `src/validation.R`, `src/models.R`, `src/backtest.R`
- Saved model contract: `src/artifacts.R`, `src/predict.R`
- Tests and smoke workflow: `test/`, `.github/workflows/tests.yml`
- Reproducibility metadata: `renv.lock`, `output/run_manifest.json`
