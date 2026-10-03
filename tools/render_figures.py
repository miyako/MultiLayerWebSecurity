#!/usr/bin/env python3
"""Render localised figures.

For every figures/layout/fig-NN.json with "localize": true, read
figures/fig-NN.<src>.txt and figures/fig-NN.<tgt>.txt (line N of each file
corresponds to item N in the layout) and write build/figures/fig-NN.png.
Languages and fonts come from technote.json.

Rules for a line in fig-NN.<tgt>.txt:
  * identical to the source line -> left untouched (code, numbers, names)
  * empty                        -> source text is erased, nothing drawn
                                    (use this to merge two source lines
                                    into one translated line)
  * anything else                -> source erased, translation drawn in place
Figures with "replace": "<file>" use that file from figures/ instead (e.g. a localised screenshot).
Figures with "localize": false (or without a .<tgt>.txt) are copied unchanged.
"""
import json
import shutil
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

import config

ROOT = config.ROOT
CFG = config.load()
SRC, TGT = CFG["source_lang"], CFG["target_lang"]
FIG = ROOT / "figures"
OUT = ROOT / "build" / "figures"
FONTS = config.figure_fonts(CFG)


def font(weight, size):
    path, index = FONTS[weight]
    return ImageFont.truetype(path, max(6, int(round(size))), index=index)


def dist(a, b):
    return sum((x - y) ** 2 for x, y in zip(a[:3], b[:3])) ** 0.5


