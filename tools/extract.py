#!/usr/bin/env python3
"""Disassemble the source PDF into editable parts.

Outputs (never overwrites existing files unless --force):
  src/<src>.md                source body text as Markdown
  figures/fig-NN.png          original figure images
  figures/fig-NN.<src>.txt    OCR'd figure text, one element per line
  figures/layout/fig-NN.json  bounding box of each figure text line

All document-specific thresholds come from technote.json (see tools/config.py
and `make inspect`).
"""
import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

import pymupdf

import config

ROOT = config.ROOT
CFG = config.load()
CODE_COLORS = {int(c.lstrip("#"), 16) for c in CFG["code"]["colors"]}
CODE_FONTS = CFG["code"]["fonts"]
MARKERS = set(CFG["bullets"]["fonts"])
STRIP_FONTS = set(CFG["bullets"]["strip_fonts"])
HEADING_LEVEL_BY_X = {int(k): v for k, v in CFG["heading"]["levels_by_x"].items()}
SRC = CFG["source_lang"]


def write(path: Path, text: str, force: bool):
    if path.exists() and not force:
        print(f"skip (exists): {path.relative_to(ROOT)}")
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")
    print(f"wrote: {path.relative_to(ROOT)}")


def esc(text):
    """Escape characters that Markdown would read as markup (<tag, *)."""
    return re.sub(r"<(?=[A-Za-z/!])", "&lt;", text).replace("*", r"\*")


def is_bold(span):
    return "Bold" in font_of(span)


def is_italic(span):
    return "Italic" in font_of(span) or "Oblique" in font_of(span)


def cell_text(page, rect):
    """(text, all_bold, x) of a table cell. Lines are joined; a wrapped token such as a regex
    or path (no spaces, contains ^$|\\/) is joined without a space."""
    lines, bold, x = [], True, None
    for b in page.get_text("dict", clip=rect)["blocks"]:
        for l in b.get("lines", []):
            spans = [s for s in l["spans"] if s["text"].strip()]
            if not spans:
                continue
            bold = bold and all(is_bold(s) for s in spans)
            x = l["bbox"][0] if x is None else min(x, l["bbox"][0])
            lines.append("".join(s["text"] for s in l["spans"]).strip())
    if len(lines) > 1 and all(" " not in l for l in lines) and re.search(r"[\^$|\\/]", "".join(lines)):
        return "".join(lines), bold, x
    return join_lines(lines), bool(lines) and bold, x


def table_rows(page, table):
    """[[cells], is_header] for a ruled table. Logical columns are the text x positions of the
    first row; every other cell goes to the nearest column (the grid has padding columns)."""
    rows = []
    for r in table.rows:
        cells = [cell_text(page, pymupdf.Rect(c)) for c in r.cells if c]
        cells = [c for c in cells if c[0]]
        if cells:
            rows.append(cells)
    if not rows:
        return []
    cols = sorted(c[2] for c in rows[0])
    out = []
    for cells in rows:
        texts = [""] * len(cols)
        for t, _, x in cells:
            i = min(range(len(cols)), key=lambda k: abs(cols[k] - x))
            texts[i] = join_lines([texts[i], t]) if texts[i] else t
        out.append([texts, all(b for _, b, _ in cells)])
    return out


def merge_row(dst, src):
    for i, t in enumerate(src):
        if t:
            dst[i] = join_lines([dst[i], t]) if dst[i] else t


def line_items(page):
    items = []
    tables = []
    if CFG["table"].get("ruled"):
        for t in page.find_tables().tables:
            rect = pymupdf.Rect(t.bbox)
            tables.append(rect)
            items.append({"kind": "table", "y0": rect.y0, "y1": rect.y1, "x": round(rect.x0),
                          "rows": table_rows(page, t)})
    for b in page.get_text("dict")["blocks"]:
        if b["type"] != 0:
            continue
        for l in b["lines"]:
            spans = list(l["spans"])
            x0, y0, x1, y1 = l["bbox"]
            if y0 > CFG["footer_y"] or y0 < CFG["header_y"]:  # running header/footer
                continue
            if any(pymupdf.Point((x0 + x1) / 2, (y0 + y1) / 2) in r for r in tables):
                continue
            items.append({"kind": "line", "x": round(x0), "y0": y0, "y1": y1, "x1": x1,
                          "spans": spans, "text": "".join(s["text"] for s in spans)})
    for info in page.get_image_info(xrefs=True):
        x0, y0, x1, y1 = info["bbox"]
        items.append({"kind": "image", "y0": y0, "y1": y1, "xref": info["xref"],
                      "width_pt": x1 - x0})
    items.sort(key=lambda it: (it["y0"], it.get("x", 0)))
    return items


