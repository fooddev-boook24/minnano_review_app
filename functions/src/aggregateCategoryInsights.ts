import * as admin from 'firebase-admin';
import { onSchedule } from 'firebase-functions/v2/scheduler';

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();

const REGION = 'asia-northeast1';

const TOPIC_KEYWORDS = {
  bug: ['バグ', 'クラッシュ', '落ちる', '固まる', 'エラー', '不具合', '動かない'],
  ux: ['使いにくい', 'デザイン', '操作', 'UI', '画面', 'レイアウト', 'わかりにくい'],
  feature: ['欲しい', '追加して', '機能', 'できない', 'できれば', 'あったら', '対応して'],
  price: ['高い', '値段', '課金', '料金', '無料', '有料'],
  positive: ['最高', '良い', 'おすすめ', '便利', 'ありがとう', '好き', '使いやすい'],
} as const;

type TopicKey = keyof typeof TOPIC_KEYWORDS;

interface ReviewDoc {
  body: string;
  title: string;
  rating: number;
}

export const aggregateCategoryInsights = onSchedule(
  {
    schedule: '0 18 * * *', // JST 03:00 = UTC 18:00
    timeZone: 'UTC',
    region: REGION,
  },
  async () => {
    // timelines からカテゴリ一覧を収集（読み取りのみ）
    const timelinesSnap = await db.collection('timelines').get();

    const categoryMap: Record<string, number[]> = {};
    for (const timelineDoc of timelinesSnap.docs) {
      const appsSnap = await timelineDoc.ref.collection('apps').get();
      for (const appDoc of appsSnap.docs) {
        const appData = appDoc.data();
        const genre: string = appData.primaryGenreName;
        const trackId: number = appData.trackId;
        if (!genre || !trackId) continue;
        if (!categoryMap[genre]) categoryMap[genre] = [];
        categoryMap[genre].push(trackId);
      }
    }

    for (const [categoryName, trackIds] of Object.entries(categoryMap)) {
      await _aggregateCategory(categoryName, trackIds);
    }
  }
);

async function _aggregateCategory(
  categoryName: string,
  trackIds: number[]
): Promise<void> {
  const complaints: Record<string, number> = {};
  const praise: Record<string, number> = {};
  const topicCounts: Record<TopicKey, number> = {
    bug: 0, ux: 0, feature: 0, price: 0, positive: 0,
  };
  const keywordFreq: Record<string, number> = {};
  let totalRating = 0;
  let reviewCount = 0;

  for (const trackId of trackIds.slice(0, 50)) {
    const itemsSnap = await db
      .collection('appReviews')
      .doc(String(trackId))
      .collection('items')
      .orderBy('reviewDate', 'desc')
      .limit(100)
      .get();

    for (const doc of itemsSnap.docs) {
      const review = doc.data() as ReviewDoc;
      const text = `${review.title} ${review.body}`;
      totalRating += review.rating;
      reviewCount++;

      for (const [topic, keywords] of Object.entries(TOPIC_KEYWORDS)) {
        if (keywords.some((kw) => text.includes(kw))) {
          topicCounts[topic as TopicKey]++;
        }
      }

      if (review.rating <= 2) {
        for (const kw of Object.values(TOPIC_KEYWORDS).flat()) {
          if (text.includes(kw)) {
            complaints[kw] = (complaints[kw] ?? 0) + 1;
          }
        }
      }

      if (review.rating >= 4) {
        for (const kw of TOPIC_KEYWORDS.positive) {
          if (text.includes(kw)) {
            praise[kw] = (praise[kw] ?? 0) + 1;
          }
        }
      }

      for (const kw of Object.values(TOPIC_KEYWORDS).flat()) {
        if (text.includes(kw)) {
          keywordFreq[kw] = (keywordFreq[kw] ?? 0) + 1;
        }
      }
    }
  }

  if (reviewCount === 0) return;

  const avgRating = totalRating / reviewCount;

  const topComplaints = Object.entries(complaints)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 5)
    .map(([label, count]) => ({
      label,
      count,
      pct: Math.round((count / reviewCount) * 1000) / 10,
      delta: null,
    }));

  const topPraise = Object.entries(praise)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 5)
    .map(([label, count]) => ({
      label,
      count,
      pct: Math.round((count / reviewCount) * 1000) / 10,
    }));

  const risingKeywords = Object.entries(keywordFreq)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 10)
    .map(([kw]) => kw);

  const bugRate     = reviewCount > 0 ? topicCounts.bug / reviewCount : 0;
  const uxRate      = reviewCount > 0 ? topicCounts.ux  / reviewCount : 0;
  const featureRate = reviewCount > 0 ? topicCounts.feature / reviewCount : 0;
  const priceRate   = reviewCount > 0 ? topicCounts.price / reviewCount : 0;
  const positiveRate= reviewCount > 0 ? topicCounts.positive / reviewCount : 0;

  const topComplaintKeyword = topComplaints[0]?.label ?? '';
  const topPraiseKeyword    = topPraise[0]?.label ?? '';

  let whitespaceHint: string;
  if (bugRate > 0.25) {
    whitespaceHint = `「${topComplaintKeyword}」など安定性への不満が目立ちます。クラッシュゼロ・高速起動を打ち出すことで既存ユーザーを取り込めます。`;
  } else if (uxRate > 0.2) {
    whitespaceHint = `操作性・画面設計への不満が多く（${Math.round(uxRate * 100)}%）、UI の分かりやすさで差別化できます。オンボーディングの改善が有効です。`;
  } else if (featureRate > 0.2) {
    whitespaceHint = `「${topComplaintKeyword}」など機能追加の要望が集中しています（${Math.round(featureRate * 100)}%）。競合が未対応の機能を先行実装することで優位に立てます。`;
  } else if (priceRate > 0.15) {
    whitespaceHint = `価格・課金への不満が${Math.round(priceRate * 100)}%あります。フリーミアム設計や低コストプランで新規ユーザーを獲得できます。`;
  } else if (positiveRate > 0.4) {
    whitespaceHint = `「${topPraiseKeyword}」への評価が高い成熟カテゴリです。ニッチなターゲット（職業・年代・用途）に絞った特化型アプリが参入機会になります。`;
  } else {
    whitespaceHint = `全体的に評価が安定しています。「${topComplaintKeyword}」などの不満点を解消しつつ、${topPraiseKeyword ? `「${topPraiseKeyword}」` : '高評価要因'}を踏襲することが参入の近道です。`;
  }

  await db.collection('categoryInsights').doc(categoryName).set({
    categoryName,
    avgRating,
    reviewCount,
    topComplaints,
    topPraise,
    risingKeywords,
    whitespaceHint,
    aggregatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}
