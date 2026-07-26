from handbook.content import HANDBOOK_SECTIONS


def flattened_text():
    return "\n".join(
        section["title"]
        + "\n"
        + "\n".join(str(block) for block in section["blocks"])
        for section in HANDBOOK_SECTIONS
    )


def test_all_four_tasks_are_explained():
    text = flattened_text()
    for phrase in [
        "Task 1：时空可视化",
        "Task 2：EOF",
        "Task 3：IDW",
        "Task 4：基函数线性回归",
    ]:
        assert phrase in text


def test_teaching_bridges_are_present():
    text = flattened_text()
    for phrase in [
        "高等代数",
        "概率论",
        "设计矩阵",
        "B-spline",
        "Fourier",
        "径向基函数",
        "Ridge",
        "数据泄漏",
    ]:
        assert phrase in text


def test_core_path_contains_all_beginner_steps():
    text = flattened_text()
    for step in range(0, 15):
        assert f"第{step}步" in text


def test_core_steps_explain_actions_checks_and_errors():
    text = flattened_text()
    for phrase in [
        "这一步解决什么问题",
        "为什么现在运行",
        "输入对象",
        "逐行解释",
        "运行后应该看到",
        "检查命令",
        "常见错误",
        "评分连接",
    ]:
        assert phrase in text


def test_core_r_vocabulary_is_explained():
    text = flattened_text()
    for phrase in [
        "<-",
        "readr::",
        "show_col_types",
        "|>",
        "mutate",
        "count",
        "complete",
        "ggplot",
        "filter",
        "model.matrix",
        "lm.fit",
        "glmnet",
        "MAE",
        "RMSE",
        "R²",
    ]:
        assert phrase in text


def test_executable_handbook_path_uses_production_pipeline():
    text = flattened_text()
    for phrase in [
        "resolve_bicycle_csv",
        "make_monthly_panel(raw)",
        "make_task1_plots(panel",
        "fit_models(splits, basis_recipe)",
        "model_fit$test_predictions",
        "函数内部原理展开（不单独运行）",
        "可直接运行",
    ]:
        assert phrase in text


def test_visualization_explanation_uses_the_production_aggregation():
    text = flattened_text()
    assert (
        'panel, ggplot2::aes(factor(month_of_year), theft_count)'
        not in text
    )
    for phrase in [
        "seasonal <- panel |>",
        "group_by(year, month_of_year)",
        "hotspots <- panel |>",
        "heat <- panel |>",
    ]:
        assert phrase in text
