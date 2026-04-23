# CLAUDE.md — みんなのレビュー

> Claude Code への引き渡しドキュメント。
> 実装前に必ずこのファイルを**全て読んでから**作業を開始すること。
> 不明点は推測で実装せず、**必ず日本語で確認してから**実装すること。

---

## ⚠️ 最重要：既存データ・リソース保護ルール

このプロジェクトは **Firebase プロジェクト `minnano-app` を既存サービス「みんなのアプリ」と共有している。**
みんなのアプリは本番稼働中であり、既存のデータ・Functions・Hosting・Rules・Indexes に
**いかなる理由があっても影響を与えてはならない。**

---

### 🔥 Firebase デプロイの絶対ルール

#### 【禁止】以下のコマンドは絶対に実行しない

```bash
# ❌ 全体デプロイ — 既存Functions/Hosting/Rules/Indexes 全てに影響する
firebase deploy

# ❌ Functions全体デプロイ — 【重要】このリポジトリの functions/ には3関数しかないため、
# 実行すると既存みんなのアプリの8関数が削除される可能性がある（Firebase SDK バージョンによる）
firebase deploy --only functions

# ❌ Hosting全体デプロイ — minnano-app が上書きされる
firebase deploy --only hosting

# ❌ Rules全体デプロイ — 既存Rulesが上書きされる（後述の手順を使うこと）
firebase deploy --only firestore:rules

# ❌ Indexes全体デプロイ — 既存Indexesが削除される（後述の手順を使うこと）
firebase deploy --only firestore:indexes
```

#### 【必須】デプロイは必ず対象リソースを明示する

```bash
# ✅ Functionsは関数名を個別指定
firebase deploy --only functions:fetchAppReviews
firebase deploy --only functions:generateReviewSummary
firebase deploy --only functions:aggregateCategoryInsights

# ✅ Hostingはサイト名を指定
firebase deploy --only hosting:minnano-review

# ✅ Rules は後述の「Rulesの安全な更新手順」に従う
# ✅ Indexes は後述の「Indexesの安全な更新手順」に従う
```

#### 【必須】デプロイ前に必ずプロジェクトIDを確認する

```bash
# 現在のプロジェクトを確認
firebase use

# 必ず minnano-app であることを確認してから実行
# 別プロジェクトが選択されている場合は以下で切り替え
firebase use minnano-app
```

---

### 🔥 Firestore Rules の安全な更新手順

`firestore.rules` はプロジェクト全体で1ファイルであり、
`firebase deploy --only firestore:rules` を実行すると**ファイル全体が上書きされる。**
以下の手順を必ず守ること。

#### Step 1: みんなのアプリのリポジトリから Rules をコピーする

> `firebase firestore:rules:get` コマンドは存在しない。
> 必ずみんなのアプリのリポジトリにある `firestore.rules` を起点にすること。

```bash
# みんなのアプリのリポジトリから firestore.rules をコピー
cp /path/to/minnano_app/firestore.rules firestore.rules
```

#### Step 2: コピーした内容を確認し、末尾に追記する

みんなのレビュー用のルールは **既存ルールの末尾にのみ追記** する。
既存の `match` ブロックは1文字も変更しないこと。

追記内容：
```javascript
// ── みんなのレビュー（新規追加） ──────────────────────────

match /appReviews/{trackId} {
  allow read: if true;
  allow write: if false;
}

match /appReviews/{trackId}/items/{reviewId} {
  allow read: if true;
  allow write: if false;
}

match /appReviewSummaries/{trackId} {
  allow read: if true;
  allow write: if false;
}

match /categoryInsights/{categoryName} {
  allow read: if true;
  allow write: if false;
}
```

#### Step 3: 差分を目視確認してからデプロイ

```bash
# 差分確認（追記のみであることを必ず確認）
git diff firestore.rules

# 問題なければデプロイ
firebase deploy --only firestore:rules
```

---

### 🔥 Firestore Indexes の安全な更新手順

`firestore.indexes.json` も全体上書きになるため、以下の手順を守ること。

#### Step 1: 現在の本番 Indexes を取得する

```bash
firebase firestore:indexes > firestore.indexes.current.json
```

