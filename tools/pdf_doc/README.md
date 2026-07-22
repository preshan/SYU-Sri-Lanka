# Temporary PDF generator (SYU docs)

NAITA-style academic report layout (Times / serif, white pages, centered chapter
titles, justified body, Contents with clickable page links).

## Setup

```bash
cd tools/pdf_doc
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python generate_sample.py
# → output/SYU-Sri-Lanka-doc-sample.pdf
```

Open the PDF and click **Contents** entries to jump to sections.
