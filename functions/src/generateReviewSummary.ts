import * as admin from 'firebase-admin';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import Anthropic from '@anthropic-ai/sdk';

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();

const REGION = 'asia-northeast1';
const CACHE_HOURS = 24;
const MAX_REVIEWS = 200;
const MODEL = 'claude-haiku-4-5-20251001';

const SYSTEM_PROMPT = `あなたはApp Storeレビューから競合インテリジェンスを抽出するAIです。
開発者が「競合アプリのユーザーレビュー」を読み解き、市場参入・差別化の判断に使うための情報を提供してください。
必ず以下のJSON形式のみで回答してください。前置きや説明文は一切不要です。JSONのみを出力してください。

{
  "positivePoints": ["ユーザーが評価している点1（競合の強み）", "評価している点2", "評価している点3"],
  "negativePoints": ["ユーザーが繰り返し不満を述べている点1（あなたが勝てる弱点）", "不満点2", "不満点3"],
  "featureRequests": ["ユーザーが強く求めているが未解決のニーズ1（参入機会）", "ニーズ2", "ニーズ3", "ニーズ4"],
  "asoHint": "このアプリの弱点・ユーザーの不満を踏まえて、競合として参入・差別化するための具体的な戦略",
  "keywords": {
    "positive": ["ユーザーが繰り返し使うポジティブワード1", "ポジティブワード2"],
    "negative": ["ユーザーが繰り返し使うネガティブワード1", "ネガティブワード2"]
  },
  "topicCounts": {
    "bug": 0,
    "ux": 0,
    "feature": 0,
    "price": 0,
    "positive": 0
  }
}

各フィールドの分析視点：
- positivePoints: このアプリがユーザーから支持されている理由。競合として意識すべき強み。
- negativePoints: ユーザーが繰り返し不満を述べていること。ここがあなたの差別化ポイントになる。
- featureRequests: ユーザーが強く求めているがまだ実現されていない機能・体験。これが市場の空白（参入機会）。
- asoHint: 上記の分析を踏まえ、このカテゴリに参入・競合するための具体的な差別化戦略を1〜3文で。`;

export const generateReviewSummary = onCall(
  { region: REGION },
  async (request) => {
    const trackId: number = request.data.trackId;
    if (!trackId) {
      throw new HttpsError('invalid-argument', 'trackId is required');
    }

    // 24時間インターバルチェック
    const summaryRef = db.collection('appReviewSummaries').doc(String(trackId));
    const existing = await summaryRef.get();
    if (existing.exists) {
      const generatedAt: admin.firestore.Timestamp = existing.data()!.generatedAt;
      const diffHours = (Date.now() - generatedAt.toMillis()) / 3_600_000;
      if (diffHours < CACHE_HOURS) {
        throw new HttpsError('already-exists', 'Summary generated within 24 hours');
      }
    }

    // レビューを最大200件取得
    const itemsSnap = await db
      .collection('appReviews')
      .doc(String(trackId))
      .collection('items')
      .orderBy('reviewDate', 'desc')
      .limit(MAX_REVIEWS)
      .get();

    if (itemsSnap.empty) {
      throw new HttpsError('not-found', 'No reviews found');
    }

    const reviews = itemsSnap.docs.map((doc) => {
      const d = doc.data();
      return `[★${d.rating}] ${d.title}: ${d.body}`;
    });

    // Anthropic API で解析
    const client = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });

    const message = await client.messages.create({
      model: MODEL,
      max_tokens: 2048,
      system: SYSTEM_PROMPT,
      messages: [
        {
          role: 'user',
          content: `以下は競合アプリ（trackId: ${trackId}）の${reviews.length}件のApp Storeレビューです。競合インテリジェンスの観点で分析してください。\n\n${reviews.join('\n')}`,
        },
      ],
    });

    const content = message.content[0];
    if (content.type !== 'text') {
      throw new HttpsError('internal', 'Unexpected response type');
    }

    let parsed: Record<string, unknown>;
    try {
      parsed = JSON.parse(content.text);
    } catch {
      throw new HttpsError('internal', 'Failed to parse AI response');
    }

    await summaryRef.set({
      ...parsed,
      generatedAt: admin.firestore.FieldValue.serverTimestamp(),
      reviewCount: reviews.length,
    });

    return { success: true };
  }
);
