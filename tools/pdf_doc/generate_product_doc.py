#!/usr/bin/env python3
"""Generate the full SYU Sri Lanka product documentation PDF with screenshots + Mermaid."""

from __future__ import annotations

import base64
import sys
import urllib.error
import urllib.request
from pathlib import Path
from typing import Optional

ROOT = Path(__file__).resolve().parents[2]
BRAND = ROOT / "assets" / "brand"
SHOTS = ROOT / "docs" / "samples" / "screenshots"
DIAG = Path(__file__).resolve().parent / "output" / "diagrams"
OUT = ROOT / "docs" / "samples" / "SYU-Sri-Lanka-Product-Documentation.pdf"

sys.path.insert(0, str(Path(__file__).resolve().parent))
from syu_pdf import SyuPdfBuilder  # noqa: E402


def ss(n: int) -> Path:
    return SHOTS / f"SS-{n:02d}.png"


def render_mermaid(name: str, source: str) -> Optional[Path]:
    """Render Mermaid to PNG via mermaid.ink (fallback: skip figure)."""
    DIAG.mkdir(parents=True, exist_ok=True)
    out = DIAG / f"{name}.png"
    if out.exists() and out.stat().st_size > 500:
        return out
    # mermaid.ink expects base64 of the diagram text
    b64 = base64.urlsafe_b64encode(source.encode("utf-8")).decode("ascii")
    url = f"https://mermaid.ink/img/{b64}?type=png"
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "SYU-pdf-doc/1.0"})
        with urllib.request.urlopen(req, timeout=60) as resp:
            data = resp.read()
        if data[:8] == b"\x89PNG\r\n\x1a\n" or data[:2] == b"\xff\xd8":
            out.write_bytes(data)
            print(f"  diagram {name}: {len(data)} bytes")
            return out
        # sometimes SVG returned
        if b"<svg" in data[:200]:
            out_svg = DIAG / f"{name}.svg"
            out_svg.write_bytes(data)
            print(f"  diagram {name}: svg saved (png preferred)")
            return None
        print(f"  diagram {name}: unexpected payload {data[:40]!r}")
    except Exception as e:
        print(f"  diagram {name}: failed ({e})")
    return None


def build_diagrams() -> dict:
    diagrams = {}
    diagrams["architecture"] = render_mermaid(
        "architecture",
        """
flowchart LR
  subgraph Clients
    A[Android app]
    W[Flutter Web]
  end
  subgraph Supabase
    Auth[Auth]
    DB[(Postgres + RLS)]
    St[Storage]
    Edge[Edge Functions]
  end
  A --> Auth
  A --> DB
  A --> St
  A --> Edge
  W --> Auth
  W --> DB
  W --> Edge
  Edge --> Mail[Gmail SMTP]
""",
    )
    diagrams["roles"] = render_mermaid(
        "roles",
        """
flowchart TB
  SA[super_admin]
  DA[district_admin]
  VA[division_admin]
  M[member]
  SA -->|creates| DA
  SA -->|creates| VA
  DA -->|creates| VA
  SA --> M
  DA --> M
  VA --> M
""",
    )
    diagrams["login_gates"] = render_mermaid(
        "login_gates",
        """
flowchart TD
  L[Login success] --> S{Suspended?}
  S -->|yes| X[Sign out + message]
  S -->|no| V{Email verified?}
  V -->|no| C[/confirm-email/]
  V -->|yes| P{must_change_password?}
  P -->|yes| F[/force-password/]
  P -->|no| H[/home/]
  C --> H
  F --> H
""",
    )
    diagrams["signup"] = render_mermaid(
        "signup",
        """
sequenceDiagram
  actor U as Guest
  participant App
  participant Auth as Supabase Auth
  participant Fn as send-app-otp
  participant Mail as Gmail
  U->>App: Register
  App->>Auth: signUp
  App->>Fn: purpose=signup
  Fn->>Mail: 6-digit OTP
  U->>App: Confirm email
  App->>App: /home
""",
    )
    diagrams["admin_nav"] = render_mermaid(
        "admin_nav",
        """
flowchart TB
  Home[Admin dashboard]
  Home --> Members
  Home --> Chat
  Home --> Broadcast
  Home --> News
  Home --> Events
  Home --> StaffAdmins[District and DN admins]
  Home --> Organizers
  Home --> WhatsApp[WhatsApp group link]
""",
    )
    return {k: v for k, v in diagrams.items() if v and v.exists()}


