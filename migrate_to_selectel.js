// Скрипт: мигрировать все видео из Bunny Storage → Selectel S3 и обновить Firestore
// Запуск: node migrate_to_selectel.js

const https   = require('https');
const crypto  = require('crypto');
const fs      = require('fs');
const path    = require('path');

// ── Service Account ───────────────────────────────────────────────────────────
const SA_PATH = path.join(__dirname, 'valorant-linemaps-firebase-adminsdk-fbsvc-74769a7b9c.json');

// ── Bunny ─────────────────────────────────────────────────────────────────────
const BUNNY_ZONE = 'valorant-lineups1';
const BUNNY_HOST = 'se.storage.bunnycdn.com';
const BUNNY_KEY  = 'fc600980-14fc-40e0-b320651320f6-1a31-4b61';
const BUNNY_CDN  = 'cdn.vlineups.tech';

// ── Selectel S3 ───────────────────────────────────────────────────────────────
const SEL_ACCESS_KEY = '6eac43cff0e4498c864fc36fdcd27a64';
const SEL_SECRET_KEY = 'e2ffe93a51ba4c05abadc810d9c0edfc';
const SEL_BUCKET     = 'valorant-lineups-video';
const SEL_ENDPOINT   = 's3.ru-3.storage.selcloud.ru';
const SEL_REGION     = 'ru-3';

// ── Firebase ──────────────────────────────────────────────────────────────────
const FIREBASE_ID    = 'valorant-linemaps';
const FIRESTORE_HOST = 'firestore.googleapis.com';

// ── AWS4 helpers ──────────────────────────────────────────────────────────────
function hmacSha256(key, data) {
  return crypto.createHmac('sha256', key).update(data).digest();
}
function sha256hex(buf) {
  return crypto.createHash('sha256').update(buf).digest('hex');
}
function padZ(n) { return String(n).padStart(2, '0'); }
function awsDate(d) {
  return `${d.getUTCFullYear()}${padZ(d.getUTCMonth()+1)}${padZ(d.getUTCDate())}`;
}
function awsDateTime(d) {
  return `${awsDate(d)}T${padZ(d.getUTCHours())}${padZ(d.getUTCMinutes())}${padZ(d.getUTCSeconds())}Z`;
}
function getSigningKey(dateStamp) {
  let k = hmacSha256('AWS4' + SEL_SECRET_KEY, dateStamp);
  k = hmacSha256(k, SEL_REGION);
  k = hmacSha256(k, 's3');
  k = hmacSha256(k, 'aws4_request');
  return k;
}

// ── HTTP helpers ──────────────────────────────────────────────────────────────
function httpRequest(options, body = null) {
  return new Promise((resolve, reject) => {
    const req = https.request(options, res => {
      const chunks = [];
      res.on('data', c => chunks.push(c));
      res.on('end', () => resolve({ status: res.statusCode, body: Buffer.concat(chunks) }));
    });
    req.on('error', reject);
    if (body) req.write(body);
    req.end();
  });
}

// ── Google OAuth2 токен через Service Account (JWT RS256) ─────────────────────
let _cachedToken = null;
let _tokenExpiry = 0;

async function getAccessToken() {
  if (_cachedToken && Date.now() < _tokenExpiry) return _cachedToken;

  const sa = JSON.parse(fs.readFileSync(SA_PATH, 'utf8'));
  const now = Math.floor(Date.now() / 1000);

  const header  = Buffer.from(JSON.stringify({ alg: 'RS256', typ: 'JWT' })).toString('base64url');
  const payload = Buffer.from(JSON.stringify({
    iss: sa.client_email,
    scope: 'https://www.googleapis.com/auth/datastore',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  })).toString('base64url');

  const toSign    = `${header}.${payload}`;
  const signature = crypto.createSign('RSA-SHA256').update(toSign).sign(sa.private_key, 'base64url');
  const jwt       = `${toSign}.${signature}`;

  const body = Buffer.from(
    `grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=${jwt}`
  );

  const res = await httpRequest({
    host: 'oauth2.googleapis.com',
    path: '/token',
    method: 'POST',
    headers: {
      'Content-Type':   'application/x-www-form-urlencoded',
      'Content-Length': body.length,
    },
  }, body);

  if (res.status !== 200) {
    throw new Error(`OAuth2 HTTP ${res.status}: ${res.body.toString().slice(0, 300)}`);
  }

  const data = JSON.parse(res.body.toString());
  _cachedToken = data.access_token;
  _tokenExpiry = Date.now() + (data.expires_in - 60) * 1000;
  return _cachedToken;
}

