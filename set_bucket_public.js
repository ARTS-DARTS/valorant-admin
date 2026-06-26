// Устанавливает публичную политику на весь bucket Selectel
// Запуск: node set_bucket_public.js

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
function signingKey(ds) {
  let k = hmac('AWS4' + SEL_SECRET_KEY, ds);
  k = hmac(k, SEL_REGION); k = hmac(k, 's3'); k = hmac(k, 'aws4_request');
  return k;
}

function sign({ method, uri, queryParams = {}, body }) {
  const now = new Date();
  const ds  = awsDate(now), dt = awsDateTime(now);
  const payloadHash = hexHash(body);

  const canonicalQS = Object.keys(queryParams).sort()
    .map(k => `${encodeURIComponent(k)}=${encodeURIComponent(queryParams[k])}`)
    .join('&');

  const canonicalHeaders =
    `host:${SEL_HOST}\nx-amz-content-sha256:${payloadHash}\nx-amz-date:${dt}\n`;
  const signedHeaders = 'host;x-amz-content-sha256;x-amz-date';

  const canonicalRequest = [method, uri, canonicalQS, canonicalHeaders, signedHeaders, payloadHash].join('\n');
  const credScope  = `${ds}/${SEL_REGION}/s3/aws4_request`;
  const strToSign  = ['AWS4-HMAC-SHA256', dt, credScope, hexHash(canonicalRequest)].join('\n');
  const signature  = hmac(signingKey(ds), strToSign).toString('hex');
  const auth       = `AWS4-HMAC-SHA256 Credential=${SEL_ACCESS_KEY}/${credScope}, SignedHeaders=${signedHeaders}, Signature=${signature}`;

  return {
    'Authorization':        auth,
    'x-amz-content-sha256': payloadHash,
    'x-amz-date':           dt,
    'Content-Type':         'application/json',
    'Content-Length':       body.length,
  };
}

function httpReq(options, body) {
  return new Promise((resolve, reject) => {
    const req = https.request(options, res => {
      const chunks = [];
      res.on('data', c => chunks.push(c));
      res.on('end', () => resolve({ status: res.statusCode, body: Buffer.concat(chunks).toString() }));
    });
    req.on('error', reject);
    if (body) req.write(body);
    req.end();
  });
}

async function main() {
  const policy = JSON.stringify({
    Version: '2012-10-17',
    Statement: [{
      Sid:       'PublicReadGetObject',
      Effect:    'Allow',
      Principal: '*',
      Action:    's3:GetObject',
      Resource:  `arn:aws:s3:::${SEL_BUCKET}/*`,
    }],
  });

  const body    = Buffer.from(policy);
  const headers = sign({ method: 'PUT', uri: '/', queryParams: { policy: '' }, body });

  console.log('Устанавливаем публичную политику bucket…');
  const res = await httpReq({
    host:   SEL_HOST,
    path:   '/?policy',
    method: 'PUT',
    headers,
  }, body);

  console.log(`HTTP ${res.status}`);
  if (res.body) console.log(res.body);

  if (res.status >= 200 && res.status < 300) {
    console.log('✅ Bucket теперь публичный — все видео доступны без авторизации');
  } else {
    console.log('❌ Не удалось. Попробуй сделать контейнер публичным вручную в панели Selectel.');
  }
}

main().catch(e => { console.error('Ошибка:', e.message); process.exit(1); });
