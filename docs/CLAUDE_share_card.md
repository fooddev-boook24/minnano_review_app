# CLAUDE.md — シェアカード機能（追加仕様）

> みんなのレビューへの追加機能として単独で渡すドキュメント。
> 既存の `CLAUDE.md`（みんなのレビュー本体）と合わせて読むこと。
> 不明点は推測で実装せず、**必ず日本語で確認してから**実装すること。

---

## ⚠️ 既存実装への影響禁止

- 既存の画面・機能・Firestore コレクションへの **変更は禁止**
- 既存の Cloud Functions への **変更は禁止**
- 新規追加のみ許可

---

## 機能概要

アプリ詳細画面に「シェアカードを作る」ボタンを追加する。
開発者が自分のアプリを SNS でシェアする際に使うカード画像を生成する機能。

**ユーザーフロー：**
```
アプリ詳細画面
  └─「シェアカードを作る」ボタン
      └─ シェアカード画面
          ├─【無料】デフォルトテンプレートでそのままシェア
          └─【リワード広告視聴後】カスタマイズモードをアンロック
              ├─ テンプレート選択（3種）
              ├─ 文言を自由入力（80文字以内）
              │   候補文言あり（「レビューお願いします！」など）
              └─ シェア実行 → OGP画像URL生成 → share_plus でシェア
```

---

## 画面仕様

### シェアカード画面（新規）

遷移元：アプリ詳細画面の任意の場所に追加するボタン

**ロック状態（広告未視聴）**
- OGP プレビューの文言・テンプレート部分はぼかし表示
- 「動画を見てアンロック」ボタン → リワード広告を再生
- 「デフォルトのままシェア」ボタン → 広告なしで即シェア可能

**アンロック状態（広告視聴済み・当日中有効）**
- テンプレート3種を切り替え可能
  - A: スタンダード（白背景）
  - B: オレンジ（グラデーション背景）
  - C: ダーク（黒背景）
- 文言を自由入力（最大80文字）
- 候補文言タップで入力欄に反映
  - 「レビューお願いします！」
  - 「使ってみてね✨」
  - 「新作リリースしました！」
  - 「ぜひ試してみて🙏」
- 「シェアする」ボタン → OGP 画像生成 → share_plus でシェート

**OGP カード構成要素**
- アプリアイコン（`artworkUrl100`）
- アプリ名（`trackName`）
- 開発者名（`developerName`）
- 評価（`averageUserRating`）
- カテゴリ（`primaryGenreName`）
- カスタム文言（アンロック時）または固定文言「App Storeで公開中」（無料時）
- App Store リンク（`trackViewUrl`）

---

## アンロック状態の管理

```dart
// lib/core/services/share_unlock_service.dart

// アンロック状態を SharedPreferences に保存
// キー: 'share_unlocked_date'
// 値:  'yyyy-MM-dd' 形式の日付文字列
// 判定: 保存された日付 == 今日の日付 → アンロック中

Future<bool> isUnlocked() async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString('share_unlocked_date');
  if (saved == null) return false;
  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
  return saved == today;
}

Future<void> unlock() async {
  final prefs = await SharedPreferences.getInstance();
  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
  await prefs.setString('share_unlocked_date', today);
}
```

---

## リワード広告（AdMob）

### アカウント方針
- 既存みんなのアプリの **AdMob アカウントを流用**
- AdMob アカウント内で「みんなのレビュー」を **新規アプリとして追加登録**
- 広告ユニット ID は iOS / Android それぞれ新規発行

### パッケージ
```yaml
google_mobile_ads: latest
```

### 広告ユニット ID の管理
```dart
// lib/core/config/env.dart に追加
static const String rewardAdUnitIdIos     = 'ca-app-pub-XXXXXXXX/XXXXXXXXXX'; // 要設定
static const String rewardAdUnitIdAndroid = 'ca-app-pub-XXXXXXXX/XXXXXXXXXX'; // 要設定

// テスト用（開発中は必ずテスト ID を使う）
static const String rewardAdUnitIdIosTest     = 'ca-app-pub-3940256099942544/1712485313';
static const String rewardAdUnitIdAndroidTest = 'ca-app-pub-3940256099942544/5224354917';
```

### 実装方針
```dart
// lib/features/share_card/services/reward_ad_service.dart

// 広告ロード → 視聴完了コールバックでアンロック処理
// 視聴完了前にアプリを閉じた場合はアンロックしない（onUserEarnedReward のみで判定）
// 広告ロード失敗時はエラーメッセージを表示してリトライボタンを出す
```

---

## Cloud Functions 追加

### 追加ファイル

```
functions/src/
├── index.ts                ← 末尾に export 追記のみ（既存行変更禁止）
├── generateShareOgp.ts     ← 新規追加
```

