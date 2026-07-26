from pathlib import Path
import subprocess
import sys

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
    assert 22 <= len(reader.pages) <= 45
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
        "这一步解决什么问题",
        "为什么现在运行",
        "逐行解释",
        "show_col_types",
        "model.matrix",
        "lm.fit",
        "glmnet",
    ]:
        assert phrase in text


def test_teaching_layout_uses_compact_spacing():
    styles = build_styles()
    assert styles["body"].spaceAfter <= 5
    assert styles["code"].spaceAfter <= 5
    assert styles["step_label"].spaceBefore <= 5
    assert styles["step_label"].spaceAfter <= 3


def test_builder_can_run_as_a_direct_script():
    result = subprocess.run(
        [sys.executable, "handbook/build_pdf.py"],
        cwd=Path(__file__).resolve().parents[1],
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0, result.stderr
