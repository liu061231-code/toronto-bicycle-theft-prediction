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
