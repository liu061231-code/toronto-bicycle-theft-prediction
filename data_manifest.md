# Data Manifest

数据快照与转换规则版本记录。用于复现与对账；数据更新时记录新版本。

## 快照信息

| 项目 | 值 |
|---|---|
| 源 | Toronto Police Service — Bicycle Thefts Open Data (ArcGIS FeatureServer) |
| 源 URL | `https://services.arcgis.com/S9th0jAJ7bqgIRjw/ArcGIS/rest/services/Bicycle_Thefts_Open_Data/FeatureServer/0` |
| 下载脚本 | `scripts/download_data.py` |
| 转换脚本 | `scripts/convert_data.py` |
| 下载时间 | 2026-09-19 (UTC) |
| 转换规则版本 | v3：保留主键及 `OCC_DATE`/`REPORT_DATE`，双输出带完整性清单 |

## 文件与哈希

| 文件 | 行数 | SHA-256 |
|---|---|---|
| `data/raw/bicycle_raw_latest.csv` | 40,583 | `55a50152f5615f8e197d7c2158335e4a293a1edefe7b7539ca82f8c0566b68da` |
| `data/raw/bicycle.csv` | 40,524 | `bd942a7bcbe33ba673b7fdec9b2ff2b747cb0d530af4522e5d003d78fb3f640b` |
| `data/raw/bicycle_enhanced.csv` | 40,524 | `b47a0705892c5dc8eabd24f0eb75c50c37da42ccfb05b929f949b0b13c508e74` |
| `data/reference/neighborhood_coordinates.csv` | 140 | `e8bb60441d7e0ec5d8b15007a4c383e2e9961f3c97f63891b45452b692ccdb97` |

## 计数口径（关键）

| 口径 | 值 |
|---|---|
| 下载行数（原始） | 40,583 |
| `OBJECTID` 唯一数 | 40,583（无重复，主键校验通过） |
| 保留行数（2014+，日期有效） | 40,524 |
| 跳过行数（pre-2014 或缺日期） | 59 |
| `EVENT_UNIQUE_ID` 唯一数（保留后） | 36,398 |
| 面板单元 | 141（140 社区 + NSA） |
| 面板观测 | 20,304（141 × 144 月，2014-01 ~ 2025-12） |

**注意**：`行数 ≠ 案件数`。40,583 行对应 36,449 个不同 `EVENT_UNIQUE_ID`
（原始）或 36,398（保留后）。当前 `theft_count` 按行计数，严格说是
「按行计数的记录量」，详见 `data_dictionary.md`。

## 修复记录

| 版本 | 变更 |
|---|---|
| v1 | 旧版：无主键、`n()` 计行数、NSA `(0,0)` 污染空间尺度、全量坐标中位数泄漏 |
| v2 | 保留 `OBJECTID`/`EVENT_UNIQUE_ID`；NSA 标记未知并排除空间特征；坐标改为固定地理常量（修复未来泄漏）；下载脚本 mkdir/错误校验/原子替换 |
| v3 | 冻结 2014–2017 坐标估计；保留发生/报案日期；下载 ID 集合对账；转换输出哈希清单 |