def main() -> Path:
    print("Rendering Mermaid diagrams…")
    d = build_diagrams()

    logo = BRAND / "syu_logo_full.png"
    icon = BRAND / "syu_icon_192.png"

    b = SyuPdfBuilder(
        output=OUT,
        logo=logo if logo.exists() else None,
        icon=icon if icon.exists() else None,
        doc_title="SYU Sri Lanka",
        doc_subtitle="Product Documentation",
        header_left="SYU Sri Lanka — Product Documentation",
    ).cover(
        title="State Youth Union Sri Lanka",
        subtitle="Membership Application — Product Documentation",
        meta_lines=[
            "Document          : Product documentation",
            "Application       : SYU Sri Lanka (Flutter + Supabase)",
            "Version           : 0.10.2",
            "Screenshots       : SS-01 … SS-15",
            "Audience          : Stakeholders / UAT / training",
        ],
    )

    # 1 Overview
    imgs = []
    if d.get("architecture"):
        imgs.append((d["architecture"], "Figure 1.1: System context"))
    b.add_section(
        "1. Overview",
        "SYU Sri Lanka is a Flutter membership application for the State Youth Union. "
        "Members register, complete a profile wizard, read news, RSVP to events, and chat. "
        "Staff admins manage members by district and DS division, publish content, and "
        "provision accounts.\n\n"
        "Backend platform: <b>Supabase</b> (Auth, Postgres with Row Level Security, Storage, "
        "Realtime, Edge Functions). Clients use the anon key only; privileged actions "
        "(OTP mail, admin create member/staff) run in Edge Functions with the service role.",
        images=imgs,
    )

    # 2 Architecture & roles
    imgs = []
    if d.get("roles"):
        imgs.append((d["roles"], "Figure 2.1: Role hierarchy"))
    b.add_section(
        "2. Architecture and roles",
        "<b>Member</b> — self-service profile, news, events, chat.<br/>"
        "<b>Division admin</b> — members in a DS division; WhatsApp group link; add members.<br/>"
        "<b>District admin</b> — members in a district; create division admins; organizers.<br/>"
        "<b>Super admin</b> — national tools: publish news/events, broadcast, clubs, "
        "staff admins (reference: admin@syu.lk).\n\n"
        "Authorization is enforced in Postgres RLS. Staff UI is gated by "
        "<b>is_staff_admin()</b> (super ∨ district ∨ division).",
        images=imgs,
    )

    # 3 Guest / auth
    imgs = []
    if ss(1).exists():
        imgs.append((ss(1), "Figure 3.1: Splash / brand (SS-01) — Guest"))
    if ss(2).exists():
        imgs.append((ss(2), "Figure 3.2: Sign in (SS-02) — Guest"))
    if ss(3).exists():
        imgs.append((ss(3), "Figure 3.3: Create account (SS-03) — Guest"))
    if d.get("signup"):
        imgs.append((d["signup"], "Figure 3.4: Sign-up OTP sequence"))
    if d.get("login_gates"):
        imgs.append((d["login_gates"], "Figure 3.5: Login gates"))
    b.add_section(
        "3. Guest entry — splash, login, register",
        "Cold start shows the brand splash, then login. Guests create an account with "
        "name, email, and password. After sign-up the app sends a six-digit OTP via "
        "Edge Function <b>send-app-otp</b> (Gmail SMTP in app_mail_settings), bypassing "
        "Supabase Auth email quotas.\n\n"
        "<b>Text paths (no screenshot):</b> Confirm email at /confirm-email; "
        "Forgot password at /forgot-password; Force password change for admin-provisioned "
        "users at /force-password; Suspended accounts are blocked at login.",
        images=imgs,
    )

    # 4 Member app
    imgs = []
    for n, cap in [
        (4, "Figure 4.1: Member home (SS-04) — Member"),
        (5, "Figure 4.2: Registration · Personal (SS-05) — Member"),
        (6, "Figure 4.3: News feed (SS-06) — Member"),
        (7, "Figure 4.4: Events list (SS-07) — Member"),
    ]:
        if ss(n).exists():
            imgs.append((ss(n), cap))
    b.add_section(
        "4. Member experience",
        "After login, members see the home hub (RISE TOGETHER), completeness banner when "
        "NIC/location/etc. are missing, and shortcuts to news and events.\n\n"
        "Registration wizard collects personal data, location (district → DS → GN), "
        "youth club, and qualifications. News and Events tabs list published items "
        "for audience <b>all</b> (or scoped to the member’s location).\n\n"
        "<b>Text paths:</b> Settings → language / notifications; Edit profile; "
        "Chat inbox → open thread; Notification center; RSVP Going on an event.",
        images=imgs,
    )

    # 5 Admin
    imgs = []
    if d.get("admin_nav"):
        imgs.append((d["admin_nav"], "Figure 5.1: Admin dashboard modules"))
    for n, cap in [
        (8, "Figure 5.2: Admin dashboard — Super admin (SS-08)"),
        (9, "Figure 5.3: Admin dashboard — District scope (SS-09)"),
        (10, "Figure 5.4: Members list (SS-10)"),
        (11, "Figure 5.5: Add member (SS-11)"),
        (12, "Figure 5.6: Create announcement (SS-12)"),
        (13, "Figure 5.7: Create event (SS-13)"),
        (14, "Figure 5.8: District & DN admins (SS-14)"),
        (15, "Figure 5.9: Divisional organizers (SS-15)"),
    ]:
        if ss(n).exists():
            imgs.append((ss(n), cap))
    b.add_section(
        "5. Staff administration",
        "Staff land on an admin dashboard with tiles for Members, Saved, Chat, Broadcast, "
        "News, Events, District & DN admins, Organizers, and (for division admins) "
        "WhatsApp group link.\n\n"
        "<b>Add member</b> provisions Auth + profile and emails a temporary password "
        "(force password change on first login). <b>Publish</b> news/events with audience "
        "ALL or district/DS/GN and optional notify.\n\n"
        "<b>Staff Admins:</b> Super admin creates district and division admins; "
        "district admin creates division admins only.\n\n"
        "<b>Text paths:</b> Member row actions (note / suspend / save); Broadcast; "
        "Admin chat; Youth clubs; Audit; Reports; Change email while force-password pending.",
        images=imgs,
    )

    # 6 Flows summary
    b.add_section(
        "6. Flow catalogue summary",
        "The repository documents thirty-four flows (F-01…F-34) in "
        "<b>docs/SCREENSHOT_GUIDE.md</b>. Fifteen require screenshots (this document); "
        "the remainder are described as text paths (OTP confirm, forgot password, "
        "edit profile, chat thread, broadcast, clubs, audit, etc.).\n\n"
        "Use cases UC-01…UC-22 and Mermaid sources also live in <b>docs/USE_CASES.md</b> "
        "and <b>docs/ARCHITECTURE.md</b>.",
    )

    b.end_page(
        title="— End of Document —",
        body="SYU Sri Lanka · Product documentation · v0.10.2\n"
        "github.com/preshan/SYU-Sri-Lanka",
    )

    path = b.build()
    print(f"Wrote {path}")
    return path


if __name__ == "__main__":
    main()
