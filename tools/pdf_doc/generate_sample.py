#!/usr/bin/env python3
"""Generate a 5-page NAITA-style sample PDF for SYU Sri Lanka documentation."""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BRAND = ROOT / "assets" / "brand"
OUT_DIR = Path(__file__).resolve().parent / "output"
OUT_DIR.mkdir(parents=True, exist_ok=True)
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
            doc_subtitle="Product Documentation (Sample)",
            header_left="SYU Sri Lanka — Product Documentation",
        )
        .cover(
            title="State Youth Union Sri Lanka",
            subtitle="Membership Application — Product Documentation",
            meta_lines=[
                "Document          : Product documentation (sample)",
                "Application       : SYU Sri Lanka (Flutter + Supabase)",
                "Version           : 0.10.2",
                "Audience          : Stakeholders / UAT / internal training",
            ],
        )
        .add_section(
            "1. Overview",
            "This document introduces the <b>SYU Sri Lanka</b> membership application. "
            "The app supports youth member registration, profile management, news, events, "
            "and messaging, together with staff tools for district and division administration.\n\n"
            "The system is built with <b>Flutter</b> (Android and web) and <b>Supabase</b> "
            "(Auth, Postgres with Row Level Security, Storage, and Edge Functions). "
            "Email verification and password recovery use a six-digit OTP sent through "
            "Gmail via the <b>send-app-otp</b> Edge Function, avoiding Supabase Auth email quotas.\n\n"
            "Formatting of this sample follows a conventional product-report layout "
            "(Calibri-like body text, centered chapter titles, Contents with page links).",
            image=logo if logo.exists() else None,
            image_caption="Figure 1: SYU Sri Lanka brand mark",
        )
        .add_section(
            "2. Roles and Access",
            "Access is controlled by roles stored in Postgres and enforced with RLS.\n\n"
            "<b>Member</b> — Completes registration, maintains a profile, reads news, "
            "RSVPs to events, and uses member chat.\n\n"
            "<b>Division admin</b> — Manages members within a DS division, may add members, "
            "and can set the division WhatsApp group link.\n\n"
            "<b>District admin</b> — Manages members within a district, creates division admins, "
            "and maintains divisional organizers.\n\n"
            "<b>Super admin</b> — National scope: publish news and events, broadcast messages, "
            "manage youth clubs and staff admins (reference account: admin@syu.lk).\n\n"
            "Detailed flows and the screenshot checklist are maintained in the repository under "
            "<b>docs/USE_CASES.md</b>, <b>docs/ARCHITECTURE.md</b>, and "
            "<b>docs/SCREENSHOT_GUIDE.md</b> (fifteen required screenshots and thirty-four flows).",
            image=icon if icon.exists() else None,
            image_caption="Figure 2: Application icon",
        )
        .end_page(
            title="— End of Sample Document —",
            body="Full product PDF will include captured screens (SS-01 … SS-15).\n"
            "Generator: tools/pdf_doc/  ·  github.com/preshan/SYU-Sri-Lanka",
        )
    )

    path = builder.build()
    print(f"Wrote {path}")
    return path


if __name__ == "__main__":
    main()
