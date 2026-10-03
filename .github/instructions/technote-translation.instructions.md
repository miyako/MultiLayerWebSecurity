---
description: "Reference for the technical-note localisation pipeline: technote.json keys, extraction heuristics, figure localisation, PDF reassembly and known pitfalls"
applyTo: "document/**,src/**,figures/**,tools/**,style/**,data/**,glossary.md,technote.json,Makefile"
---

# Technical note localisation pipeline: reference

The workflow and checkpoints are in `.github/copilot-instructions.md`. This file is a technical reference for
`tools/`. `<src>` is `source_lang` (normally `en`) and `<tgt>` is `target_lang` (e.g. `ja`).

## Pipeline

| Step | Tool | Input → output |
|---|---|---|
| inspect | `tools/inspect_pdf.py [--write]` | PDF → style report + suggested `technote.json` |
| extract | `tools/extract.py [--force]` | PDF → `src/<src>.md`, `figures/fig-NN.png`, `fig-NN.<src>.txt`, `layout/fig-NN.json` |
| check | `tools/build.py --check` | `src/<src>.md` vs `src/<tgt>.md`: code blocks identical, figure refs equal |
| figures | `tools/render_figures.py` | `figures/` → `build/figures/fig-NN.png` |
| review | `tools/contact_sheet.py [--compare] [NN ...]` | → `build/contact-N.png` |
| pdf | `tools/build.py [--lang xx]` | check → figures → Markdown → HTML → Chrome PDF (2 passes for TOC page numbers) |
| 4D | `tools/tool4d.py demo/<Name> [test.4dm] [--compile] [--data]` | runs a test method headlessly in a temp copy |
| data | `tools/wikidata.py query FILE.rq` / `entities Q.. --langs` | Wikidata with a QLever fallback |

`tools/config.py` loads `technote.json` merged over `DEFAULTS` (keys starting with `$` are ignored).

## technote.json keys

| Key | Meaning |
|---|---|
| `source_pdf` | Path; default is the only PDF in `document/` |
| `source_lang`, `target_lang` | Language codes; select file names and figure fonts |
| `output_pdf` | `"{stem}_{lang}.pdf"` |
| `toc_title` | `{lang: title}` for the generated table of contents |
| `accent_color` | Heading colour (CSS `--accent`) |
| `page_size` | `letter` or `a4` |
| `cover` | `{page, lines}`: the title block is the first `lines` text lines of `page` |
| `skip_pages` | 1-based pages not extracted (cover, original TOC); both are regenerated |
| `header_y`, `footer_y` | Lines with top above `header_y` or below `footer_y` (pt) are dropped |
| `heading.fonts` | Substrings of font names that mark headings; with `heading.min_size` |
| `heading.levels_by_x` | `{"x": level}`: heading level by left x (nearest within 6 pt); otherwise `default_level` |
| `code.colors` | Hex colours of syntax-highlighted code spans (Word exports code as coloured text) |
| `code.fonts` | Monospace font substrings; `code.indent` = minimum x offset for code continuation lines |
| `bullets.fonts` / `strip_fonts` | Glyph fonts that mark list items / fonts of separator spans to drop |
| `caption.italic`, `caption.min_x` | Captions are italic lines starting right of `min_x` |
| `table.size` | Font size used only by table cells (or null) |
| `paragraph.gap`, `short_line_x1` | Start a new paragraph after a vertical gap > `gap`, or after a short line ending in `.` or `:` |
| `ocr.psm`, `min_conf`, `noise` | Tesseract page-segmentation mode, word confidence threshold, regex of junk lines |
| `figure_fonts` | `{light, regular, bold: ["path#index", ...]}`: overrides the per-platform defaults |

`make inspect` derives most of these from a style histogram of the body pages:
- headings: larger than the body text, not black or bold/medium
- code: non-black colours at body size
- captions: black italic text

**Verify the result against the report;** heuristics can be wrong for unusual documents. If the PDF uses a
monospace font for code instead of colours, `code.colors` can stay empty.

## Extraction details (`tools/extract.py`)

- Lines are classified in reading order:
  - **heading:** font and size, not code
  - **code:** a code colour, a code font, or an indent within a code block
  - **caption:** italic and x > `min_x`
  - **bullet**
  - **table row:** `table.size`
  - **body**
- Code blocks:
  - consecutive code lines become one fence
  - the language is guessed: `json`, `html`, `js`, `text`, otherwise `4d`
  - indentation comes from leading spaces or relative x
- Inline: bold spans → `**…**`; inline code-coloured or monospace spans → `` `…` ``.
- Figures: raster images become `figures/fig-NN.png` (RGBA composited onto white) in document order, with
  `![caption](fig-NN)` placed where the image sits.
  - `layout/fig-NN.json` stores `source`, `page`, `width_pt` (the placed width, reused in the rebuild) and
    `localize`, plus one `items[]` entry per OCR line with its `box`.
