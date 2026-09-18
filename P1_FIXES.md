# 第一阶段（P1）修复交付记录

日期：2026-09-19
执行方：WorkBuddy
依据：`handoff.md`（Codex 审计交接）
基准 commit：`c5cc69f`

## 已完成的修复（P1 优先级）

### A. NSA 未知区域与空间坐标污染（P1-01）— 已修复

- 新增 `UNKNOWN_AREA <- "NSA"` 常量（`src/prepare_data.R`）。
- `make_neighborhood_coordinates()`：NSA 与零/缺失坐标记录被排除，坐标表仅
  含 140 个有效社区；NSA 坐标置为 `NA`。
- 面板新增 `is_unknown` 标志列，NSA 记录保留计数但对账、不进入空间特征。
- `make_basis_recipe()` / `make_design_matrix()`：空间中心、尺度、RBF 中心
  仅基于有效坐标；NSA 行的 RBF/one-hot 特征置 0。
- **结果**：空间尺度从污染后的 6.66 恢复为 `0.101871`（与审计基准一致）。

### B. 未来坐标泄漏（P1-02）— 已修复（feedback2.0 P0 Task 1 进一步加固）

- **第一轮修复（后被证明不充分）**：曾把"全期事件坐标中位数"当作固定地理
  常量。复审（feedback2.0）指出：该中位数仍在主流水线中从含未来事件的
  全量 raw 计算，扰动 2024+ raw 坐标会改变 29,880 个历史训练单元。
- **第二轮修复（现行）**：坐标改为**冻结的、版本化的参考表**
  `data/reference/neighborhood_coordinates.csv`，由
  `scripts/build_reference_coordinates.R` 从 **2014–2023 冻结训练期**一次性
  构建并随仓库提交；`make_monthly_panel()` 只读该文件，绝不从传入 raw
  重新计算。该表是**训练期估计量**，不是官方地理常量。
- **验证**：raw 层扰动测试（扰动未来 raw 坐标 / 追加未来 raw 记录 → 重建
  面板 → 历史 lon/lat 与 recipe fingerprint 不变）修复前失败、修复后通过；
  真实数据复验：29,880 → 0 个单元变化。

### C. 计数口径（P1-03）— 已明确并文档化

- 下载/转换脚本保留 `OBJECTID` 与 `EVENT_UNIQUE_ID`。
- 新增 `data_dictionary.md`：明确「行 ≠ 案件」——40,583 行对应 36,449
  个不同 `EVENT_UNIQUE_ID`；当前 `theft_count` 按行计数，文档不再称"报案数"。
- 新增 `data_manifest.md`：快照哈希、计数口径、修复记录。

### D. 误差解释（P1-04）— 已修正

- README 三处「系统性高估」改为「约 35% 低估」（2025 预测 1378.7 vs
  实际 2125，仅 1/2 月高估，其余 10 个月低估）。
- 新增「回变换偏差」为候选原因（待验证），不再断言因果。

### E. 工程复现（P1-06 / P2-01）— 已修复

- `download_data.py`：创建目录、ArcGIS `error` 当失败、`OBJECTID` 重复校验、
  临时文件原子替换。
- `convert_data.py`：保留主键、弃用警告修复（`utcfromtimestamp` → 时区安全）。
- `make_expanding_folds()`：改用相对月份偏移（修复 time_index 从 25 开始时
  首折只有 36 个月的 bug），并处理短序列 `wrong sign in 'by'` 边界。
- `config.R`：新增 `read_requirements()` 正确处理 `#` 注释。
- `make_design_matrix()`：显式 one-hot（修复 NSA 导致 `model.matrix` 丢行）。

### 新测试（35 R + 4 Python，全绿）

- `test/test-data-quality.R`（15）：NSA 标记、坐标排除、空间尺度、无 NA。
- `test/test-leakage.R`（6）：未来扰动不变性。
- `test/test-validation.R`（14）：折叠相对起点、短序列边界、时序完整性。
- `test/test_scripts.py`（4）：下载错误处理、目录创建、原子写入。

## 修复后的成绩（同口径对照）

| 指标 | 修复前（审计基准） | 修复后 |
|---|---|---|
| 空间尺度 | 6.663885（污染） | 0.101871 |
| 2025 test R² | 0.6651412 | 0.6671430 |
| 2025 test RMSE | 1.9686175 | 1.9627244 |
| 2025 预测合计 | 1371.45 | 1378.7 |
| 相对偏差 | −35.46% | −35.12% |

修复后分数基本持平（0.665→0.667），符合预期——空间 RBF/context 与社区
one-hot 共线（handoff 4.B），移除 NSA 对最终分数影响很小。**未以维持分数
为由保留泄漏或错误数据。**

## 未完成 / 后续（第二阶段）

按 `handoff.md` 顺序，以下留待下一步：

1. **公平模型比较**（4.A）：Poisson/NB 目前无社区固定效应、无调参，不能与
   Ridge 直接比；需建立「特征组 × 模型族」实验表。
2. **回变换偏差验证**（4.D）：验证 `expm1(E[log1p(Y)]) ≠ E[Y]` 是否解释低估。
3. **context 增益归因**（4.B）：多折消融，区分预测增益与解释性。
4. **验证协议对齐**（4.C）：若产品是「每月重训预测下月」，需 horizon=1 滚动
   回测；2025 已多次用于诊断，不宜再称「从未接触」。
5. **ZINB/hurdle**：在拟合合理 NB/GAM、检查残差零值后再决定，非优先项。

## 给接手者的注意

- 原始数据已备份至 `data/raw_backup/`（已 gitignore）。
- 数据快照哈希已更新（见 `data_manifest.md`）。
- 所有修改仅在约定项目目录内，未触碰原课程项目 `/Users/liumingyuan/Documents/project of stat38888`。
- 上传 GitHub 仍未完成（账号权限问题），需用户确认目标后再处理。
