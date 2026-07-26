# STAT3888 手册逐步代码一致性修复设计

## 1. 修复目标

修复 PDF 中“教学简化代码”与正式 R 管道不一致的问题，使以下两条路径产生相同的数据、
图表和模型指标：

1. 在 `/Users/liumingyuan/sta pj` RStudio Project 中按照 PDF 第 0–14 步逐步运行；
2. 在完整项目目录中运行 `source("R/run_all.R")`。

修复后，PDF 中所有标记为“运行”的代码都必须能够执行。仅用于说明函数内部机制的片段必须
明确标记为“原理展开，不单独运行”，不能与可执行代码混淆。

## 2. 单一真实管道

正式函数是唯一计算来源：

- `read_bicycle(path)`；
- `audit_bicycle(raw)`；
- `make_monthly_panel(raw)`；
- `make_task1_plots(panel, figure_dir)`；
- `split_panel(panel)`；
- `make_basis_recipe(train)`；
- `make_design_matrix(data, recipe)`；
- `fit_models(splits, recipe)`；
- `make_model_plots(fit, panel, recipe, figure_dir)`。

PDF 逐步路线调用这些函数。正文可以展示函数内部关键语句，但不得重新实现一套不同的计算。

## 3. 数据路径

`project_paths()` 不再只依赖已失效的
`/Users/liumingyuan/Downloads/four_dataset/bicycle.csv`。数据解析按以下优先级进行：

1. 环境变量 `STAT3888_BICYCLE_CSV` 指定的文件；
2. 当前项目 `data/bicycle.csv`；
3. `/Users/liumingyuan/sta pj/data/bicycle.csv`；
4. `/Users/liumingyuan/Downloads/four_dataset/bicycle.csv`；
5. `/Users/liumingyuan/Downloads/four_dataset/bicycle_副本.csv`。

候选文件必须满足预期八列。找不到时，错误信息列出所有已检查位置，并说明如何设置环境变量。
PDF 的逐步路线首先显示实际解析到的路径。

## 4. 逐步运行入口

新增 `R/handbook_step_by_step.R`，与 PDF 第 0–14 步一一对应。它负责：

- 加载项目配置和正式函数；
- 解析数据路径；
- 创建 `raw`、`audit`、`prepared`、`panel`；
- 生成 Task 1 四张图；
- 创建 `splits`、`basis_recipe`、三个设计矩阵；
- 拟合所有基线、OLS 和 Ridge；
- 输出指标、预测和诊断图；
- 运行关键 `stopifnot()` 一致性检查。

该脚本不能复制 `make_monthly_panel()`、`make_task1_plots()` 或 `fit_models()` 的实现。
它只负责按教学顺序调用正式函数和暴露中间对象。

## 5. PDF 代码规则

每一步使用以下标签：

- `可直接运行`：可以从干净 R 会话按顺序执行；
- `函数内部原理展开`：用于理解正式函数内部机制，不应作为第二套计算路径；
- `检查命令`：验证对象形状、列名、时间边界或指标；
- `预期输出`：来自真实数据运行结果。

关键修复：

- 第 1 步使用解析后的真实数据路径；
- 第 4 步调用 `make_monthly_panel()`，面板必须包含 `lon` 和 `lat`；
- 第 5 步调用 `make_task1_plots()`；
- 季节图使用 `year × month_of_year` 的城市总量，共 120 行；
- `hotspots` 和 `heat` 在原理展开中完整定义；
- 第 7 步使用同一个训练期 `basis_recipe`；
- 第 10 步通过 `fit_models()` 完成 Ridge 选择、重拟合和预测；
- 第 11 步直接读取 `model_fit$metrics`；
- 第 12 步从 `model_fit$test_predictions` 建立诊断对象。

## 6. 必须一致的检查点

逐步路线和一键路线必须同时满足：

- 原始数据：31,833 行、8 个原始字段；
- 社区数：140；
- 完全重复行：1,475；
- 面板：16,800 行、包含 `lon` 和 `lat`；
- 每个社区：120 个月；
- 训练/验证/测试：13,440 / 1,680 / 1,680 行；
- 时间节点：20、39、58、77；
- RBF 中心：16；
- 模型指标与 `output/analysis/model_metrics.csv` 在容差 `1e-8` 内一致。

目标测试结果：

- Global mean：MAE 2.1873、RMSE 4.1670、R² -0.00696；
- Neighborhood mean：MAE 1.4111、RMSE 2.7258、R² 0.5691；
- Basis OLS：MAE 1.0082、RMSE 2.0483、R² 0.7567；
- Basis Ridge：MAE 1.0063、RMSE 2.0600、R² 0.7539。

## 7. 测试策略

测试必须先复现当前缺陷：

- 旧绝对路径失效；
- PDF 式手工面板缺少 `lon`、`lat`；
- 简化季节图使用 16,800 行而正式图使用 120 行；
- `hotspots`、`heat` 或 `test_predictions` 未生成即被引用。

修复后增加：

- 数据路径解析测试；
- 逐步入口对象形状测试；
- 逐步指标与一键指标一致性测试；
- PDF 文本测试，禁止再次出现把 `panel` 直接用于季节箱线图的错误片段；
- PDF 构建、文本提取和逐页渲染测试。

## 8. 排版与交付

- 保持紧凑单栏版式；
- 不通过增加空白制造页数；
- 可执行代码与原理展开使用不同标题和底色；
- 稳定覆盖
  `output/pdf/STAT3888_自行车盗窃时空基函数回归_完整项目手册.pdf`；
- 使用 WPS Office 打开最终 PDF；
- 保留全部源代码、测试和分析输出。

## 9. 范围边界

- 不改变数据集、研究问题、Task 1 + Task 4 选择；
- 不改变已经验证的模型结构和结论；
- 不因为修复手册而增加新的模型；
- 不删除原始重复记录；
- 不把测试集用于选择模型；
- 不把教学解释重新变成独立计算实现。
