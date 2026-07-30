"""Authoritative content for the STAT3888 five-minute speech guide."""

PROJECT_FACTS = {
    "dataset": "Toronto bicycle theft reports",
    "period": "2014–2023",
    "raw_rows": 31833,
    "neighbourhoods": 140,
    "panel_rows": 16800,
    "required_tasks": ["Task 1", "Task 4"],
    "train_period": "2014–2021",
    "validation_period": "2022",
    "test_period": "2023",
    "basis_ols_mae": 1.008,
    "basis_ols_rmse": 2.05,
    "basis_ols_r2": 0.757,
    "basis_ridge_mae": 1.006,
    "basis_ridge_rmse": 2.06,
    "basis_ridge_r2": 0.754,
    "neighbourhood_mean_rmse": 2.73,
    "selected_lambda": 0.0001,
    "time_knots": 4,
    "spatial_rbf_centers": 16,
}


SPEECH_SECTIONS = [
    {
        "slide": 1,
        "start_seconds": 0,
        "end_seconds": 70,
        "title": "研究问题与时间证据",
        "script": (
            "Good morning. My project studies reported bicycle thefts in Toronto from 2014 "
            "to 2023. The raw data contain 31,833 incidents across 140 neighbourhoods. I "
            "aggregated these events into a neighbourhood-by-month panel, where each row "
            "records the number of reported thefts in one neighbourhood during one month. "
            "This structure lets us study temporal change and spatial variation together. "
            "On the left, the citywide monthly series shows repeated sharp peaks, mostly "
            "during the warmer part of each year. However, the peak height is not constant "
            "across years, so the data contain both a seasonal cycle and longer-run change. "
            "The monthly distribution on the right confirms that the typical count rises "
            "from winter into summer and then falls toward the end of the year. The main "
            "message from this slide is that Toronto bicycle theft is seasonal, but the "
            "strength of the seasonal peak changes over time."
        ),
        "pointing_cues": (
            "先指左侧时间序列中的多个夏季尖峰；说到季节循环时转向右侧月份分布；"
            "最后停在底部结论框。"
        ),
        "core_sentence": (
            "盗窃具有重复的温暖季节高峰，同时峰值强度随年份发生长期变化。"
        ),
    },
    {
        "slide": 2,
        "start_seconds": 70,
        "end_seconds": 135,
        "title": "空间热点与时空共同变化",
        "script": (
            "Slide two adds the spatial dimension and completes the required Task 1. In the "
            "space-time heatmap, each row is one high-count neighbourhood, each column is one "
            "month, and brighter colours indicate more reported thefts. Many rows brighten "
            "during similar months, showing that the seasonal peak is not an isolated event "
            "in only one area. At the same time, the brightest cells remain concentrated in "
            "a relatively small group of neighbourhoods. The map at the upper right returns "
            "these long-run averages to their geographic locations and shows that the main "
            "hotspots are concentrated around downtown Toronto. The short animation below "
            "shows how the pattern changes month by month from 2014 to 2023. Hotspot intensity "
            "rises and falls, but the broad spatial ordering remains persistent. Therefore, "
            "Task 1 provides two connected findings: a warm-season temporal peak and a stable "
            "downtown spatial concentration."
        ),
        "pointing_cues": (
            "沿热力图横向指时间、纵向指社区；随后指右上地图的downtown高值区；"
            "视频只播放约5秒，用一句话概括，不等待完整播放。"
        ),
        "core_sentence": (
            "季节强度会变化，但报告盗窃长期集中在downtown neighbourhoods。"
        ),
    },
    {
        "slide": 3,
        "start_seconds": 135,
        "end_seconds": 245,
        "title": "Task 4：基函数线性回归",
        "script": (
            "I then address Task 4 by building a linear regression model with basis "
            "functions. The response is the monthly theft count for each neighbourhood. "
            "Because a small number of neighbourhood-months have very high counts, I model "
            "log one plus the count. This reduces the influence of extreme peaks while "
            "preserving zero observations. The model is still linear in its coefficients, "
            "but the design matrix contains transformed features rather than only raw time "
            "and coordinates. First, cubic B-splines represent smooth long-run change using "
            "several local curves. Second, sine and cosine terms represent annual and "
            "half-year seasonal cycles. Third, sixteen radial basis functions, or RBFs, "
            "convert distance from selected spatial centres into smooth measures of "
            "proximity. I also retain neighbourhood indicators to capture persistent area "
            "differences. In other words, the basis functions convert nonlinear time, "
            "seasonal, and spatial patterns into columns of a design matrix, and the "
            "regression forms a linear combination of those columns. "
            "The split is strictly chronological to avoid future information leakage: "
            "2014 to 2021 are used for training, 2022 is used to choose the Ridge penalty, "
            "and 2023 is held out for final testing. Basis OLS is the standard basis-function "
            "linear regression required by Task 4. Basis Ridge uses the same design matrix "
            "but adds a squared-coefficient penalty, which stabilises coefficients when basis "
            "columns are correlated; it is not a separate black-box model. On the 2023 test "
            "set, Basis OLS has an RMSE of 2.05 and an R-squared of 0.757. Basis Ridge has an "
            "RMSE of 2.06 and an R-squared of 0.754. Their predictive performance is almost "
            "identical. The selected lambda is only 0.0001, so the validation procedure "
            "indicates that only very weak regularisation is needed."
        ),
        "pointing_cues": (
            "依次指左侧B-spline、周期波形和空间基函数；说到测试结果时指右侧OLS与"
            "Ridge两行；不要把R²读成“75.7%的预测准确率”。"
        ),
        "core_sentence": (
            "基函数让线性模型表达非线性的时间、季节和空间结构，Ridge则提高系数稳定性。"
        ),
    },
    {
        "slide": 4,
        "start_seconds": 245,
        "end_seconds": 300,
        "title": "预测、残差与结论",
        "script": (
            "The final slide checks what the model actually learned. The observed and Ridge "
            "prediction curves share the main annual cycle, and both basis models clearly "
            "outperform the citywide-mean and neighbourhood-mean baselines. However, the "
            "largest summer peaks are still underestimated. The residual map also shows that "
            "most neighbourhood errors are modest, while extreme months and a small number "
            "of hotspots remain the main difficulty. Overall, the project completes Task 1 "
            "and Task 4: the visualisations identify warm-season peaks and persistent downtown "
            "concentration, while basis-function regression combines long-run, seasonal, and "
            "spatial signals in one interpretable predictive framework. Finally, these are "
            "associations in reported theft counts. They do not establish a causal effect of "
            "season or location on bicycle theft. Thank you."
        ),
        "pointing_cues": (
            "先指实际与预测曲线的共同周期，再指被压低的最高峰；最后指残差图和底部结论。"
        ),
        "core_sentence": (
            "模型捕捉了主要时空结构，但对极端峰值的低估仍是最重要的局限。"
        ),
    },
]


