"""Build the STAT3888 five-minute speech and principles guide."""

from pathlib import Path
import sys

from docx import Document
from docx.enum.table import WD_CELL_VERTICAL_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Inches, Pt, RGBColor

from five_minute_speech_content import (
    PRINCIPLE_SECTIONS,
    PROJECT_FACTS,
    SPEECH_SECTIONS,
    VIVA_QA,
)


WORKTREE_ROOT = Path(__file__).resolve().parents[2]
MAIN_ROOT = Path("/Users/liumingyuan/Documents/project of stat38888")
DELIVERABLE_DIR = (
    WORKTREE_ROOT
    / "deliverables"
    / "STAT3888_Toronto_Bicycle_Theft_Presentation"
)
OUTPUT = DELIVERABLE_DIR / "STAT3888_五分钟演讲稿与原理解析.docx"
SLIDE_DIR = (
    MAIN_ROOT
    / "deliverables"
    / "STAT3888_Toronto_Bicycle_Theft_Presentation"
    / "STAT3888_Toronto_Bicycle_Theft_Embedded_Video"
)

SKILL_DIR = Path(
    "/Users/liumingyuan/.codex/plugins/cache/openai-primary-runtime/"
    "documents/26.727.11326/skills/documents"
)
sys.path.insert(0, str(SKILL_DIR / "scripts"))
from table_geometry import apply_table_geometry  # noqa: E402


BLUE = RGBColor(46, 116, 181)
DARK_BLUE = RGBColor(31, 77, 120)
INK = RGBColor(24, 33, 41)
MUTED = RGBColor(87, 98, 110)
TEAL = RGBColor(0, 127, 130)
PURPLE = RGBColor(98, 36, 109)
RED = RGBColor(155, 28, 28)
LIGHT_BLUE = "E8EEF5"
LIGHT_TEAL = "E8F3F4"
LIGHT_PURPLE = "F1EAF3"
LIGHT_GRAY = "F2F4F7"
WHITE = RGBColor(255, 255, 255)


def set_font(
    run,
    size=None,
    bold=None,
    italic=None,
    color=INK,
    ascii_font="Calibri",
    east_asia="Arial Unicode MS",
):
    text = run.text or ""
    font_name = east_asia if any("\u3400" <= char <= "\u9fff" for char in text) else ascii_font
    run.font.name = font_name
    r_pr = run._element.get_or_add_rPr()
    r_pr.rFonts.set(qn("w:ascii"), font_name)
    r_pr.rFonts.set(qn("w:hAnsi"), font_name)
    r_pr.rFonts.set(qn("w:eastAsia"), east_asia)
    if size is not None:
        run.font.size = Pt(size)
    if bold is not None:
        run.bold = bold
    if italic is not None:
        run.italic = italic
    if color is not None:
        run.font.color.rgb = color


def set_cell_shading(cell, fill):
    tc_pr = cell._tc.get_or_add_tcPr()
    shd = tc_pr.find(qn("w:shd"))
    if shd is None:
        shd = OxmlElement("w:shd")
        tc_pr.append(shd)
    shd.set(qn("w:fill"), fill)


def set_paragraph_shading(paragraph, fill):
    p_pr = paragraph._p.get_or_add_pPr()
    shd = p_pr.find(qn("w:shd"))
    if shd is None:
        shd = OxmlElement("w:shd")
        p_pr.append(shd)
    shd.set(qn("w:fill"), fill)


def set_repeat_table_header(row):
    tr_pr = row._tr.get_or_add_trPr()
    tbl_header = OxmlElement("w:tblHeader")
    tbl_header.set(qn("w:val"), "true")
    tr_pr.append(tbl_header)


def add_page_number(paragraph):
    run = paragraph.add_run()
    begin = OxmlElement("w:fldChar")
    begin.set(qn("w:fldCharType"), "begin")
    instruction = OxmlElement("w:instrText")
    instruction.set(qn("xml:space"), "preserve")
    instruction.text = " PAGE "
    end = OxmlElement("w:fldChar")
    end.set(qn("w:fldCharType"), "end")
    run._r.extend([begin, instruction, end])
    set_font(run, size=9, color=MUTED)