#### Step 2: 取得した内容の `indexes` 配列末尾に追記する

既存エントリは1件も変更・削除しないこと。

追記内容（`indexes` 配列の末尾に追加）：
```json
{
  "collectionGroup": "items",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "trackId",    "order": "ASCENDING" },
    { "fieldPath": "rating",     "order": "ASCENDING" },
    { "fieldPath": "reviewDate", "order": "DESCENDING" }
  ]
},
{
  "collectionGroup": "items",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "trackId",    "order": "ASCENDING" },
    { "fieldPath": "reviewDate", "order": "DESCENDING" }
  ]
}
```

#### Step 3: 差分を目視確認してからデプロイ

```bash
# 差分確認（追記のみであることを必ず確認）
diff firestore.indexes.current.json firestore.indexes.json

# 問題なければデプロイ
firebase deploy --only firestore:indexes
```

---

### 🔥 firebase.json の安全な設定手順

`flutterfire configure` を実行すると `firebase.json` が上書きされる場合がある。
以下の手順を守ること。

#### Step 1: `flutterfire configure` 実行前にバックアップ

```bash
cp firebase.json firebase.json.backup
```

#### Step 2: 実行後に差分を確認

```bash
diff firebase.json.backup firebase.json
```

#### Step 3: みんなのレビュー用の hosting 設定を追記する

`firebase.json` の `hosting` 配列には以下を**追記のみ**で対応する。
既存の `minnano-app` サイトの設定は変更しないこと。

```json
{
  "site": "minnano-review",
  "public": "build/web-review",
  "rewrites": [{ "source": "**", "destination": "/index.html" }],
  "headers": [
    {
      "source": "**/*.@(js|css)",
      "headers": [{ "key": "Cache-Control", "value": "max-age=31536000" }]
    }
  ]
}
```

#### Step 4: Web ビルド時は出力先を明示する

Flutter のデフォルト出力は `build/web` であり `build/web-review` には出力されない。
必ず `--output` オプションを指定すること。

```bash
# ✅ 出力先を明示してビルド
flutter build web --output=build/web-review

# ✅ その後デプロイ
firebase deploy --only hosting:minnano-review
```

---

### 🔥 Firestore 書き込み禁止コレクション

以下のコレクションへの **書き込み・更新・削除は完全禁止。**
読み取り（`.get()`, `.where().get()` 等）は許可。

| コレクション | 禁止操作 |
|---|---|
| `timelines/` | set / update / delete |
| `timelines/{id}/apps/` | set / update / delete |
| `likes/` | set / update / delete |
| `screenshotCache/` | set / update / delete |

コード中に上記コレクションへの書き込みが1件でも含まれていたら**即座に修正すること。**

---

### 🔥 Functions の同名禁止リスト

以下の関数名は既存みんなのアプリで使用中。**同名の関数を作成しないこと。**

```
generateTimeline / unlinkXAccount / getAvatar / serveTimelineMeta
generateOgpImage / linkXAccount / toggleLike / getAppScreenshots
```

みんなのレビュー用の関数名（これ以外の名前は使用禁止）：
```
fetchAppReviews / generateReviewSummary / aggregateCategoryInsights
```

---

## プロジェクト概要

| 項目 | 内容 |
|---|---|
| サービス名 | みんなのレビュー |
| URL | `https://review.minna-no.app`（予定） |
| 対象ユーザー | 個人開発者 |
| 目的 | App Storeレビューを横断的に解析し、開発の意思決定を支援する |
| Flutter プロジェクト | **みんなのアプリとは完全に別プロジェクト（新規作成）** |
| Firebase プロジェクト | `minnano-app`（みんなのアプリと**共有**） |
| 対応プラットフォーム | iOS / Android / Web（Flutter） |
| 対象国・言語 | 日本（`jp`）のみ（v1） |

---

## 参照ドキュメント

| ファイル | 内容 |
|---|---|
| `docs/design.md` | デザインシステム・トンマナ（必読） |
| `docs/firebase-shared-architecture.md` | 既存 Firestore 構造・接続方針（必読） |

---

## Firebase 接続設定

```bash
# 実行前に必ず firebase.json をバックアップすること
cp firebase.json firebase.json.backup

flutterfire configure --project=minnano-app

# 実行後に差分確認
diff firebase.json.backup firebase.json
```

