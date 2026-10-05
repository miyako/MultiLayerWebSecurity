# 用語集 / Glossary

Keep terminology consistent across `src/<target>.md` and `figures/*.<target>.txt`.
Change an entry here first, then search and replace in both places.

Style (ja): です・ます調. Half-width alphanumerics, no space between Japanese and Latin text (e.g. `4D.Vector型`).
Full-width `（）` and `：` in prose. First occurrence of a technical term: 日本語（English）.

## 4D terms (from the official 4D Japanese documentation)

| English | 日本語 | Notes |
|---|---|---|
| entity / entity selection | エンティティ / エンティティセレクション | |
| datastore | データストア | |
| dataclass | データクラス | |
| attribute | 属性 | |
| computed attribute | 計算属性 | |
| collection | コレクション | |
| object | オブジェクト | |
| method | メソッド | |
| project method | プロジェクトメソッド | |
| function | 関数 | |
| class | クラス | |
| parameter | 引数 | |
| form | フォーム | |
| form object | フォームオブジェクト | |
| list box | リストボックス | |
| web area | Webエリア | |
| 4D Web Server | 4D Webサーバー | |
| worker | ワーカー | |
| process | プロセス | |
| query | クエリ | |
| formula | フォーミュラ | |
| component | コンポーネント | |
| class function | クラス関数 | |
| shared singleton class | 共有シングルトンクラス | |
| database method | データベースメソッド | On Web Authentication etc. stay in English |
| HTTP Request Handlers | HTTPリクエストハンドラー | developer.4d.com/docs/ja |
| HTTP Rules | HTTPルール | developer.4d.com/docs/ja |
| privilege | 権限 | roles.json |
| web server | Webサーバー | |
| request / response header | リクエスト / レスポンスヘッダー | |

## Document-specific terms

| English | 日本語 | Notes |
|---|---|---|
| defense pipeline | 防御パイプライン | |
| gate | ゲート | eleven-gate → 11段階のゲート |
| defense technique | 防御手法 | |
| allowlist / blocklist | 許可リスト / ブロックリスト | UI label "IP Blacklist" kept as is |
| strike counter | ストライクカウンター | |
| rate limiting | レート制限 | per-IP / global → IP単位 / グローバル |
| sliding window | スライディングウィンドウ | |
| token bucket | トークンバケット | |
| burst | バースト | |
| panic mode | パニックモード | |
| master gate / master switch | マスターゲート / マスタースイッチ | |
| honeypot | ハニーポット | |
| decoy path | おとりのパス | |
| deception body | おとり用のレスポンス本文 | |
| reconnaissance | 偵察 | |
| Web Application Firewall (WAF) | Webアプリケーションファイアウォール（WAF） | |
| Intrusion Detection / Prevention System | 侵入検知システム（IDS）/ 侵入防止システム（IPS） | |
| sniper queue / drone queue | スナイパーキュー / ドローンキュー | |
| scoring rubric | スコアリング基準 | |
| signal | シグナル | |
| brute force | 総当たり攻撃 | first occurrence: 総当たり攻撃（brute force） |
| credential stuffing | クレデンシャルスタッフィング | |
| lockout | ロックアウト | |
| static passphrase | 静的パスフレーズ | |
| Dynamic Passphrase Generation (DPG) | 動的パスフレーズ生成（DPG） | |
| path traversal | パストラバーサル | |
| SQL injection | SQLインジェクション | |
| cross-site scripting (XSS) | クロスサイトスクリプティング（XSS） | |
| clickjacking | クリックジャッキング | |
| MIME sniffing | MIMEスニッフィング | |
| CRLF injection | CRLFインジェクション | |
| header overflow | ヘッダーオーバーフロー | |
| denial of service | サービス拒否（DoS） | |
| atomic write | アトミック書き込み | |
| hot reload | ホットリロード | |
| heartbeat | ハートビート | |
| cadence | 間隔 | "one-second cadence" → 1秒間隔 |
| telemetry | テレメトリ | |
| toggle | トグル | defense toggles → 防御トグル |
| polling | ポーリング | |
| attack simulator | 攻撃シミュレーター | |
| catch-all rule | キャッチオールルール | |
| preflight request | プリフライトリクエスト | |
| origin | オリジン | |

## Proper nouns in examples

| English | 日本語 | Notes |
|---|---|---|
| Sentinel, Sonar, DoSGuard, … | (unchanged) | product, class and method names stay in English |
| Technical Note | テクニカルノート | |
| By <name>, Quality Support Engineer, 4D Morocco | <name>（4D Morocco クオリティサポートエンジニア） | byline format used in other 4D Japan technical notes |
| Dashboard UI labels (Clear All, IP Blacklist, Security Equalizer, ACTIVE, STALLED) | (unchanged for now) | revisit if the dashboard UI is localised in Phase 5 |
