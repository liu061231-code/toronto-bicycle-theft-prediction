"""Build the final STAT3888 teaching handbook PDF."""

from datetime import date
from pathlib import Path
from xml.sax.saxutils import escape

from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import mm
from reportlab.platypus import (
    BaseDocTemplate,
    CondPageBreak,
    Frame,
    PageBreak,
    PageTemplate,
    Paragraph,
    Spacer,
    Table,
    TableStyle,
)
from reportlab.platypus.tableofcontents import TableOfContents

from handbook.components import (
    bullet_list,
    callout,
    code_block,
    data_table,
    figure,
    formula_box,
    paragraph,
)
from handbook.content import HANDBOOK_SECTIONS
from handbook.styles import build_styles


PROJECT_ROOT = Path(__file__).resolve().parents[1]
FIGURE_DIR = PROJECT_ROOT / "output" / "figures"


class HandbookDocTemplate(BaseDocTemplate):
    def __init__(self, filename, styles, **kwargs):
        super().__init__(filename, **kwargs)
        self.styles = styles
        self.current_chapter = "STAT3888 教学型项目手册"
        frame = Frame(
            self.leftMargin,
            self.bottomMargin,
            self.width,
            self.height,
            id="normal",
        )
        self.addPageTemplates(
            PageTemplate(id="main", frames=[frame], onPage=self._draw_page)
        )

    def afterFlowable(self, flowable):
        if isinstance(flowable, Paragraph):
            style_name = flowable.style.name
            if style_name == "H1":
                title = flowable.getPlainText()
                self.current_chapter = title
                key = "h1-%s" % self.seq.nextf("h1")
                self.canv.bookmarkPage(key)
                self.canv.addOutlineEntry(title, key, level=0, closed=False)
                self.notify("TOCEntry", (0, title, self.page, key))

    def _draw_page(self, canvas, doc):
        canvas.saveState()
        if doc.page > 1:
            canvas.setStrokeColor(colors.HexColor("#D9E2EC"))
            canvas.setLineWidth(0.5)
            canvas.line(
                self.leftMargin,
                A4[1] - 12 * mm,
                A4[0] - self.rightMargin,
                A4[1] - 12 * mm,
            )
            canvas.setFont("CN", 7)
            canvas.setFillColor(colors.HexColor("#627D98"))
            canvas.drawString(
                self.leftMargin,
                A4[1] - 9.5 * mm,
                self.current_chapter[:42],
            )
            canvas.drawCentredString(
                A4[0] / 2,
                8 * mm,
                f"STAT3888 · {doc.page}",
            )
        canvas.restoreState()


def _cover(styles):
    title = Paragraph(
        "STAT3888 自行车盗窃<br/>时空基函数回归",
        styles["title"],
    )
    subtitle = Paragraph(
        "从时空可视化到可信预测的完整项目手册",
        styles["subtitle"],
    )
    card = Table(
        [
            [Paragraph("数据", styles["callout_title"]),
             Paragraph("bicycle.csv · 31,833条事件 · 140个社区 · 2014–2023", styles["callout"])],
            [Paragraph("主线", styles["callout_title"]),
             Paragraph("Task 1 时空可视化 + Task 4 基函数线性回归", styles["callout"])],
            [Paragraph("基础", styles["callout_title"]),
             Paragraph("从高等代数、概率论进入设计矩阵、样条、验证和诊断", styles["callout"])],
            [Paragraph("版本", styles["callout_title"]),
             Paragraph(f"{date.today().isoformat()} · 基于真实数据验证结果", styles["callout"])],
        ],
        colWidths=[65, 410],
    )
    card.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, -1), colors.HexColor("#F0F7F7")),
                ("BOX", (0, 0), (-1, -1), 0.8, colors.HexColor("#0B6E75")),
                ("INNERGRID", (0, 0), (-1, -1), 0.3, colors.HexColor("#B8D8D8")),
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("LEFTPADDING", (0, 0), (-1, -1), 9),
                ("RIGHTPADDING", (0, 0), (-1, -1), 9),
                ("TOPPADDING", (0, 0), (-1, -1), 8),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 8),
            ]
        )
    )
    return [
        Spacer(1, 27 * mm),
        title,
        Spacer(1, 7 * mm),
        subtitle,
        Spacer(1, 18 * mm),
        card,
        Spacer(1, 22 * mm),
        Paragraph(
            "这本手册强调理解、复现与诚实验证。所有模型指标均来自真实的2023时间外测试集。",
            styles["subtitle"],
        ),
        PageBreak(),
    ]


def _toc(styles):
    toc = TableOfContents()
    toc.levelStyles = [styles["toc"]]
    return [
        Paragraph("目录", styles["h1"]),
        Paragraph(
            "章节按“核心路线—进阶加分—未来连接”组织。先完成核心路线，再根据时间深入。",
            styles["body"],
        ),
        Spacer(1, 8),
        toc,
        PageBreak(),
    ]


def _section_story(section, styles, available_width):
    story = [
        CondPageBreak(70),
        Paragraph(escape(section["level"]), styles["badge"]),
        Paragraph(escape(section["title"]), styles["h1"]),
    ]
    for block in section["blocks"]:
        kind = block["kind"]
        if kind == "p":
            story.append(paragraph(block["text"], "body", styles))
        elif kind == "bullets":
            story.append(bullet_list(block["items"], styles))
        elif kind == "callout":
            story.append(
                callout(
                    block["title"],
                    block["text"],
                    styles,
                    block.get("level", section["level"]),
                )
            )
        elif kind == "formula":
            story.append(
                formula_box(block["text"], block["explanation"], styles)
            )
        elif kind == "code":
            story.append(code_block(block["text"], block["caption"], styles))
        elif kind == "figure":
            story.append(
                figure(
                    FIGURE_DIR / block["filename"],
                    block["caption"],
                    max_width=available_width,
                    max_height=82 * mm,
                    styles=styles,
                )
            )
        elif kind == "table":
            story.extend(
                data_table(
                    block["headers"],
                    block["rows"],
                    block.get("widths"),
                    available_width,
                    styles,
                )
            )
        else:
            raise ValueError(f"Unknown block kind: {kind}")
    return story


def build_handbook(output_path):
    output = Path(output_path)
    output.parent.mkdir(parents=True, exist_ok=True)
    styles = build_styles()
    doc = HandbookDocTemplate(
        str(output),
        styles,
        pagesize=A4,
        leftMargin=17 * mm,
        rightMargin=17 * mm,
        topMargin=17 * mm,
        bottomMargin=15 * mm,
        title="STAT3888 自行车盗窃时空基函数回归完整项目手册",
        author="Codex with verified local analysis",
        subject="STAT3888 Spatiotemporal Data Science project handbook",
    )
    story = []
    story.extend(_cover(styles))
    story.extend(_toc(styles))
    for index, section in enumerate(HANDBOOK_SECTIONS):
        if index:
            story.append(PageBreak())
        story.extend(_section_story(section, styles, doc.width))
    doc.multiBuild(story)
    return str(output.resolve())


if __name__ == "__main__":
    target = (
        PROJECT_ROOT
        / "output"
        / "pdf"
        / "STAT3888_自行车盗窃时空基函数回归_完整项目手册.pdf"
    )
    print(build_handbook(str(target)))
