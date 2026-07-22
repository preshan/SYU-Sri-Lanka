# Temporary PDF generator (SYU docs)

Small ReportLab helper to produce branded PDFs with:

- Cover page (logo)
- Contents / index with **clickable links** to sections
- Header + footer + page numbers
- Body pages (text + images)
- End page

Not used by the Flutter app — local tooling only.

## Setup

```bash
cd tools/pdf_doc
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

## Sample (5–6 page test PDF)

```bash
python generate_sample.py
# → tools/pdf_doc/output/SYU-Sri-Lanka-doc-sample.pdf
```

Open in Preview / Chrome and click **Contents** entries to jump.

## Use in your own script

```python
from syu_pdf import SyuPdfBuilder

SyuPdfBuilder(
    output="my.pdf",
    logo="../../assets/brand/syu_logo_full.png",
    icon="../../assets/brand/syu_icon_192.png",
).cover(title="SYU Sri Lanka", subtitle="Full product guide") \
 .add_section("Overview", "Text here...") \
 .add_section("Members", "More text...", image="shots/SS-04-member-home.png", image_caption="SS-04") \
 .end_page() \
 .build()
```

## Word docs

This path generates PDF directly (no Word). If you already have a `.docx`, convert with LibreOffice or paste content into `add_section` calls. For a future Word→PDF pipeline, keep this package as the layout engine.
