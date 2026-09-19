# Data Dictionary

本文档明确本项目数据中「一行、一个案件、一辆自行车」之间的关系，以及计数、
时间、地域、重复和迟报的口径。它是审计与复现的基础，任何涉及"数量"的说法
都必须与本口径一致。

## 1. 数据来源

- **发布方**：多伦多警察局（Toronto Police Service）公开数据集
  "Bicycle Thefts Open Data"。
- **ArcGIS FeatureServer**：
  `https://services.arcgis.com/S9th0jAJ7bqgIRjw/ArcGIS/rest/services/Bicycle_Thefts_Open_Data/FeatureServer/0`
- **门户**：
  - Toronto Police 数据目录：`https://data.torontopolice.on.ca/datasets/TorontoPS::bicycle-thefts-open-data`
  - 多伦多市开放数据门户：`https://open.toronto.ca/dataset/bicycle-thefts/`
- **快照**：本仓库基准快照 `data/raw/bicycle_raw_latest.csv` 记录 40,583 行，
  时间跨度 2014–2026（2026 为进行中的部分年份）。

## 2. 一行 / 一个案件 / 一辆自行车

这是最关键的计数口径，直接决定"预测什么"。

| 概念 | 定义 | 证据 |
|---|---|---|
| **一行（row）** | CSV 中的一条记录 | 40,583 行 |
| **一个案件（event）** | 由 `EVENT_UNIQUE_ID` 标识的一次报案事件 | 40,583 行 → 36,449 个不同 `EVENT_UNIQUE_ID` |
| **一辆自行车** | 单次事件中被盗的具体车辆 | 无法从现有字段唯一识别 |

**核心结论**：`EVENT_UNIQUE_ID` 不是行主键。40,583 行只对应 36,449 个不同
事件，只能证明一个事件 ID 对应多行；车辆数量及拆行原因需官方代码本确认。因此：

- **`n()`（按行计数）≠ 报案数（事件数）**。
- 当前管线对 `theft_count` 用 `n()` 按行聚合，严格说是「按行计数的记录量」，
  而非「独立案件数」。在数据口径进一步核实前，文档与指标命名不得将其包装成
  未经核实的"案件数"。

### 对象主键（OBJECTID）

- `OBJECTID` 是 ArcGIS 服务端的对象主键，用于识别单条记录、检测下载重复。
- 下载脚本 `scripts/download_data.py` 会校验 `OBJECTID` 是否唯一，重复即失败。
- 旧版下载脚本未请求 `OBJECTID`；当前版本已补上。转换脚本
  `scripts/convert_data.py` 会把 `OBJECTID` 与 `EVENT_UNIQUE_ID` 一并写入输出，
  便于对账。

## 3. 时间口径

| 字段 | 含义 | 用途 |
|---|---|---|
| `OCC_DATE` | 案件**发生**日期（occurence） | 当前按此聚合为"发生月份" |
| `REPORT_DATE` | 案件**报案**日期 | 未用于当前聚合 |

**迟报（late reporting）**：2025 年发生的记录中有 26 行在 2026 年才报案。
当前快照即便有 `REPORT_DATE`，也无法完全重建历史数据库的修订状态；无历史
快照时应披露回顾性评估的这一限制。

**预测起点**：预测未来月份时，只能使用截至预测起点已可得的记录。迟报意味着
"截至某月已知的数量"会随时间上修，属于部署时的数据可用性约束。

## 4. 地域口径

- **140 个历史社区（neighbourhoods）** + **1 个 `NSA`（Not Specified Area，
  未指定区域）** = 141 个面板单元。
- **`NSA` 是"未知区域"的兜底分类，不是真实社区**：
  - 40,583 行中 370 行属于 NSA；
  - 其中 359 行坐标为 `(0, 0)`（无效），11 行有有效坐标（2014–2019 早期记录，
    编码不一致的历史遗留）。
  - NSA 整类标记为未知，**坐标置为 NA，不参与任何空间距离 / RBF 计算**，
    避免单个 `(0,0)` 点将空间尺度放大约 65 倍、把地图压缩成一团。