def configure_document(document):
    section = document.sections[0]
    section.page_width = Inches(8.5)
    section.page_height = Inches(11)
    section.top_margin = Inches(0.78)
    section.bottom_margin = Inches(0.75)
    section.left_margin = Inches(0.82)
    section.right_margin = Inches(0.82)
    section.header_distance = Inches(0.36)
    section.footer_distance = Inches(0.36)

    normal = document.styles["Normal"]
    normal.font.name = "Arial Unicode MS"
    normal._element.rPr.rFonts.set(qn("w:ascii"), "Arial Unicode MS")
    normal._element.rPr.rFonts.set(qn("w:hAnsi"), "Arial Unicode MS")
    normal._element.rPr.rFonts.set(qn("w:eastAsia"), "Arial Unicode MS")
    normal.font.size = Pt(10.5)
    normal.font.color.rgb = INK
    normal.paragraph_format.space_before = Pt(0)
    normal.paragraph_format.space_after = Pt(5)
    normal.paragraph_format.line_spacing = 1.22
    normal.paragraph_format.widow_control = True

    for style_name, size, color, before, after in [
        ("Heading 1", 17, BLUE, 16, 8),
        ("Heading 2", 13.5, BLUE, 12, 6),
        ("Heading 3", 11.5, DARK_BLUE, 8, 4),
    ]:
        style = document.styles[style_name]
        style.font.name = "Arial Unicode MS"
        style._element.rPr.rFonts.set(qn("w:ascii"), "Arial Unicode MS")
        style._element.rPr.rFonts.set(qn("w:hAnsi"), "Arial Unicode MS")
        style._element.rPr.rFonts.set(qn("w:eastAsia"), "Arial Unicode MS")
        style.font.size = Pt(size)
        style.font.bold = True
        style.font.color.rgb = color
        style.paragraph_format.space_before = Pt(before)
        style.paragraph_format.space_after = Pt(after)
        style.paragraph_format.keep_with_next = True

    header = section.header
    header_paragraph = header.paragraphs[0]
    header_paragraph.alignment = WD_ALIGN_PARAGRAPH.LEFT
    run = header_paragraph.add_run("STAT3888 · Toronto Bicycle Theft · Task 1 + Task 4")
    set_font(run, size=8.5, bold=True, color=MUTED)

    footer = section.footer
    footer_paragraph = footer.paragraphs[0]
    footer_paragraph.alignment = WD_ALIGN_PARAGRAPH.RIGHT
    run = footer_paragraph.add_run("五分钟演讲稿与原理解析  ·  ")
    set_font(run, size=8.5, color=MUTED)
    add_page_number(footer_paragraph)


def add_para(
    document,
    text="",
    size=10.5,
    bold=False,
    italic=False,
    color=INK,
    before=0,
    after=5,
    line=1.22,
    align=WD_ALIGN_PARAGRAPH.LEFT,
    keep=False,
):
    paragraph = document.add_paragraph()
    paragraph.alignment = align
    paragraph.paragraph_format.space_before = Pt(before)
    paragraph.paragraph_format.space_after = Pt(after)
    paragraph.paragraph_format.line_spacing = line
    paragraph.paragraph_format.keep_with_next = keep
    run = paragraph.add_run(text)
    set_font(run, size=size, bold=bold, italic=italic, color=color)
    return paragraph


def add_callout(document, label, text, fill=LIGHT_TEAL, accent=TEAL, after=8):
    paragraph = document.add_paragraph()
    paragraph.paragraph_format.left_indent = Inches(0.14)
    paragraph.paragraph_format.right_indent = Inches(0.14)
    paragraph.paragraph_format.space_before = Pt(3)
    paragraph.paragraph_format.space_after = Pt(after)
    paragraph.paragraph_format.line_spacing = 1.18
    set_paragraph_shading(paragraph, fill)
    label_run = paragraph.add_run(f"{label}\n")
    set_font(label_run, size=9, bold=True, color=accent)
    text_run = paragraph.add_run(text)
    set_font(text_run, size=10.5, bold=label in {"本页核心句", "评分安全线"})
    return paragraph


