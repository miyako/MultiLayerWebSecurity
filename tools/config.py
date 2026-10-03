"""Shared configuration for the localisation pipeline.

All document-specific values live in technote.json at the repository root.
Run `make inspect` to get a suggested configuration for a new PDF.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

DEFAULTS = {
    "source_pdf": None,            # default: the only PDF in document/
    "source_lang": "en",
    "target_lang": "ja",
    "output_pdf": "{stem}_{lang}.pdf",
    "toc_title": {"ja": "目次", "en": "Table of Contents"},
    "accent_color": "#2f5496",      # heading colour, injected into the CSS as --accent
    "page_size": "letter",          # letter | a4
    "cover": {"page": 1, "lines": 3},
    "skip_pages": [1, 2],           # cover + table of contents (regenerated, never extracted)
    "header_y": 0,                  # ignore lines whose top is above this (pt)
    "footer_y": 710,                # ignore lines whose top is below this (pt)
    "heading": {"fonts": ["Bold", "Medium"], "min_size": 12, "levels_by_x": {}, "default_level": 2},
    "code": {"colors": [], "fonts": ["Mono", "Courier", "Menlo", "Consolas", "Monaco"], "indent": 5},
    "bullets": {"fonts": ["SymbolMT", "Wingdings-Regular"], "strip_fonts": ["ArialMT"]},
    "caption": {"italic": True, "min_x": 0},
    "table": {"size": None},        # font size used only by table cells, or null
    "paragraph": {"gap": 3, "short_line_x1": 470},
    "ocr": {"psm": 11, "min_conf": 30, "noise": r"^[E ]+$"},
    "figure_fonts": {},             # {"light"|"regular"|"bold": [path or path#index, ...]}
    "demo_dir": "demo",
}

DEFAULT_FIGURE_FONTS = {
    "ja": {
        "light": ["/System/Library/Fonts/ヒラギノ角ゴシック W3.ttc",
                  "/usr/share/fonts/opentype/noto/NotoSansCJK-Light.ttc#0",
                  "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc#0"],
        "regular": ["/System/Library/Fonts/ヒラギノ角ゴシック W4.ttc",
                    "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc#0"],
        "bold": ["/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc",
                 "/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc#0"],
    },
    "*": {
        "light": ["/System/Library/Fonts/HelveticaNeue.ttc#7",
                  "/usr/share/fonts/truetype/dejavu/DejaVuSans-ExtraLight.ttf",
                  "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"],
        "regular": ["/System/Library/Fonts/HelveticaNeue.ttc#0",
                    "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"],
        "bold": ["/System/Library/Fonts/HelveticaNeue.ttc#1",
                 "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"],
    },
}


def _merge(base, over):
    out = dict(base)
    for k, v in over.items():
        out[k] = _merge(base[k], v) if isinstance(v, dict) and isinstance(base.get(k), dict) else v
    return out


def load():
    path = ROOT / "technote.json"
    user = json.loads(path.read_text(encoding="utf-8")) if path.exists() else {}
    user = {k: v for k, v in user.items() if not k.startswith("$")}
    cfg = _merge(DEFAULTS, user)
    if not cfg["source_pdf"]:
        pdfs = sorted((ROOT / "document").glob("*.pdf"))
        if len(pdfs) != 1:
            raise SystemExit(f"Put exactly one PDF in document/ or set source_pdf in technote.json "
                             f"(found {len(pdfs)})")
        cfg["source_pdf"] = str(pdfs[0].relative_to(ROOT))
    cfg["source_path"] = ROOT / cfg["source_pdf"]
    return cfg


def output_pdf(cfg, lang):
    stem = Path(cfg["source_pdf"]).stem
    return cfg["output_pdf"].format(stem=stem, lang=lang)


def figure_fonts(cfg):
    """Resolve {weight: (path, index)} to the first existing font file per weight."""
    lang = cfg["target_lang"]
    wanted = _merge(DEFAULT_FIGURE_FONTS.get(lang, DEFAULT_FIGURE_FONTS["*"]), cfg["figure_fonts"])
    out = {}
    for weight in ("light", "regular", "bold"):
        for cand in wanted.get(weight, []):
            path, _, idx = cand.partition("#")
            if Path(path).exists():
                out[weight] = (path, int(idx or 0))
                break
    if "regular" not in out:
        raise SystemExit(f"No figure font found for '{lang}'. Set figure_fonts in technote.json.")
    for weight in ("light", "bold"):
        out.setdefault(weight, out["regular"])
    return out
