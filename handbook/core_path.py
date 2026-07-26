"""Beginner-facing, executable core route for the STAT3888 handbook."""


def note(label, text, tone="core"):
    return {"kind": "teaching", "label": label, "text": text, "tone": tone}


def code(text, caption="在 RStudio Console 中运行"):
    return {"kind": "code", "text": text, "caption": caption}


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
        code(check, "检查命令"),
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
        "建立项目并准备 R 环境",
        "让 R 知道项目文件在哪里，并让后续脚本能找到所需函数。工作目录错误是初学者最常见、也最容易误以为是代码错误的问题。",
        "所有相对路径都以当前工作目录为起点。先固定项目根目录，后续才能稳定读取数据、保存图片和重复运行分析。",
        "一个新文件夹，例如 `stat3888_bicycle_project/`；其中建立 `data/`、`R/`、`output/figures/` 和 `output/analysis/`。",
        'getwd()\n'
        'dir.create("data", showWarnings = FALSE)\n'
        'dir.create("output/figures", recursive = TRUE, showWarnings = FALSE)\n'
        'install.packages(c("tidyverse", "lubridate", "glmnet"))\n'
        'library(tidyverse)\n'
        'library(lubridate)\n'
        'library(glmnet)',
        "`getwd()` 返回当前工作目录；`dir.create()` 建立文件夹，`recursive = TRUE` 会连同缺失的上层目录一起建立，"
        "`showWarnings = FALSE` 只隐藏“文件夹已存在”的提示。`install.packages()` 把软件包安装到电脑，通常只需执行一次；"
        "`library()` 把包加载到当前 R 会话，每次重新打开 RStudio 都要运行。安装和加载是两件不同的事。",
        "`getwd()` 显示项目根目录；Environment 中没有报错；三个软件包可以正常加载。安装时出现下载信息属于正常输出。",
        'getwd()\n'
        'all(c("tidyverse", "lubridate", "glmnet") %in% rownames(installed.packages()))',
        "若出现 `there is no package called ...`，说明只加载但没有成功安装；重新运行 `install.packages()`。若之后提示找不到 "
        "`data/bicycle.csv`，先检查 `getwd()`，不要反复改分析代码。推荐在 RStudio 中用 File → New Project 建立 `.Rproj`。",
        "可复现性与软件说明会影响方法可信度。展示时应能说清 R、RStudio 和各软件包分别负责什么。",
    ),
    step(
        1,
        "读取 bicycle.csv 并理解 R 对象",
        "把磁盘上的 CSV 转换成 R 内存中的数据框 `bike`，并确认行数、列数和变量类型与预期一致。",
        "后续所有清洗、作图和建模都依赖 `bike`。如果读错文件或字段类型错误，后面的漂亮图表也没有意义。",
        "`data/bicycle.csv`。它是事件表：每行代表一条被报告的自行车盗窃事件，而不是一个社区或一个月份。",
        'bike <- readr::read_csv(\n'
        '  "data/bicycle.csv",\n'
        '  show_col_types = FALSE\n'
        ')\n'
        'dim(bike)\n'
        'dplyr::glimpse(bike)',
        "`bike <-` 把右侧结果保存为名为 `bike` 的对象；`<-` 可以理解为“把结果交给这个名字”。"
        "`readr::read_csv()` 中的 `readr::` 明确指定函数来自 readr 包，即使没有先运行 `library(readr)` 也能调用。"
        "引号内是相对于 `getwd()` 的路径。`show_col_types = FALSE` 只关闭列类型提示，不改变数据内容。"
        "`dim()` 返回“行数、列数”；`glimpse()` 用紧凑方式展示列名、类型和样例。",
        "`dim(bike)` 应得到 `31833 8`；`glimpse()` 应显示 date、quarter、day_of_week、neighborhood、bike_cost、location、long、lat。",
        'stopifnot(nrow(bike) == 31833)\n'
        'stopifnot(ncol(bike) == 8)\n'
        'names(bike)',
        "`cannot open file` 或 `file does not exist` 几乎总是路径问题：确认文件确实放入 `data/`，再检查 `getwd()`。"
        "若行数不是 31,833，不要继续；先确认没有打开另一个同名文件，也没有在 Excel 中另存时损坏分隔符。",
        "明确数据来源、观测单位和真实样本量，是数据介绍与方法合理性的基础证据。",
    ),
    step(
        2,
        "审计日期、缺失、重复和季度",
        "在改变数据前建立质量证据：日期能否解析、是否缺失、是否有完全相同行，以及原 quarter 字段是否与 date 一致。",
        "审计必须先于删除或修正。否则无法区分原始问题和自己加工时制造的问题，也无法在报告中解释清洗决定。",
        "`bike`：31,833 × 8 的原始事件表。这里不使用未来模型结果，也不修改原始文件。",
        'bike <- bike |>\n'
        '  dplyr::mutate(\n'
        '    date = as.Date(date),\n'
        '    derived_quarter = paste0(\n'
        '      lubridate::year(date), "Q", lubridate::quarter(date)\n'
        '    )\n'
        '  )\n\n'
        'sum(is.na(bike))\n'
        'sum(duplicated(bike[, 1:8]))\n'
        'dplyr::n_distinct(bike$neighborhood)',
        "`|>` 是 R 的管道：把左边对象作为右边函数的第一个输入，可按阅读顺序写处理流程。`mutate()` 新增或修改列；"
        "`as.Date()` 把文字转为日期；`year()` 和 `quarter()` 从日期提取年份和季度；`paste0()` 把它们拼成如 `2014Q1`。"
        "`is.na()` 标记缺失，`sum()` 统计 TRUE；`duplicated()` 标记与之前完全相同的行；`n_distinct()` 统计不同社区。",
        "原始字段无缺失；有 140 个社区；1,475 行与前面的原始八列完全相同；从 date 推导后可发现大量 quarter 不一致。",
        'audit <- tibble::tibble(\n'
        '  missing_cells = sum(is.na(bike[, 1:8])),\n'
        '  duplicate_rows = sum(duplicated(bike[, 1:8])),\n'
        '  neighborhoods = dplyr::n_distinct(bike$neighborhood),\n'
        '  first_date = min(bike$date),\n'
        '  last_date = max(bike$date)\n'
        ')\n'
        'audit',
        "不要看到 1,475 就直接运行 `distinct()`。数据没有唯一事件 ID，同一日期和社区可能发生多起真实盗窃；自动删除会低估数量。"
        "若 `as.Date()` 产生 NA，先查看原始日期格式，再指定 `format=`，不能用猜测填补。",
        "高分清洗不是“删得多”，而是每个决定都有证据。报告应明确：重复行保留、quarter 从 date 重新推导。",
    ),
    step(
        3,
        "把事件表聚合为社区 × 月份",
        "把“一行一事件”转换为“一行一社区月份”，响应变量 `theft_count` 表示该社区该月报告了多少起盗窃。",
        "Task 1 和 Task 4 都需要固定的时空分析单位。事件表中没有发生事件的月份根本没有行，不能直接与其他月份比较。",
        "`bike`，其中 date 已是 Date 类型，neighborhood 是社区名称。输出暂时只包含发生过事件的社区月份。",
        'monthly_counts <- bike |>\n'
        '  dplyr::mutate(month = lubridate::floor_date(date, "month")) |>\n'
        '  dplyr::count(neighborhood, month, name = "theft_count") |>\n'
        '  dplyr::arrange(month, neighborhood)',
        "`floor_date(date, \"month\")` 把同月所有日期归到该月第一天，例如 2023-07-19 变为 2023-07-01。"
        "`count(neighborhood, month)` 等价于按社区和月份分组后统计行数；`name=` 给计数列命名。"
        "`arrange()` 只改变显示顺序，不改变数值。此处的计数就是响应变量，所以不能在 count 前误删事件。",
        "`monthly_counts` 每行对应一个确实发生过盗窃的社区月份；同一 neighborhood-month 组合只出现一次。",
        'monthly_counts |>\n'
        '  dplyr::count(neighborhood, month) |>\n'
        '  dplyr::filter(n != 1)\n'
        'summary(monthly_counts$theft_count)',
        "若检查结果出现行，说明同一社区月份仍重复，通常是分组字段拼写不一致或没有真正执行 `count()`。"
        "不要把 `day_of_week` 一起加入分组，否则一行会变成“社区 × 月份 × 星期”，分析单位就变了。",
        "明确空间单位、时间单位和响应变量，可直接支持评分中的数据处理与研究问题一致性。",
    ),
    step(
        4,
        "补齐零事件月份并验证面板",
        "加入没有记录但应当存在的社区月份，并把这些组合的盗窃数设为 0，形成规则的 140 × 120 面板。",
        "没有事件的月份是 0，不是 NA。若忽略这些月份，平均值会偏高，趋势图断裂，模型也只学习“已经发生事件”的条件分布。",
        "`monthly_counts` 与完整月份序列 `all_months`。输出 `panel` 应有 16,800 行。",
        'all_months <- seq(\n'
        '  as.Date("2014-01-01"), as.Date("2023-12-01"), by = "month"\n'
        ')\n\n'
        'panel <- monthly_counts |>\n'
        '  tidyr::complete(\n'
        '    neighborhood,\n'
        '    month = all_months,\n'
        '    fill = list(theft_count = 0L)\n'
        '  ) |>\n'
        '  dplyr::mutate(\n'
        '    year = lubridate::year(month),\n'
        '    month_of_year = lubridate::month(month),\n'
        '    time_index = (year - 2014) * 12 + month_of_year\n'
        '  )',
        "`seq(..., by=\"month\")` 生成连续 120 个月。`complete()` 展开所有社区和月份组合；"
        "`fill = list(theft_count = 0L)` 只把新组合的计数补为整数 0。`year` 用于时间切分，`month_of_year` 用于季节特征，"
        "`time_index` 把 2014-01 到 2023-12 编为 1 到 120，便于样条计算。",
        "`panel` 有 16,800 行；每个社区恰好 120 行；`theft_count` 没有 NA；`time_index` 范围为 1–120。",
        'stopifnot(nrow(panel) == 140 * 120)\n'
        'stopifnot(!anyNA(panel$theft_count))\n'
        'stopifnot(all(table(panel$neighborhood) == 120))\n'
        'range(panel$time_index)',
        "若行数不是 16,800，检查 `all_months` 的起止日期、社区名称是否含前后空格，以及 complete 前是否仍有重复组合。"
        "若把 0 错补成 NA，后续 `mean()` 可能传播 NA 或通过 `na.rm=TRUE` 悄悄忽略月份。",
        "完整规则面板是时空可视化与基函数回归的共同数据基础，也是可复现性检查的重要证据。",
    ),
    step(
        5,
        "完成 Task 1 的四类时空图",
        "分别回答长期变化、季节分布、空间热点和地点随时间变化四个问题，而不是用一张拥挤图承载所有信息。",
        "可视化先提供结构证据：季节模式支持 Fourier，平滑长期变化支持 B-spline，持续热点支持空间基函数。",
        "`panel`，并从原始数据按社区计算中心经纬度后连接为 lon、lat。图形对象分别保存为 p_time、p_season、p_space、p_heat。",
        'monthly <- panel |>\n'
        '  dplyr::group_by(month) |>\n'
        '  dplyr::summarise(thefts = sum(theft_count), .groups = "drop")\n\n'
        'p_time <- ggplot2::ggplot(\n'
        '  monthly, ggplot2::aes(x = month, y = thefts)\n'
        ') +\n'
        '  ggplot2::geom_line(color = "#0B6E75") +\n'
        '  ggplot2::labs(x = NULL, y = "Reported thefts")\n\n'
        'ggplot2::ggsave(\n'
        '  "output/figures/monthly_trend.png", p_time,\n'
        '  width = 9, height = 5.4, dpi = 180\n'
        ')',
        "`group_by(month)` 指定汇总单位，`summarise(sum(...))` 得到全市月总数。`ggplot(data, aes(...))` 建立数据与视觉属性映射："
        "x 轴是月份，y 轴是数量；`geom_line()` 决定用线连接；`labs()` 明确轴含义。`+` 是给图逐层添加组件，不是数值相加。"
        "`ggsave()` 保存指定图对象；width/height 是英寸，dpi 控制清晰度。季节箱线图、空间点图和时空热力图遵循同一语法层次。",
        "输出四张图：总体月趋势、月份箱线图、社区热点图、前 25 高值社区热力图。每张图都应有标题、轴、单位和数据来源。",
        'print(p_time)\n'
        'file.exists("output/figures/monthly_trend.png")\n'
        'ggplot2::ggplot_build(p_time)',
        "出现 `object not found` 时，检查 monthly 是否先运行生成；出现空图时检查 aes 中的列名。"
        "空间图使用的是社区中心点，不要把它写成案件精确位置；比较多张地图时应固定颜色尺度。",
        "Task 1 占 30%。高分来自“每张图回答一个问题并推动模型设计”，而不是颜色多或图形复杂。",
        extra=[
            bullets(
                "时间图：横轴时间、纵轴全市报告数；看趋势、突变和峰值。",
                "季节图：每个箱表示同一月份跨十年的分布；看可重复季节性。",
                "空间图：每个点是社区中心；颜色和大小表示长期月均数量。",
                "热力图：一行一个社区、一列一个月；连续高色带表示持续热点。",
            )
        ],
    ),
    step(
        6,
        "按时间划分训练、验证和测试集",
        "模拟真实使用场景：用过去学习模型，用较新的年份选设置，最后用完全未见的 2023 年评价。",
        "随机抽行会让同一社区的未来月份进入训练，造成时间泄漏。看似更高的分数不能代表未来预测能力。",
        "`panel`，其中 year 已从 month 可靠推导。输出 train、validation、test 三个互不重叠的数据框。",
        'train <- dplyr::filter(panel, year <= 2021)\n'
        'validation <- dplyr::filter(panel, year == 2022)\n'
        'test <- dplyr::filter(panel, year == 2023)',
        "`filter()` 保留条件为 TRUE 的行；`<=` 表示小于等于，`==` 才是比较是否相等。2014–2021 用于估计结构，"
        "2022 只选择 λ，2023 最后一次报告结果。不能写成 `year = 2023`，因为单个 `=` 在这里不是相等比较。",
        "train 13,440 行，validation 1,680 行，test 1,680 行；年份分别为 2014–2021、2022、2023。",
        'stopifnot(max(train$year) < min(validation$year))\n'
        'stopifnot(max(validation$year) < min(test$year))\n'
        'c(train = nrow(train), validation = nrow(validation), test = nrow(test))',
        "若三个集合行数相加不等于 16,800，检查年份条件是否遗漏或重叠。不要用 `sample()` 随机拆分；"
        "也不要在看到 2023 结果后不断修改模型再重测，否则 test 已经变成 validation。",
        "无泄漏验证、明确数据角色和诚实测试结果是 Task 4 方法可信度的核心加分点。",
    ),
    step(
        7,
        "构造时空基函数与设计矩阵",
        "把时间、月份、位置和社区名称转换为数值特征列，使线性模型能够表示非线性趋势、周期和空间差异。",
        "回归只能读取数值矩阵 X。基函数负责把我们在 Task 1 看见的结构翻译成模型可以学习的列。",
        "`train` 以及只从训练期确定的 recipe：样条节点、空间中心、缩放尺度和社区水平。输出 x_train 数值矩阵。",
        'time_bs <- splines::bs(\n'
        '  train$time_index, degree = 3,\n'
        '  knots = c(20, 39, 58, 77),\n'
        '  Boundary.knots = c(1, 120)\n'
        ')\n'
        'season <- cbind(\n'
        '  sin1 = sin(2*pi*train$month_of_year/12),\n'
        '  cos1 = cos(2*pi*train$month_of_year/12)\n'
        ')\n'
        'area <- stats::model.matrix(~ neighborhood - 1, data = train)\n'
        'x_train <- cbind(time_bs, season, area)',
        "`bs()` 把一列 time_index 展开为多列局部三次样条；`knots` 是内部连接点，`Boundary.knots` 固定可预测范围。"
        "`sin()`/`cos()` 把月份变成首尾相接的年度周期。`cbind()` 按列拼接矩阵。`model.matrix(~ neighborhood - 1)` "
        "为每个社区建立 0/1 指示列，`-1` 表示不额外自动生成截距。完整项目还加入 16 个空间 RBF 列。",
        "`x_train` 的行数与 train 完全相同，列数远大于原始变量数；所有列都是数值。相同 recipe 可生成验证和测试矩阵。",
        'stopifnot(nrow(x_train) == nrow(train))\n'
        'stopifnot(is.matrix(x_train))\n'
        'dim(x_train)\n'
        'x_train[1:3, 1:6]',
        "若验证或测试出现不同列数，通常是分别调用 `model.matrix()` 时因子水平不同。正确做法是保存训练期社区 levels，"
        "并把相同 levels 应用于未来数据。节点、中心和缩放参数不能从 test 的盗窃结果中选择。",
        "公式、设计矩阵与代码一一对应，能够证明你不是把模型当黑箱；这是方法解释深度的重要证据。",
    ),
    step(
        8,
        "建立两个简单预测基线",
        "先回答“复杂模型是否比不建模更有价值”：比较全局历史均值和每个社区历史均值。",
        "没有基线时，R² 或误差数字缺乏参照。复杂模型即使看起来先进，也可能不如一个历史平均值。",
        "`train` 和 `test`。基线只能使用 train 计算均值，不能偷看 2022 或 2023。",
        'global_mean <- mean(train$theft_count)\n'
        'pred_global <- rep(global_mean, nrow(test))\n\n'
        'area_means <- train |>\n'
        '  dplyr::group_by(neighborhood) |>\n'
        '  dplyr::summarise(pred = mean(theft_count), .groups = "drop")\n'
        'pred_area <- test |>\n'
        '  dplyr::left_join(area_means, by = "neighborhood") |>\n'
        '  dplyr::pull(pred)',
        "`mean()` 得到训练期全局平均；`rep()` 为每个测试行重复同一预测。社区基线先 `group_by()` 再求每个社区平均，"
        "`left_join()` 按 neighborhood 把预测接回 test，`pull()` 抽出数值向量。连接前后必须保持测试行顺序。",
        "得到长度均为 1,680 的 pred_global 和 pred_area；社区均值通常明显优于全局均值，说明稳定空间差异很重要。",
        'stopifnot(length(pred_global) == nrow(test))\n'
        'stopifnot(length(pred_area) == nrow(test))\n'
        'stopifnot(!anyNA(pred_area))',
        "若 pred_area 有 NA，说明测试集中出现训练未见社区，或社区名称不一致。不能用测试集自身均值填补；"
        "应说明外推限制，或退回全局均值/RBF-only 模型。",
        "与至少两个透明基线比较，可以直接支撑“复杂度带来额外价值”的论证。",
    ),
    step(
        9,
        "拟合 OLS 基函数模型",
        "用最小二乘估计设计矩阵每一列的权重，再把预测从 log(1+y) 尺度还原到盗窃数量。",
        "OLS 是 Task 4 的直接实现，也是检验基函数本身是否有效的透明主模型。先理解它，再讨论正则化。",
        "`x_train_validation`、`y_train_validation` 和 `x_test`；最终拟合合并 2014–2022，预测 2023。",
        'y_fit <- log1p(train_validation$theft_count)\n'
        'ols <- stats::lm.fit(\n'
        '  cbind(Intercept = 1, x_train_validation), y_fit\n'
        ')\n'
        'beta <- ols$coefficients\n'
        'beta[is.na(beta)] <- 0\n'
        'pred_ols_log <- cbind(Intercept = 1, x_test) %*% beta\n'
        'pred_ols <- pmax(0, expm1(pred_ols_log))',
        "`log1p(y)` 精确计算 log(1+y)，允许 y=0 并缓解右偏。`lm.fit(X,y)` 直接对矩阵做最小二乘；"
        "`cbind(Intercept=1, ...)` 添加截距列。`%*%` 是高等代数中的矩阵乘法 Xβ。"
        "`expm1()` 是 log1p 的反变换，`pmax(0, ...)` 把不合理的负计数截为 0。共线列可能产生 NA 系数，本项目将其置零。",
        "`pred_ols` 是长度 1,680 的非负预测；在真实 2023 测试上约得到 MAE 1.008、RMSE 2.048、R² 0.757。",
        'stopifnot(length(pred_ols) == nrow(test))\n'
        'stopifnot(all(is.finite(pred_ols)))\n'
        'stopifnot(all(pred_ols >= 0))',
        "若 `%*%` 报维度不匹配，检查训练和测试设计矩阵列数及列顺序。若忘记 `expm1()`，指标会把 log 尺度预测与原始计数比较，"
        "结果没有实际意义。OLS 系数很多时不应逐一作因果解释。",
        "这一步把理论公式 y=Xβ+ε、实际 R 代码和测试集预测连成完整证据链。",
    ),
    step(
        10,
        "拟合 Ridge 并选择 λ",
        "给大系数增加平方惩罚，降低高度相关基函数造成的系数波动，并用 2022 验证集选择惩罚强度 λ。",
        "基函数和 140 个社区指示列可能相关。Ridge 是现代、稳健的扩展，但是否更好必须由验证结果决定。",
        "`x_train`、`y_train`、`x_validation` 和候选 lambda_grid。2023 测试集完全不参与 λ 选择。",
        'lambda_grid <- exp(seq(log(100), log(1e-4), length.out = 100))\n'
        'ridge_path <- glmnet::glmnet(\n'
        '  x_train, log1p(train$theft_count),\n'
        '  alpha = 0, lambda = lambda_grid, standardize = TRUE\n'
        ')\n'
        'val_log <- predict(ridge_path, newx = x_validation,\n'
        '                   s = lambda_grid)\n'
        'val_rmse <- apply(val_log, 2, function(z) {\n'
        '  pred <- pmax(0, expm1(z))\n'
        '  sqrt(mean((validation$theft_count - pred)^2))\n'
        '})\n'
        'best_lambda <- lambda_grid[which.min(val_rmse)]',
        "`glmnet()` 一次拟合多个 λ；`alpha=0` 指 Ridge，惩罚为 λΣβ²；`standardize=TRUE` 先统一不同列的尺度。"
        "`predict(..., s=lambda_grid)` 给出每个候选 λ 的验证预测。`apply(...,2,...)` 逐列计算 RMSE；"
        "`which.min()` 找最小误差位置。λ 越大收缩越强，接近 0 时接近未惩罚回归。",
        "本项目选择的 λ 约为 1e-4；Ridge 测试 RMSE 约 2.060，略差于 OLS 2.048。因此最终应诚实报告 OLS 略优。",
        'best_lambda\n'
        'min(val_rmse)\n'
        'stopifnot(best_lambda %in% lambda_grid)',
        "不要使用测试 RMSE 选择 λ，也不要因为 Ridge 名字更新就宣布它获胜。若 λ 总落在网格边界，应扩大网格后只用验证集重选。"
        "对 glmnet 预测时 `newx` 必须是数值矩阵，不能直接传 tibble。",
        "展示超参数如何选择、并接受简单模型胜出，体现方法严谨性而不是模型宣传。",
    ),
    step(
        11,
        "计算 MAE、RMSE 和 R²",
        "用同一组 2023 实际值比较全部模型，并理解三个指标分别强调什么。",
        "单一指标可能掩盖问题：MAE 表示典型绝对误差，RMSE 更惩罚大错，R² 比较模型与测试集均值基准的平方误差。",
        "`actual = test$theft_count` 与长度相同的预测向量 predicted。所有计算都在原始“每社区每月盗窃数”尺度。",
        'score <- function(actual, predicted) {\n'
        '  tibble::tibble(\n'
        '    MAE = mean(abs(actual - predicted)),\n'
        '    RMSE = sqrt(mean((actual - predicted)^2)),\n'
        '    R2 = 1 - sum((actual - predicted)^2) /\n'
        '      sum((actual - mean(actual))^2)\n'
        '  )\n'
        '}\n'
        'score(test$theft_count, pred_ols)',
        "`actual-predicted` 是残差。`abs()` 消除正负抵消后取平均得到 MAE；平方后平均再开根号得到 RMSE，"
        "所以峰值错误权重更大。R²=1-SSE/SST；1 表示完全预测，0 约等于测试均值，负数表示比均值还差。"
        "R² 不是“预测正确百分比”。",
        "全局均值：MAE 2.19、RMSE 4.17、R² -0.007；社区均值：1.41、2.73、0.569；"
        "Basis OLS：1.01、2.05、0.757；Basis Ridge：1.01、2.06、0.754。",
        'stopifnot(length(test$theft_count) == length(pred_ols))\n'
        'score(test$theft_count, pred_ols)\n'
        'score(test$theft_count, pred_area)',
        "若出现极高误差，先确认预测是否已从 log 尺度反变换。若 R² 为负不代表计算错误；它表示模型比测试均值基准更差。"
        "比较模型时必须使用完全相同的测试行，不能各自删除不同观测。",
        "指标表是 Task 4 结果页的核心证据；同时报告基线和多个指标比只给一个最好分数更可信。",
    ),
    step(
        12,
        "绘制预测与残差诊断",
        "检查模型在哪些月份和社区系统性低估或高估，而不只盯住一个总体分数。",
        "模型可能有不错 RMSE，却持续漏掉夏季峰值或中心区热点。残差结构说明哪些信息尚未被基函数解释。",
        "`test_predictions`：包含 month、neighborhood、lon、lat、actual、predicted；新增 residual=actual-predicted。",
        'diagnostic <- test_predictions |>\n'
        '  dplyr::mutate(residual = actual - predicted)\n\n'
        'monthly_fit <- diagnostic |>\n'
        '  dplyr::group_by(month) |>\n'
        '  dplyr::summarise(\n'
        '    actual = sum(actual), predicted = sum(predicted),\n'
        '    .groups = "drop"\n'
        '  )\n\n'
        'residual_map <- diagnostic |>\n'
        '  dplyr::group_by(neighborhood, lon, lat) |>\n'
        '  dplyr::summarise(mean_residual = mean(residual), .groups = "drop")',
        "`residual = actual-predicted`：正值表示模型低估，负值表示高估。月度汇总比较城市总量随时间变化；"
        "社区平均残差把 2023 的 12 个月压缩为每个地点一个诊断值。随后用 `ggplot()` 画实际/预测折线和以 0 为中心的发散色地图。",
        "预测线应捕捉主要季节形状，但会低估部分夏季峰值；残差地图仍显示中心附近的正残差聚集。",
        'summary(diagnostic$residual)\n'
        'mean(diagnostic$residual)\n'
        'sum(diagnostic$residual > 0)\n'
        'stopifnot(abs(diagnostic$residual - (diagnostic$actual - diagnostic$predicted)) < 1e-10)',
        "颜色方向很容易写反：必须在图注声明“正残差=实际高于预测”。地图残差不是犯罪原因；它只提示土地用途、交通、人流或暴露量等遗漏变量可能重要。",
        "诊断图把模型评价从“报分数”提升到“理解失败模式”，是高质量分析区别于机械建模的关键。",
    ),
    step(
        13,
        "把分析压缩为四页 PowerPoint",
        "把完整分析转化为四页内可理解、可答辩的证据链，而不是把手册内容缩小后全部塞进去。",
        "项目限制最多四页。必须选择最能回答研究问题的图和数字，省略不支持主线的中间输出。",
        "已验证的四张 Task 1 图、模型指标表、预测图、残差图及方法公式。",
        'slide_plan <- tibble::tribble(\n'
        '  ~page, ~question, ~evidence,\n'
        '  1, "研究什么？", "数据、研究问题、流程",\n'
        '  2, "发现什么时空规律？", "趋势、季节、热点",\n'
        '  3, "怎样建模并验证？", "基函数、时间切分、指标",\n'
        '  4, "模型做到了什么？", "预测、残差、结论与局限"\n'
        ')\n'
        'slide_plan',
        "`tribble()` 用逐行方式建立小表；`~page` 声明列名，后续每三项是一行。这里输入 R 代码不是为了自动生成 PPT，"
        "而是强迫自己检查每页只回答一个问题。页面 2 只保留最强的 Task 1 证据，页面 3 必须出现时间切分和基线。",
        "得到 4 × 3 的展示计划；四页形成“问题→发现→方法→可信结论”的连续叙事。",
        'stopifnot(nrow(slide_plan) == 4)\n'
        'stopifnot(length(unique(slide_plan$page)) == 4)',
        "不要复制完整代码到 PPT；代码属于复现材料，PPT 应展示方法结构和证据。字体不要小于 18pt，图标题直接写发现。"
        "不要把 0.757 写成“75.7% 盗窃被准确预测”，应写为测试 R²。",
        "表达与逻辑占 30%。四页各回答一个问题，比堆叠更多模型和图更容易拿到清晰度分数。",
    ),
    step(
        14,
        "从头复现并完成提交检查",
        "验证一个空 R 会话能按照固定顺序重建审计表、面板、图形、模型指标和最终展示证据。",
        "只在当前 Environment 中运行成功不等于可复现；对象可能来自之前某次试验。清空后重跑才能发现隐藏依赖和顺序错误。",
        "保存好的 `R/config.R`、`R/01_prepare_data.R`、`R/02_visualize.R`、`R/03_model.R` 和 `R/run_all.R`，以及原始 CSV。",
        'rm(list = ls())\n'
        'source("R/run_all.R")\n'
        'list.files("output/analysis", full.names = TRUE)\n'
        'list.files("output/figures", full.names = TRUE)',
        "`ls()` 列出当前对象，`rm(list=...)` 清空 Environment，模拟第一次运行；这不会删除硬盘文件。"
        "`source()` 按顺序执行整个脚本。`list.files()` 检查输出是否真正写入磁盘。项目脚本应先创建目录、加载包，再读取数据、作图和建模。",
        "自动生成 data_audit.csv、bicycle_monthly_panel.csv、model_metrics.csv、test_predictions.csv，以及 8 张图；控制台无错误。",
        'stopifnot(file.exists("output/analysis/model_metrics.csv"))\n'
        'stopifnot(length(list.files("output/figures", pattern = "\\\\.png$")) >= 8)\n'
        'readr::read_csv("output/analysis/model_metrics.csv", show_col_types = FALSE)',
        "若清空后报 `object not found`，说明脚本依赖了未在文件中创建的对象；把生成该对象的代码放到正确的前序脚本。"
        "不要在脚本中写 `setwd()` 指向个人绝对路径，也不要把测试集结果用于重新选择模型。",
        "最终提交前的可复现运行同时保护数据处理、方法、结果和表达四条证据链。确认 PPT 不超过四页，并保留脚本和输出作为答辩依据。",
    ),
]