PRINCIPLE_SECTIONS = [
    {
        "title": "1. 为什么建立 neighbourhood-month 面板",
        "intuition": (
            "原始数据的一行是一宗盗窃事件，不能直接回答“某社区某月有多少宗”。面板化"
            "把事件按社区和月份计数，并为没有事件的组合补零，使所有社区拥有同一条时间轴。"
        ),
        "formula": "yᵢₜ = 社区 i 在月份 t 的报告盗窃次数。",
        "project_use": (
            "140个社区乘120个月得到16,800行；每行同时包含yᵢₜ、经纬度、时间索引、"
            "月份和年份。"
        ),
        "why_suitable": (
            "响应变量、时间位置和空间位置被放入同一观察单位，才能统一完成时空可视化和预测。"
        ),
    },
    {
        "title": "2. 三种时空可视化分别做什么",
        "intuition": (
            "趋势图回答“什么时候高”；热点图回答“哪里高”；时空热力图和动画回答"
            "“哪里在什么时候变高”。三者互补，不能相互替代。"
        ),
        "formula": (
            "趋势：Σᵢyᵢₜ；长期热点：平均ₜ(yᵢₜ)；热力图单元格：yᵢₜ。"
        ),
        "project_use": (
            "Slide 1展示月度总量和月份分布；Slide 2展示25个高值社区的热力图、"
            "社区地图和2014–2023动画。"
        ),
        "why_suitable": (
            "评分标准把Task 1单独计为30%，因此必须从时间、空间和联合时空三个角度提供证据。"
        ),
    },
    {
        "title": "3. 为什么使用 log(1+y)",
        "intuition": (
            "计数分布右偏：大多数社区月份计数较低，少数热点月份特别高。直接最小化平方"
            "误差时，大值会被平方后放大，模型容易被少数峰值支配。"
        ),
        "formula": "z = log(1+y)，预测后用 ŷ = max(0, exp(ẑ)-1) 返回计数尺度。",
        "project_use": (
            "OLS和Ridge都在log1p尺度拟合，但MAE、RMSE和R²全部在原始盗窃次数尺度计算。"
        ),
        "why_suitable": (
            "它保留零值、压缩高值并让误差更均衡；代价是反变换可能产生偏差，峰值也更容易被低估。"
        ),
    },
    {
        "title": "4. 设计矩阵如何连接高等代数",
        "intuition": (
            "把每个观测转成一行特征，把每个基函数转成一列，就得到矩阵X。预测就是X的"
            "各列按系数β做线性组合。"
        ),
        "formula": "z = Xβ + ε；第 j 列是基函数φⱼ，ẑᵢ = β₀ + Σⱼβⱼφⱼ(xᵢ)。",
        "project_use": (
            "X包含时间B-spline、4个周期基函数、16个空间RBF和140个社区指示变量。"
        ),
        "why_suitable": (
            "非线性来自φⱼ的形状，而参数β仍然线性，因此可以沿用线性代数中的矩阵乘法和最小二乘。"
        ),
    },
    {
        "title": "5. B-spline 如何表达长期变化",
        "intuition": (
            "一条直线只能表示固定斜率，无法同时表示上升、下降和转折。B-spline使用多条"
            "局部平滑曲线覆盖时间轴，模型把它们叠加成整体趋势。"
        ),
        "formula": "f(t) = ΣₖβₖBₖ(t)，其中Bₖ(t)是三次B-spline基函数。",
        "project_use": (
            "训练期时间索引的20%、40%、60%、80%分位数作为4个内部结点，边界覆盖1到120月。"
        ),
        "why_suitable": (
            "它比高阶多项式更局部、更稳定，也比为每个月单独设置参数更平滑、更节省自由度。"
        ),
    },
    {
        "title": "6. sine/cosine 为什么能表示季节性",
        "intuition": (
            "一年后月份会回到同一季节，因此季节不是单向趋势，而是循环。正弦和余弦天然"
            "首尾相接，并能通过不同系数组合改变峰值出现的月份。"
        ),
        "formula": (
            "sin(2πm/12)、cos(2πm/12)表示一年周期；sin(4πm/12)、"
            "cos(4πm/12)表示半年谐波。"
        ),
        "project_use": "m是1到12的月份编号，四列周期特征与长期B-spline同时进入模型。",
        "why_suitable": (
            "它用很少的参数表达平滑重复循环，并避免把12个月当作彼此毫无关系的类别。"
        ),
    },
    {
        "title": "7. RBF 如何把空间距离变成特征",
        "intuition": (
            "经纬度本身只给出坐标；RBF改问“这个社区离某个空间中心有多近”。越靠近中心，"
            "该基函数的值越接近1，越远则平滑下降到0。"
        ),
        "formula": "φₖ(s) = exp(-||s-cₖ||²/(2σ²))。",
        "project_use": (
            "从140个社区中均匀选取16个中心，标准化经纬度后使用σ=0.8生成16列空间特征。"
        ),
        "why_suitable": (
            "RBF提供平滑的空间邻近表达；相邻社区可以共享信息，而不是只依赖硬边界。"
        ),
    },
    {
        "title": "8. Basis OLS 的目标是什么",
        "intuition": (
            "OLS寻找一组系数，使所有训练观测的实际log计数与预测log计数之间的平方距离最小。"
        ),
        "formula": "β̂OLS = argminβ ||z-Xβ||²。",
        "project_use": (
            "模型使用2014–2022数据拟合OLS，再对完全未参与拟合的2023年进行预测。"
        ),
        "why_suitable": (
            "这是Task 4最直接、可解释的基函数线性回归；每个系数对应一列基函数的贡献。"
        ),
    },
    {
        "title": "9. Ridge 为什么更稳定",
        "intuition": (
            "相邻B-spline、相近RBF和社区指示变量可能携带相似信息，导致不同列相关。"
            "OLS仍可预测，但系数可能对样本小变化非常敏感。Ridge允许增加一点训练误差，"
            "换取更小、更稳定的系数。"
        ),
        "formula": "β̂Ridge = argminβ {||z-Xβ||² + λ||β||²₂}。",
        "project_use": (
            "在2022验证集上从100到0.0001比较100个λ，最终选择λ=0.0001；然后使用"
            "2014–2022重新拟合，并在2023测试。"
        ),
        "why_suitable": (
            "Ridge仍属于线性回归，只增加L2惩罚；本项目很小的λ解释了其结果为何与OLS几乎相同。"
        ),
    },
    {
        "title": "10. 为什么必须按时间切分并使用基线",
        "intuition": (
            "随机切分会让未来月份进入训练集，相当于提前看到答案。按时间切分才模拟真实任务："
            "用过去预测未来。基线则回答复杂模型是否真的比简单规则更好。"
        ),
        "formula": (
            "MAE = mean|y-ŷ|；RMSE = sqrt(mean((y-ŷ)²))；"
            "R² = 1-Σ(y-ŷ)²/Σ(y-ȳ)²。"
        ),
        "project_use": (
            "2014–2021训练、2022验证、2023测试；比较Global mean、Neighbourhood mean、"
            "Basis OLS和Basis Ridge。"
        ),
        "why_suitable": (
            "测试集只使用一次，指标更接近未来泛化能力；同时简单基线让性能提升具有可解释参照。"
        ),
    },
]


