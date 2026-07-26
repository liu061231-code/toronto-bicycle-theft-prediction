"""ReportLab styles and Chinese font registration."""

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_LEFT
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont


FONT_REGULAR = "/System/Library/Fonts/STHeiti Medium.ttc"
FONT_CODE = "/System/Library/Fonts/Supplemental/Arial Unicode.ttf"


def register_fonts():
    pdfmetrics.registerFont(TTFont("CN", FONT_REGULAR, subfontIndex=0))
    pdfmetrics.registerFont(TTFont("CNBold", FONT_REGULAR, subfontIndex=0))
    pdfmetrics.registerFont(TTFont("Code", FONT_CODE))


def build_styles():
    register_fonts()
    sample = getSampleStyleSheet()
    return {
        "body": ParagraphStyle(
            "Body",
            parent=sample["BodyText"],
            fontName="CN",
            fontSize=9.5,
            leading=15,
            textColor=colors.HexColor("#1F2933"),
            spaceAfter=7,
            alignment=TA_LEFT,
        ),
        "title": ParagraphStyle(
            "Title",
            parent=sample["Title"],
            fontName="CNBold",
            fontSize=25,
            leading=34,
            textColor=colors.HexColor("#12355B"),
            alignment=TA_LEFT,
        ),
        "subtitle": ParagraphStyle(
            "Subtitle",
            parent=sample["BodyText"],
            fontName="CN",
            fontSize=12,
            leading=19,
            textColor=colors.HexColor("#486581"),
        ),
        "h1": ParagraphStyle(
            "H1",
            parent=sample["Heading1"],
            fontName="CNBold",
            fontSize=17,
            leading=23,
            textColor=colors.HexColor("#0B6E75"),
            spaceAfter=10,
            keepWithNext=True,
        ),
        "h2": ParagraphStyle(
            "H2",
            parent=sample["Heading2"],
            fontName="CNBold",
            fontSize=12,
            leading=17,
            textColor=colors.HexColor("#12355B"),
            spaceBefore=6,
            spaceAfter=5,
            keepWithNext=True,
        ),
        "callout_title": ParagraphStyle(
            "CalloutTitle",
            fontName="CNBold",
            fontSize=9.5,
            leading=14,
            textColor=colors.HexColor("#12355B"),
        ),
        "callout": ParagraphStyle(
            "Callout",
            fontName="CN",
            fontSize=9,
            leading=14,
            textColor=colors.HexColor("#243B53"),
        ),
        "code": ParagraphStyle(
            "Code",
            fontName="Code",
            fontSize=7.2,
            leading=10,
            textColor=colors.HexColor("#102A43"),
            leftIndent=5,
            rightIndent=5,
        ),
        "caption": ParagraphStyle(
            "Caption",
            fontName="CN",
            fontSize=7.5,
            leading=11,
            textColor=colors.HexColor("#52667A"),
            alignment=TA_CENTER,
            spaceAfter=6,
        ),
        "badge": ParagraphStyle(
            "Badge",
            fontName="CNBold",
            fontSize=7.5,
            leading=10,
            textColor=colors.HexColor("#0B6E75"),
        ),
        "toc": ParagraphStyle(
            "TOC",
            fontName="CN",
            fontSize=9,
            leading=14,
            textColor=colors.HexColor("#243B53"),
        ),
        "footer": ParagraphStyle(
            "Footer",
            fontName="CN",
            fontSize=7,
            leading=9,
            textColor=colors.HexColor("#7B8794"),
            alignment=TA_CENTER,
        ),
    }