def font_of(span):
    return span["font"].split("+")[-1]


def is_code_font(span):
    return any(f in font_of(span) for f in CODE_FONTS)


def is_code_line(item, body_x):
    if any((s["color"] in CODE_COLORS or is_code_font(s)) and s["text"].strip() for s in item["spans"]):
        return True
    return item["x"] >= body_x + CFG["code"]["indent"]


def is_heading(fonts, size):
    h = CFG["heading"]
    return size >= h["min_size"] and any(any(f in font for f in h["fonts"]) for font in fonts)


def is_caption(item):
    spans = [s for s in item["spans"] if s["text"].strip()]
    italic = all(("Italic" in font_of(s) or "Oblique" in font_of(s)) for s in spans)
    return bool(spans) and (italic or not CFG["caption"]["italic"]) and item["x"] > CFG["caption"]["min_x"]


def inline_md(spans):
    out = []
    for s in spans:
        t = esc(s["text"])
        if t.strip() and s["color"] not in CODE_COLORS and is_bold(s):
            lead = t[: len(t) - len(t.lstrip())]
            trail = t[len(t.rstrip()):]
            t = f"{lead}**{t.strip()}**{trail}"
        out.append(t)
    return "".join(out)


def join_lines(lines):
    text = ""
    for l in lines:
        l = l.strip()
        if not text:
            text = l
        elif text.endswith("-") and not text.endswith(" -"):
            text += l
        else:
            text += " " + l
    return re.sub(r"\s{2,}", " ", text).strip()


def code_lang(lines):
    """Best guess; the agent should review fences after extraction.
    ```text marks sample values (numbers, output) that may be localised."""
    src = "\n".join(lines)
    if re.match(r"\s*[\[{]", src) and re.search(r'"\s*:', src) and not re.search(r":=", src):
        return "json"
    if re.search(r"^\s*<(!doctype|html|div|script)", src, re.M | re.I):
        return "html"
    if re.search(r"^\s*(var|let|const|function) |=>|\bdocument\.|\bwindow\.", src, re.M) and ":=" not in src:
        return "js"
    if re.fullmatch(r"[\s\d\.\-+\[\],°'\"NSEW:/=×θ]+", src):
        return "text"
    return "4d"


def code_line_text(item, min_x):
    raw = "".join(s["text"] for s in item["spans"]).rstrip()
    stripped = raw.lstrip(" ")
    spaces = len(raw) - len(stripped)
    level = spaces // 4 if spaces >= 4 else (1 if item["x"] > min_x + 10 else 0)
    return "    " * level + stripped