生成される `lib/core/config/firebase_options.dart` はそのまま使用する。
`google-services.json` / `GoogleService-Info.plist` は
**みんなのアプリと同一の `minnano-app` プロジェクトのものを使用する。**

---

## Functions プロジェクト構成

みんなのレビューは**独立した新規 Functions プロジェクト。**
みんなのアプリの `functions/` とは別ディレクトリ・別リポジトリ。

```
functions/src/
├── index.ts                     ← みんなのレビュー専用（新規）
├── fetchAppReviews.ts           ← 新規
├── generateReviewSummary.ts     ← 新規
└── aggregateCategoryInsights.ts ← 新規
```

`index.ts`：
```typescript
export { fetchAppReviews }           from './fetchAppReviews';
export { generateReviewSummary }     from './generateReviewSummary';
export { aggregateCategoryInsights } from './aggregateCategoryInsights';
```

---

## 機能仕様

### 画面構成（BottomNav 4タブ）

```
BottomNav
├── ホーム   — 最近見たアプリ・おすすめアプリ
├── 探索     — カテゴリ横断 / 競合比較（2タブ）
├── 検索     — アプリ・開発者を検索
└── 設定     — Proプラン管理・その他
```

### 各画面の詳細

#### ホーム画面
- 最近閲覧したアプリのカード一覧
- カテゴリ別おすすめアプリ（`timelines/{artistId}/apps/` から**読み取りのみ**）
- ウォッチリストに追加した競合アプリの評価変動サマリー

#### 検索画面
- **みんなのアプリに登録済みの開発者・アプリのみ**が対象
- `timelines/` の `developerNameLower` / `trackNameLower` を使用（**読み取りのみ**）
- 検索結果タップでアプリ詳細画面へ遷移

#### アプリ詳細画面（4タブ）

**レビュータブ**
- App Store レビュー一覧（`appReviews/{trackId}/items/` から表示）
- キーワード検索・高評価 / 低評価 フィルタ

**解析タブ**
- 評価推移グラフ（バージョン × 平均評価の時系列）
- トピック分類棒グラフ（バグ・UI/UX・機能要望・価格・ポジティブ）
- ワードクラウド（高評価・低評価を並列表示）

**比較タブ**
- 同カテゴリの他アプリを選んで指標を並列比較（無料: 2アプリ / Pro: 4アプリ）
- 指標：バグ言及率 / UI評価率 / 機能要望率 / 価格不満率 / 高評価率
- 頻出キーワードのポジティブ / ネガティブ対比表示・差分サマリー
- 探索画面の競合比較タブからも遷移可（双方向）

**AI分析タブ（Pro機能）**
- ユーザーが手動でリクエスト → Anthropic API で生成
- 機能リクエスト Top4 / 強み / 改善点 / ASO改善ヒント
- 生成結果は `appReviewSummaries/{trackId}` にキャッシュ
- 同一アプリの再生成は24時間インターバル

#### 探索画面（2タブ）

**カテゴリ横断タブ**
- カテゴリ選択チップ（`primaryGenreName` ベース、**読み取りのみ**）
- よくある不満（増減デルタ付き）・評価されていること・急上昇キーワード
- ホワイトスペース提案テキスト
- データソース：`categoryInsights/{categoryName}`（定期バッチ集計済み）
- 無料: 3カテゴリまで / Pro: 全カテゴリ

**競合比較タブ**
- アプリを最大4つ選んで比較（無料: 2 / Pro: 4）
- アプリ詳細の比較タブからも遷移可（双方向）

---

## Firestore 新規コレクション設計

**書き込みが許可されているコレクションはこの3つのみ。**

### `appReviews/{trackId}`

```
appReviews/{trackId}
├── lastFetchedAt:  Timestamp
├── totalCount:     number
└── items/{reviewId}
    ├── reviewId:   string      // iTunes 固有ID
    ├── trackId:    number
    ├── rating:     number      // 1〜5
    ├── title:      string
    ├── body:       string
    ├── authorName: string
    ├── country:    string      // 固定値: "jp"
    ├── version:    string?
    ├── reviewDate: Timestamp
    └── fetchedAt:  Timestamp
```

