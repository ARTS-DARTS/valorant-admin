import { existsSync, writeFileSync, readFileSync } from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';

const root = process.cwd();
const keyPath = process.env.GOOGLE_APPLICATION_CREDENTIALS
  || path.join(root, 'valorant-linemaps-firebase-adminsdk-fbsvc-74769a7b9c.json');
const outPath = process.env.AD_STATS_PUBLIC_OUT
  || path.join(root, 'ad_stats_daily_public.json');
const maxDays = Number(process.env.AD_STATS_PUBLIC_MAX_DAYS || 370);

if (!existsSync(keyPath)) {
  throw new Error(`Service account key not found. Set GOOGLE_APPLICATION_CREDENTIALS or place key at ${keyPath}`);
}

const serviceAccount = JSON.parse(readFileSync(keyPath, 'utf8'));
const projectId = serviceAccount.project_id || 'valorant-linemaps';

function base64url(value) {
  return Buffer.from(value)
    .toString('base64')
    .replace(/=/g, '')
    .replace(/\+/g, '-')
    .replace(/\//g, '_');
}

function signJwt() {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: 'RS256', typ: 'JWT' };
  const claim = {
    iss: serviceAccount.client_email,
    scope: 'https://www.googleapis.com/auth/datastore',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  };
  const input = `${base64url(JSON.stringify(header))}.${base64url(JSON.stringify(claim))}`;
  const signature = crypto.sign('RSA-SHA256', Buffer.from(input), serviceAccount.private_key);
  return `${input}.${base64url(signature)}`;
}

async function getAccessToken() {
  const body = new URLSearchParams({
    grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
    assertion: signJwt(),
  });
  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body,
  });
  if (!res.ok) throw new Error(`OAuth failed ${res.status}: ${await res.text()}`);
  const json = await res.json();
  return json.access_token;
}

function fieldNumber(fields, key) {
  const value = fields?.[key];
  if (!value) return 0;
  const raw = value.integerValue ?? value.doubleValue ?? 0;
  const n = Number(raw);
  return Number.isFinite(n) && n > 0 ? Math.round(n) : 0;
}

function docId(name) {
  return String(name || '').split('/').pop();
}

async function listAdStats(accessToken) {
  const docs = [];
  let pageToken = '';
  do {
    const url = new URL(`https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/ad_stats_daily`);
    url.searchParams.set('pageSize', '300');
    if (pageToken) url.searchParams.set('pageToken', pageToken);
    const res = await fetch(url, {
      headers: { Authorization: `Bearer ${accessToken}` },
    });
    if (!res.ok) throw new Error(`Firestore list failed ${res.status}: ${await res.text()}`);
    const json = await res.json();
    docs.push(...(json.documents || []));
    pageToken = json.nextPageToken || '';
  } while (pageToken);
  return docs;
}

function localDayKey(date = new Date()) {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, '0');
  const d = String(date.getDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

const token = await getAccessToken();
const today = localDayKey();
const docs = await listAdStats(token);
const rows = docs
  .map(doc => [docId(doc.name), doc.fields || {}])
  .filter(([day]) => /^\d{4}-\d{2}-\d{2}$/.test(day) && day < today)
  .sort(([a], [b]) => a.localeCompare(b))
  .slice(-maxDays);

const days = {};
for (const [day, fields] of rows) {
  days[day] = {
    banner_shown: fieldNumber(fields, 'banner_shown'),
    interstitial_shown: fieldNumber(fields, 'interstitial_shown'),
    rewarded_shown: fieldNumber(fields, 'rewarded_shown'),
    rewarded_completed: fieldNumber(fields, 'rewarded_completed'),
    rewarded_skipped: fieldNumber(fields, 'rewarded_skipped'),
    app_open_shown: fieldNumber(fields, 'app_open_shown'),
    other: fieldNumber(fields, 'other'),
    total_shown: fieldNumber(fields, 'total_shown'),
    total_events: fieldNumber(fields, 'total_events'),
  };
}

const output = {
  schema: 1,
  generated_at: new Date().toISOString(),
  safe_public_data: true,
  description: 'Sanitized daily ad aggregates only. No uid, no user data, no raw events.',
  days,
};

writeFileSync(outPath, `${JSON.stringify(output, null, 2)}\n`, 'utf8');
console.log(`Exported ${Object.keys(days).length} public ad stat days to ${outPath}`);
