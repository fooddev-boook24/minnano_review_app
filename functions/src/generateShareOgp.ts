import * as admin from 'firebase-admin';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import * as crypto from 'crypto';

if (!admin.apps.length) admin.initializeApp();

const db      = admin.firestore();
const storage = admin.storage();

const REGION = 'asia-northeast1';

// ─── Types ────────────────────────────────────────────────

type TemplateId = 'A' | 'B' | 'C';

interface AppInfo {
  trackName:    string;
  developerName: string;
  primaryGenreName: string;
  averageUserRating?: number;
  artworkUrl100?: string;
}

// ─── Template colors ──────────────────────────────────────

const TEMPLATES: Record<TemplateId, { bg: string; text: string; sub: string; star: string }> = {
  A: { bg: '#FFFFFF', text: '#16121D', sub: '#8C7F99', star: '#FF9500' },
  B: { bg: 'gradient', text: '#FFFFFF', sub: 'rgba(255,255,255,0.75)', star: '#FFFFFF' },
  C: { bg: '#16121D', text: '#FFFFFF', sub: 'rgba(255,255,255,0.60)', star: '#FFAC33' },
};

// ─── Function ────────────────────────────────────────────

export const generateShareOgp = onCall(
  { region: REGION, timeoutSeconds: 60, memory: '512MiB' },
  async (request) => {
    const { trackId, template, message } = request.data as {
      trackId:  number;
      template: string;
      message:  string;
      deviceId: string;
    };

    // ── Validation ──────────────────────────────────────
    if (!trackId || typeof trackId !== 'number') {
      throw new HttpsError('invalid-argument', 'trackId is required');
    }
    if (!['A', 'B', 'C'].includes(template)) {
      throw new HttpsError('invalid-argument', 'template must be A, B, or C');
    }
    if (typeof message !== 'string' || message.length > 80) {
      throw new HttpsError('invalid-argument', 'message must be 80 chars or less');
    }

    const templateId = template as TemplateId;

    // ── Cache key ────────────────────────────────────────
    const cacheHash = crypto
      .createHash('md5')
      .update(template + message)
      .digest('hex');
    const filePath = `share-ogp/${trackId}/${cacheHash}.png`;
    const bucket   = storage.bucket();
    const file     = bucket.file(filePath);

    // Check if cached file exists
    const [exists] = await file.exists();
    if (exists) {
      const [url] = await file.getSignedUrl({
        action: 'read',
        expires: Date.now() + 24 * 60 * 60 * 1000, // 24h
      });
      return { url };
    }

    // ── Fetch app info ───────────────────────────────────
    let appInfo: AppInfo | null = null;

    // Try timelines collectionGroup first
    const appsSnap = await db
      .collectionGroup('apps')
      .where('trackId', '==', trackId)
      .limit(1)
      .get();

    if (!appsSnap.empty) {
      const d = appsSnap.docs[0].data();
      appInfo = {
        trackName:        d.trackName      ?? '',
        developerName:    d.developerName  ?? '',
        primaryGenreName: d.primaryGenreName ?? '',
        averageUserRating: d.averageUserRating,
        artworkUrl100:    d.artworkUrl100,
      };
    } else {
      throw new HttpsError('not-found', 'App not found');
    }

    // ── Generate SVG ──────────────────────────────────────
    const svgStr = _buildSvg(appInfo, templateId, message);
    const svgBuf = Buffer.from(svgStr, 'utf-8');

    // ── Convert SVG → PNG with sharp ──────────────────────
    const { default: sharp } = await import('sharp');
    const pngBuf = await sharp(svgBuf, { density: 144 })
      .resize(1200, 630)
      .png()
      .toBuffer();

    // ── Upload to Storage ─────────────────────────────────
    await file.save(pngBuf, {
      metadata: { contentType: 'image/png', cacheControl: 'public, max-age=86400' },
    });

    const [url] = await file.getSignedUrl({
      action: 'read',
      expires: Date.now() + 24 * 60 * 60 * 1000,
    });

    return { url };
  }
);

// ─── SVG builder ─────────────────────────────────────────