def add_labelled_para(document, label, text, label_color=DARK_BLUE, after=5):
    paragraph = document.add_paragraph()
    paragraph.paragraph_format.space_after = Pt(after)
    paragraph.paragraph_format.line_spacing = 1.22
    label_run = paragraph.add_run(label)
    set_font(label_run, size=10.5, bold=True, color=label_color)
    text_run = paragraph.add_run(text)
    set_font(text_run, size=10.5)
    return paragraph


def add_table(document, headers, rows, widths, header_fill=LIGHT_BLUE):
    table = document.add_table(rows=1, cols=len(headers))
    table.style = "Table Grid"
    table.autofit = False
    header = table.rows[0]
    set_repeat_table_header(header)
    for index, text in enumerate(headers):
        cell = header.cells[index]
        cell.vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER
        set_cell_shading(cell, header_fill)
        paragraph = cell.paragraphs[0]
        paragraph.alignment = WD_ALIGN_PARAGRAPH.CENTER
        paragraph.paragraph_format.space_after = Pt(0)
        run = paragraph.add_run(text)
        set_font(run, size=9, bold=True, color=DARK_BLUE)
    for row in rows:
        cells = table.add_row().cells
        for index, text in enumerate(row):
            cell = cells[index]
            cell.vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER
            paragraph = cell.paragraphs[0]
            paragraph.paragraph_format.space_after = Pt(0)
            paragraph.paragraph_format.line_spacing = 1.12
            if index > 0 and len(str(text)) <= 20:
                paragraph.alignment = WD_ALIGN_PARAGRAPH.CENTER
            run = paragraph.add_run(str(text))
            set_font(run, size=8.8)
    apply_table_geometry(
        table,
        widths,
        table_width_dxa=9605,
        indent_dxa=120,
        cell_margins_dxa={"top": 90, "bottom": 90, "start": 110, "end": 110},
    )
    document.add_paragraph().paragraph_format.space_after = Pt(1)
    return table


def add_slide_image(document, slide_number):
    image_path = SLIDE_DIR / f"slide-{slide_number}.png"
    if not image_path.exists():
        add_callout(
            document,
            "PPT缩略图",
            f"未找到第{slide_number}页渲染图；正式内容仍可独立使用。",
            fill=LIGHT_GRAY,
            accent=MUTED,
        )
        return
    paragraph = document.add_paragraph()
    paragraph.alignment = WD_ALIGN_PARAGRAPH.CENTER
    paragraph.paragraph_format.space_before = Pt(1)
    paragraph.paragraph_format.space_after = Pt(7)
    run = paragraph.add_run()
    inline = run.add_picture(str(image_path), width=Inches(6.0))
    inline._inline.docPr.set("descr", f"STAT3888 presentation slide {slide_number}")


