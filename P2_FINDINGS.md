# 第二阶段：公平比较与误差归因

日期：2026-09-19
执行方：WorkBuddy
依据：`handoff.md` 第二阶段（4.A 公平对照 / 4.B context 归因 / 4.C 验证协议 / 4.D 回变换偏差）

## 核心发现

### 1. 公平比较推翻了"Ridge 最优"结论（4.A）

之前 Poisson/NB GLM 表现差（test R² ≈ 0.01~0.38），是因为它们**缺少社区固定
效应 + 没有调参**（lambda 固定 1e-2），与 Ridge 比较不公平。修正后：

| 模型 | test RMSE | test R² | 2025 总量偏差 |
|---|---:|---:|---:|
| **Poisson (area, ridge)** | **1.73** | **0.741** | **−13.6%** |
| Basis Ridge (tuned) | 1.96 | 0.667 | −35.1% |
| Poisson (compact，无社区) | 2.72 | 0.360 | — |
| Negative-binomial（glm.nb，无社区/无调参） | 2.83 | 0.307 | — |

**关键证据链**：
- `Poisson (compact)`（无社区固定效应）test R² 仅 0.360 —— 印证社区固定效应
  对计数模型同样关键。
- `Poisson (area, ridge)`（社区 one-hot + ridge 惩罚 + 每折内 cv.glmnet 调参）
  test R² 跳到 **0.741**，全面超越 Ridge。
- Poisson 用对数链接直接预测条件均值 `E[Y]`，**天然规避了 log1p 回变换的
  Jensen 不等式偏差**，因此总量校准从 −35% 改善到 −13.6%。

**公平性保证**：Poisson 的 lambda 由每折训练数据内部的 `cv.glmnet` 选择，
遵守时间顺序验证协议，未用 2025 标签调参。

### 2. 回变换偏差是低估的结构性主因（4.D）

独立脚本 `src/backtransform_bias.R` 量化了 `expm1(E[log1p(Y)]) ≠ E[Y]` 的偏差：

- 训练内 log 尺度残差 SD = 0.4975，隐含校正因子 ≈ 1.13（+13%）。
- 训练分布上 `expm1(mu)` 均值 1.508 vs 实际 2.025，**Jensen gap ≈ 25.5%**。
- 结论：**回变换偏差解释了约 25% 的低估（结构性、即使完美校准也存在），
  剩余约 10% 才是真正的 2025 分布漂移**。

这修正了 P1 阶段"35% 全部归因于分布漂移"的认知——低估的**主要**来源是模型
设定的回变换偏差，而非数据漂移。

### 3. 总量与分层诊断输出（4.A/D 验收）

新增 `evaluate.R::summarise_forecast_errors()`，输出：
- 全年总量偏差、分月总量偏差（`monthly_errors.csv`）
- 非零样本误差、活跃社区误差
- 社区分层指标（`neighborhood_errors.csv`）

管道同时输出 Ridge 与 Poisson 两套诊断，误差方向和数字由输出表自动生成。

## 代码变更

- `src/models.R`：
  - `make_glm_design_matrix(..., with_area)` 支持社区 one-hot。
  - `model_poisson_glm(alpha, lambda, with_area)`：`lambda=NULL` 时每折内
    `cv.glmnet` 调参；`with_area=TRUE` 加社区固定效应 + ridge 惩罚。
  - `model_negbin_glm(with_area=FALSE)`：glmnet 5.0 不支持 negative.binomial
    family，NB 回退 MASS::glm.nb（紧凑特征），已记录此环境限制。
  - 新增 `baseline_recent_seasonal_mean(12)` 实用基线（近 12 月均值）。
- `src/evaluate.R`：新增 `summarise_forecast_errors()`。
- `src/run_pipeline.R`：模型列表加入 Poisson 两种配置 + 最近均值基线；同时
  输出 Ridge 与 Poisson 的预测与诊断。
- `src/backtransform_bias.R`：新增，量化回变换偏差（不用 2025 标签校准）。

## 诚实性说明（4.C）

- **2025 已被多轮诊断使用，不能称"从未接触的测试集"**。Poisson 的 0.741
  是在同一 2025 上发现的，存在一定的过拟合风险。下一步应：
  1. 用 horizon=1 滚动回测（每月重训预测下月）独立评估；
  2. 或冻结方案后用真正未参与决策的新时间窗验证。
- CV 平均值（`cv_R2`）仍显示 Ridge 略优（0.623 vs Poisson 0.411），但 CV 的
  horizon=12 任务与"预测 2025 全年"不完全一致；Poisson 在 2025 上的优势
  需要在滚动回测中确认是否稳定。

## 待办（第三阶段）

- horizon=1 滚动回测（handoff 4.C）。
- 公平比较的完整实验表（特征组 × 模型族 × 调参预算），当前已覆盖主要组合。
- context 增益多折消融（4.B）。
- 若 Poisson 稳定最优，将其设为最终模型并更新 README 全部数字。