`index.ts` 末尾に追記：
```typescript
export { generateShareOgp } from './generateShareOgp';
```

### `generateShareOgp`

- **トリガー**: `https.onCall`
- **役割**: OGP 画像を生成し、Firebase Storage に保存して公開 URL を返す
- **参照**: みんなのアプリの既存 `generateOgpImage` の実装を参考にすること
- **書き込み先**: Firebase Storage（`share-ogp/{trackId}/{uuid}.png`）のみ
  - Firestore への書き込みは禁止
- **入力パラメータ**:
  ```typescript
  {
    trackId:    number,
    template:   'A' | 'B' | 'C',
    message:    string,   // 最大80文字
    deviceId:   string,
  }
  ```
- **バリデーション**:
  - `message` は80文字以内
  - `template` は A/B/C のいずれか
  - `trackId` が `appReviews/` または `timelines/` に存在すること（読み取りで確認）
- **画像サイズ**: 1200×630px（OGP 推奨サイズ）
- **返却値**: `{ url: string }` // Storage の公開 URL
- **キャッシュ**: 同一 trackId + template + message の組み合わせは24時間キャッシュ
  - キャッシュキー: `share-ogp/{trackId}/{md5(template+message)}.png`
  - Storage に既存ファイルがあれば再生成せず URL を返す

### デプロイコマンド（個別指定で実行）
```bash
firebase deploy --only functions:generateShareOgp
```

---

## Firebase Storage ルール追記

`storage.rules` の末尾に追記（既存ルールは変更禁止）：

```
match /share-ogp/{trackId}/{fileName} {
  allow read: if true;
  allow write: if false; // Cloud Functions のみ書き込み可
}
```

---

## Firestore 変更なし

この機能は Firestore への読み書きを行わない。
- `timelines/` の読み取りのみ（アプリ情報取得）
- Storage のみに書き込む

---

## Flutter プロジェクト追加ファイル構成

```
lib/features/share_card/          ← 新規ディレクトリ
├── share_card_screen.dart        ← シェアカード画面
├── widgets/
│   ├── ogp_preview_card.dart     ← OGP プレビューウィジェット
│   ├── template_selector.dart    ← テンプレート選択
│   └── message_editor.dart      ← 文言入力エリア
└── services/
    ├── reward_ad_service.dart    ← AdMob リワード広告
    └── share_unlock_service.dart ← アンロック状態管理
```

### 追加パッケージ
```yaml
dependencies:
  google_mobile_ads: latest   # AdMob
  share_plus: latest          # シェートシート
  shared_preferences: latest  # アンロック状態の永続化（既存で入っている可能性あり）
  intl: latest                # 日付フォーマット（既存で入っている可能性あり）
```

---

## アナリティクス追加イベント

既存の `analytics_service.dart` に以下を追加：

| イベント名 | タイミング |
|---|---|
| `review_share_card_opened` | シェアカード画面を開いたとき |
| `review_share_card_ad_started` | 広告視聴を開始したとき |
| `review_share_card_ad_completed` | 広告視聴完了・アンロックしたとき |
| `review_share_card_ad_failed` | 広告ロード失敗したとき |
| `review_share_card_shared` | シェア実行したとき（template, is_unlocked を付与） |
| `review_share_card_default_shared` | デフォルトのままシェアしたとき |

---

## デザイン

`docs/design.md` のトンマナに準拠。
モックは `docs/share_card_mock.jsx` を参照すること。

---

## 作業チェックリスト

### 実装前
- [ ] AdMob に「みんなのレビュー」アプリを新規追加し、リワード広告ユニット ID を取得した
- [ ] Firebase Storage のルールを確認した
- [ ] みんなのアプリの `generateOgpImage` の実装を確認した（参考用）

### 実装中
- [ ] 広告視聴中は `onUserEarnedReward` のみでアンロック判定している
- [ ] テスト中は AdMob テスト ID を使用している（本番 ID を直書きしない）
- [ ] Storage への書き込みのみで Firestore への書き込みがないことを確認した
- [ ] `timelines/` への書き込みがないことを確認した
- [ ] 文言の候補に「レビューお願いします！」が含まれているが、**強制挿入はしていない**

### デプロイ前
- [ ] `firebase deploy --only functions:generateShareOgp` で個別デプロイしている
- [ ] `firebase deploy --only functions` など全体デプロイを実行していない
- [ ] Storage ルールは差分確認してからデプロイした

---

## 不明点が生じた場合

推測で実装せず、**必ず日本語で確認すること。**
特に AdMob の設定・Storage ルール・既存機能への影響がある操作は確認を取ってから実装すること。