def extract_body(doc):
    out = []
    cover = CFG["cover"]
    p1 = [it for it in line_items(doc[cover["page"] - 1]) if it["kind"] == "line" and it["text"].strip()]
    head = p1[:cover["lines"]]
    style = lambda it: (font_of(it["spans"][0]), round(it["spans"][0]["size"]))
    n = next((i for i, it in enumerate(head) if style(it) != style(head[0])), len(head))
    title = join_lines([it["text"] for it in head[:n]])
    rest = [it["text"].strip() for it in head[n:]]
    out.append(f"# {title}\n\n" + "".join(f"{r}\n\n" for r in rest).rstrip("\n") + "\n")

    figures = []
    state = {"para": [], "code": [], "bullets": [], "in_bullet": False, "table": [], "callout": []}
    body_x = 72
    prev = None

    def flush_para():
        if state["para"]:
            out.append(join_lines(state["para"]) + "\n")
            state["para"] = []

    def flush_bullets():
        if state["bullets"]:
            out.append("\n".join(f"- {join_lines(b)}" for b in state["bullets"]) + "\n")
            state["bullets"] = []
        state["in_bullet"] = False

    def flush_code():
        items = state["code"]
        if items:
            min_x = min(it["x"] for it in items if it["text"].strip())
            lines = [code_line_text(it, min_x) if it["text"].strip() else "" for it in items]
            while lines and not lines[-1]:
                lines.pop()
            out.append(f"```{code_lang(lines)}\n" + "\n".join(lines) + "\n```\n")
            state["code"] = []

    def flush_table():
        if state["table"]:
            rows = [[c["text"].strip() for c in sorted(cells, key=lambda c: c["x"])]
                    for _, cells in state["table"]]
            md = ["| " + " | ".join(rows[0]) + " |", "|" + "---|" * len(rows[0])]
            md += ["| " + " | ".join(r) + " |" for r in rows[1:]]
            out.append("\n".join(md) + "\n")
            state["table"] = []

    def flush_callout():
        if state["callout"]:
            out.append("> " + join_lines(state["callout"]) + "\n")
            state["callout"] = []

    def flush_all():
        flush_para(); flush_bullets(); flush_code(); flush_table(); flush_callout()

    def add_ruled_table(rows):
        """Append a ruled table; a table that repeats the previous header continues it (page break)."""
        nhead = 0
        while nhead < len(rows) and rows[nhead][1]:
            nhead += 1
        header = [""] * len(rows[0][0])
        for texts, _ in rows[:nhead]:
            merge_row(header, texts)
        body = [texts for texts, _ in rows[nhead:]]
        prev = out[-1] if out and isinstance(out[-1], dict) else None
        if prev and prev["header"] == header and nhead:
            target = prev
        else:
            target = {"header": header if nhead else body.pop(0), "rows": []}
            out.append(target)
        for texts in body:
            if target["rows"] and not texts[0]:
                merge_row(target["rows"][-1], texts)
            else:
                target["rows"].append(texts)

    skip = {p - 1 for p in CFG["skip_pages"]}
    for pno in (p for p in range(len(doc)) if p not in skip):
        for it in line_items(doc[pno]):
            if it["kind"] == "table":
                flush_all()
                if it["rows"]:
                    add_ruled_table(it["rows"])
                prev = None
                continue
            if it["kind"] == "image":
                flush_all()
                figures.append({"page": pno + 1, "xref": it["xref"], "width_pt": it["width_pt"]})
                out.append(f"![](fig-{len(figures):02d})\n")
                prev = None
                continue
            text = it["text"]
            fonts = {font_of(s) for s in it["spans"] if s["text"].strip()}
            size = round(max(s["size"] for s in it["spans"]))

            if not text.strip():
                if state["code"] and it["x"] >= body_x + CFG["code"]["indent"]:
                    state["code"].append(it)
                else:
                    flush_code()
                prev = None
                continue

            if is_heading(fonts, size) and not is_code_line(it, it["x"] + 1000):
                flush_all()
                near = [x for x in HEADING_LEVEL_BY_X if abs(x - it["x"]) <= 6]
                level = (HEADING_LEVEL_BY_X[min(near, key=lambda x: abs(x - it["x"]))] if near
                         else CFG["heading"]["default_level"])
                out.append(f"{'#' * level} {text.strip()}\n")
                body_x = it["x"]
                prev = None
                continue

            if CFG.get("callout", {}).get("italic") and all(
                    is_italic(s) for s in it["spans"] if s["text"].strip()):
                flush_para(); flush_bullets(); flush_code(); flush_table()
                if state["callout"] and it["y0"] - state["callout_y1"] > CFG["paragraph"]["gap"] + 6:
                    flush_callout()
                state["callout"].append(inline_md(it["spans"]))
                state["callout_y1"] = it["y1"]
                prev = it
                continue
            flush_callout()

            if is_caption(it):
                flush_all()
                caption = text.strip()
                last_fig = max((i for i, o in enumerate(out) if o.startswith("![](fig-")), default=None)
                if last_fig is not None:
                    out[last_fig] = out[last_fig].replace("![]", f"![{caption}]")
                else:
                    out.append(f"*{caption}*\n")
                prev = None
                continue

            if CFG["table"]["size"] and size == CFG["table"]["size"]:  # table cells
                flush_para(); flush_bullets(); flush_code()
                if state["table"] and abs(state["table"][-1][0] - it["y0"]) < 3:
                    state["table"][-1][1].append(it)
                else:
                    state["table"].append((it["y0"], [it]))
                continue
            flush_table()

            if fonts & MARKERS:
                flush_para(); flush_code()
                state["in_bullet"] = True
                rest = inline_md([s for s in it["spans"] if font_of(s) not in MARKERS | STRIP_FONTS])
                state["bullets"].append([rest] if rest.strip() else [])
                prev = it
                continue

            if state["in_bullet"] and it["x"] > body_x and not any(
                    s["color"] in CODE_COLORS for s in it["spans"]):
                state["bullets"][-1].append(inline_md(it["spans"]))
                prev = it
                continue

            has_code = any((s["color"] in CODE_COLORS or is_code_font(s)) and s["text"].strip()
                           for s in it["spans"])
            if (it["x"] != body_x or has_code) and is_code_line(it, body_x):
                flush_para(); flush_bullets()
                state["code"].append(it)
                prev = it
                continue

            flush_bullets(); flush_code()
            para = CFG["paragraph"]
            if prev is not None and state["para"] and (
                    abs(it["y0"] - prev["y1"]) > para["gap"]
                    or (prev["x1"] < para["short_line_x1"] and prev["text"].rstrip().endswith((".", ":")))):
                flush_para()
            body_x = it["x"]
            state["para"].append(inline_md(it["spans"]))
            prev = it
    flush_all()

    def render(o):
        if not isinstance(o, dict):
            return o
        cell = lambda t: esc(t).replace("|", r"\|")
        md = ["| " + " | ".join(cell(t) for t in o["header"]) + " |", "|" + "---|" * len(o["header"])]
        md += ["| " + " | ".join(cell(t) for t in r) + " |" for r in o["rows"]]
        return "\n".join(md) + "\n"
    return "\n".join(render(o) for o in out), figures


