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