- **坐标**：社区坐标来自**冻结的、版本化的参考表**
  `data/reference/neighborhood_coordinates.csv`。该表由
  `scripts/build_reference_coordinates.R` 一次性构建：取 **2014-01-01 至
  2017-12-31（冻结训练期）** 内各社区有效事件坐标的中位数，并随仓库提交。
  主流水线只读取该文件、**绝不从传入的原始事件重新计算坐标**——这是
  feedback2.0 P0 Task 1 的硬性要求：从全量事件计算坐标会让未来记录移动
  历史训练特征（修复前实测 29,880 个训练期单元随未来扰动改变）。
  **诚实性说明**：这些坐标是**训练期估计量**，不是官方地理常量；社区的真实
  物理位置虽不随时间变化，但本表是对它的一个特定数据快照估计。若将来采用
  多伦多市官方社区质心表，替换该文件并更新 `source_version` 即可。
- **坐标精度**：发布方为保护隐私将坐标偏移到最近的道路交叉口，因此分析仅在
  社区粒度有效，不适用于地址级。

## 5. 重复与缺失

| 情形 | 数量 | 处理 |
|---|---|---|
| 完整输出行重复 | 0（OBJECTID 唯一） | 不按事件 ID 擅自去重 |
| 仅 8 个建模列重复 | 1,923 | 属于列投影后的重复，非完整原始行重复 |
| NSA 记录 | 370 行 | 保留计数，坐标置 NA，排除空间特征 |
| 零 / 缺失坐标 | 359 行（均为 NSA） | 同上 |
| `EVENT_UNIQUE_ID` 重复 | 40,583 − 36,449 = 4,134 行 | 保留，按行计数但注明口径 |

## 6. 预测目标与命名

- **预测目标（当前）**：`theft_count` = 某社区某月的**按行计数的记录量**
  （`n()` 聚合），单位「记录条数/社区/月」。
- **建议命名**：在数据口径最终核实前，使用「已记录失窃记录数」而非
  「报案数」或「案件数」，避免把行数包装成未经核实的事件数。
- **候选目标（待定）**：
  - 已报告的失窃**自行车**记录数；
  - 独立**案件**数（按 `EVENT_UNIQUE_ID` 去重）；
  - 新**报案量**（按 `REPORT_DATE`）。
  三者口径不同，切换目标时必须同步更新聚合规则、文档与指标命名，并重新对账。

## 7. 数据管道与对账

| 步骤 | 脚本 | 输入 → 输出 |
|---|---|---|
| 下载 | `scripts/download_data.py` | ArcGIS API → `data/raw/bicycle_raw_latest.csv` |
| 转换 | `scripts/convert_data.py` | `bicycle_raw_latest.csv` → `bicycle.csv` + `bicycle_enhanced.csv` |
| 面板 | `src/prepare_data.R::make_monthly_panel()` | `bicycle.csv` → 月度平衡面板 |

**对账要求**：处理前后总量必须逐项对账——下载行数、`OBJECTID` 唯一数、
`EVENT_UNIQUE_ID` 唯一数、NSA 行数、零坐标行数、建模记录数、未知记录数。

## 8. 基准快照

| 文件 | SHA-256 |
|---|---|
| `data/raw/bicycle_raw_latest.csv` | `55a50152f5615f8e197d7c2158335e4a293a1edefe7b7539ca82f8c0566b68da` |
| `data/raw/bicycle.csv` | `bd942a7bcbe33ba673b7fdec9b2ff2b747cb0d530af4522e5d003d78fb3f640b` |
| `data/raw/bicycle_enhanced.csv` | `b47a0705892c5dc8eabd24f0eb75c50c37da42ccfb05b929f949b0b13c508e74` |

> 上述哈希来自修复后的数据快照（v2，保留 OBJECTID/EVENT_UNIQUE_ID）。
> 官方数据持续更新，重新下载后内容可能变化；数据变化时记录新版本，
> 不要把差异自动当成程序错误。