// ── Скачать файл из Bunny Storage ─────────────────────────────────────────────
// filename должен быть уже процент-закодирован (как в URL)
async function downloadFromBunny(encodedFilename) {
  const res = await httpRequest({
    host: BUNNY_HOST,
    path: `/${BUNNY_ZONE}/lineups_videos/${encodedFilename}`,
    method: 'GET',
    headers: { 'AccessKey': BUNNY_KEY },
  });
  if (res.status !== 200) {
    throw new Error(`Bunny HTTP ${res.status}: ${res.body.toString().slice(0, 200)}`);
  }
  return res.body;
}

// ── Загрузить на Selectel S3 ──────────────────────────────────────────────────
// encodedFilename — процент-закодированное имя (безопасно для HTTP пути)
async function uploadToSelectel(buffer, encodedFilename, contentType = 'video/mp4') {
  const filename  = encodedFilename; // уже закодирован, используем как есть в пути
  const objectKey = `lineups_videos/${encodedFilename}`;
  const host        = `${SEL_BUCKET}.${SEL_ENDPOINT}`;
  const now         = new Date();
  const dateStamp   = awsDate(now);
  const amzDate     = awsDateTime(now);
  const payloadHash = sha256hex(buffer);

  const signedHeaders    = 'content-type;host;x-amz-content-sha256;x-amz-date';
  const canonicalHeaders = `content-type:${contentType}\nhost:${host}\nx-amz-content-sha256:${payloadHash}\nx-amz-date:${amzDate}\n`;
  const canonicalRequest = ['PUT', `/${objectKey}`, '', canonicalHeaders, signedHeaders, payloadHash].join('\n');

  const credScope = `${dateStamp}/${SEL_REGION}/s3/aws4_request`;
  const strToSign = ['AWS4-HMAC-SHA256', amzDate, credScope, sha256hex(canonicalRequest)].join('\n');
  const signature = hmacSha256(getSigningKey(dateStamp), strToSign).toString('hex');
  const auth      = `AWS4-HMAC-SHA256 Credential=${SEL_ACCESS_KEY}/${credScope}, SignedHeaders=${signedHeaders}, Signature=${signature}`;

  const res = await httpRequest({
    host,
    path: `/${objectKey}`,
    method: 'PUT',
    headers: {
      'Authorization':        auth,
      'Content-Type':         contentType,
      'Content-Length':       buffer.length,
      'x-amz-content-sha256': payloadHash,
      'x-amz-date':           amzDate,
    },
  }, buffer);

  if (res.status < 200 || res.status >= 300) {
    throw new Error(`Selectel HTTP ${res.status}: ${res.body.toString().slice(0, 300)}`);
  }
  return `https://${host}/${objectKey}`;
}

