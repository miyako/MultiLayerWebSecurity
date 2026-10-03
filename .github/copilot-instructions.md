# Copilot instructions: 4D technical note localisation

This repository turns **an English 4D technical note (PDF in `document/`)** and **its companion 4D project
(`demo/<Name>/`)** into a localised PDF and a localised demo, published as a GitHub release.
The target language is set in `technote.json` (`target_lang`, default `ja`). Below, `<tgt>` means that code.

The user is the **editor**. Your job is to build and drive a repeatable pipeline, produce first drafts,
and stop at every checkpoint so the user can decide and edit. The pipeline already exists in `tools/`:
use it, and fix or extend it if needed. Don't rewrite it from scratch.

Detailed references:
- `.github/instructions/technote-translation.instructions.md`: the pipeline, config keys, figure rules, pitfalls
- `.github/instructions/4d-*.instructions.md` and the other `*.instructions.md` files: 4D coding conventions for `demo/**`
- Skills in `.github/skills/`: `review-figures`, `apply-glossary`, `localise-demo-data`, `localise-4d-project`, `release-technote`
- `.github/templates/README.technote.md`: the README of the converted repository (see Phase 6)

`README.md` is the template's usage guide until the release. Don't edit it for the specific document before then.

## Non-negotiable rules

1. **Code is never translated.** Program code blocks in `src/<tgt>.md` must be byte-identical to `src/en.md`.
   `make check` enforces this. Only ```` ```text ```` blocks (sample values or output) may differ.
2. **Never patch the PDF.** Always regenerate it from `src/` and `figures/` with `make`.
3. **Keep `src/en.md` and `src/<tgt>.md` block-aligned:** same headings, paragraphs, code blocks and figures, in the same order.
4. **Never overwrite user edits.** Don't run `tools/extract.py --force` without asking. Don't regenerate `<tgt>` files.
   Before editing a file, re-read it: the user may have changed it since you last saw it.
5. **Glossary first.** Terminology lives in `glossary.md`. When a term changes, update the glossary, then report and
   (after confirmation) replace the occurrences in `src/<tgt>.md` and `figures/*.<tgt>.txt`.
6. **Never invent data.** Numbers in the text (distances, counts, coordinates, results) must be computed from the
   actual demo data or code.
7. **Ask, don't assume,** on design decisions. Use `ask_user` with choices when available. In the cloud agent, write
   the question in the PR and stop.
8. **Commit after each milestone** with a descriptive message. Don't commit `build/`, `.venv/` or 4D runtime folders
   (see `.gitignore`).
9. **Verify visually.** Look at figures through contact sheets (`make review`) and spot-check PDF pages before saying
   something is done.

## Workflow with checkpoints

Track the phases with todos. **STOP** means: summarise what you did, list what the user should look at
(file paths, page or figure numbers), list the open decisions as questions, and wait.

### Phase 0: Setup and inspection
- `make setup`. Check the tools: Chrome (`$CHROME` or the standard locations), `tesseract`, and fonts for `<tgt>`.
  On Linux they are installed by `copilot-setup-steps.yml`.
- Confirm there is exactly one PDF in `document/` and find the 4D project(s) under `demo/`.
- `make inspect`: read the report and check the suggested `technote.json` against it (heading levels, code colours,
  caption position, footer cut-off, cover and TOC pages). If the PDF is scanned (no text layer), stop: that needs a
  different project.
- **STOP (checkpoint 1):** show `technote.json` and ask:
  - the target language and style (for Japanese: です・ます調, official 4D Japanese terms)
  - whether example data in the demo should be localised later (just flag it now)

### Phase 1: Disassembly
- `make extract` writes `src/en.md`, `figures/fig-NN.png`, `figures/fig-NN.en.txt` and `figures/layout/fig-NN.json`.
- Read `src/en.md` end to end against the PDF. Check:
  - heading levels
  - broken paragraph joins
  - merged or split code blocks
  - code language tags (one-line JS can come out tagged as `4d`)
  - captions
  - lists and tables
  - missing text near the footer cut-off
- Fix `src/en.md` by hand, or adjust `technote.json` and re-extract with `--force` (only before any translation exists).
- Correct OCR errors in `figures/*.en.txt` (e.g. `AD` → `4D`, stray `E`/`eee` noise lines). Mark app screenshots
  `"localize": false` in their layout files.
- Commit. **STOP (checkpoint 2):** report the counts of headings, code blocks and figures, plus anything doubtful.

### Phase 2: Translation
- Create `src/<tgt>.md`: translate paragraph by paragraph, keeping the structure, code fences and `![caption](fig-NN)`.
- Create `figures/fig-NN.<tgt>.txt` for each localisable figure, line-aligned with the English file.
- Record every terminology choice and proper noun in `glossary.md`.
- `make`, then `make review`. Check the contact sheets and fix layout issues with the overrides in `figures/layout/`
  (skill `review-figures`).
- Commit. **STOP (checkpoint 3):** ask the user to review `src/<tgt>.md` and `glossary.md`, and list any terms you
  were unsure about.
- **STOP (checkpoint 4):** ask the user to review the contact sheets and the PDF. Ask for localised screenshots of
  the app for figures marked `"localize": false`, and use `"replace"` when they arrive.

### Phase 3: Edit loop (repeat as needed)
- Apply the user's directions, or rebuild after the user's own edits: run `make`, inspect what changed, and commit.
- Glossary changes: skill `apply-glossary`.

### Phase 4: Demo data (optional; only if the user agreed)
- Skill `localise-demo-data`: replace sample data with local equivalents (e.g. foreign cities with cities in the
  target country), keeping the record format and adding `<tgt>` fields.
- Recompute every example number in `src/<tgt>.md` and the figures from the new data.
- **STOP (checkpoint 5)** before replacing data, with the list of candidates. Stop again after rewriting the
  examples in the text.

### Phase 5: 4D project
- Skill `localise-4d-project`: XLIFF for UI strings, language-dependent attributes, startup UX.
- **STOP (checkpoint 6)** with the plan before editing any 4D files. Verify with tool4d when it is available
  (`tools/tool4d.py`); otherwise say so explicitly. Ask the user to check the forms visually in 4D.

### Phase 6: Release
- Replace `README.md` with `.github/templates/README.technote.md`. Fill in every placeholder from real data
  (`technote.json`, the PDF title, `demo/`, the release URL), and remove the sections that don't apply.
  Ask the user for the introduction text and the credits, or draft them and get them approved.
- Skill `release-technote`. **STOP (checkpoint 7):** confirm the README, the version tag, the title, the notes
  and the assets before publishing.

## Environment notes
- Local runs are usually macOS: Hiragino fonts, `/Applications/Google Chrome.app`, tool4d under `/Applications/tool4d/`.
- The cloud agent and Actions run on Ubuntu: Noto CJK fonts, Chrome from the runner image, no tool4d.
  Builds on the two platforms differ slightly in fonts. Say this when you produce release assets on Linux.
- The image viewer shows one image per call. Use `make review` contact sheets to compare many figures at once.
