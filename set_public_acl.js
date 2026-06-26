// Делает все объекты в lineups_videos/ публичными (x-amz-acl: public-read)
// Запуск: node set_public_acl.js

const https  = require('https');
const crypto = require('crypto');

const SEL_ACCESS_KEY = '593e98c47f3f44ba8c19ab31aa65fbfc';
const SEL_SECRET_KEY = '72b0e462bc594ccd95c500d4b4a99605';
const SEL_BUCKET     = 'valorant-lineups-video';
const SEL_ENDPOINT   = 's3.ru-3.storage.selcloud.ru';
const SEL_REGION     = 'ru-3';
const SEL_HOST       = `${SEL_BUCKET}.${SEL_ENDPOINT}`;

function hmac(key, data) { return crypto.createHmac('sha256', key).update(data).digest(); }
function hexHash(buf)     { return crypto.createHash('sha256').update(buf).digest('hex'); }
function padZ(n)          { return String(n).padStart(2, '0'); }
function awsDate(d)       { return `${d.getUTCFullYear()}${padZ(d.getUTCMonth()+1)}${padZ(d.getUTCDate())}`; }
function awsDateTime(d)   { return `${awsDate(d)}T${padZ(d.getUTCHours())}${padZ(d.getUTCMinutes())}${padZ(d.getUTCSeconds())}Z`; }
function signingKey(ds)   {
  let k = hmac('AWS4' + SEL_SECRET_KEY, ds);
  k = hmac(k, SEL_REGION); k = hmac(k, 's3'); k = hmac(k, 'aws4_request');
  return k;
}

// uri — путь без query string, queryParams — объект { key: value }
function sign({ method, uri, queryParams = {}, payloadHash, extraHeaders = {} }) {
  const now = new Date();
  const ds  = awsDate(now), dt = awsDateTime(now);

  // Canonical query string — ключи отсортированы
  const canonicalQS = Object.keys(queryParams).sort()
    .map(k => `${encodeURIComponent(k)}=${encodeURIComponent(queryParams[k])}`)
    .join('&');

  // Собираем все заголовки для подписи (уже включаем host, x-amz-*)
  const allHeaders = {
    'host':                SEL_HOST,
    'x-amz-content-sha256': payloadHash,
    'x-amz-date':          dt,
    ...extraHeaders,
  };

  // Сортируем заголовки по ключу
  const sortedKeys    = Object.keys(allHeaders).sort();
  const signedHeaders = sortedKeys.join(';');
  const canonicalHeaders = sortedKeys.map(k => `${k}:${allHeaders[k]}\n`).join('');

  const canonicalRequest = [method, uri, canonicalQS, canonicalHeaders, signedHeaders, payloadHash].join('\n');

  const credScope = `${ds}/${SEL_REGION}/s3/aws4_request`;
  const strToSign = ['AWS4-HMAC-SHA256', dt, credScope, hexHash(canonicalRequest)].join('\n');
  const signature = hmac(signingKey(ds), strToSign).toString('hex');
  const auth      = `AWS4-HMAC-SHA256 Credential=${SEL_ACCESS_KEY}/${credScope}, SignedHeaders=${signedHeaders}, Signature=${signature}`;

  return { 'Authorization': auth, ...allHeaders };
}

function httpReq(options, body = null) {
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

async function listObjects() {
  const emptyHash = hexHash(Buffer.alloc(0));
  const queryParams = { 'list-type': '2', 'prefix': 'lineups_videos/', 'max-keys': '1000' };
  const headers = sign({ method: 'GET', uri: '/', queryParams, payloadHash: emptyHash });

  const qs   = Object.keys(queryParams).sort().map(k => `${encodeURIComponent(k)}=${encodeURIComponent(queryParams[k])}`).join('&');
  const path = `/?${qs}`;
  const res  = await httpReq({ host: SEL_HOST, path, method: 'GET', headers });
  if (res.status !== 200) throw new Error(`List HTTP ${res.status}: ${res.body.toString().slice(0, 400)}`);

  const xml  = res.body.toString();
  const keys = [...xml.matchAll(/<Key>([^<]+)<\/Key>/g)].map(m => m[1]);
  return keys;
}

async function setPublicAcl(key) {
  const emptyHash = hexHash(Buffer.alloc(0));
  const headers   = sign({
    method:       'PUT',
    uri:          `/${key}`,
    queryParams:  { acl: '' },
    payloadHash:  emptyHash,
    extraHeaders: { 'x-amz-acl': 'public-read' },
  });
  headers['Content-Length'] = '0';

  const path = `/${key}?acl`;
  const res  = await httpReq({ host: SEL_HOST, path, method: 'PUT', headers }, Buffer.alloc(0));
  if (res.status < 200 || res.status >= 300) {
    throw new Error(`ACL HTTP ${res.status}: ${res.body.toString().slice(0, 200)}`);
  }
}

async function main() {
  console.log('Получаем список объектов…');
  const keys = await listObjects();
  console.log(`Найдено ${keys.length} объектов\n`);

  let ok = 0, fail = 0;
  for (let i = 0; i < keys.length; i++) {
    const key = keys[i];
    process.stdout.write(`[${i+1}/${keys.length}] ${key.split('/').pop()} … `);
    try {
      await setPublicAcl(key);
      console.log('✅');
      ok++;
    } catch (e) {
      console.log(`❌ ${e.message}`);
      fail++;
    }
  }
  console.log(`\nГотово: ✅ ${ok} | ❌ ${fail}`);
}

main().catch(e => { console.error('Ошибка:', e.message); process.exit(1); });
