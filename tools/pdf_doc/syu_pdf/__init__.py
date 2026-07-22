"""
SYU temporary PDF documentation builder.

Features:
  - Cover page (logo)
  - Index / TOC with clickable links + page numbers
  - Header / footer on content pages
  - Body pages with text + images
  - End page

Usage:
  from syu_pdf import SyuPdfBuilder
  b = SyuPdfBuilder(output="out.pdf", logo=".../syu_logo_full.png")
  b.cover(title="...", subtitle="...")
  b.add_section("Overview", "Body text...")
  b.add_image("shot.png", caption="SS-04")
  b.end_page()
  b.build()
"""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
from typing import List, Optional, Sequence, Union

from reportlab.lib.colors import HexColor, white
from reportlab.lib.enums import TA_CENTER, TA_JUSTIFY
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
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

CRIMSON = HexColor("#E10600")
NEAR_BLACK = HexColor("#0A0A0A")
MUTED = HexColor("#555555")
LIGHT_GRAY = HexColor("#F5F5F5")


@dataclass
class Section:
    title: str
    body: str
    level: int = 1
    image: Optional[Path] = None
    image_caption: Optional[str] = None


@dataclass
class SyuPdfBuilder:
    """Build a branded multi-page PDF with TOC links, header, footer, end page."""

    output: Union[str, Path]
    logo: Optional[Union[str, Path]] = None
    icon: Optional[Union[str, Path]] = None
    doc_title: str = "SYU Sri Lanka"
    doc_subtitle: str = "Product documentation"
    header_left: str = "SYU Sri Lanka"
    footer_center: str = "Confidential — internal use"
    cover_title: Optional[str] = None
    cover_subtitle: Optional[str] = None
    cover_meta: Optional[str] = None
    sections: List[Section] = field(default_factory=list)
    end_title: str = "Thank you"
    end_body: str = (
        "For support, contact your SYU administrator.\n"
        "App: https://preshan.github.io/SYU-Sri-Lanka/"
    )
    _include_cover: bool = True
    _include_end: bool = True

    def cover(
        self,
        title: Optional[str] = None,
        subtitle: Optional[str] = None,
        meta: Optional[str] = None,
    ) -> "SyuPdfBuilder":
        self._include_cover = True
        if title:
            self.cover_title = title
        if subtitle:
            self.cover_subtitle = subtitle
        if meta:
            self.cover_meta = meta
        return self

    def add_section(
        self,
        title: str,
        body: str,
        *,
        level: int = 1,
        image: Optional[Union[str, Path]] = None,
        image_caption: Optional[str] = None,
    ) -> "SyuPdfBuilder":
        self.sections.append(
            Section(
                title=title,
                body=body,
                level=level,
                image=Path(image) if image else None,
                image_caption=image_caption,
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
            self.sections[-1].image = p
            self.sections[-1].image_caption = caption
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
        if body:
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

        # Page 1 = Cover (first template). Minimal flowable so the page exists.
        if self._include_cover:
            story.append(Spacer(1, 1))
            story.append(NextPageTemplate("TOC"))
            story.append(PageBreak())

        # Index / Contents (clickable after multiBuild)
        story.append(Paragraph("Contents", styles["Heading1"]))
        story.append(Spacer(1, 6 * mm))
        toc = TableOfContents()
        toc.levelStyles = [
            ParagraphStyle(
                name="TOC1",
                fontName="Helvetica",
                fontSize=12,
                leading=18,
                leftIndent=0,
                textColor=NEAR_BLACK,
            ),
            ParagraphStyle(
                name="TOC2",
                fontName="Helvetica",
                fontSize=10,
                leading=14,
                leftIndent=12,
                textColor=MUTED,
            ),
        ]
        story.append(toc)
        story.append(NextPageTemplate("Body"))
        story.append(PageBreak())

        # Body sections (one section per page for the sample layout)
        for i, sec in enumerate(self.sections):
            heading_style = styles["Heading1"] if sec.level == 1 else styles["Heading2"]
            story.append(Paragraph(sec.title, heading_style))
            story.append(Spacer(1, 3 * mm))
            for para in _split_paras(sec.body):
                story.append(Paragraph(para, styles["Body"]))
                story.append(Spacer(1, 2 * mm))
            if sec.image and sec.image.exists():
                img = _fit_image(sec.image, max_w=150 * mm, max_h=90 * mm)
                bits = [Spacer(1, 4 * mm), img]
                if sec.image_caption:
                    bits.append(Spacer(1, 2 * mm))
                    bits.append(Paragraph(sec.image_caption, styles["Caption"]))
                story.append(KeepTogether(bits))
            if i < len(self.sections) - 1:
                story.append(PageBreak())
            elif self._include_end:
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
        "Heading1": ParagraphStyle(
            "SYUH1",
            parent=base["Heading1"],
            fontName="Helvetica-Bold",
            fontSize=18,
            textColor=CRIMSON,
            spaceAfter=6,
            spaceBefore=0,
        ),
        "Heading2": ParagraphStyle(
            "SYUH2",
            parent=base["Heading2"],
            fontName="Helvetica-Bold",
            fontSize=14,
            textColor=NEAR_BLACK,
            spaceAfter=4,
        ),
        "Body": ParagraphStyle(
            "SYUBody",
            parent=base["Normal"],
            fontName="Helvetica",
            fontSize=11,
            leading=16,
            textColor=NEAR_BLACK,
            alignment=TA_JUSTIFY,
        ),
        "Caption": ParagraphStyle(
            "SYUCaption",
            parent=base["Normal"],
            fontName="Helvetica-Oblique",
            fontSize=9,
            textColor=MUTED,
            alignment=TA_CENTER,
        ),
        "CoverTitle": ParagraphStyle(
            "SYUCoverTitle",
            fontName="Helvetica-Bold",
            fontSize=28,
            textColor=white,
            alignment=TA_CENTER,
            leading=34,
        ),
        "CoverSub": ParagraphStyle(
            "SYUCoverSub",
            fontName="Helvetica",
            fontSize=14,
            textColor=white,
            alignment=TA_CENTER,
            leading=20,
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
        self._page_offset = 0  # content page numbering starts after cover+toc

        page_w, page_h = A4
        margin = 18 * mm

        cover_frame = Frame(0, 0, page_w, page_h, id="cover")
        toc_frame = Frame(
            margin, margin + 12 * mm, page_w - 2 * margin, page_h - 2 * margin - 12 * mm, id="toc"
        )
        body_frame = Frame(
            margin, margin + 12 * mm, page_w - 2 * margin, page_h - 2 * margin - 14 * mm, id="body"
        )
        end_frame = Frame(0, 0, page_w, page_h, id="end")

        self.addPageTemplates(
            [
                PageTemplate(id="Cover", frames=[cover_frame], onPage=self._draw_cover),
                PageTemplate(id="TOC", frames=[toc_frame], onPage=self._draw_toc_chrome),
                PageTemplate(id="Body", frames=[body_frame], onPage=self._draw_body_chrome),
                PageTemplate(id="End", frames=[end_frame], onPage=self._draw_end),
            ]
        )

    def afterFlowable(self, flowable):
        """Register TOC entries for Heading1/Heading2 paragraphs."""
        if not isinstance(flowable, Paragraph):
            return
        style_name = flowable.style.name
        text = flowable.getPlainText()
        if style_name == "SYUH1":
            key = f"sec-{text}"
            self.canv.bookmarkPage(key)
            self.notify("TOCEntry", (0, text, self.page, key))
        elif style_name == "SYUH2":
            key = f"sub-{text}"
            self.canv.bookmarkPage(key)
            self.notify("TOCEntry", (1, text, self.page, key))

    def _draw_header_footer(self, canv: canvas.Canvas, doc, *, show_page: bool):
        page_w, page_h = A4
        canv.saveState()
        # Header bar
        canv.setFillColor(CRIMSON)
        canv.rect(0, page_h - 10 * mm, page_w, 10 * mm, fill=1, stroke=0)
        canv.setFillColor(white)
        canv.setFont("Helvetica-Bold", 9)
        canv.drawString(18 * mm, page_h - 6.5 * mm, self.builder.header_left)
        if self.icon and self.icon.exists():
            try:
                canv.drawImage(
                    str(self.icon),
                    page_w - 18 * mm - 7 * mm,
                    page_h - 9 * mm,
                    width=7 * mm,
                    height=7 * mm,
                    mask="auto",
                    preserveAspectRatio=True,
                )
            except Exception:
                pass
        # Footer
        canv.setFillColor(LIGHT_GRAY)
        canv.rect(0, 0, page_w, 12 * mm, fill=1, stroke=0)
        canv.setStrokeColor(CRIMSON)
        canv.setLineWidth(1.5)
        canv.line(18 * mm, 12 * mm, page_w - 18 * mm, 12 * mm)
        canv.setFillColor(MUTED)
        canv.setFont("Helvetica", 8)
        canv.drawCentredString(page_w / 2, 5 * mm, self.builder.footer_center)
        if show_page:
            # Page number for body: exclude cover (page 1) and count from TOC as i, ii or numeric
            canv.setFillColor(NEAR_BLACK)
            canv.setFont("Helvetica-Bold", 9)
            canv.drawRightString(page_w - 18 * mm, 5 * mm, f"{doc.page}")
        canv.restoreState()

    def _draw_cover(self, canv: canvas.Canvas, doc):
        page_w, page_h = A4
        canv.saveState()
        canv.setFillColor(NEAR_BLACK)
        canv.rect(0, 0, page_w, page_h, fill=1, stroke=0)
        # crimson accent band
        canv.setFillColor(CRIMSON)
        canv.rect(0, page_h * 0.38, page_w, 28 * mm, fill=1, stroke=0)

        if self.logo and self.logo.exists():
            try:
                lw, lh = 70 * mm, 28 * mm
                canv.drawImage(
                    str(self.logo),
                    (page_w - lw) / 2,
                    page_h * 0.62,
                    width=lw,
                    height=lh,
                    mask="auto",
                    preserveAspectRatio=True,
                    anchor="c",
                )
            except Exception:
                pass

        title = self.builder.cover_title or self.builder.doc_title
        sub = self.builder.cover_subtitle or self.builder.doc_subtitle
        meta = self.builder.cover_meta or ""

        canv.setFillColor(white)
        canv.setFont("Helvetica-Bold", 22)
        canv.drawCentredString(page_w / 2, page_h * 0.42, title)
        canv.setFont("Helvetica", 12)
        canv.drawCentredString(page_w / 2, page_h * 0.42 - 10 * mm, sub)
        if meta:
            canv.setFont("Helvetica", 9)
            canv.setFillColor(HexColor("#CCCCCC"))
            canv.drawCentredString(page_w / 2, 25 * mm, meta)
        canv.restoreState()

    def _draw_toc_chrome(self, canv: canvas.Canvas, doc):
        self._draw_header_footer(canv, doc, show_page=True)

    def _draw_body_chrome(self, canv: canvas.Canvas, doc):
        self._draw_header_footer(canv, doc, show_page=True)

    def _draw_end(self, canv: canvas.Canvas, doc):
        page_w, page_h = A4
        canv.saveState()
        canv.setFillColor(NEAR_BLACK)
        canv.rect(0, 0, page_w, page_h, fill=1, stroke=0)
        canv.setFillColor(CRIMSON)
        canv.rect(0, page_h / 2 - 20 * mm, page_w, 40 * mm, fill=1, stroke=0)

        if self.icon and self.icon.exists():
            try:
                canv.drawImage(
                    str(self.icon),
                    (page_w - 18 * mm) / 2,
                    page_h / 2 + 28 * mm,
                    width=18 * mm,
                    height=18 * mm,
                    mask="auto",
                    preserveAspectRatio=True,
                )
            except Exception:
                pass

        canv.setFillColor(white)
        canv.setFont("Helvetica-Bold", 20)
        canv.drawCentredString(page_w / 2, page_h / 2 + 4 * mm, self.builder.end_title)
        canv.setFont("Helvetica", 10)
        y = page_h / 2 - 8 * mm
        for line in self.builder.end_body.split("\n"):
            canv.drawCentredString(page_w / 2, y, line.strip())
            y -= 5 * mm
        canv.restoreState()
