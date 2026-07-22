# Temporary PDF generator (SYU docs)

Office-style report layout with **Calibri-like** fonts:

1. System **Calibri** (if installed)
2. Bundled **Carlito** in `fonts/` (Calibri-compatible, SIL OFL)
3. Arial / Helvetica fallback

White pages, centered chapter titles, justified body, Contents with clickable links.

## Setup

```bash
cd tools/pdf_doc
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python generate_sample.py
# → output/SYU-Sri-Lanka-doc-sample.pdf
```