function _buildSvg(app: AppInfo, templateId: TemplateId, message: string): string {
  const t   = TEMPLATES[templateId];
  const W   = 1200;
  const H   = 630;
  const R   = 0; // no border-radius in top-level SVG

  const appName  = _esc(app.trackName);
  const devName  = _esc(app.developerName);
  const category = _esc(app.primaryGenreName);
  const msg      = _esc(message || 'App Storeで公開中');
  const rating   = app.averageUserRating ?? 0;
  const stars    = _buildStars(rating, t.star);

  // Background
  let bgDefs = '';
  let bgFill = '';
  if (templateId === 'B') {
    bgDefs = `
      <defs>
        <linearGradient id="grad" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0%" stop-color="#FFAC33"/>
          <stop offset="100%" stop-color="#FF7A00"/>
        </linearGradient>
      </defs>`;
    bgFill = 'url(#grad)';
  } else {
    bgFill = t.bg;
  }

  // Subtle highlight for white template
  const highlight = templateId === 'A'
    ? `<ellipse cx="1100" cy="60" rx="300" ry="200" fill="rgba(255,172,51,0.07)"/>`
    : '';

  // Badge color
  const badgeColor = templateId === 'B'
    ? 'rgba(255,255,255,0.25)'
    : templateId === 'C'
    ? 'rgba(255,149,0,0.25)'
    : 'none';
  const badgeGrad = templateId === 'A'
    ? `<defs><linearGradient id="badgeGrad" x1="0" y1="0" x2="1" y2="0"><stop offset="0%" stop-color="#FFAC33"/><stop offset="100%" stop-color="#FF7A00"/></linearGradient></defs>`
    : '';
  const badgeFill = templateId === 'A' ? 'url(#badgeGrad)' : badgeColor;
  const badgeText = templateId === 'C' ? '#FFAC33' : '#FFFFFF';

  return `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">
  ${bgDefs}
  ${badgeGrad}
  <rect width="${W}" height="${H}" fill="${bgFill}" rx="${R}"/>
  ${highlight}

  <!-- App icon placeholder (circle) -->
  <rect x="60" y="60" width="120" height="120" rx="28" fill="${templateId !== 'A' ? 'rgba(255,255,255,0.15)' : '#FFF3E0'}" />
  <text x="120" y="133" text-anchor="middle" font-size="56" font-family="sans-serif">📱</text>

  <!-- App name -->
  <text x="210" y="110" font-family="sans-serif" font-weight="700" font-size="36" fill="${t.text}">${_truncate(appName, 30)}</text>
  <!-- Dev + category -->
  <text x="210" y="148" font-family="sans-serif" font-size="24" fill="${t.sub}">${_truncate(devName, 36)} · ${_truncate(category, 20)}</text>
  <!-- Stars -->
  ${stars}
  <!-- Rating value -->
  <text x="${210 + rating * 28 + 8}" y="188" font-family="sans-serif" font-size="22" fill="${t.sub}">${rating > 0 ? rating.toFixed(1) : ''}</text>

  <!-- Divider -->
  <line x1="60" y1="230" x2="${W - 60}" y2="230" stroke="${t.sub}" stroke-width="1" stroke-opacity="0.2"/>

  <!-- Custom message (multiline) -->
  ${_multilineText(msg, 60, 290, W - 120, t.text, 38, 54)}

  <!-- Bottom: App Store label -->
  <text x="60" y="${H - 40}" font-family="sans-serif" font-weight="700" font-size="18" fill="${t.sub}" letter-spacing="3">APP STORE</text>

  <!-- Download badge -->
  <rect x="${W - 260}" y="${H - 80}" width="200" height="48" rx="24" fill="${badgeFill}"/>
  <text x="${W - 160}" y="${H - 48}" text-anchor="middle" font-family="sans-serif" font-weight="700" font-size="22" fill="${badgeText}">ダウンロード</text>
</svg>`;
}

function _buildStars(rating: number, color: string): string {
  const full    = Math.floor(rating);
  const partial = rating - full;
  let svg = '';
  for (let i = 0; i < 5; i++) {
    const x = 210 + i * 30;
    const y = 165;
    const isFull = i < full;
    const isPartial = i === full && partial > 0.3;
    svg += `<text x="${x}" y="${y}" font-size="22" fill="${isFull || isPartial ? color : 'rgba(128,128,128,0.3)'}" font-family="sans-serif">★</text>`;
  }
  return svg;
}

function _multilineText(
  text: string,
  x: number,
  y: number,
  maxWidth: number,
  fill: string,
  fontSize: number,
  lineHeight: number,
): string {
  // Simple word-wrap: split by newlines first, then each segment into chunks of ~20 chars per line
  const segments = text.split('\n').slice(0, 3);
  const charsPerLine = Math.floor(maxWidth / (fontSize * 0.6));
  let result = '';
  let lineY = y;
  for (const seg of segments) {
    const lines: string[] = [];
    let remaining = seg;
    while (remaining.length > 0) {
      lines.push(remaining.slice(0, charsPerLine));
      remaining = remaining.slice(charsPerLine);
      if (lines.length >= 2) break;
    }
    for (const line of lines) {
      result += `<text x="${x}" y="${lineY}" font-family="'Hiragino Sans', 'Noto Sans JP', sans-serif" font-weight="700" font-size="${fontSize}" fill="${fill}">${_esc(line)}</text>\n`;
      lineY += lineHeight;
    }
  }
  return result;
}

function _truncate(s: string, maxLen: number): string {
  return s.length > maxLen ? s.slice(0, maxLen - 1) + '…' : s;
}

function _esc(s: string): string {
  return s
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}
