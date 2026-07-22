"""
SYU PDF documentation builder — clean Office-style report formatting.

- White pages, Calibri-like sans (Calibri → bundled Carlito → Arial)
- Cover: centered titles + logo
- Contents: clickable TOC, right-aligned page numbers
- Body: centered chapter titles, justified 11–12pt body
- Light header line + footer page number
- End page (centered, clean)
"""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
from typing import List, Optional, Sequence, Tuple, Union

from reportlab.lib.colors import HexColor, black, white
from reportlab.lib.enums import TA_CENTER, TA_JUSTIFY, TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfgen import canvas
from reportlab.platypus import (
    BaseDocTemplate,
    Frame,
    Image,
    KeepTogether,
    NextPageTemplate,
    PageBreak,
    PageTemplate,
    Paragraph,
    Spacer,
)
from reportlab.platypus.tableofcontents import TableOfContents

# Academic report palette (NAITA-like); crimson only as a thin accent
INK = HexColor("#000000")
MUTED = HexColor("#44546A")
RULE = HexColor("#333333")
ACCENT = HexColor("#E10600")  # SYU brand — thin rules only
PAGE_W, PAGE_H = A4


def _register_fonts() -> Tuple[str, str]:
    """Prefer Calibri, then bundled Carlito (Calibri-compatible), then Arial."""
    bundle = Path(__file__).resolve().parent.parent / "fonts"
    regular_candidates = [
        "/Library/Fonts/Microsoft/Calibri.ttf",
        "/Library/Fonts/Calibri.ttf",
        "/System/Library/Fonts/Supplemental/Calibri.ttf",
        str(bundle / "Carlito-Regular.ttf"),
        "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/Library/Fonts/Arial.ttf",
    ]
    bold_candidates = [
        "/Library/Fonts/Microsoft/Calibri Bold.ttf",
        "/Library/Fonts/Calibri Bold.ttf",
        "/System/Library/Fonts/Supplemental/Calibri Bold.ttf",
        str(bundle / "Carlito-Bold.ttf"),
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
        "/Library/Fonts/Arial Bold.ttf",
    ]
    regular = "Helvetica"
    bold = "Helvetica-Bold"
    for path in regular_candidates:
        p = Path(path)
        if p.exists():
            try:
                pdfmetrics.registerFont(TTFont("SYUSans", str(p)))
                regular = "SYUSans"
                break
            except Exception:
                continue
    for path in bold_candidates:
        p = Path(path)
        if p.exists():
            try:
                pdfmetrics.registerFont(TTFont("SYUSans-Bold", str(p)))
                bold = "SYUSans-Bold"
                break
            except Exception:
                continue
    return regular, bold


FONT, FONT_BOLD = _register_fonts()


@dataclass
class Section:
    title: str
    body: str
    level: int = 1
    image: Optional[Path] = None
    image_caption: Optional[str] = None
    extra_images: List[Tuple[Path, Optional[str]]] = field(default_factory=list)
    page_break_before: bool = True


