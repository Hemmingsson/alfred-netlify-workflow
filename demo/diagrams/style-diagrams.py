#!/usr/bin/env python3
"""Apply the documentation style to exported technical diagrams, then render all PNGs.
Run after build-wireframes.py (or after re-exporting a technical diagram).
"""
from pathlib import Path
import re
import subprocess
import tempfile

root = Path(__file__).resolve().parents[2] / 'assets' / 'diagrams'
for name in ('cache-first-refresh', 'module-dependencies', 'preview-decision'):
    path = root / f'{name}.svg'
    svg = path.read_text()
    svg = re.sub(r'<style id="documentation-style">.*?</style>', '', svg, flags=re.S)
    # Use the same installed monospace family for every text role.
    svg = re.sub(r'--sc-font-(?:serif|sans|mono):[^;]+;', lambda m: m.group(0).split(':')[0] + ":'SF Mono',ui-monospace,Menlo,monospace;", svg)
    ident = re.search(r'<svg[^>]* id="([^"]+)"', svg)[1]
    css = f'''<style id="documentation-style">
#{ident} text{{font-family:'SF Mono',ui-monospace,Menlo,monospace}}
#{ident} .n-label{{font-size:11px;font-weight:500}}
#{ident} .n-box{{fill:#f3f3f3;stroke:#050505;stroke-width:1}}
#{ident} .k-focal .n-box{{fill:#e8e8e8}}
#{ident} .q-life,#{ident} .e-line.dashed,#{ident} .g-dashed{{stroke-dasharray:3 4;stroke-linecap:round}}
#{ident} .e-line{{stroke-linecap:round;stroke-linejoin:round}}
#{ident} *{{animation:none!important}}
#{ident} .e-token{{display:none}}
</style>'''
    svg = svg.replace('</svg>', css + '</svg>')
    path.write_text(svg)
    title = re.search(r'<title[^>]*>(.*?)</title>', svg)[1]
    (root / f'{name}.html').write_text(f'''<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>{title}</title><style>html,body{{margin:0}}svg{{display:block;max-width:100%;height:auto}}</style></head><body><main>{svg}</main></body></html>''')
for path in sorted(root.glob('*.svg')):
    svg = path.read_text()
    variables = dict(re.findall(r'(--sc-[\w-]+):([^;}]+)', svg))
    svg = re.sub(r'var\((--sc-[\w-]+)\)', lambda m: variables.get(m[1], m[0]), svg)
    with tempfile.NamedTemporaryFile(suffix='.svg', mode='w') as source:
        source.write(svg)
        source.flush()
        subprocess.run(['resvg', source.name, str(path.with_suffix('.png'))], check=True)