def mode_color(pixels):
    counts = {}
    for p in pixels:
        key = tuple(c // 8 * 8 for c in p[:3])
        counts[key] = counts.get(key, 0) + 1
    key = max(counts, key=counts.get)
    sel = [p for p in pixels if tuple(c // 8 * 8 for c in p[:3]) == key]
    return tuple(sum(p[i] for p in sel) // len(sel) for i in range(4))


def background(img, box, pad=4):
    x, y, w, h = box
    W, H = img.size
    px = img.load()
    ring = []
    for xx in range(max(0, x - pad), min(W, x + w + pad)):
        for yy in (max(0, y - pad), min(H - 1, y + h + pad)):
            ring.append(px[xx, yy])
    for yy in range(max(0, y - pad), min(H, y + h + pad)):
        for xx in (max(0, x - pad), min(W - 1, x + w + pad)):
            ring.append(px[xx, yy])
    return mode_color(ring)


def foreground(img, box, bg):
    x, y, w, h = box
    px = img.load()
    inside = [px[xx, yy] for xx in range(x, x + w) for yy in range(y, y + h)]
    far = sorted(inside, key=lambda p: dist(p, bg), reverse=True)
    core = far[: max(1, len(far) // 10)]
    ink = sum(1 for p in inside if dist(p, bg) > 60) / max(1, len(inside))
    return tuple(sum(p[i] for p in core) // len(core) for i in range(4)), ink


def free_span(img, box, bg, tol=40):
    """Horizontal extent around the text that has the same background colour."""
    x, y, w, h = box
    W, _ = img.size
    px = img.load()
    rows = [y + h // 4, y + h // 2, y + 3 * h // 4]

    def clear(xx):
        return all(dist(px[xx, r], bg) < tol for r in rows)

    left = x
    while left > 0 and clear(left - 1):
        left -= 1
    right = x + w
    while right < W - 1 and clear(right + 1):
        right += 1
    return left, right


def text_size(draw, text, f):
    l, t, r, b = draw.textbbox((0, 0), text, font=f, anchor="ls")
    return r - l, b - t


def estimate_size(draw, text, box):
    """Font size at which the English text fills its OCR box."""
    _, _, w, h = box
    ref = 100
    tw, _ = text_size(draw, text, font("regular", ref))
    _, ref_h = text_size(draw, "Hg", font("regular", ref))
    by_width = ref * w / max(1, tw)
    by_height = ref * h / ref_h
    return min(max(by_width, by_height * 0.75), by_height * 1.15)


def snap_sizes(sizes, tol=0.08, absorb=0.30):
    """Group near-equal size estimates so labels of the same rank match."""
    if not sizes:
        return []
    order = sorted(range(len(sizes)), key=lambda i: sizes[i])
    groups = [[order[0]]]
    for i in order[1:]:
        if sizes[i] <= sizes[groups[-1][-1]] * (1 + tol):
            groups[-1].append(i)
        else:
            groups.append([i])
    medians = [sorted(sizes[i] for i in g)[len(g) // 2] for g in groups]
    big = [m for g, m in zip(groups, medians) if len(g) > 1] or medians
    out = list(sizes)
    for g, m in zip(groups, medians):
        if len(g) == 1:
            near = min(big, key=lambda b: abs(b - m))
            m = near if abs(near - m) / m <= absorb else m
        for i in g:
            out[i] = m
    return out


def render(name, layout, en, ja):
    src_img = Image.open(FIG / layout["source"]).convert("RGBA")
    img = Image.new("RGBA", src_img.size, (255, 255, 255, 255))
    img.alpha_composite(src_img)
    draw = ImageDraw.Draw(img)
    jobs = []
    for item, src, dst in zip(layout["items"], en, ja):
        if dst == src:
            continue
        box = item["box"]
        bg = tuple(item["bg"]) if "bg" in item else background(img, box)
        fg, ink = foreground(img, box, bg)
        if "fg" in item:
            fg = tuple(item["fg"])
        size_en = estimate_size(draw, src, box)
        weight = item.get("weight", "regular")
        left, right = free_span(img, box, bg)
        jobs.append((item, src, dst, box, bg, fg, weight, left, right, size_en))
    snapped = snap_sizes([j[-1] for j in jobs])
    jobs = [j[:-1] + (sz,) for j, sz in zip(jobs, snapped)]
    for item, src, dst, box, bg, fg, weight, left, right, size_en in jobs:
        x, y, w, h = box
        p = item.get("erase_pad", 3)
        draw.rectangle([x - p, y - p, x + w + p, y + h + p], fill=bg)
    W = img.size[0]
    for item, src, dst, box, bg, fg, weight, left, right, size_en in jobs:
        if not dst:
            continue
        x, y, w, h = box
        size = (item.get("size") or size_en) * item.get("scale", 1.0)
        margin = max(6, h // 3)
        if item.get("align") == "left":
            avail = right - x - margin
        else:
            cx = x + w / 2
            avail = 2 * min(cx - left, right - cx) - 2 * margin
        avail = max(avail, w)
        f = font(weight, size)
        tw, _ = text_size(draw, dst, f)
        if tw > avail:
            size *= avail / tw
            f = font(weight, size)
            tw, _ = text_size(draw, dst, f)
        cy = y + h / 2 + item.get("dy", 0)
        tx = x if item.get("align") == "left" else x + w / 2 - tw / 2
        tx = max(4, min(tx + item.get("dx", 0), W - tw - 4))
        draw.text((tx, cy), dst, font=f, fill=fg, anchor="lm")
    OUT.mkdir(parents=True, exist_ok=True)
    img.save(OUT / f"{name}.png")


def main():
    errors = 0
    print("figure fonts: " + ", ".join(f"{w}={Path(p).name}" for w, (p, _) in FONTS.items()))
    OUT.mkdir(parents=True, exist_ok=True)
    for lay_path in sorted((FIG / "layout").glob("fig-*.json")):
        name = lay_path.stem
        layout = json.loads(lay_path.read_text())
        ja_path = FIG / f"{name}.{TGT}.txt"
        if layout.get("replace"):
            shutil.copy(FIG / layout["replace"], OUT / f"{name}.png")
            print(f"{name}: replaced with {layout['replace']}")
            continue
        if not layout.get("localize", True) or not ja_path.exists():
            shutil.copy(FIG / layout["source"], OUT / f"{name}.png")
            print(f"{name}: copied unchanged")
            continue
        en = (FIG / f"{name}.{SRC}.txt").read_text(encoding="utf-8").splitlines()
        ja = ja_path.read_text(encoding="utf-8").splitlines()
        n = len(layout["items"])
        if len(en) != n or len(ja) != n:
            print(f"ERROR {name}: layout has {n} items, {SRC}.txt {len(en)} lines, "
                  f"{TGT}.txt {len(ja)} lines - they must match", file=sys.stderr)
            errors += 1
            continue
        render(name, layout, [s.strip() for s in en], [s.strip() for s in ja])
        print(f"{name}: localised")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
