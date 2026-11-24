# Documentation visuals

Read this when creating or changing a documentation diagram or wireframe.
The project skills use this shared style instead of the global house defaults.

## Composition

Start with the drawing. Keep the canvas close to its content, with enough margin
for labels. No visible sheet title, eyebrow, ID, page counter, title block,
watermark, footer legend or decorative frame. An actual window border belongs
in a UI wireframe. Keep SVG `title` and `desc` for accessibility; they are not
visible headings. Short headings distinguish states in a comparison sheet.

Use monospace for **every** text role: `'SF Mono', ui-monospace, Menlo, monospace`.
Use monochrome fills, line weight and spacing to establish hierarchy. Light
appearance has an explicit white canvas, ink `#050505`, muted text `#626262`,
soft lines `#878787`, fills `#f3f3f3` and `#e8e8e8`. SVG and HTML should also
respond to `prefers-color-scheme: dark`, with coordinated paper, ink, fills,
icons and lines. PNG is the static light export. Keep dark colours in shared
CSS variables; test both appearances rather than inverting a finished image.

Typical wireframe weights: outer/structural lines 1–1.4 px, leaders 0.7–0.8 px,
slot outlines 0.8 px. Use rounded dash caps with `3 4` spacing for slots and
lifelines. Preserve purposeful differences such as empty-state outlines.
Use the existing generator's proportions rather than applying these numbers
to an unrelated scale.

## Words carry one job

Label a concept once, where the reader needs it. Use the real control label or
one callout; do not repeat it inside the region, outside it, in a caption and
in a tooltip. “Search” needs no “Local search” callout. A “Site preview” callout
needs no labelled box inside the preview. Label one representative result row;
use skeleton bars for repeated rows. Use “Thumbnail” for the row image.

Keep implementation labels such as FLEX, HUG and FILL out of the drawing.
Omit tooltips that repeat visible labels. If hover adds necessary information,
make that fact available in the static diagram or nearby documentation too.
An accessible description may explain the visual without adding visible copy.
Use short, direct wording and the repository's terms. A node subtitle, branch
label or state note must add a fact that its main label does not already convey.

## Files and delivery

- Editable specs, generators and configuration: `demo/diagrams/`.
- Matching SVG, HTML and PNG exports: `assets/diagrams/<slug>.*`.
- Inline SVG where it explains the section, e.g.
  `![Preview modes](../assets/diagrams/site-browser-variants.svg)` in `docs/`.
  README paths start with `assets/`. Use concise, meaningful alt text.
- Retain HTML for viewing and PNG for static sharing. Do not add “The diagram
  shows…” link paragraphs or separate interactive-view links to the docs.

Before completion, inspect the output at its documentation size, check light
and dark SVG/HTML, parse the SVG, and check all affected relative links and
`git diff --check`. Confirm there is no clipped text, overlapping leader or
unexplained arrow. Keep edits in generators/specs so regeneration preserves them.

## Why these choices

The 24 November 2026 sessions are the baseline, not templates to copy verbatim:

- Local: <t3-thread://v2/d4c06ace-2f02-4805-89d3-36be52d9506c/a67d8bfb-2728-48bc-86e9-9beb2b96eee6>
  — white SVG embeds, no titles/eyebrows or sizing jargon, contextual embedding.
- MacBook: <t3-thread://v2/d7b364f3-a7e2-4fa8-9e7b-1bb622b9cf72/f8281e5e-f40b-4555-b067-4a93b585a7a2>
  — monospace throughout, fewer labels, real vector icons and action buttons,
  square navigation/viewport corners, separate three-state sheets, assets/demo
  split, then adaptive SVG/HTML with light PNGs. The final theme changes were
  uncommitted there when these skills were written; the release exports still
  provide the geometry reference, not the final theme implementation.
