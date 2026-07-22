#!/usr/bin/env python3
"""Generate a simple 5-page test PDF for SYU Sri Lanka app documentation."""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BRAND = ROOT / "assets" / "brand"
OUT_DIR = Path(__file__).resolve().parent / "output"
OUT_DIR.mkdir(parents=True, exist_ok=True)

# Allow `python generate_sample.py` without installing the package.
sys.path.insert(0, str(Path(__file__).resolve().parent))

from syu_pdf import SyuPdfBuilder  # noqa: E402


def main() -> Path:
    logo = BRAND / "syu_logo_full.png"
    icon = BRAND / "syu_icon_192.png"
    out = OUT_DIR / "SYU-Sri-Lanka-doc-sample.pdf"

    builder = (
        SyuPdfBuilder(
            output=out,
            logo=logo if logo.exists() else None,
            icon=icon if icon.exists() else None,
            doc_title="SYU Sri Lanka",
            doc_subtitle="App documentation — sample",
            header_left="SYU Sri Lanka · Product documentation",
            footer_center="SYU Sri Lanka — sample PDF (temporary generator)",
        )
        .cover(
            title="SYU Sri Lanka",
            subtitle="Membership app — documentation sample",
            meta="v0.10.2  ·  Test PDF  ·  Click Contents links to jump",
        )
        .add_section(
            "1. Overview",
            "SYU Sri Lanka is a Flutter + Supabase membership app for State Youth Union.\n\n"
            "Members register with email OTP (Gmail via Edge Function), complete a registration "
            "wizard, read news, RSVP to events, and chat. Staff roles manage members and publish content.\n\n"
            "This sample demonstrates cover, clickable Contents, headers, footers, page numbers, "
            "images, and an end page.",
            image=logo if logo.exists() else None,
            image_caption="Brand mark — assets/brand/syu_logo_full.png",
        )
        .add_section(
            "2. Roles, flows & screenshots",
            "<b>Roles:</b> Member · Division admin · District admin · Super admin (<i>admin@syu.lk</i>).<br/><br/>"
            "<b>Key flows:</b> Guest → Register → OTP → Home; Login gates (suspend / verify / force password); "
            "Admin → Members → Add member; Publish news/events.<br/><br/>"
            "Full catalogue: <b>docs/SCREENSHOT_GUIDE.md</b> (15 screenshots + 34 flows) · "
            "<b>docs/USE_CASES.md</b> · <b>docs/ARCHITECTURE.md</b>.",
            image=icon if icon.exists() else None,
            image_caption="App icon — assets/brand/syu_icon_192.png",
        )
        .end_page(
            title="End of sample",
            body="Replace this generator output with the full product PDF once screenshots are ready.\n"
            "Generator: tools/pdf_doc/  ·  Repo: github.com/preshan/SYU-Sri-Lanka",
        )
    )

    path = builder.build()
    print(f"Wrote {path}")
    print("Pages: cover + contents + 2 sections + end = 5")
    return path


if __name__ == "__main__":
    main()
