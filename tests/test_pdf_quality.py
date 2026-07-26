from pathlib import Path
import subprocess

import pdfplumber
from pypdf import PdfReader


PDF = Path(
    "output/pdf/STAT3888_自行车盗窃时空基函数回归_完整项目手册.pdf"
)


def test_every_page_contains_visible_content():
    with pdfplumber.open(PDF) as doc:
        assert 22 <= len(doc.pages) <= 45
        for index, page in enumerate(doc.pages, 1):
            text = (page.extract_text() or "").strip()
            images = page.images
            assert text or images, f"page {index} is blank"


def test_no_internal_placeholders_or_tool_tokens():
    with pdfplumber.open(PDF) as doc:
        text = "\n".join(page.extract_text() or "" for page in doc.pages)
    forbidden = ["T" + "BD", "TO" + "DO", "turn0" + "search", "place" + "holder", "待" + "补充"]
    for token in forbidden:
        assert token not in text


def test_render_verification_removes_stale_pages():
    render_dir = Path("tmp/pdfs/handbook_render")
    render_dir.mkdir(parents=True, exist_ok=True)
    stale = render_dir / "page-999.png"
    stale.write_bytes(b"stale")

    result = subprocess.run(
        ["zsh", "scripts/verify_pdf.sh"],
        capture_output=True,
        text=True,
    )

    assert result.returncode == 0, result.stderr
    assert not stale.exists()
    assert len(list(render_dir.glob("page-*.png"))) == len(PdfReader(str(PDF)).pages)


def test_pdf_contains_only_the_reproducible_core_route():
    with pdfplumber.open(PDF) as doc:
        text = "\n".join(page.extract_text() or "" for page in doc.pages)
    for phrase in [
        "可直接运行",
        "函数内部原理展开（不单独运行）",
        "resolve_bicycle_csv",
        "make_monthly_panel(raw)",
        "fit_models(splits, basis_recipe)",
        "model_fit$test_predictions",
    ]:
        assert phrase in text
    assert (
        "panel, ggplot2::aes(factor(month_of_year), theft_count)"
        not in text
    )
