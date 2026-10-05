# Sentinel：HTTPリクエストハンドラーとHTTPルールを使用した多層Webセキュリティアーキテクチャ

Sentinel: A Multi-Layer Web Security Architecture Using HTTP Request Handlers and HTTP Rules (Technical Note 26-05): Japanese edition.

このテクニカルノートでは、4D v21.0 LTSのHTTPリクエストハンドラーとHTTPルールを基盤とした多層Webセキュリティアーキテクチャ「Sentinel」を解説します。受信したすべてのリクエストを11段階のゲートで評価する防御パイプライン、Sonar侵入検知・防止システム、総当たり攻撃対策を備えた認証、設定のホットリロード、ワーカーのオーケストレーションを順に取り上げます。付属のデモアプリケーションでは、リアルタイムのテレメトリ、防御トグル、攻撃シミュレーターを備えたダッシュボードから、これらの仕組みを実際に試すことができます。

This repository contains the Japanese translation of 4D Technical Note 26-05 and its demo, with the dashboard UI available in English and Japanese.

## Download

| | |
|---|---|
| PDF (Japanese) | [26-05_MultiLayerWebSecurity_ja.pdf](https://github.com/miyako/MultiLayerWebSecurity/releases/latest/download/26-05_MultiLayerWebSecurity_ja.pdf) |
| 4D demo | [MultiLayerWebSecurity.zip](https://github.com/miyako/MultiLayerWebSecurity/releases/latest/download/MultiLayerWebSecurity.zip) |
| Original (English) | `document/26-05_MultiLayerWebSecurity.pdf` |

## Demo

- 4D version: 21.0 LTS or later
- Open `demo/MultiLayerWebSecurity/Project/MultiLayerWebSecurity.4DProject`.
- Languages: English, Japanese. The web UI (login page, dashboard, Security Equalizer) follows the browser language. The EN/JA button on each page switches the language, and the choice is saved in the browser. The strings are in `WebFolder/i18n.*.js`.
- The Web server starts on port 8044 when the project opens. Go to http://127.0.0.1:8044, generate a passphrase on the login page, and log in. `Data/` is created with default settings on first launch. See `demo/MultiLayerWebSecurity/Project/README.md` (English) for how to use the dashboard.

## Differences from the original

- Counts and timings in the text are checked against the demo code and corrected where the original differs: 16 singleton classes, 9 defense techniques, 58 registered routes (route table completed), worker intervals, the lockout duration and the STALLED threshold.
- The known issue ACI0106333 is noted as fixed in 4D 21 R3. The demo still requires 21.0 LTS.
- Labels quoted in the text match the Japanese dashboard UI.
- Demo: the web UI is localised (English and Japanese) with Japanese font fallbacks. The 4D code, server messages and log values are unchanged and remain in English.

## Editing and rebuilding

The PDF is generated from plain-text sources. Edit them and run `make`.

| File | What |
|---|---|
| `src/ja.md` | Translated body text. **Don't touch code blocks** (`make check` verifies them). |
| `glossary.md` | Terminology |
| `style/style.css` | PDF layout |

```sh
make            # check → build/26-05_MultiLayerWebSecurity_ja.pdf
make check      # code blocks unchanged
make release-assets
```

Requirements: Python 3, Google Chrome, CJK fonts, and Tesseract (only needed for re-extraction).
See the [localisation template](https://github.com/miyako/4d-technote-localisation-template) for the full workflow.

## Credits

- Original: Anouar Moustarih, Quality Support Engineer, 4D Morocco
- Produced with [4d-technote-localisation-template](https://github.com/miyako/4d-technote-localisation-template) and GitHub Copilot.