### `appReviewSummaries/{trackId}`

```
appReviewSummaries/{trackId}
├── positivePoints:  string[]
├── negativePoints:  string[]
├── featureRequests: string[]
├── asoHint:         string
├── keywords: {
│   positive: string[]
│   negative: string[]
│ }
├── topicCounts: {
│   bug: number / ux: number / feature: number
│   price: number / positive: number
│ }
├── generatedAt:     Timestamp
└── reviewCount:     number
```

### `categoryInsights/{categoryName}`

```
categoryInsights/{categoryName}
├── categoryName:    string
├── avgRating:       number
├── reviewCount:     number
├── topComplaints:   [{ label, count, pct, delta }]
├── topPraise:       [{ label, pct }]
├── risingKeywords:  string[]
├── whitespaceHint:  string
└── aggregatedAt:    Timestamp
```

---

## Cloud Functions 仕様

### `fetchAppReviews`

- **トリガー**: `https.onCall`
- **役割**: iTunes RSS から指定 `trackId` のレビューを取得し `appReviews/{trackId}` に保存
- **キャッシュ**: `lastFetchedAt` から24時間以内はスキップ
- **対象国**: `jp` のみ
- **エンドポイント**: `https://itunes.apple.com/jp/rss/customerreviews/page={n}/id={trackId}/sortBy=mostRecent/json`
- **ページネーション**: page=1〜10（最大500件）
- **重複排除**: `reviewId` をドキュメントIDとして `set`（冪等）
- **書き込み先**: `appReviews/{trackId}` **のみ**

### `generateReviewSummary`

- **トリガー**: `https.onCall`（Pro ユーザーの手動リクエスト）
- **役割**: `appReviews/{trackId}/items/` を読み取り Anthropic API で解析
- **書き込み先**: `appReviewSummaries/{trackId}` **のみ**
- **再生成制限**: `generatedAt` から24時間以内は `already-exists` を返す
- **使用モデル**: `claude-haiku-4-5-20251001`（コスト最適化）
- **レビュー数上限**: 最大200件を渡す
- **レスポンス形式**: JSON のみ（システムプロンプトで preamble 禁止を明示）

### `aggregateCategoryInsights`

- **トリガー**: `pubsub.schedule`（毎日 AM 3:00 JST）
- **役割**: 全カテゴリのレビューを集計し `categoryInsights/{categoryName}` を更新
- **処理フロー**:
  1. `timelines/` から `primaryGenreName` を収集（**読み取りのみ**）
  2. カテゴリごとに `appReviews/` のレビューを集計
  3. `categoryInsights/{categoryName}` に書き込み
- **書き込み先**: `categoryInsights/` **のみ**

---

## アナリティクス

### 方針

Firebase Analytics を使用。みんなのアプリと同一の `minnano-app` プロジェクトに記録される。
イベント名には必ず `review_` プレフィックスを付けてみんなのアプリのイベントと区別する。

### パッケージ

```yaml
firebase_analytics: latest
```

### 計測イベント一覧

| イベント名 | タイミング |
|---|---|
| `review_app_viewed` | アプリ詳細画面を開いたとき |
| `review_tab_changed` | アプリ詳細のタブを切り替えたとき |
| `review_search_executed` | 検索を実行したとき |
| `review_category_selected` | カテゴリ横断でカテゴリを選択したとき |
| `review_compare_app_added` | 競合比較にアプリを追加したとき |
| `review_summary_requested` | AI分析をリクエストしたとき |
| `review_summary_completed` | AI分析が完了したとき |
| `review_pro_paywall_shown` | Proペイウォールが表示されたとき |
| `review_pro_purchase_started` | Pro購入フローを開始したとき |
| `review_pro_purchase_completed` | Pro購入が完了したとき |

### 実装パターン

```dart
// lib/core/services/analytics_service.dart
class AnalyticsService {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  Future<void> logAppViewed(String trackId) async {
    await _analytics.logEvent(
      name: 'review_app_viewed',
      parameters: {'track_id': trackId},
    );
  }
  // 以降同様のパターンで実装
}
```

---

## 収益化：RevenueCat

### パッケージ