def add_cover(document):
    add_para(
        document,
        "STAT3888 · SPATIOTEMPORAL DATA SCIENCE",
        size=10.5,
        bold=True,
        color=TEAL,
        before=56,
        after=20,
        align=WD_ALIGN_PARAGRAPH.CENTER,
    )
    add_para(
        document,
        "Toronto Bicycle Theft",
        size=29,
        bold=True,
        color=RGBColor(32, 55, 72),
        after=5,
        align=WD_ALIGN_PARAGRAPH.CENTER,
    )
    add_para(
        document,
        "五分钟演讲稿与方法原理解析",
        size=17,
        color=RGBColor(43, 81, 99),
        after=25,
        align=WD_ALIGN_PARAGRAPH.CENTER,
    )
    add_callout(
        document,
        "使用方式",
        "Part I 可以直接照着练习；Part II 用于真正理解基函数回归；Part III 用于答辩前快速复习。",
        fill=LIGHT_TEAL,
        accent=TEAL,
        after=15,
    )
    add_labelled_para(document, "姓名：", "____________________________")
    add_labelled_para(document, "学号：", "____________________________")
    add_labelled_para(document, "项目范围：", "Task 1 时空可视化 + Task 4 基函数线性回归")
    add_labelled_para(document, "正式时长：", "5分钟（含指图、停顿和约5秒视频展示）")
    add_labelled_para(
        document,
        "数据：",
        "Toronto bicycle theft reports，2014–2023，31,833条事件，140个社区",
    )
    add_callout(
        document,
        "评分安全线",
        "Basis OLS 是Task 4标准模型；Basis Ridge是稳定化扩展。R²不是准确率，空间相关不是因果。",
        fill=LIGHT_PURPLE,
        accent=PURPLE,
        after=10,
    )
    document.add_page_break()


def add_quick_map(document):
    document.add_heading("使用说明与五分钟路线图", level=1)
    add_para(
        document,
        "先完整朗读两遍。第三遍打开PPT，只在“指图动作”规定的位置指图，不要逐字朗读坐标轴或图题。",
    )
    rows = []
    for section in SPEECH_SECTIONS:
        start = f"{section['start_seconds']//60}:{section['start_seconds']%60:02d}"
        end = f"{section['end_seconds']//60}:{section['end_seconds']%60:02d}"
        rows.append(
            (
                f"第{section['slide']}页",
                f"{start}–{end}",
                section["title"],
                section["core_sentence"],
            )
        )
    add_table(
        document,
        ["PPT", "时间", "任务", "必须让听众记住"],
        rows,
        [850, 900, 2050, 5805],
    )
    add_callout(
        document,
        "计时建议",
        "全文约945个汉字。以每分钟约190个汉字的清晰学术语速，加上指图和视频停顿，约为5分钟。",
        fill=LIGHT_GRAY,
        accent=DARK_BLUE,
    )
    document.add_heading("正式演讲必须保持的四个区分", level=2)
    for text in [
        "Task 1负责发现和展示模式；Task 4负责建立预测模型。",
        "Basis OLS满足任务要求；Basis Ridge是在同一线性模型上的L2正则化扩展。",
        "OLS测试RMSE最低；Ridge强调系数稳定性，不能说Ridge在所有指标上最好。",
        "reported theft counts是报告数量，不等于真实风险，也不证明因果关系。",
    ]:
        paragraph = document.add_paragraph(style="List Bullet")
        paragraph.paragraph_format.space_after = Pt(4)
        run = paragraph.add_run(text)
        set_font(run, size=10.5)
    document.add_page_break()


def add_speech_part(document):
    document.add_heading("Part I · 五分钟逐页演讲稿", level=1)
    add_para(
        document,
        "下列内容按最终四页PPT排列。方括号中的动作不需要说出口。",
        color=MUTED,
        italic=True,
        after=9,
    )
    for index, section in enumerate(SPEECH_SECTIONS):
        if index:
            document.add_page_break()
        start = f"{section['start_seconds']//60}:{section['start_seconds']%60:02d}"
        end = f"{section['end_seconds']//60}:{section['end_seconds']%60:02d}"
        document.add_heading(
            f"第{section['slide']}页 · {section['title']}  |  {start}–{end}",
            level=2,
        )
        add_slide_image(document, section["slide"])
        add_callout(
            document,
            "指图动作",
            section["pointing_cues"],
            fill=LIGHT_GRAY,
            accent=DARK_BLUE,
            after=7,
        )
        add_para(
            document,
            section["script"],
            size=11.2,
            line=1.32,
            after=8,
        )
        add_callout(
            document,
            "本页核心句",
            section["core_sentence"],
            fill=LIGHT_TEAL,
            accent=TEAL,
            after=5,
        )