- Vector diagrams (drawn with PDF paths, not images) are **not** extracted. `inspect` lists pages with many
  drawings. If they contain text, ask the user: either rasterise the region with `page.get_pixmap(clip=…)` into a
  new figure, or leave it.
- Re-extraction never overwrites. `--force` overwrites `<src>` files and layouts, so warn the user first:
  it discards OCR corrections and layout tweaks.

## Translation conventions

- Translate paragraph by paragraph, keeping Markdown structure and order.
- Translate captions but keep `fig-NN`. Keep the fences of code blocks exactly as they are, language tag included.
- Japanese:
  - です・ます調.
  - Half-width alphanumerics, no spaces between Japanese and Latin text.
  - Full-width `（）` and `：` in prose.
  - Use the official 4D Japanese documentation terms (see `glossary.md`).
  - First occurrence of a technical term: 日本語（English）.
- Other languages: agree on the style with the user, and set the fonts (`figure_fonts`) and the font stack in
  `style/style.css`.
- Inline code (`` `name` ``) stays as is. Identifiers in prose that refer to code stay in their original form.

## Figure localisation (`tools/render_figures.py`)

Line N of `fig-NN.<tgt>.txt` maps to line N of `fig-NN.<src>.txt` and to `items[N]` in the layout:
- **identical:** keep the original pixels
- **empty:** erase, draw nothing
- **otherwise:** erase and draw the translation

For each changed item:
1. The background colour is sampled from a ring around the box; the box is erased with padding (`erase_pad`).
2. The foreground colour is sampled from the darkest differing pixels.
3. The size comes from the original text height and width, then is clamped to the box.
4. Similar sizes are snapped together, so labels of the same rank match.
5. The text is drawn with the weight (`light`, `regular` or `bold`) and alignment (`center` or `left`).

Overrides per item: `scale`, `size`, `weight`, `align`, `dx`, `dy`, `box`, `bg`, `fg`, `erase_pad`.
Per figure:
- `"localize": false` copies the image unchanged (use it for screenshots)
- `"replace": "fig-NN-<tgt>.png"` uses a ready-made image from `figures/`, keeping `width_pt`

Typical fixes:
- OCR merged two labels: split the text and give explicit `box` values.
- The erase removes legend dots or arrows next to text: shift the box (`dx`, or a narrower `box`) and use `align: left`.
- A title came out too small: `scale: 1.3`.
- Text runs outside its shape: shorten the translation (preferred), or use `size`.
- Figures that show sample data (field names, values) may need edits that match the demo, e.g. new
  `name<TGT>` fields.

Always check with `make review` (original above, localised below).

## Reassembly (`tools/build.py`)

1. Check: code blocks are compared by position, ```` ```text ```` blocks are skipped, and the sets of figure
   references must match. Any mismatch aborts with a diff.
2. Render the figures.
3. Markdown → HTML (`fenced_code`, `tables`, `attr_list`).
   - The cover comes from the first lines of `<tgt>.md`, and the TOC is generated from the headings.
   - Figures become `<figure>` with `width:{width_pt}pt`.
4. The CSS is `style/style.css` plus injected `:root{--accent}` and `@page{size}`. Chrome is run headless twice;
   the second pass fills in the TOC page numbers found with pymupdf.
5. The output is `build/<output_pdf>`. Compare its page count with the original: ±2 pages is normal.

To prove the check works, change one character inside a code block of `<tgt>.md`, run `make check`, confirm it
fails, then revert.

## Verification checklist (before release)

- [ ] `make check` passes. `make` builds; TOC page numbers are right; the page count is plausible.
- [ ] Every localised figure has been seen on a contact sheet. Screenshots are replaced or approved as is.
- [ ] No source-language leftovers: grep `<tgt>.md` and `*.<tgt>.txt` for long ASCII sentences and old example
  names.
- [ ] The glossary is consistent: grep for alternative spellings of key terms.
- [ ] Numbers in examples were recomputed from the committed data.
- [ ] 4D: compile check passes (or it is stated that tool4d was unavailable); XLIFF resolves in each language.
- [ ] `git status` is clean; temporary files are removed.

## Pitfalls

- A caption just above `footer_y` can be dropped. Check that every figure has a caption.
- Files the user drops into `build/` are lost on rebuild: move them to `figures/`.
- Re-saving 4D methods in the 4D editor can change line endings (CRLF vs LF). Mention it; don't "fix" it silently.
- The Wikidata SPARQL service can be down or rate-limited for long periods. `tools/wikidata.py` falls back to QLever.
- Linux and macOS builds use different CJK fonts, so release assets should come from the platform the user reviewed.
