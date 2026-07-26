from pathlib import Path

from pypdf import PdfReader

from handbook.build_pdf import build_handbook
from handbook.styles import build_styles


OUTPUT = Path(
    "output/pdf/STAT3888_自行车盗窃时空基函数回归_完整项目手册.pdf"
)


def test_build_handbook_has_expected_pages_and_text():
    result = Path(build_handbook(str(OUTPUT)))
    assert result.exists()
    reader = PdfReader(str(result))
    assert 35 <= len(reader.pages) <= 65
    text = "\n".join(page.extract_text() or "" for page in reader.pages)
    for phrase in [
        "Task 1",
        "Task 2",
        "Task 3",
        "Task 4",
        "时空可视化",
        "基函数",
        "Ridge",
        "最终检查清单",
    ]:
        assert phrase in text


def test_teaching_layout_uses_compact_spacing():
    styles = build_styles()
    assert styles["body"].spaceAfter <= 5
    assert styles["code"].spaceAfter <= 5
    assert styles["step_label"].spaceBefore <= 5
    assert styles["step_label"].spaceAfter <= 3
