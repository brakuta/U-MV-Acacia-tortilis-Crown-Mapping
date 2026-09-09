#!/usr/bin/env python3
"""Build the Windows runbook (PDF) from docs/09_windows_runbook.md."""
import datetime
from pathlib import Path

from _pdfbook import NUM, ROOT, S, Doc, NextPageTemplate, PageBreak, Paragraph, Spacer, cm, heading, md_to_flowables, read  # noqa: F401

VERSION = '1.0'
DATE = datetime.date(2026, 9, 9).strftime('%d %B %Y')
OUT = ROOT / 'docs' / 'U-MV_Windows_Runbook.pdf'

md = read('docs/09_windows_runbook.md')
title, body = md.split('\n', 1)
NUM.chapter('')  # unnumbered headings
story = [NextPageTemplate('main')] + heading(1, title.lstrip('# ').strip())
story += [Paragraph(f'Version {VERSION} · {DATE} · companion to the U-MV technical hand-over guide', S['note'])]
story += md_to_flowables(body, skip_h1=True)

if __name__ == '__main__':
    import argparse
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--out', default=str(OUT))
    out = Path(ap.parse_args().out)
    Doc(str(out), header='U-MV · Windows runbook (PowerShell + Docker Desktop)', footer_right=f'v{VERSION} · {DATE}',
        title='U-MV Windows runbook', author='Mohamed Barakat A. Gibril', subject='Step-by-step setup').multiBuild(story)
    print('written', out, out.stat().st_size // 1024, 'kB')
