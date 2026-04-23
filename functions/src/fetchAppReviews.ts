import * as admin from 'firebase-admin';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import axios from 'axios';

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();

const REGION = 'asia-northeast1';
const CACHE_HOURS = 24;
const MAX_PAGES = 10;

interface ItunesReviewEntry {
  id: { label: string };
  title: { label: string };
  content: { label: string };
  'im:rating': { label: string };
  author: { name: { label: string } };
  'im:version'?: { label: string };
  updated: { label: string };
}

export const fetchAppReviews = onCall(
  { region: REGION },
  async (request) => {
    const trackId: number = request.data.trackId;
    if (!trackId) {
      throw new HttpsError('invalid-argument', 'trackId is required');
    }

    // キャッシュチェック（24時間以内はスキップ）
    const metaRef = db.collection('appReviews').doc(String(trackId));
    const meta = await metaRef.get();
    if (meta.exists) {
      const lastFetched: admin.firestore.Timestamp = meta.data()!.lastFetchedAt;
      const diffHours = (Date.now() - lastFetched.toMillis()) / 3_600_000;
      if (diffHours < CACHE_HOURS) {
        return { skipped: true, reason: 'cache_valid' };
      }
    }

    const itemsRef = metaRef.collection('items');
    let totalCount = 0;

    for (let page = 1; page <= MAX_PAGES; page++) {
      const url =
        `https://itunes.apple.com/jp/rss/customerreviews/page=${page}/id=${trackId}/sortBy=mostRecent/json`;

      let entries: ItunesReviewEntry[];
      try {
        const res = await axios.get(url, { timeout: 10_000 });
        const feed = res.data?.feed;
        if (!feed?.entry) break;
        entries = Array.isArray(feed.entry) ? feed.entry : [feed.entry];
      } catch {
        break;
      }

      const batch = db.batch();
      for (const entry of entries) {
        const reviewId = entry.id.label;
        const rating = parseInt(entry['im:rating'].label, 10);
        const reviewDate = new Date(entry.updated.label);

        batch.set(itemsRef.doc(reviewId), {
          reviewId,
          trackId,
          rating,
          title: entry.title.label,
          body: entry.content.label,
          authorName: entry.author.name.label,
          country: 'jp',
          version: entry['im:version']?.label ?? null,
          reviewDate: admin.firestore.Timestamp.fromDate(reviewDate),
          fetchedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        totalCount++;
      }
      await batch.commit();

      if (entries.length < 50) break;
    }

    await metaRef.set(
      {
        lastFetchedAt: admin.firestore.FieldValue.serverTimestamp(),
        totalCount,
      },
      { merge: true }
    );

    return { success: true, totalCount };
  }
);