@dataclass
class SyuPdfBuilder:
    output: Union[str, Path]
    logo: Optional[Union[str, Path]] = None
    icon: Optional[Union[str, Path]] = None
    doc_title: str = "SYU Sri Lanka"
    doc_subtitle: str = "Product documentation"
    header_left: str = "SYU Sri Lanka — Product Documentation"
    footer_center: str = ""
    cover_title: Optional[str] = None
    cover_subtitle: Optional[str] = None
    cover_meta_lines: List[str] = field(default_factory=list)
    sections: List[Section] = field(default_factory=list)
    end_title: str = "— End of Document —"
    end_body: str = ""
    _include_cover: bool = True
    _include_end: bool = True

    def cover(
        self,
        title: Optional[str] = None,
        subtitle: Optional[str] = None,
        meta: Optional[str] = None,
        meta_lines: Optional[Sequence[str]] = None,
    ) -> "SyuPdfBuilder":
        self._include_cover = True
        if title:
            self.cover_title = title
        if subtitle:
            self.cover_subtitle = subtitle
        if meta_lines:
            self.cover_meta_lines = list(meta_lines)
        elif meta:
            self.cover_meta_lines = [meta]
        return self

    def add_section(
        self,
        title: str,
        body: str,
        *,
        level: int = 1,
        image: Optional[Union[str, Path]] = None,
        image_caption: Optional[str] = None,
        images: Optional[Sequence[Tuple[Union[str, Path], Optional[str]]]] = None,
        page_break_before: bool = True,
    ) -> "SyuPdfBuilder":
        extras: List[Tuple[Path, Optional[str]]] = []
        if images:
            for p, cap in images:
                extras.append((Path(p), cap))
        self.sections.append(
            Section(
                title=title,
                body=body,
                level=level,
                image=Path(image) if image else None,
                image_caption=image_caption,
                extra_images=extras,
                page_break_before=page_break_before,
            )
        )
        return self

    def add_image(
        self,
        path: Union[str, Path],
        caption: Optional[str] = None,
        *,
        under_last_section: bool = True,
    ) -> "SyuPdfBuilder":
        p = Path(path)
        if under_last_section and self.sections:
            sec = self.sections[-1]
            if sec.image is None:
                sec.image = p
                sec.image_caption = caption
            else:
                sec.extra_images.append((p, caption))
        else:
            self.add_section("Figure", "", image=p, image_caption=caption)
        return self

    def end_page(
        self,
        title: Optional[str] = None,
        body: Optional[str] = None,
    ) -> "SyuPdfBuilder":
        self._include_end = True
        if title:
            self.end_title = title
        if body is not None:
            self.end_body = body
        return self

    def build(self) -> Path:
        out = Path(self.output)
        out.parent.mkdir(parents=True, exist_ok=True)
        logo = Path(self.logo) if self.logo else None
        icon = Path(self.icon) if self.icon else None

        doc = _SyuDocTemplate(
            str(out),
            pagesize=A4,
            title=self.doc_title,
            author="SYU Sri Lanka",
            builder=self,
            logo=logo,
            icon=icon,
        )
        styles = _styles()
        story: List = []

        if self._include_cover:
            story.append(Spacer(1, 1))
            story.append(NextPageTemplate("TOC"))
            story.append(PageBreak())

        # Contents (NAITA: left title, hierarchical TOC)
        story.append(Paragraph("Contents", styles["ContentsTitle"]))
        story.append(Spacer(1, 8 * mm))
        toc = TableOfContents()
        toc.levelStyles = [
            ParagraphStyle(
                name="TOC1",
                fontName=FONT,
                fontSize=12,
                leading=18,
                leftIndent=0,
                firstLineIndent=0,
                textColor=INK,
            ),
            ParagraphStyle(
                name="TOC2",
                fontName=FONT,
                fontSize=11,
                leading=16,
                leftIndent=10 * mm,
                textColor=INK,
            ),
        ]
        story.append(toc)
        story.append(NextPageTemplate("Body"))
        story.append(PageBreak())

        for i, sec in enumerate(self.sections):
            if i > 0 and sec.page_break_before:
                story.append(PageBreak())
            heading_style = styles["Heading1"] if sec.level == 1 else styles["Heading2"]
            if sec.level == 1:
                story.append(Paragraph(sec.title, styles["ChapterTitle"]))
            else:
                story.append(Paragraph(sec.title, heading_style))
            story.append(Spacer(1, 6 * mm))
            for para in _split_paras(sec.body):
                story.append(Paragraph(para, styles["Body"]))
                story.append(Spacer(1, 4 * mm))

            figures: List[Tuple[Path, Optional[str]]] = []
            if sec.image:
                figures.append((sec.image, sec.image_caption))
            figures.extend(sec.extra_images)

            for path, caption in figures:
                if not path.exists():
                    continue
                # Phone screenshots are tall — prefer height budget
                img = _fit_image(path, max_w=95 * mm, max_h=145 * mm)
                bits = [Spacer(1, 4 * mm), img]
                if caption:
                    bits.append(Spacer(1, 2 * mm))
                    bits.append(Paragraph(caption, styles["Caption"]))
                story.append(KeepTogether(bits))

        if self._include_end:
            story.append(NextPageTemplate("End"))
            story.append(PageBreak())
            story.append(Spacer(1, 1))

        doc.multiBuild(story)
        return out


def _split_paras(text: str) -> Sequence[str]:
    parts = [p.strip().replace("\n", "<br/>") for p in text.split("\n\n")]
    return [p for p in parts if p]


def _fit_image(path: Path, max_w: float, max_h: float) -> Image:
    img = Image(str(path))
    iw, ih = float(img.imageWidth), float(img.imageHeight)
    scale = min(max_w / iw, max_h / ih, 1.0)
    img.drawWidth = iw * scale
    img.drawHeight = ih * scale
    img.hAlign = "CENTER"
    return img


