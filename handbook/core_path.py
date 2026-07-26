"""Executable beginner route backed by the production R pipeline."""


def note(label, text, tone="core"):
    return {"kind": "teaching", "label": label, "text": text, "tone": tone}


def code(text, caption="可直接运行", tone="execute"):
    return {
        "kind": "code",
        "text": text,
        "caption": caption,
        "tone": tone,
    }


def principle_code(text):
    return code(
        text,
        "函数内部原理展开（不单独运行）",
        "principle",
    )


def bullets(*items):
    return {"kind": "bullets", "items": list(items)}


def step(number, title, purpose, reason, inputs, r_code, explanations,
         expected, check, error, rubric, extra=None):
    blocks = [
        note("这一步解决什么问题", purpose),
        note("为什么现在运行", reason),
        note("输入对象", inputs),
        code(r_code),
        note("逐行解释", explanations),
        note("运行后应该看到", expected, "result"),
        code(check, "检查命令", "check"),
        note("常见错误", error, "warning"),
        note("评分连接", rubric, "rubric"),
    ]
    if extra:
        blocks.extend(extra)
    return {
        "title": f"第{number}步：{title}",
        "level": "核心路径·照做与理解",
        "blocks": blocks,
    }


CORE_PATH_SECTIONS = [
    step(
        0,
        "连接真实分析管道并检查环境",
        "让你当前的 RStudio Project 调用已经验证的正式函数，同时仍把输出保存在当前 Project。",
        "以前 PDF 重新写了一套简化代码，容易与正式结果分叉。现在先加载唯一真实管道，后面每一步只调用这些函数。",
        "当前工作目录应为 `/Users/liumingyuan/sta pj`；正式代码位于 `/Users/liumingyuan/Documents/project of stat38888`。",
        'getwd()\n'
        'project_code_root <- "/Users/liumingyuan/Documents/project of stat38888"\n'
        'source(file.path(\n'
        '  project_code_root, "R", "handbook_step_by_step.R"\n'
        '))\n'
        'workspace_root <- getwd()\n'
        'paths <- project_paths(workspace_root)\n'
        'ensure_packages()\n'
        'paths$source_csv',
        "`getwd()` 返回当前 RStudio Project。`project_code_root` 只告诉 R 正式函数放在哪里；`source()` 把这些函数加载进当前会话。"
        "`workspace_root <- getwd()` 决定分析 CSV、图片和结果保存在哪里。`project_paths(workspace_root)` 调用 "
        "`resolve_bicycle_csv()` 寻找真实数据，而不再依赖一个失效的绝对文件名。`ensure_packages()` 只检查包，不改变数据。",
        "控制台显示你当前 Project 的路径和一个确实存在的 bicycle CSV。Environment 中出现 `run_handbook_steps` 等函数。",
        'stopifnot(dir.exists(workspace_root))\n'
        'stopifnot(file.exists(paths$source_csv))\n'
        'all(c("tidyverse", "lubridate", "glmnet") %in%\n'
        '    rownames(installed.packages()))',
        "若 `source()` 找不到文件，检查 `project_code_root` 是否原样复制。若提示缺少软件包，只对缺失包运行 "
        "`install.packages(c(\"包名\"))`，安装后重新执行 `ensure_packages()`。",
        "清楚区分“代码仓库”和“分析工作目录”，能够避免路径错误并证明项目可复现。",
    ),
    step(
        1,
        "解析数据路径并读取事件表",
        "读取与最终报告完全相同的 bicycle CSV，并用正式读取函数创建 `raw`。",
        "数据副本或路径不同会让后续所有数字不一致，所以第一步必须显示实际读取的是哪个文件。",
        "`paths$source_csv`：路径解析器找到的现存文件；每行是一条被报告的盗窃事件。",
        'data_path <- resolve_bicycle_csv(workspace_root)\n'
        'raw <- read_bicycle(data_path)\n'
        'original_columns <- c(\n'
        '  "date", "quarter", "day_of_week", "neighborhood",\n'
        '  "bike_cost", "location", "long", "lat"\n'
        ')\n'
        'c(rows = nrow(raw), original_columns = length(original_columns))\n'
        'dplyr::glimpse(raw[, original_columns])',
        "`resolve_bicycle_csv()` 的优先级是环境变量、当前 Project 的 `data/bicycle.csv`、你现有的 `sta pj/data` 和下载目录副本。"
        "`raw <-` 把 `read_bicycle()` 的返回值保存为对象；`<-` 表示赋值。该函数内部使用 `readr::read_csv(..., "
        "show_col_types = FALSE)`；`readr::` 指明函数来源，`show_col_types` 只关闭提示。正式 `raw` 还增加四个季度审计辅助列，"
        "因此检查原始字段时显式选择 `original_columns`。",
        "显示 31,833 行、8 个原始字段；日期范围为 2014-01-01 至 2023-12-31。",
        'stopifnot(nrow(raw) == 31833L)\n'
        'stopifnot(all(original_columns %in% names(raw)))\n'
        'range(raw$date)\n'
        'data_path',
        "若行数不是 31,833，立即停止并查看 `data_path`。不要通过改期望数字让检查通过；先确认没有读取其他城市或修改后的 CSV。",
        "明确数据版本、观测单位和样本量，是数据介绍与全部结果可信性的起点。",
    ),
    step(
        2,
        "运行正式数据审计",
        "用与一键管道相同的 `audit_bicycle()` 统计缺失、重复、社区数和季度不一致。",
        "审计必须先于删除。没有事件 ID 时，完全相同行不一定是重复录入。",
        "`raw`：包含八个原始字段和正式读取函数生成的季度辅助字段。",
        'audit <- audit_bicycle(raw)\n'
        'audit',
        "`audit_bicycle()` 内部使用 `is.na()` 统计缺失、`duplicated()` 标记与前行相同的记录、`n_distinct()` 统计社区。"
        "它比较从 date 推导的季度与原 quarter，但不修改原始文件，也不执行 `distinct()`。",
        "缺失单元格 0；完全重复行 1,475；社区 140；quarter 不一致 15,751。",
        'stopifnot(audit$value[audit$metric == "rows"] == 31833)\n'
        'stopifnot(audit$value[audit$metric == "exact_duplicate_rows"] == 1475)\n'
        'stopifnot(audit$value[audit$metric == "neighborhoods"] == 140)',
        "不要对 `raw` 运行 `distinct()` 后再继续，否则盗窃计数、所有图和模型指标都会改变。季度分析使用 date 推导值。",
        "高分数据清洗强调有证据的决定：保留不确定重复记录，并明确说明理由。",
        extra=[
            principle_code(
                'raw |>\n'
                '  dplyr::mutate(\n'
                '    date = as.Date(date),\n'
                '    derived_quarter = paste0(\n'
                '      lubridate::year(date), "Q",\n'
                '      lubridate::quarter(date)\n'
                '    )\n'
                '  )'
            )
        ],
    ),
    step(
        3,
        "调用正式函数构造社区 × 月份数据",
        "把事件表转换成统一的社区月份分析单位，但不另写第二套 `count()` 逻辑。",
        "Task 1 和 Task 4 必须共享同一个面板。调用正式函数可以保证逐步路线与一键路线不会再次漂移。",
        "`raw`；输出 `prepared`，其中同时包含完整面板和社区中心坐标表。",
        'prepared <- make_monthly_panel(raw)\n'
        'panel <- prepared$panel\n'
        'coordinates <- prepared$coordinates\n'
        'dim(panel)\n'
        'names(panel)',
        "`make_monthly_panel(raw)` 是唯一面板构造入口。`prepared$panel` 用 `$` 从列表取出面板；"
        "`prepared$coordinates` 保存每个社区的中心经纬度。`dim()` 返回行列数，`names()` 检查列是否完整。",
        "`panel` 为 16,800 × 8，包含 neighborhood、month、theft_count、lon、lat、time_index、month_of_year、year。",
        'stopifnot(nrow(panel) == 16800L)\n'
        'stopifnot(all(c("lon", "lat") %in% names(panel)))\n'
        'stopifnot(nrow(coordinates) == 140L)',
        "若只有 6 列，说明你运行了旧 PDF 的手工 `complete()` 代码，而没有调用 `make_monthly_panel(raw)`。请删除旧 panel 并重新执行本步。",
        "统一面板同时支撑时间、空间可视化和模型，是方法一致性的核心证据。",
        extra=[
            principle_code(
                'monthly_counts <- raw |>\n'
                '  dplyr::mutate(\n'
                '    month = lubridate::floor_date(date, "month")\n'
                '  ) |>\n'
                '  dplyr::count(\n'
                '    neighborhood, month, name = "theft_count"\n'
                '  )'
            ),
            note(
                "为什么使用管道",
                "`|>` 把左侧对象传给右侧函数；`mutate()` 新增月份；`count()` 按社区和月份计数。"
                "这段展示正式函数内部原理，不应另行生成替代 panel。",
            ),
        ],
    ),
    step(
        4,
        "检查零事件月份、坐标和时间索引",
        "证明正式面板既补齐了 0，又保留了空间坐标和建模所需时间字段。",
        "旧 PDF 只补齐计数却漏掉 lon/lat，导致 RBF 和地图无法运行。本步专门阻止该错误再次出现。",
        "`panel`：第 3 步由正式函数生成的 16,800 行面板。",
        'panel |>\n'
        '  dplyr::summarise(\n'
        '    rows = dplyr::n(),\n'
        '    zero_months = sum(theft_count == 0),\n'
        '    missing_counts = sum(is.na(theft_count)),\n'
        '    missing_coordinates = sum(is.na(lon) | is.na(lat)),\n'
        '    first_index = min(time_index),\n'
        '    last_index = max(time_index)\n'
        '  )',
        "`summarise()` 把多行压缩为检查摘要；`n()` 统计行数。0 表示该社区月份没有记录，NA 表示未知，两者不能混淆。"
        "`time_index` 把 2014-01 至 2023-12 编为 1–120。",
        "16,800 行；计数和坐标均无缺失；time_index 范围为 1–120；每个社区 120 个月。",
        'stopifnot(!anyNA(panel$theft_count))\n'
        'stopifnot(!anyNA(panel$lon), !anyNA(panel$lat))\n'
        'stopifnot(all(table(panel$neighborhood) == 120L))\n'
        'stopifnot(identical(range(panel$time_index), c(1L, 120L)))',
        "若坐标缺失，不要手工用 0 填充；回到第 3 步确认使用正式函数。经纬度为社区中心，不是案件精确地点。",
        "检查空间字段与零月份可避免错误图和错误设计矩阵进入展示。",
        extra=[
            principle_code(
                'tidyr::complete(\n'
                '  neighborhood = unique(raw$neighborhood),\n'
                '  month = months,\n'
                '  fill = list(theft_count = 0L)\n'
                ') |>\n'
                'dplyr::left_join(coordinates, by = "neighborhood")'
            )
        ],
    ),
    step(
        5,
        "用正式函数生成 Task 1 四张图",
        "生成与最终 PDF 和一键管道完全相同的时间、季节、空间和时空图。",
        "Task 1 占 30%。每张图必须使用正确聚合口径，特别是季节图不能把 16,800 个社区月份误当成 120 个城市月份。",
        "`panel` 与 `paths$figure_dir`；输出四个真实 PNG 路径。",
        'task1_paths <- make_task1_plots(panel, paths$figure_dir)\n'
        'task1_paths',
        "`make_task1_plots()` 内部建立四个对象并保存图。时间图使用城市月总数；季节图先按 year 和 month_of_year 汇总，"
        "因此一月至十二月每组各有十个年份观测；空间图使用社区长期月均；热力图使用前 25 个高值社区。",
        "trend、seasonality、hotspots、heatmap 四个路径均存在，输出目录出现四张 PNG。",
        'stopifnot(length(task1_paths) == 4L)\n'
        'stopifnot(all(file.exists(task1_paths)))\n'
        'names(task1_paths)',
        "若季节箱线图数值集中在 0–几起，说明仍在使用旧代码直接画社区月份。正式季节图是全市月总数，应为数百量级。",
        "正确聚合让图真正回答趋势、季节、空间热点和时空持续性四个问题。",
        extra=[
            principle_code(
                'monthly <- panel |>\n'
                '  dplyr::group_by(month) |>\n'
                '  dplyr::summarise(\n'
                '    thefts = sum(theft_count), .groups = "drop"\n'
                '  )\n'
                'seasonal <- panel |>\n'
                '  dplyr::group_by(year, month_of_year) |>\n'
                '  dplyr::summarise(\n'
                '    thefts = sum(theft_count), .groups = "drop"\n'
                '  )\n'
                'hotspots <- panel |>\n'
                '  dplyr::group_by(neighborhood, lon, lat) |>\n'
                '  dplyr::summarise(\n'
                '    mean_monthly = mean(theft_count), .groups = "drop"\n'
                '  )\n'
                'top_names <- hotspots |>\n'
                '  dplyr::slice_max(mean_monthly, n = 25) |>\n'
                '  dplyr::pull(neighborhood)\n'
                'heat <- panel |>\n'
                '  dplyr::filter(neighborhood %in% top_names)'
            ),
            note(
                "ggplot 如何使用这些对象",
                "`ggplot(data, aes(...))` 负责数据与坐标、颜色或大小的映射；`geom_line()` 画时间线，"
                "`geom_boxplot()` 画季节分布，`geom_point()` 画空间热点，`geom_tile()` 画时空热力图。",
            ),
        ],
    ),
    step(
        6,
        "按时间划分训练、验证和测试集",
        "用过去估计、用 2022 选择设置、用完全未见的 2023 报告泛化结果。",
        "随机拆行会让同一社区未来月份泄漏进训练，使结果虚高。",
        "`panel`，其中 year 已由 month 推导。",
        'splits <- split_panel(panel)\n'
        'train <- splits$train\n'
        'validation <- splits$validation\n'
        'test <- splits$test\n'
        'vapply(splits, nrow, integer(1))',
        "`split_panel()` 内部使用 `filter()`：year<=2021、year==2022、year==2023。`==` 是相等比较，"
        "单个 `=` 不能在这里替代它。列表中的三个对象互不重叠。",
        "train 13,440 行；validation 1,680 行；test 1,680 行。",
        'stopifnot(max(train$year) < min(validation$year))\n'
        'stopifnot(max(validation$year) < min(test$year))\n'
        'stopifnot(sum(vapply(splits, nrow, integer(1))) == 16800L)',
        "不要使用 `sample()`；不要在看到 test 指标后修改模型并反复重测。",
        "无泄漏时间验证是 Task 4 可信度最重要的证据之一。",
    ),
    step(
        7,
        "构造同一套时空基函数设计矩阵",
        "把时间、季节、位置和社区转换为模型可读取的数值列，并保证三个数据段列结构完全一致。",
        "设计矩阵 X 是高等代数与回归的连接。节点、中心和因子水平必须只由训练集确定。",
        "`splits`；输出 `basis_recipe` 和三个数值矩阵。",
        'basis_recipe <- make_basis_recipe(splits$train)\n'
        'x_train <- make_design_matrix(\n'
        '  splits$train, basis_recipe\n'
        ')\n'
        'x_validation <- make_design_matrix(\n'
        '  splits$validation, basis_recipe\n'
        ')\n'
        'x_test <- make_design_matrix(\n'
        '  splits$test, basis_recipe\n'
        ')\n'
        'c(dim(x_train), dim(x_validation), dim(x_test))',
        "`make_basis_recipe()` 保存 B-spline 节点、经纬度中心与尺度、16 个 RBF 中心和社区 levels。"
        "`make_design_matrix()` 对三个数据段复用同一 recipe；内部用 `model.matrix(~ neighborhood - 1)` 创建社区 0/1 列。",
        "时间节点为 20、39、58、77；RBF 中心 16；三个矩阵列数和列名完全相同。",
        'stopifnot(identical(\n'
        '  as.numeric(basis_recipe$time_knots), c(20, 39, 58, 77)\n'
        '))\n'
        'stopifnot(nrow(basis_recipe$rbf_centers) == 16L)\n'
        'stopifnot(identical(colnames(x_train), colnames(x_test)))',
        "若矩阵列数不同，通常是分别重新计算社区 levels 或 recipe。不要从 validation/test 重新选择节点或 RBF 中心。",
        "公式、设计矩阵和代码一一对应，证明模型不是黑箱。",
        extra=[
            principle_code(
                'time_basis <- splines::bs(\n'
                '  data$time_index,\n'
                '  knots = recipe$time_knots,\n'
                '  Boundary.knots = recipe$time_boundary,\n'
                '  degree = 3\n'
                ')\n'
                'seasonal <- cbind(\n'
                '  sin1 = sin(2*pi*data$month_of_year/12),\n'
                '  cos1 = cos(2*pi*data$month_of_year/12)\n'
                ')\n'
                'neighborhood_basis <- stats::model.matrix(\n'
                '  ~ neighborhood - 1, data = data\n'
                ')'
            )
        ],
    ),
    step(
        8,
        "一次拟合全部基线、OLS 和 Ridge",
        "调用唯一正式建模函数，避免分别复制四套预测代码造成结果漂移。",
        "所有比较必须使用同一测试行、同一反变换和同一评价指标。",
        "`splits` 和训练期 `basis_recipe`。",
        'model_fit <- fit_models(splits, basis_recipe)\n'
        'baseline_predictions <- model_fit$test_predictions |>\n'
        '  dplyr::select(\n'
        '    month, neighborhood, actual,\n'
        '    global_mean, neighborhood_mean\n'
        '  )\n'
        'dplyr::slice_head(baseline_predictions, n = 3)',
        "`fit_models()` 同时生成全局均值、社区历史均值、Basis OLS 和 Basis Ridge。"
        "这里仅从 `model_fit$test_predictions` 读取已经计算好的基线，而不是重新实现均值连接逻辑。",
        "`baseline_predictions` 有 1,680 行；全局均值每行相同，社区均值随 neighborhood 改变。",
        'stopifnot(nrow(baseline_predictions) == nrow(test))\n'
        'stopifnot(!anyNA(baseline_predictions))',
        "若重新手写基线时使用 2022 或 2023 均值，会产生泄漏。使用 `model_fit` 可保证与一键管道一致。",
        "透明基线证明复杂模型是否真正带来额外价值。",
        extra=[
            principle_code(
                'global_prediction <- rep(\n'
                '  mean(train$theft_count), nrow(test)\n'
                ')\n'
                'neighborhood_means <- train |>\n'
                '  dplyr::group_by(neighborhood) |>\n'
                '  dplyr::summarise(\n'
                '    value = mean(theft_count), .groups = "drop"\n'
                '  )'
            )
        ],
    ),
    step(
        9,
        "检查 OLS 基函数预测",
        "理解最小二乘如何把设计矩阵变成 2023 预测，同时读取正式模型已经生成的 OLS 结果。",
        "OLS 是 Task 4 的直接实现，也是本数据上测试 RMSE 最低的模型。",
        "`model_fit$test_predictions` 中的 `basis_ols` 列。",
        'ols_predictions <- model_fit$test_predictions |>\n'
        '  dplyr::select(\n'
        '    month, neighborhood, actual, basis_ols\n'
        '  )\n'
        'summary(ols_predictions$basis_ols)',
        "`basis_ols` 已由正式 `fit_models()` 生成。模型先对 `log1p(theft_count)` 拟合，再用 `expm1()` 返回计数尺度并截断负值。"
        "矩阵乘法 `%*%` 对应高等代数中的 Xβ。",
        "1,680 个非负 OLS 预测；测试 MAE 约 1.008、RMSE 约 2.048、R² 约 0.757。",
        'stopifnot(nrow(ols_predictions) == 1680L)\n'
        'stopifnot(all(is.finite(ols_predictions$basis_ols)))\n'
        'stopifnot(all(ols_predictions$basis_ols >= 0))',
        "不要拿 log 尺度预测直接与原始计数计算误差；不要逐个解释大量基函数系数为因果效应。",
        "OLS 将 y=Xβ+ε、R 代码和测试集预测连成可解释证据链。",
        extra=[
            principle_code(
                'fit_ols <- function(x, y) {\n'
                '  fit <- stats::lm.fit(\n'
                '    cbind(Intercept = 1, x), y\n'
                '  )\n'
                '  fit$coefficients\n'
                '}\n'
                'prediction <- pmax(\n'
                '  0, expm1(cbind(Intercept = 1, x_test) %*% beta)\n'
                ')'
            )
        ],
    ),
    step(
        10,
        "检查 Ridge 的 λ 选择和最终预测",
        "确认 Ridge 只用 2022 选择 λ，随后用 2014–2022 重拟合并预测 2023。",
        "旧 PDF 只算到 best_lambda，没有完成最终 Ridge 拟合与预测；现在所有结果都直接来自正式函数。",
        "`model_fit`，包含 selected_lambda、validation_rmse、ridge_model 和最终 predicted 列。",
        'model_fit$selected_lambda\n'
        'model_fit$validation_rmse\n'
        'ridge_predictions <- model_fit$test_predictions |>\n'
        '  dplyr::select(\n'
        '    month, neighborhood, actual, predicted\n'
        '  )\n'
        'summary(ridge_predictions$predicted)',
        "`selected_lambda` 是验证 RMSE 最小的候选值。`predicted` 是 Ridge 在 2023 的最终计数尺度预测。"
        "`glmnet(..., alpha=0)` 表示 Ridge；`standardize=TRUE` 统一特征尺度。",
        "λ 约 1e-4；Ridge 测试 MAE 约 1.006、RMSE 约 2.060、R² 约 0.754，略逊于 OLS RMSE。",
        'stopifnot(model_fit$selected_lambda >= 1e-4)\n'
        'stopifnot(nrow(ridge_predictions) == 1680L)\n'
        'stopifnot(all(ridge_predictions$predicted >= 0))',
        "不要用 test 选择 λ；不要因为 Ridge 更新就宣布它获胜。本项目应如实报告 OLS 的 RMSE 略低。",
        "完整超参数选择、重拟合和时间外预测体现现代建模规范。",
        extra=[
            principle_code(
                'ridge_path <- glmnet::glmnet(\n'
                '  x_train, log1p(train$theft_count),\n'
                '  alpha = 0, lambda = lambda_grid,\n'
                '  standardize = TRUE\n'
                ')\n'
                'selected_lambda <- lambda_grid[\n'
                '  which.min(validation_rmse)\n'
                ']\n'
                'ridge_final <- glmnet::glmnet(\n'
                '  x_train_validation, y_train_validation,\n'
                '  alpha = 0, lambda = selected_lambda\n'
                ')'
            )
        ],
    ),
    step(
        11,
        "读取统一的 MAE、RMSE 和 R²",
        "从正式模型对象读取同一 2023 测试集上的四模型指标。",
        "不再手工重算部分模型，避免预测向量、尺度或测试行不一致。",
        "`model_fit$metrics`。",
        'metrics <- model_fit$metrics\n'
        'metrics',
        "`MAE` 是平均绝对误差；`RMSE` 对大错惩罚更强；`R²=1-SSE/SST` 比较模型与测试均值基准。"
        "R² 不是预测正确百分比，负值表示比均值基准更差。",
        "Global mean：2.187/4.167/-0.00696；Neighborhood mean：1.411/2.726/0.569；"
        "Basis OLS：1.008/2.048/0.757；Basis Ridge：1.006/2.060/0.754。",
        'stopifnot(nrow(metrics) == 4L)\n'
        'stopifnot(all(c("MAE", "RMSE", "R2") %in% names(metrics)))\n'
        'stopifnot(metrics$RMSE[metrics$model == "Basis OLS"] <\n'
        '          metrics$RMSE[metrics$model == "Neighborhood mean"])',
        "若数值不同，先检查是否删除过重复行、是否漏补 0、是否随机拆分、是否忘记反变换；不要先修改期望结果。",
        "统一指标表是 Task 4 结论页最重要的量化证据。",
    ),
    step(
        12,
        "从正式预测对象生成诊断图",
        "检查模型在哪些月份和社区系统性低估或高估。",
        "旧 PDF 直接引用未创建的 `test_predictions`；现在明确从 `model_fit$test_predictions` 取得。",
        "`model_fit$test_predictions`、`panel`、`basis_recipe` 和输出目录。",
        'test_predictions <- model_fit$test_predictions\n'
        'model_paths <- make_model_plots(\n'
        '  model_fit, panel, basis_recipe, paths$figure_dir\n'
        ')\n'
        'diagnostic <- test_predictions |>\n'
        '  dplyr::mutate(residual_check = actual - predicted)\n'
        'model_paths',
        "`test_predictions` 已包含 actual、predicted 和 residual。`make_model_plots()` 生成基函数、模型比较、预测折线和残差地图。"
        "`mutate()` 再算 residual_check 只用于验证正式 residual 的定义。",
        "四张模型图存在；residual 与 actual-predicted 在数值容差内完全一致。",
        'stopifnot(all(file.exists(model_paths)))\n'
        'stopifnot(max(abs(\n'
        '  diagnostic$residual - diagnostic$residual_check\n'
        ')) < 1e-10)',
        "正残差表示实际高于预测，即模型低估。不要把残差热点写成社区导致盗窃。",
        "诊断失败模式比只报告最好分数更能体现分析深度。",
    ),
    step(
        13,
        "把真实证据压缩为四页 PowerPoint",
        "用已验证图和指标建立“问题→发现→方法→结论”的四页叙事。",
        "项目最多四页；选择证据比堆叠全部代码更重要。",
        "`task1_paths`、`metrics`、`model_paths` 和局限性结论。",
        'slide_plan <- tibble::tribble(\n'
        '  ~page, ~question, ~evidence,\n'
        '  1, "研究什么？", "数据、问题、流程",\n'
        '  2, "发现什么？", "趋势、季节、热点",\n'
        '  3, "怎样建模？", "基函数、时间切分、指标",\n'
        '  4, "结论可信到哪里？", "预测、残差、局限"\n'
        ')\n'
        'slide_plan',
        "`tribble()` 建立展示检查表；`~page` 等带波浪号的项定义列名。它不是生成 PPT，而是确保每页只回答一个问题。",
        "得到 4 × 3 的页面计划。",
        'stopifnot(nrow(slide_plan) == 4L)\n'
        'stopifnot(length(unique(slide_plan$page)) == 4L)',
        "不要把代码截图塞入 PPT；不要把 R² 0.757 写成 75.7% 预测正确。",
        "表达与逻辑占 30%，四页必须形成连续证据链。",
    ),
    step(
        14,
        "从干净会话一键复现并核对逐步结果",
        "证明逐步路线和一键路线调用同一管道并产生相同输出。",
        "Environment 中残留对象可能掩盖依赖错误；最终提交前必须从头运行。",
        "当前 RStudio Project 的 `data/bicycle.csv` 和正式代码目录。",
        'rm(list = ls())\n'
        'project_code_root <- "/Users/liumingyuan/Documents/project of stat38888"\n'
        'source(file.path(\n'
        '  project_code_root, "R", "handbook_step_by_step.R"\n'
        '))\n'
        'result <- run_handbook_steps(\n'
        '  write_outputs = TRUE,\n'
        '  workspace_root = getwd()\n'
        ')\n'
        'result$model_fit$metrics',
        "`rm(list=ls())` 只清空 R 内存对象，不删除磁盘文件。`run_handbook_steps()` 按第 1–12 步相同顺序调用正式函数；"
        "`workspace_root=getwd()` 让结果写入当前 `/Users/liumingyuan/sta pj/output`。",
        "自动生成审计 CSV、16,800 行面板、预测 CSV、模型指标和 8 张图；指标与第 11 步完全相同。",
        'stopifnot(nrow(result$panel) == 16800L)\n'
        'stopifnot(all(c("lon", "lat") %in% names(result$panel)))\n'
        'stopifnot(nrow(result$model_fit$metrics) == 4L)\n'
        'list.files(file.path(getwd(), "output", "figures"))',
        "若清空后失败，说明前面曾依赖未显式生成的对象。不要用旧 Environment 补对象；从错误出现的第一步修正。",
        "逐步与一键结果一致，是本手册修复后的最终可复现性证明。",
    ),
]
