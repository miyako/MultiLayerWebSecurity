#!/usr/bin/env python3
"""Inspect the source PDF and suggest technote.json values.

Prints a report (fonts, sizes, colours, x positions, images, header/footer
candidates) and a suggested configuration. The suggestion is a starting point:
review it against the report before extracting.

  python tools/inspect_pdf.py            # report + suggestion
  python tools/inspect_pdf.py --write    # also write technote.json if it does not exist
"""
import argparse
import collections
import json
import re
import sys

import pymupdf

import config

MONO = re.compile(r"Mono|Courier|Menlo|Consolas|Monaco|Code", re.I)


def spans(doc):
    for pno, page in enumerate(doc):
        for b in page.get_text("dict")["blocks"]:
            if b["type"] != 0:
                continue
            for l in b["lines"]:
                for s in l["spans"]:
                    if s["text"].strip():
                        yield pno, l, s


def font(s):
    return s["font"].split("+")[-1]


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--write", action="store_true")
    args = ap.parse_args()
    cfg = config.load()
    doc = pymupdf.open(cfg["source_path"])
    W, H = doc[0].rect.width, doc[0].rect.height

    print(f"# {cfg['source_pdf']}")
    print(f"pages: {len(doc)}, size: {W:.0f} x {H:.0f} pt "
          f"({'letter' if abs(W - 612) < 3 else 'a4' if abs(W - 595) < 3 else 'other'}), "
          f"tagged: {bool(doc.pdf_catalog() and 'StructTreeRoot' in doc.xref_object(doc.pdf_catalog()))}")
    chars = sum(len(p.get_text()) for p in doc)
    print(f"text characters: {chars}" + ("  <-- looks scanned: stop and discuss with the user" if chars < 200 * len(doc) else ""))

    styles = collections.Counter()
    samples = {}
    xs = collections.defaultdict(collections.Counter)
    for pno, l, s in spans(doc):
        key = (font(s), round(s["size"], 1), f"#{s['color']:06x}")
        styles[key] += len(s["text"])
        samples.setdefault(key, (pno + 1, s["text"].strip()[:50]))
        xs[key][round(l["bbox"][0])] += 1

    print("\n## Text styles (by characters)")
    print(f"{'font':34} {'size':>5} {'colour':8} {'chars':>7}  x positions            sample (page)")
    for key, n in styles.most_common(40):
        xpos = ",".join(str(x) for x, _ in xs[key].most_common(4))
        print(f"{key[0][:34]:34} {key[1]:5} {key[2]:8} {n:7}  {xpos:22} {samples[key][1]!r} (p{samples[key][0]})")

    print("\n## Images")
    for pno, page in enumerate(doc):
        for info in page.get_image_info(xrefs=True):
            x0, y0, x1, y1 = info["bbox"]
            print(f"p{pno + 1}: xref {info['xref']} at ({x0:.0f},{y0:.0f}) width {x1 - x0:.1f}pt "
                  f"{info['width']}x{info['height']}px")
    vec = [pno + 1 for pno, p in enumerate(doc) if len(p.get_drawings()) > 50]
    if vec:
        print(f"pages with many vector drawings (diagrams may be vector, not raster): {vec}")

    print("\n## Header / footer candidates (lines near the page edges)")
    edge = collections.Counter()
    for pno, page in enumerate(doc):
        for b in page.get_text("dict")["blocks"]:
            for l in b.get("lines", []):
                t = "".join(s["text"] for s in l["spans"]).strip()
                y0 = l["bbox"][1]
                if t and (y0 > H - 90 or y0 < 60):
                    edge[(round(y0), re.sub(r"\d+", "#", t)[:40])] += 1
    for (y, t), n in sorted(edge.items()):
        print(f"y={y:4}  x{n:<3} {t!r}")

    # ---- suggestion (body pages only: cover and TOC are skipped) ----
    skip = {p - 1 for p in cfg["skip_pages"]}
    bstyles, bxs = collections.Counter(), collections.defaultdict(collections.Counter)
    for pno, l, s in spans(doc):
        if pno in skip:
            continue
        key = (font(s), round(s["size"], 1), f"#{s['color']:06x}")
        bstyles[key] += len(s["text"])
        bxs[key][round(l["bbox"][0])] += 1
    body = max(bstyles, key=bstyles.get)
    body_size = body[1]
    symbol = re.compile(r"Symbol|Wingdings|Dingbat", re.I)
    heads = [k for k in bstyles if k[1] >= body_size + 0.9 and not MONO.search(k[0])
             and not symbol.search(k[0]) and (k[2] != "#000000" or re.search(r"Bold|Medium|Semi|Heavy", k[0]))]
    head_fonts = sorted({k[0] for k in heads})
    head_xs = sorted({x for k in heads for x in bxs[k]})
    levels = {str(x): min(2 + i, 4) for i, x in enumerate(head_xs[:3])}
    accent = collections.Counter({k[2]: bstyles[k] for k in heads if k[2] != "#000000"})
    code_colors = sorted({k[2] for k in bstyles if k[2] not in ("#000000",) and k[2] not in accent
                          and abs(k[1] - body_size) < 2.5})
    italic_x = [x for k in bstyles if re.search("Italic|Oblique", k[0]) and k[2] == "#000000" for x in bxs[k]]
    styles = bstyles
    footer = [y for (y, t), n in edge.items() if y > H - 90 and n >= len(doc) // 2]
    smaller = [k for k in styles if k[1] < body_size - 0.5 and not MONO.search(k[0])]
    bullets = sorted({k[0] for k in styles if re.search(r"Symbol|Wingdings|Dingbat", k[0])})
    suggestion = {
        "source_lang": "en",
        "target_lang": cfg["target_lang"],
        "page_size": "letter" if abs(W - 612) < 3 else "a4",
        "accent_color": accent.most_common(1)[0][0] if accent else "#2f5496",
        "cover": {"page": 1, "lines": 3},
        "skip_pages": [1, 2],
        "footer_y": (min(footer) - 2) if footer else round(H - 80),
        "heading": {"fonts": head_fonts, "min_size": min((k[1] for k in heads), default=body_size + 1),
                    "levels_by_x": levels},
        "code": {"colors": code_colors},
        "bullets": {"fonts": bullets or config.DEFAULTS["bullets"]["fonts"]},
        "caption": {"italic": True, "min_x": (min(italic_x) - 2) if italic_x else 0},
        "table": {"size": round(smaller[0][1]) if smaller else None},
    }
    print("\n## Suggested technote.json (REVIEW against the report above)")
    print(f"body style: {body}")
    text = json.dumps(suggestion, indent=2, ensure_ascii=False)
    print(text)
    target = config.ROOT / "technote.json"
    if args.write:
        current = json.loads(target.read_text()) if target.exists() else {}
        if "heading" in current:
            print(f"\n{target.name} already configured; not overwritten", file=sys.stderr)
        else:
            target.write_text(json.dumps({**suggestion, **current}, indent=2, ensure_ascii=False) + "\n")
            print(f"\nwrote {target.name}")


if __name__ == "__main__":
    main()