def _styles():
    base = getSampleStyleSheet()
    return {
        "ChapterTitle": ParagraphStyle(
            "SYUChapterTitle",
            fontName=FONT,
            fontSize=18,
            leading=24,
            textColor=INK,
            alignment=TA_CENTER,
            spaceAfter=8,
        ),
        "ContentsTitle": ParagraphStyle(
            "SYUContentsTitle",
            fontName=FONT_BOLD,
            fontSize=16,
            leading=20,
            textColor=INK,
            alignment=TA_LEFT,
        ),
        "Heading1": ParagraphStyle(
            "SYUH1",
            parent=base["Heading1"],
            fontName=FONT_BOLD,
            fontSize=18,
            leading=24,
            textColor=INK,
            spaceBefore=12,
            spaceAfter=8,
            alignment=TA_LEFT,
        ),
        "Heading2": ParagraphStyle(
            "SYUH2",
            parent=base["Heading2"],
            fontName=FONT_BOLD,
            fontSize=16,
            leading=20,
            textColor=INK,
            spaceBefore=8,
            spaceAfter=6,
            alignment=TA_LEFT,
        ),
        "Body": ParagraphStyle(
            "SYUBody",
            fontName=FONT,
            fontSize=12,
            leading=18,
            textColor=INK,
            alignment=TA_JUSTIFY,
            spaceBefore=0,
            spaceAfter=0,
        ),
        "Caption": ParagraphStyle(
            "SYUCaption",
            fontName=FONT,
            fontSize=9,
            leading=12,
            textColor=MUTED,
            alignment=TA_CENTER,
        ),
    }