```yaml
purchases_flutter: latest
```

### プラン

```
プラン名: pro_monthly
価格: ¥480 / 月（推奨）
```

### Pro 限定機能

| 機能 | 無料 | Pro |
|---|---|---|
| AI分析タブ | ❌ | ✅ |
| 競合比較アプリ数 | 2アプリ | 4アプリ |
| カテゴリ横断閲覧 | 3カテゴリ | 全カテゴリ |

### 判定実装

```dart
// lib/core/services/revenue_cat_service.dart
Future<bool> isProUser() async {
  final info = await Purchases.getCustomerInfo();
  return info.entitlements.active.containsKey('pro');
}
```

---

## Flutter プロジェクト構成

```
lib/
├── main.dart
├── core/
│   ├── config/
│   │   ├── firebase_options.dart
│   │   └── env.dart
│   ├── constants/
│   │   ├── app_colors.dart           // docs/design.md に準拠
│   │   ├── app_text_styles.dart      // docs/design.md に準拠
│   │   └── app_shadows.dart          // docs/design.md に準拠
│   └── services/
│       ├── firestore_service.dart
│       ├── functions_service.dart
│       ├── analytics_service.dart
│       └── revenue_cat_service.dart
├── features/
│   ├── home/
│   ├── search/
│   ├── app_detail/
│   │   └── tabs/
│   │       ├── reviews_tab.dart
│   │       ├── analysis_tab.dart
│   │       ├── compare_tab.dart
│   │       └── ai_analysis_tab.dart
│   ├── explore/
│   │   └── tabs/
│   │       ├── category_tab.dart
│   │       └── compare_tab.dart
│   └── settings/
└── shared/
    ├── widgets/
    └── models/
```

### 主要パッケージ

```yaml
dependencies:
  firebase_core: latest
  cloud_firestore: latest
  cloud_functions: latest
  firebase_analytics: latest
  purchases_flutter: latest
  flutter_riverpod: latest
  go_router: latest
  cached_network_image: latest
  fl_chart: latest
  google_fonts: latest
```

---

## デザイン実装の注意点

`docs/design.md` を必ず参照。以下は特に重要な点：

- **フォント**: Zen Maru Gothic（日本語見出し）/ DM Sans（数値・ラベル）
- **グラデーション**: `#FFAC33 → #FF7A00`（CTAボタン・アクセントバー・グラデーションテキスト）
- **背景**: `#F6F6F9`（画面）/ `#FFFFFF`（カード）
- **カード**: 角丸18px・影あり・上部3pxグラデーションバー
- **ボタン**: 角丸999px・グラデーション背景・オレンジ影

---

## 作業前・作業中チェックリスト

### 🔴 デプロイ前（毎回必ず確認）

- [ ] `firebase use` でプロジェクトが `minnano-app` であることを確認した
- [ ] デプロイコマンドにリソースを個別指定している（`firebase deploy` 単体は禁止）
- [ ] Functions デプロイは関数名を個別指定している
- [ ] Hosting デプロイは `--only hosting:minnano-review` を指定している
- [ ] Rules 更新は「安全な更新手順」に従い差分確認済み
- [ ] Indexes 更新は「安全な更新手順」に従い差分確認済み

### 🔴 コード実装中（随時確認）

- [ ] `timelines/`, `likes/`, `screenshotCache/` への書き込みコードが存在しない
- [ ] `timelines/`, `apps/` サブコレクションへの操作は `.get()` のみ
- [ ] 新規 Function 名が禁止リストと重複していない
- [ ] `firebase.json` の `minnano-app` hosting 設定を変更していない
- [ ] アナリティクスイベント名に `review_` プレフィックスが付いている

### 🔴 `flutterfire configure` 実行時

- [ ] 実行前に `firebase.json` をバックアップした
- [ ] 実行後に `diff` で差分を確認した
- [ ] `minnano-app` hosting 設定が消えていないことを確認した

---

## 不明点が生じた場合

実装中に仕様・設計が不明な箇所が出た場合は、**推測で実装せず必ず日本語で確認すること。**
特に既存データ・既存リソースに影響する可能性がある操作は、
内容を日本語で説明した上で確認を取ってから実装すること。
