# 4D technical note localisation

This repository turns **an English 4D technical note (PDF in `document/`)** and **its companion 4D project
(`demo/<Name>/`)** into a localised PDF and a localised demo, published as a GitHub release. It was created from
[miyako/4d-technote-localisation-template](https://github.com/miyako/4d-technote-localisation-template).
The target language is set in `technote.json` (`target_lang`, default `ja`). Below, `<tgt>` means that code.

The user is the **editor**. Your job is to build and drive a repeatable pipeline, produce first drafts,
and stop at every checkpoint so the user can decide and edit. The pipeline already exists in `tools/` (Python,
committed): use it, and fix or extend it if needed. Don't rewrite it from scratch.

- `document/`: the original PDF (read-only)
- `src/`: `en.md` (extracted) and `<tgt>.md` (translation)
- `figures/`: figure images, label files `fig-NN.<lang>.txt`, per-figure layouts in `figures/layout/`
- `demo/<Name>/`: the 4D project(s); `data/`: localised demo data (optional)
- `glossary.md`, `technote.json`, `style/style.css`, `tools/`, `Makefile`; output goes to `build/` (git-ignored)

References:
- `.github/instructions/technote-translation.instructions.md`: the pipeline, `technote.json` keys, figure rules,
  verification checklist and pitfalls
- Technote skills (see [Skills](#skills-keep-as-is)): `technote-review-figures`, `technote-apply-glossary`,
  `technote-localise-demo-data`, `technote-localise-4d-project`, `technote-release`
- Generic 4D skills for `demo/**`: `4dlocalise` (XLIFF, names that follow the UI language), `4dstartup`
  (non-blocking startup window), `4dmodernise` (`C_*` → `var`), `4dmethods` (method visibility), `4dform`
  (forms, list boxes), `4dcss` (stylesheets, dark mode, Liquid Glass), `4dproject` (`menus.json`, version,
  token suffixes, `.gitignore`), `4dorda` (ORDA code, computed attributes), `4dlsp` (syntax checks), `4dcli`
  (running tool4d)
- `.github/templates/README.technote.md`: the README of the localised repository (see Phase 6)

Until the first release, `README.md` is the template's usage guide. Don't edit it for the specific document before
then; at release it is replaced (Phase 6).

## Repository rules

1. **Code is never translated.** Program code blocks in `src/<tgt>.md` must be byte-identical to `src/en.md`.
   `make check` enforces this. Only ```` ```text ```` blocks (sample values or output) may differ.
2. **Never patch the PDF.** Always regenerate it from `src/` and `figures/` with `make`.
3. **Keep `src/en.md` and `src/<tgt>.md` block-aligned:** same headings, paragraphs, code blocks and figures, in the
   same order.
4. **Never overwrite user edits.** Don't run `tools/extract.py --force` without asking. Don't regenerate `<tgt>` files.
   Before editing a file, re-read it: the user may have changed it since you last saw it.
5. **Glossary first.** Terminology lives in `glossary.md`. When a term changes, update the glossary, then report and
   (after confirmation) replace the occurrences in `src/<tgt>.md` and `figures/*.<tgt>.txt`.
6. **Never invent data.** Numbers in the text (distances, counts, coordinates, results) must be computed from the
   actual demo data or code.
7. **Ask, don't assume,** on design decisions. Use `ask_user` with choices when available. In the cloud agent, write
   the question in the PR and stop.
8. **Commit after each milestone** with a descriptive message. Don't commit `build/`, `.venv/`, 4D runtime folders
   or tools provisioned by the skills (see `.gitignore`).
9. **Verify visually.** Look at figures through contact sheets (`make review`) and spot-check PDF pages before saying
   something is done.
10. **Syntax vs running code.** Check `.4dm` syntax with the `4dlsp` skill. Use `tools/tool4d.py` (see `4dcli`) only
    to run test methods and the whole-project compile. Don't write a startup method just to check syntax.

## Workflow and checkpoints

Track the phases with todos. **STOP** means: summarise what you did, list what the user should look at
(file paths, page or figure numbers), list the open decisions as questions, and wait.

### Phase 0: Setup and inspection
- `git submodule update --init .agents` if `.agents/` is empty (see [Setup](#setup-keep-as-is)).
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
  (skill `technote-review-figures`).
- Commit. **STOP (checkpoint 3):** ask the user to review `src/<tgt>.md` and `glossary.md`, and list any terms you
  were unsure about.
- **STOP (checkpoint 4):** ask the user to review the contact sheets and the PDF. Ask for localised screenshots of
  the app for figures marked `"localize": false`, and use `"replace"` when they arrive.

### Phase 3: Edit loop (repeat as needed)
- Apply the user's directions, or rebuild after the user's own edits: run `make`, inspect what changed, and commit.
- Glossary changes: skill `technote-apply-glossary`.

### Phase 4: Demo data (optional; only if the user agreed)
- Skill `technote-localise-demo-data`: replace sample data with local equivalents (e.g. foreign cities with cities in
  the target country), keeping the record format and adding `<tgt>` fields.
- Recompute every example number in `src/<tgt>.md` and the figures from the new data.
- **STOP (checkpoint 5)** before replacing data, with the list of candidates. Stop again after rewriting the
  examples in the text.

### Phase 5: 4D project
- Skill `technote-localise-4d-project`: survey, plan, then apply the generic 4D skills (`4dlocalise` for XLIFF and
  language-dependent attributes, `4dstartup` for the startup UX, and the others listed above as needed).
- **STOP (checkpoint 6)** with the plan before editing any 4D files.
- Check the syntax of every `.4dm` you changed with `4dlsp`. When tool4d is available, run the test methods and a
  whole-project compile with `tools/tool4d.py`; otherwise say explicitly that the code was not run or compiled.
  Ask the user to check the forms visually in 4D.

### Phase 6: Release
- Replace `README.md` with `.github/templates/README.technote.md`. Fill in every placeholder from real data
  (`technote.json`, the PDF title, `demo/`, the release URL), and remove the sections that don't apply.
  Ask the user for the introduction text and the credits, or draft them and get them approved.
- Skill `technote-release`. **STOP (checkpoint 7):** confirm the README, the version tag, the title, the notes
  and the assets before publishing.

## Environment notes
- Local runs are usually macOS: Hiragino fonts, `/Applications/Google Chrome.app`, tool4d under `/Applications/tool4d/`
  (or `$TOOL4D`).
- The cloud agent and Actions run on Ubuntu: Noto CJK fonts, Chrome from the runner image, no tool4d.
  Builds on the two platforms differ slightly in fonts. Say this when you produce release assets on Linux.
- The image viewer shows one image per call. Use `make review` contact sheets to compare many figures at once.

## Skills (keep as is)

Reusable 4D knowledge lives in the `.agents` submodule (`miyako/skills`, branch `dist`):

- Each skill is at `.agents/skills/<name>/SKILL.md`. Copilot, Codex and Claude Code discover them automatically.
- Read `.agents/AGENTS.md` first: it explains which skill to use for which 4D artifact
  (`.4DProject`, `.4DForm`, `.4DCatalog`, `.4DSettings`, `.4dm`, XLIFF …).
- Prefer the most specific skill over general knowledge of 4D.
- Never edit files under `.agents/`: they are overwritten by the weekly skills update.

## Setup (keep as is)

```sh
git submodule update --init .agents
```

If `.agents/` is empty, run the command above before doing anything else. `--recursive` is not needed.
Tools provisioned by the skills go to `tools/4dcatalog/`, `tools/4dform/`, `tools/4dlsp/`, `tools/4dlang/` and `tools/4dcli/`;
they are ignored by `.gitignore` and must not be committed.

## Instructions vs skills (keep as is)

- **Repository-specific rules** go in this file, or in `.github/instructions/*.instructions.md` with an
  `applyTo` glob when they only apply to some paths.
- **Reusable know-how** (4D language, forms, CSS, XLIFF, project settings …) goes to
  [miyako/skills](https://github.com/miyako/skills). Never copy a skill or its content into this repository;
  improve the skill there instead, and mention what you learnt to the user so it can be upstreamed.

## README (keep as is)

`README.md` is for developers. Never put Copilot model, mode, token or session content (usage tables,
model selection advice, session logs) in `README.md`.