class _SyuDocTemplate(BaseDocTemplate):
    def __init__(
        self,
        filename: str,
        *,
        builder: SyuPdfBuilder,
        logo: Optional[Path],
        icon: Optional[Path],
        **kwargs,
    ):
        super().__init__(filename, **kwargs)
        self.builder = builder
        self.logo = logo
        self.icon = icon

        margin_l = 25 * mm
        margin_r = 20 * mm
        margin_t = 22 * mm
        margin_b = 20 * mm

        cover_frame = Frame(0, 0, PAGE_W, PAGE_H, id="cover")
        toc_frame = Frame(
            margin_l,
            margin_b,
            PAGE_W - margin_l - margin_r,
            PAGE_H - margin_t - margin_b,
            id="toc",
        )
        body_frame = Frame(
            margin_l,
            margin_b,
            PAGE_W - margin_l - margin_r,
            PAGE_H - margin_t - margin_b,
            id="body",
        )
        end_frame = Frame(0, 0, PAGE_W, PAGE_H, id="end")

        self.addPageTemplates(
            [
                PageTemplate(id="Cover", frames=[cover_frame], onPage=self._draw_cover),
                PageTemplate(id="TOC", frames=[toc_frame], onPage=self._draw_chrome),
                PageTemplate(id="Body", frames=[body_frame], onPage=self._draw_chrome),
                PageTemplate(id="End", frames=[end_frame], onPage=self._draw_end),
            ]
        )

    def afterFlowable(self, flowable):
        if not isinstance(flowable, Paragraph):
            return
        style_name = flowable.style.name
        text = flowable.getPlainText()
        if style_name in ("SYUChapterTitle", "SYUH1"):
            key = f"sec-{hash(text) & 0xFFFFFFF}"
            self.canv.bookmarkPage(key)
            self.notify("TOCEntry", (0, text, self.page, key))
        elif style_name == "SYUH2":
            key = f"sub-{hash(text) & 0xFFFFFFF}"
            self.canv.bookmarkPage(key)
            self.notify("TOCEntry", (1, text, self.page, key))

    def _draw_chrome(self, canv: canvas.Canvas, doc):
        """Light academic header/footer (not heavy color bars)."""
        canv.saveState()
        # Top hairline
        canv.setStrokeColor(RULE)
        canv.setLineWidth(0.6)
        y_top = PAGE_H - 14 * mm
        canv.line(25 * mm, y_top, PAGE_W - 20 * mm, y_top)
        canv.setFillColor(MUTED)
        canv.setFont(FONT, 9)
        canv.drawString(25 * mm, y_top + 3 * mm, self.builder.header_left)
        # Bottom hairline + page number (centered, like many academic reports)
        y_bot = 12 * mm
        canv.setStrokeColor(RULE)
        canv.line(25 * mm, y_bot, PAGE_W - 20 * mm, y_bot)
        canv.setFillColor(INK)
        canv.setFont(FONT, 10)
        canv.drawCentredString(PAGE_W / 2, 6 * mm, str(doc.page))
        if self.builder.footer_center:
            canv.setFillColor(MUTED)
            canv.setFont(FONT, 8)
            canv.drawString(25 * mm, 6 * mm, self.builder.footer_center[:40])
        canv.restoreState()

    def _draw_cover(self, canv: canvas.Canvas, doc):
        """White cover, centered serif titles + logo (NAITA layout)."""
        canv.saveState()
        canv.setFillColor(white)
        canv.rect(0, 0, PAGE_W, PAGE_H, fill=1, stroke=0)

        title = self.builder.cover_title or self.builder.doc_title
        sub = self.builder.cover_subtitle or self.builder.doc_subtitle

        y = PAGE_H - 45 * mm
        canv.setFillColor(INK)
        canv.setFont(FONT_BOLD, 20)
        for line in _wrap_center(title, 40):
            canv.drawCentredString(PAGE_W / 2, y, line)
            y -= 8 * mm

        y -= 4 * mm
        canv.setFont(FONT, 14)
        for line in _wrap_center(sub, 50):
            canv.drawCentredString(PAGE_W / 2, y, line)
            y -= 7 * mm

        # Accent underline
        canv.setStrokeColor(ACCENT)
        canv.setLineWidth(1.2)
        canv.line(PAGE_W / 2 - 30 * mm, y, PAGE_W / 2 + 30 * mm, y)
        y -= 18 * mm

        if self.logo and self.logo.exists():
            try:
                lw, lh = 55 * mm, 22 * mm
                canv.drawImage(
                    str(self.logo),
                    (PAGE_W - lw) / 2,
                    y - lh,
                    width=lw,
                    height=lh,
                    mask="auto",
                    preserveAspectRatio=True,
                )
                y -= lh + 20 * mm
            except Exception:
                y -= 10 * mm
        elif self.icon and self.icon.exists():
            try:
                s = 28 * mm
                canv.drawImage(
                    str(self.icon),
                    (PAGE_W - s) / 2,
                    y - s,
                    width=s,
                    height=s,
                    mask="auto",
                    preserveAspectRatio=True,
                )
                y -= s + 20 * mm
            except Exception:
                pass

        # Meta block (label : value style), lower third
        meta = self.builder.cover_meta_lines or []
        y = min(y, 70 * mm)
        canv.setFont(FONT, 11)
        canv.setFillColor(INK)
        left = 45 * mm
        for line in meta:
            canv.drawString(left, y, line)
            y -= 7 * mm

        canv.restoreState()

    def _draw_end(self, canv: canvas.Canvas, doc):
        canv.saveState()
        canv.setFillColor(white)
        canv.rect(0, 0, PAGE_W, PAGE_H, fill=1, stroke=0)

        if self.icon and self.icon.exists():
            try:
                s = 18 * mm
                canv.drawImage(
                    str(self.icon),
                    (PAGE_W - s) / 2,
                    PAGE_H / 2 + 25 * mm,
                    width=s,
                    height=s,
                    mask="auto",
                    preserveAspectRatio=True,
                )
            except Exception:
                pass

        canv.setFillColor(INK)
        canv.setFont(FONT, 16)
        canv.drawCentredString(PAGE_W / 2, PAGE_H / 2 + 5 * mm, self.builder.end_title)
        canv.setStrokeColor(ACCENT)
        canv.setLineWidth(1)
        canv.line(PAGE_W / 2 - 25 * mm, PAGE_H / 2, PAGE_W / 2 + 25 * mm, PAGE_H / 2)
        canv.setFont(FONT, 10)
        canv.setFillColor(MUTED)
        y = PAGE_H / 2 - 12 * mm
        for line in self.builder.end_body.split("\n"):
            if line.strip():
                canv.drawCentredString(PAGE_W / 2, y, line.strip())
                y -= 5 * mm
        canv.setFont(FONT, 10)
        canv.setFillColor(INK)
        canv.drawCentredString(PAGE_W / 2, 6 * mm, str(doc.page))
        canv.restoreState()


def _wrap_center(text: str, width: int) -> List[str]:
    words = text.split()
    if not words:
        return [""]
    lines: List[str] = []
    cur = words[0]
    for w in words[1:]:
        if len(cur) + 1 + len(w) <= width:
            cur += " " + w
        else:
            lines.append(cur)
            cur = w
    lines.append(cur)
    return lines