def ocr_lines(png: Path):
    ocr = CFG["ocr"]
    tsv = subprocess.run(["tesseract", str(png), "-", "--psm", str(ocr["psm"]), "tsv"],
                         capture_output=True, text=True, check=True).stdout
    groups = {}
    for row in tsv.splitlines()[1:]:
        f = row.split("\t")
        if len(f) < 12 or not f[11].strip() or float(f[10]) < ocr["min_conf"]:
            continue
        key = (int(f[2]), int(f[3]), int(f[4]))
        groups.setdefault(key, []).append(
            {"x": int(f[6]), "y": int(f[7]), "w": int(f[8]), "h": int(f[9]), "text": f[11]})
    lines = []
    for ws in groups.values():
        ws.sort(key=lambda w: w["x"])
        x0 = min(w["x"] for w in ws); y0 = min(w["y"] for w in ws)
        x1 = max(w["x"] + w["w"] for w in ws); y1 = max(w["y"] + w["h"] for w in ws)
        text = " ".join(w["text"] for w in ws).strip(" |—-~_")
        if not re.search(r"[A-Za-z]{3}|\d", text) or re.search(ocr["noise"], text):
            continue  # arrows, borders and other OCR noise
        lines.append({"box": [x0, y0, x1 - x0, y1 - y0], "text": text})
    lines.sort(key=lambda l: (l["box"][1] // 10, l["box"][0]))
    return lines


def extract_figures(doc, figures, force):
    figdir = ROOT / "figures"
    (figdir / "layout").mkdir(parents=True, exist_ok=True)
    for n, fig in enumerate(figures, 1):
        name = f"fig-{n:02d}"
        png = figdir / f"{name}.png"
        if force or not png.exists():
            pix = pymupdf.Pixmap(doc, fig["xref"])
            smask = doc.xref_get_key(fig["xref"], "SMask")
            if smask[0] == "xref":
                pix = pymupdf.Pixmap(pix, pymupdf.Pixmap(doc, int(smask[1].split()[0])))
            pix.save(png)
            print(f"wrote: {png.relative_to(ROOT)}")
        layout_path = figdir / "layout" / f"{name}.json"
        if force or not layout_path.exists():
            lines = ocr_lines(png)
            layout = {"source": f"{name}.png", "page": fig["page"],
                      "width_pt": round(fig["width_pt"], 1), "localize": True,
                      "items": [{"box": l["box"], "align": "center"} for l in lines]}
            write(layout_path, json.dumps(layout, indent=1) + "\n", True)
            write(figdir / f"{name}.{SRC}.txt", "\n".join(l["text"] for l in lines) + "\n", True)


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--force", action="store_true", help="overwrite existing extracted files")
    args = ap.parse_args()
    doc = pymupdf.open(CFG["source_path"])
    body, figures = extract_body(doc)
    write(ROOT / "src" / f"{SRC}.md", body, args.force)
    extract_figures(doc, figures, args.force)


if __name__ == "__main__":
    sys.exit(main())
