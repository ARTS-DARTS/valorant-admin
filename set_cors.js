// Настраивает CORS на Selectel S3 bucket для браузерных PUT-загрузок из admin_panel.html
// Запуск: node set_cors.js

const https  = require('https');
const crypto = require('crypto');

const SEL_ACCESS_KEY = '6eac43cff0e4498c864fc36fdcd27a64';
const SEL_SECRET_KEY = 'e2ffe93a51ba4c05abadc810d9c0edfc';
const SEL_BUCKET     = 'valorant-lineups-video';
const SEL_ENDPOINT   = 's3.ru-3.storage.selcloud.ru';
const SEL_REGION     = 'ru-3';
const SEL_HOST       = `${SEL_BUCKET}.${SEL_ENDPOINT}`;

function hmac(key, data) { return crypto.createHmac('sha256', key).update(data).digest(); }
function hexHash(buf)     { return crypto.createHash('sha256').update(buf).digest('hex'); }
function md5Base64(buf)   { return crypto.createHash('md5').update(buf).digest('base64'); }
function padZ(n)          { return String(n).padStart(2, '0'); }
function awsDate(d)       { return `${d.getUTCFullYear()}${padZ(d.getUTCMonth()+1)}${padZ(d.getUTCDate())}`; }
function awsDateTime(d)   { return `${awsDate(d)}T${padZ(d.getUTCHours())}${padZ(d.getUTCMinutes())}${padZ(d.getUTCSeconds())}Z`; }
function signingKey(ds) {
  let k = hmac('AWS4' + SEL_SECRET_KEY, ds);
  k = hmac(k, SEL_REGION); k = hmac(k, 's3'); k = hmac(k, 'aws4_request');
  return k;
}

function sign(method, uri, body, contentType = 'application/xml') {
  const now     = new Date();
  const ds      = awsDate(now), dt = awsDateTime(now);
  const hash    = hexHash(body);
  const md5     = md5Base64(body);

  const canonicalHeaders = `content-md5:${md5}\ncontent-type:${contentType}\nhost:${SEL_HOST}\nx-amz-content-sha256:${hash}\nx-amz-date:${dt}\n`;
  const signedHeaders    = 'content-md5;content-type;host;x-amz-content-sha256;x-amz-date';
  const canonRequest     = [method, uri, 'cors=', canonicalHeaders, signedHeaders, hash].join('\n');
  const credScope        = `${ds}/${SEL_REGION}/s3/aws4_request`;
  const strToSign        = ['AWS4-HMAC-SHA256', dt, credScope, hexHash(canonRequest)].join('\n');
  const signature        = hmac(signingKey(ds), strToSign).toString('hex');

  return {
    'Authorization':        `AWS4-HMAC-SHA256 Credential=${SEL_ACCESS_KEY}/${credScope}, SignedHeaders=${signedHeaders}, Signature=${signature}`,
    'Content-MD5':          md5,
    'Content-Type':         contentType,
    'Content-Length':       body.length,
    'x-amz-content-sha256': hash,
    'x-amz-date':           dt,
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
  // CORS policy — разрешаем PUT/GET/HEAD из любого origin (admin panel)
  const corsXml = Buffer.from('<CORSConfiguration xmlns="http://s3.amazonaws.com/doc/2006-03-01/"><CORSRule><AllowedOrigin>*</AllowedOrigin><AllowedMethod>GET</AllowedMethod><AllowedMethod>PUT</AllowedMethod><AllowedMethod>HEAD</AllowedMethod><AllowedHeader>*</AllowedHeader><MaxAgeSeconds>3000</MaxAgeSeconds></CORSRule></CORSConfiguration>', 'utf8');

  const headers = sign('PUT', '/', corsXml);

  console.log('Устанавливаем CORS на bucket…');
  const res = await httpReq({
    host:   SEL_HOST,
    path:   '/?cors',
    method: 'PUT',
    headers,
  }, corsXml);

  console.log(`HTTP ${res.status}`);
  if (res.body) console.log(res.body);

  if (res.status >= 200 && res.status < 300) {
    console.log('✅ CORS настроен — браузерные загрузки из admin_panel.html будут работать');
  } else {
    console.log('❌ Ошибка. Проверь credentials.');
  }
}

main().catch(e => { console.error('Ошибка:', e.message); process.exit(1); });
