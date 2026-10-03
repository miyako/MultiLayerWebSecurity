<!--
README template for a converted repository.
At the release phase the agent replaces README.md with this file:
- fill in every {{PLACEHOLDER}}; never invent values (take them from technote.json, the PDF, demo/ and the release)
- delete sections that don't apply (e.g. "Demo data" if the data was not localised)
- delete this comment and the other HTML comments
-->

# {{TITLE_TARGET}}

{{TITLE_SOURCE}}: {{TARGET_LANGUAGE_NAME}} edition.

{{INTRODUCTION}}
<!-- 3–5 sentences in the target language: what the note explains and what the demo does. Optionally repeat in English. -->

## Download

| | |
|---|---|
| PDF ({{TARGET_LANGUAGE_NAME}}) | [{{OUTPUT_PDF}}]({{RELEASE_URL}}) |
| 4D demo | [{{DEMO_NAME}}.zip]({{RELEASE_URL}}) |
| Original (English) | `document/{{SOURCE_PDF}}` |

## Demo

- 4D version: {{4D_VERSION}}
- Open `demo/{{DEMO_NAME}}/Project/{{DEMO_NAME}}.4DProject`.
- Languages: {{UI_LANGUAGES}}. The UI follows the system language; the XLIFF files are in `Resources/<lang>.lproj/`.
- {{STARTUP_NOTES}}

### Demo data

{{DATA_NOTES}}
<!-- e.g. "Sample data replaced with Japanese cities and landmarks from Wikidata (data/...). The original data is kept in data/<original>/." -->

## Differences from the original

{{DIFFERENCES}}
<!-- bullet list: localised examples, replaced screenshots, figures changed, attributes added to the demo, etc. -->

## Editing and rebuilding

The PDF is generated from plain-text sources. Edit them and run `make`.

| File | What |
|---|---|
| `src/{{TARGET_LANG}}.md` | Translated body text. **Don't touch code blocks** (`make check` verifies them). |
| `figures/fig-NN.{{TARGET_LANG}}.txt` | Text drawn in figure NN. Line N corresponds to line N of `fig-NN.{{SOURCE_LANG}}.txt`: an identical line keeps the original, an empty line erases it. |
| `figures/layout/fig-NN.json` | Per-label overrides for size, weight, alignment and position; `"replace"` uses a ready-made image |
| `glossary.md` | Terminology |

```sh
make            # check → figures → build/{{OUTPUT_PDF}}
make check      # code blocks unchanged, figure references complete
make review     # contact sheets of the figures (build/contact-N.png)
make release-assets
```

Requirements: Python 3, Google Chrome, CJK fonts, and Tesseract (only needed for re-extraction).
See the [localisation template]({{TEMPLATE_URL}}) for the full workflow.

## Credits

- Original: {{ORIGINAL_CREDITS}}
- Translation: {{TRANSLATION_CREDITS}}
- Produced with [{{TEMPLATE_NAME}}]({{TEMPLATE_URL}}) and GitHub Copilot.