VIVA_QA = [
    {
        "question": "1. 为什么选择自行车盗窃数据？",
        "short_answer": (
            "它同时包含日期、社区和经纬度，能够自然形成社区—月份面板，既适合Task 1"
            "的时空可视化，也适合Task 4的基函数回归。"
        ),
        "deeper_answer": (
            "数据覆盖10年和140个社区，时间长度足以识别长期与季节变化，空间单元数量也"
            "足以构造热点图和空间RBF，同时研究问题容易用领域语言解释。"
        ),
    },
    {
        "question": "2. 为什么不用随机训练测试切分？",
        "short_answer": "因为目标是用过去预测未来，随机切分会把未来信息泄漏给训练过程。",
        "deeper_answer": (
            "项目按2014–2021训练、2022验证、2023测试；这样模型选择和最终评价的时间"
            "顺序与真实预测场景一致。"
        ),
    },
    {
        "question": "3. 这个项目是否真的满足Task 4？",
        "short_answer": (
            "满足。Basis OLS是在B-spline、周期基函数和空间RBF扩展后的设计矩阵上拟合"
            "普通线性回归，Basis Ridge是同一模型的正则化扩展。"
        ),
        "deeper_answer": (
            "关键是模型对参数β保持线性；输入经过非线性基函数转换并不改变“线性回归”"
            "这一点。"
        ),
    },
    {
        "question": "4. 为什么同时报告OLS和Ridge？",
        "short_answer": (
            "OLS直接对应Task 4要求，Ridge用于处理基函数相关时的系数不稳定；报告两者"
            "能同时证明合规性和稳健性。"
        ),
        "deeper_answer": (
            "两者测试RMSE只差0.01，验证集选择λ=0.0001，表明本数据只需要很弱的惩罚。"
        ),
    },
    {
        "question": "5. R²=0.757是否等于75.7%的准确率？",
        "short_answer": (
            "不是。它表示模型相对于测试集均值基准减少了约75.7%的平方误差变异，"
            "不是分类正确率。"
        ),
        "deeper_answer": (
            "R²由残差平方和与总平方和的比例定义，在测试集上甚至可能为负；因此必须"
            "与MAE和RMSE一起解释。"
        ),
    },
    {
        "question": "6. 为什么要做log(1+y)而不是直接预测计数？",
        "short_answer": (
            "它保留零值并压缩极端高计数，避免少数热点月份过度支配平方误差。"
        ),
        "deeper_answer": (
            "反变换后仍在原始计数尺度评价，但log变换和平方误差都会产生平滑效应，"
            "这也是高峰被低估的可能原因之一。"
        ),
    },
    {
        "question": "7. 为什么选16个空间RBF中心？",
        "short_answer": (
            "16个中心在表达空间平滑变化与控制模型复杂度之间提供了可管理的折中。"
        ),
        "deeper_answer": (
            "中心按已排序社区均匀抽取并在训练数据上定义；更多中心可能提高灵活性，"
            "但也增加相关性和过拟合风险。"
        ),
    },
    {
        "question": "8. 模型最大的不足是什么？",
        "short_answer": (
            "它对最高夏季峰值仍有低估，而且把误差近似当作独立连续误差，没有显式建模"
            "计数分布和残余时空相关。"
        ),
        "deeper_answer": (
            "后续可比较Poisson或negative-binomial模型，并检查残差的时间和空间相关；"
            "但这些属于项目要求之外的后续改进。"
        ),
    },
    {
        "question": "9. 热点是否说明downtown导致盗窃？",
        "short_answer": (
            "不能。地图显示的是reported theft counts的空间相关模式，不是因果效应。"
        ),
        "deeper_answer": (
            "人口、骑行量、停车设施和报告行为都可能同时影响计数；没有暴露量和因果设计"
            "时，不能把高计数直接解释成地理位置的因果作用或个体风险。"
        ),
    },
    {
        "question": "10. 为什么Ridge作为主模型但OLS的RMSE更低？",
        "short_answer": (
            "两者RMSE只差0.01，预测能力几乎相同；选择Ridge强调的是相关基函数下的"
            "系数稳定性，而不是声称它在这个测试集上数值最优。"
        ),
        "deeper_answer": (
            "正式报告应明确：OLS取得最低RMSE和最高R²，Ridge取得略低MAE并提供正则化"
            "稳定性。这样既准确又能解释模型选择。"
        ),
    },
]