// ── Получить все лайнапы с Bunny-ссылками из Firestore ────────────────────────
async function getAllLineups() {
  const docs = [];
  let pageToken = null;

  do {
    const qs = pageToken
      ? `?pageSize=300&pageToken=${encodeURIComponent(pageToken)}`
      : '?pageSize=300';
    const apiPath = `/v1/projects/${FIREBASE_ID}/databases/(default)/documents/lineups${qs}`;
    const res = await httpRequest({ host: FIRESTORE_HOST, path: apiPath, method: 'GET' });
    if (res.status !== 200) throw new Error(`Firestore list HTTP ${res.status}`);

    const data = JSON.parse(res.body.toString());
    for (const doc of (data.documents || [])) {
      const url = doc.fields?.video_url?.stringValue;
      if (url && (url.includes(BUNNY_CDN) || url.includes('bunnycdn.com'))) {
        const parts = doc.name.split('/');
        docs.push({ id: parts[parts.length - 1], url });
      }
    }
    pageToken = data.nextPageToken || null;
  } while (pageToken);

  return docs;
}

// ── Обновить video_url в Firestore ────────────────────────────────────────────
async function updateFirestoreUrl(docId, newUrl) {
  const token   = await getAccessToken();
  const apiPath = `/v1/projects/${FIREBASE_ID}/databases/(default)/documents/lineups/${docId}?updateMask.fieldPaths=video_url`;
  const body    = Buffer.from(JSON.stringify({
    fields: { video_url: { stringValue: newUrl } }
  }));

  const res = await httpRequest({
    host: FIRESTORE_HOST,
    path: apiPath,
    method: 'PATCH',
    headers: {
      'Authorization':  `Bearer ${token}`,
      'Content-Type':   'application/json',
      'Content-Length': body.length,
    },
  }, body);

  if (res.status < 200 || res.status >= 300) {
    throw new Error(`Firestore PATCH HTTP ${res.status}: ${res.body.toString().slice(0, 200)}`);
  }
}

// ── Главная функция ───────────────────────────────────────────────────────────
async function main() {
  if (!fs.existsSync(SA_PATH)) {
    console.error(`Файл не найден: ${SA_PATH}`);
    process.exit(1);
  }

  console.log('Получаем список лайнапов с Bunny-ссылками…');
  const lineups = await getAllLineups();
  console.log(`Найдено ${lineups.length} лайнапов для миграции\n`);

  if (lineups.length === 0) {
    console.log('Нечего мигрировать — все уже на Selectel!');
    return;
  }

  const results = { success: 0, failed: 0, errors: [] };
  const logFile = `migrate_log_${Date.now()}.txt`;
  const log = (msg) => { console.log(msg); fs.appendFileSync(logFile, msg + '\n'); };

  for (let i = 0; i < lineups.length; i++) {
    const { id, url } = lineups[i];
    const filename = url.split('/lineups_videos/')[1]?.split('?')[0];
    const label    = `[${i + 1}/${lineups.length}] ${filename || id}`;

    if (!filename) {
      log(`${label} — ❌ не удалось определить имя файла`);
      results.failed++;
      results.errors.push(`${id}: неизвестное имя файла`);
      continue;
    }

    process.stdout.write(`${label} … `);
    let lastErr = null;
    for (let attempt = 1; attempt <= 3; attempt++) {
      try {
        const buffer = await downloadFromBunny(filename);
        const newUrl = await uploadToSelectel(buffer, filename);
        await updateFirestoreUrl(id, newUrl);
        log(`✅ ${newUrl}`);
        results.success++;
        lastErr = null;
        break;
      } catch (e) {
        lastErr = e;
        if (attempt < 3) {
          process.stdout.write(`(retry ${attempt}) `);
          await new Promise(r => setTimeout(r, 2000 * attempt));
        }
      }
    }
    if (lastErr) {
      log(`❌ ${lastErr.message}`);
      results.failed++;
      results.errors.push(`${id} (${filename}): ${lastErr.message}`);
    }
  }

  console.log('\n══════════════════════════════════════════');
  console.log(`Итого: ${lineups.length} | ✅ ${results.success} | ❌ ${results.failed}`);
  if (results.errors.length) {
    console.log('\nОшибки:');
    results.errors.forEach(e => console.log('  •', e));
  }
  console.log(`Лог сохранён в: ${logFile}`);
}

main().catch(e => { console.error('Ошибка:', e.message); process.exit(1); });
