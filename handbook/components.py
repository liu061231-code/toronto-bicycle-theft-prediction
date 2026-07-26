"""Reusable ReportLab components for the handbook."""

from pathlib import Path
from xml.sax.saxutils import escape

from PIL import Image as PILImage
from reportlab.lib import colors
from reportlab.platypus import (
    Image,
    KeepTogether,
    ListFlowable,
    ListItem,
    Paragraph,
    Spacer,
    Table,
    TableStyle,
)


def paragraph(text, style_name, styles):
    return Paragraph(escape(text), styles[style_name])


def bullet_list(items, styles):
    return ListFlowable(
        [
            ListItem(
                Paragraph(escape(item), styles["body"]),
                leftIndent=8,
            )
            for item in items
        ],
        bulletType="bullet",
        start="circle",
        leftIndent=18,
        bulletFontName="CN",
        bulletFontSize=7,
        spaceAfter=5,
    )


def callout(title, body, styles, level="core"):
    palette = {
        "core": ("#E8F3F3", "#0B6E75"),
        "进阶加分": ("#FFF4E6", "#B45309"),
        "未来连接": ("#F2EDFF", "#6D28D9"),
    }
    background, accent = palette.get(level, palette["core"])
    content = [
        Paragraph(escape(title), styles["callout_title"]),
        Spacer(1, 2),
        Paragraph(escape(body), styles["callout"]),
    ]
    box = Table([[content]], colWidths=[480])
    box.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, -1), colors.HexColor(background)),
                ("BOX", (0, 0), (-1, -1), 0.8, colors.HexColor(accent)),
                ("LINEBEFORE", (0, 0), (0, -1), 4, colors.HexColor(accent)),
                ("LEFTPADDING", (0, 0), (-1, -1), 10),
                ("RIGHTPADDING", (0, 0), (-1, -1), 10),
                ("TOPPADDING", (0, 0), (-1, -1), 8),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 8),
            ]
        )
    )
    return KeepTogether([box, Spacer(1, 5)])


def teaching_note(label, body, styles, tone="core"):
    palette = {
        "core": ("#F4F8FA", "#0B6E75"),
        "result": ("#F1F8F2", "#2F855A"),
        "warning": ("#FFF7ED", "#C05621"),
        "rubric": ("#F5F3FF", "#6D28D9"),
    }
    background, accent = palette.get(tone, palette["core"])
    label_p = Paragraph(escape(label), styles["step_label"])
    body_p = Paragraph(escape(body), styles["teaching_body"])
    box = Table([[label_p, body_p]], colWidths=[92, 388], hAlign="LEFT")
    box.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, -1), colors.HexColor(background)),
                ("LINEBEFORE", (0, 0), (0, -1), 3, colors.HexColor(accent)),
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("LEFTPADDING", (0, 0), (-1, -1), 6),
                ("RIGHTPADDING", (0, 0), (-1, -1), 6),
                ("TOPPADDING", (0, 0), (-1, -1), 4),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
            ]
        )
    )
    return [box, Spacer(1, 3)]


def formula_box(text, explanation, styles):
    data = [
        [Paragraph(escape(text), styles["code"])],
        [Paragraph(escape(explanation), styles["callout"])],
    ]
    box = Table(data, colWidths=[480])
    box.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#102A43")),
                ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
                ("BACKGROUND", (0, 1), (-1, 1), colors.HexColor("#F0F4F8")),
                ("BOX", (0, 0), (-1, -1), 0.6, colors.HexColor("#829AB1")),
                ("LEFTPADDING", (0, 0), (-1, -1), 9),
                ("RIGHTPADDING", (0, 0), (-1, -1), 9),
                ("TOPPADDING", (0, 0), (-1, -1), 7),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 7),
            ]
        )
    )
    return KeepTogether([box, Spacer(1, 5)])


def code_block(code, caption, styles):
    safe = escape(code).replace(" ", "&nbsp;").replace("\n", "<br/>")
    content = [
        Paragraph(escape(caption), styles["badge"]),
        Spacer(1, 3),
        Paragraph(safe, styles["code"]),
    ]
    box = Table([[content]], colWidths=[480])
    box.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, -1), colors.HexColor("#F5F7FA")),
                ("BOX", (0, 0), (-1, -1), 0.6, colors.HexColor("#BCCCDC")),
                ("LEFTPADDING", (0, 0), (-1, -1), 8),
                ("RIGHTPADDING", (0, 0), (-1, -1), 8),
                ("TOPPADDING", (0, 0), (-1, -1), 5),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
            ]
        )
    )
    return KeepTogether([box, Spacer(1, 5)])


def figure(path, caption, max_width, max_height, styles):
    path = Path(path)
    if not path.exists():
        raise FileNotFoundError(path)
    with PILImage.open(path) as img:
        width_px, height_px = img.size
    scale = min(max_width / width_px, max_height / height_px)
    flowable = Image(
        str(path),
        width=width_px * scale,
        height=height_px * scale,
    )
    flowable.hAlign = "CENTER"
    return KeepTogether(
        [
            flowable,
            Spacer(1, 3),
            Paragraph(escape(caption), styles["caption"]),
        ]
    )


def data_table(headers, rows, widths, available_width, styles):
    if widths is None:
        widths = [1 / len(headers)] * len(headers)
    col_widths = [available_width * value for value in widths]
    cells = [
        [Paragraph(escape(str(value)), styles["callout_title"]) for value in headers]
    ]
    for row in rows:
        cells.append(
            [Paragraph(escape(str(value)), styles["callout"]) for value in row]
        )
    result = Table(cells, colWidths=col_widths, repeatRows=1, hAlign="LEFT")
    result.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#12355B")),
                ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
                ("BACKGROUND", (0, 1), (-1, -1), colors.HexColor("#F7FAFC")),
                ("ROWBACKGROUNDS", (0, 1), (-1, -1), [
                    colors.HexColor("#F7FAFC"),
                    colors.white,
                ]),
                ("GRID", (0, 0), (-1, -1), 0.35, colors.HexColor("#BCCCDC")),
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("LEFTPADDING", (0, 0), (-1, -1), 6),
                ("RIGHTPADDING", (0, 0), (-1, -1), 6),
                ("TOPPADDING", (0, 0), (-1, -1), 4),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
            ]
        )
    )
    return [result, Spacer(1, 5)]
