// Заменяет S3 URL на CDN selstorage.ru во всех lineup-документах Firestore
// Запуск: node update_cdn_urls.js

const https  = require('https');
const crypto = require('crypto');
const fs     = require('fs');

const OLD_HOST = 'valorant-lineups-video.s3.ru-3.storage.selcloud.ru';
const NEW_HOST = 'd5adab93-7400-49ad-b1f9-66966c03d203.selstorage.ru';

const SA       = JSON.parse(fs.readFileSync('valorant-linemaps-firebase-adminsdk-fbsvc-74769a7b9c.json'));
const PROJECT  = SA.project_id;
const FS_BASE  = `firestore.googleapis.com`;
const FS_PATH  = `/v1/projects/${PROJECT}/databases/(default)/documents`;

// ── Google OAuth2 via JWT ───────────────────────────────────────────────────
function base64url(buf) {
  return Buffer.from(buf).toString('base64').replace(/\+/g,'-').replace(/\//g,'_').replace(/=/g,'');
}
function makeJwt() {
  const now = Math.floor(Date.now()/1000);
  const hdr  = base64url(JSON.stringify({alg:'RS256',typ:'JWT'}));
  const pay  = base64url(JSON.stringify({
    iss: SA.client_email, scope: 'https://www.googleapis.com/auth/datastore',
    aud: 'https://oauth2.googleapis.com/token', iat: now, exp: now+3600,
  }));
  const sign = crypto.createSign('RSA-SHA256').update(`${hdr}.${pay}`).sign(SA.private_key);
  return `${hdr}.${pay}.${base64url(sign)}`;
}
async function getToken() {
  const jwt  = makeJwt();
  const body = Buffer.from(`grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=${jwt}`);
  return new Promise((res, rej) => {
    const req = https.request({ host:'oauth2.googleapis.com', path:'/token', method:'POST',
      headers:{'Content-Type':'application/x-www-form-urlencoded','Content-Length':body.length}
    }, r => { let b=''; r.on('data',c=>b+=c); r.on('end',()=>res(JSON.parse(b).access_token)); });
    req.on('error', rej); req.write(body); req.end();
  });
}

// ── Firestore helpers ───────────────────────────────────────────────────────
function httpsReq(options, body=null) {
  return new Promise((res, rej) => {
    const req = https.request(options, r => {
      let b = ''; r.on('data',c=>b+=c); r.on('end',()=>res({status:r.statusCode,body:b}));
    });
    req.on('error', rej);
    if (body) req.write(body);
    req.end();
  });
}

async function listAll(token, collection) {
  const docs = [];
  let pageToken = '';
  while (true) {
    const qs  = `pageSize=300${pageToken ? '&pageToken='+pageToken : ''}`;
    const res = await httpsReq({ host: FS_BASE,
      path: `${FS_PATH}/${collection}?${qs}`,
      headers: { Authorization: `Bearer ${token}` }
    });
    const data = JSON.parse(res.body);
    if (data.documents) docs.push(...data.documents);
    if (!data.nextPageToken) break;
    pageToken = data.nextPageToken;
  }
  return docs;
}

async function patchVideoUrl(token, docName, newUrl) {
  const body = Buffer.from(JSON.stringify({
    fields: { video_url: { stringValue: newUrl } }
  }));
  const res = await httpsReq({
    host:   FS_BASE,
    path:   `/v1/${docName}?updateMask.fieldPaths=video_url`,
    method: 'PATCH',
    headers: {
      Authorization:  `Bearer ${token}`,
      'Content-Type': 'application/json',
      'Content-Length': body.length,
    },
  }, body);
  if (res.status < 200 || res.status >= 300) {
    throw new Error(`PATCH ${res.status}: ${res.body.slice(0,200)}`);
  }
}

// ── Main ────────────────────────────────────────────────────────────────────
async function main() {
  console.log('Получаем токен Google...');
  const token = await getToken();

  console.log('Загружаем lineup-документы...');
  const docs = await listAll(token, 'lineups');
  console.log(`Найдено ${docs.length} документов\n`);

  let updated = 0, skipped = 0, failed = 0;

  for (const doc of docs) {
    const videoUrl = doc.fields?.video_url?.stringValue;
    if (!videoUrl || !videoUrl.includes(OLD_HOST)) { skipped++; continue; }

    const newUrl = videoUrl.replace(OLD_HOST, NEW_HOST);
    const name   = doc.name.split('/').pop();
    process.stdout.write(`  ${name} … `);
    try {
      await patchVideoUrl(token, doc.name, newUrl);
      console.log('✅');
      updated++;
    } catch(e) {
      console.log(`❌ ${e.message}`);
      failed++;
    }
  }

  console.log(`\nГотово: ✅ обновлено ${updated} | ⏭ пропущено ${skipped} | ❌ ошибок ${failed}`);
}

main().catch(e => { console.error('Ошибка:', e.message); process.exit(1); });