def add_principles_part(document):
    document.add_page_break()
    document.add_heading("Part II · 方法原理解析", level=1)
    add_para(
        document,
        "每个概念都按“直觉 → 数学表达 → 本项目如何实现 → 为什么适合”展开。"
        "先理解直觉，再看公式中的每个符号。",
        after=10,
    )
    for index, item in enumerate(PRINCIPLE_SECTIONS):
        if index in {3, 6, 8}:
            document.add_page_break()
        document.add_heading(item["title"], level=2)
        add_labelled_para(document, "直觉：", item["intuition"])
        add_callout(
            document,
            "数学表达",
            item["formula"],
            fill=LIGHT_PURPLE,
            accent=PURPLE,
            after=5,
        )
        add_labelled_para(document, "本项目如何实现：", item["project_use"])
        add_labelled_para(document, "为什么适合：", item["why_suitable"], after=8)

    document.add_heading("模型结果应如何准确表述", level=2)
    metric_rows = [
        ("Global mean", "2.187", "4.167", "-0.007", "比测试集均值还差"),
        ("Neighbourhood mean", "1.411", "2.726", "0.569", "有空间差异但无时间变化"),
        ("Basis OLS", "1.008", "2.048", "0.757", "最低RMSE、最高R²"),
        ("Basis Ridge", "1.006", "2.060", "0.754", "最低MAE、系数更稳定"),
    ]
    add_table(
        document,
        ["模型", "MAE", "RMSE", "R²", "正确解释"],
        metric_rows,
        [1800, 900, 900, 900, 5105],
    )
    add_callout(
        document,
        "推荐说法",
        "Basis OLS在2023测试集取得最低RMSE 2.05和最高R² 0.757；Basis Ridge结果几乎相同，"
        "并在相关基函数下提供稳定化，因此作为主要预测与残差展示模型。",
        fill=LIGHT_TEAL,
        accent=TEAL,
    )


def add_viva_part(document):
    document.add_page_break()
    document.add_heading("Part III · 答辩速查", level=1)
    add_para(
        document,
        "先回答“20秒版本”。只有老师继续追问时，再使用“进一步解释”。",
        color=MUTED,
        italic=True,
        after=9,
    )
    for index, item in enumerate(VIVA_QA):
        if index in {3, 6, 8}:
            document.add_page_break()
        document.add_heading(item["question"], level=2)
        add_callout(
            document,
            "20秒回答",
            item["short_answer"],
            fill=LIGHT_TEAL,
            accent=TEAL,
            after=5,
        )
        add_labelled_para(document, "进一步解释：", item["deeper_answer"], after=8)

    document.add_heading("上台前最后检查", level=2)
    checks = [
        "能在不看稿的情况下说出研究问题和两条核心发现。",
        "能解释热力图的行、列和颜色分别代表什么。",
        "能用“设计矩阵的列”解释基函数，而不是只背术语。",
        "能说出训练、验证、测试年份及其目的。",
        "能准确区分OLS与Ridge的结果和选择理由。",
        "不会把R²说成预测准确率，也不会把空间热点说成因果。",
    ]
    for text in checks:
        paragraph = document.add_paragraph(style="List Bullet")
        paragraph.paragraph_format.space_after = Pt(4)
        run = paragraph.add_run(text)
        set_font(run, size=10.5)


def build_document(output_path=OUTPUT):
    output_path = Path(output_path)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    document = Document()
    configure_document(document)
    add_cover(document)
    add_quick_map(document)
    add_speech_part(document)
    add_principles_part(document)
    add_viva_part(document)

    document.core_properties.title = "STAT3888 五分钟演讲稿与原理解析"
    document.core_properties.subject = "Task 1 spatiotemporal visualization and Task 4 basis-function regression"
    document.core_properties.author = "Name: ____________________"
    document.core_properties.keywords = "STAT3888, spatiotemporal, basis functions, OLS, Ridge"
    document.save(output_path)
    return output_path


if __name__ == "__main__":
    result = build_document()
    print(result)
