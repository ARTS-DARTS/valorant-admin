// Читает range_config из Firestore и применяет range_radius к lineup-документам
// Запуск: node apply_range_config.js

const https = require('https');
const crypto = require('crypto');
const fs = require('fs');

const SA      = JSON.parse(fs.readFileSync('valorant-linemaps-firebase-adminsdk-fbsvc-74769a7b9c.json'));
const PROJECT = SA.project_id;
const FS_HOST = 'firestore.googleapis.com';
const FS_PATH = `/v1/projects/${PROJECT}/databases/(default)/documents`;

function base64url(b) {
  return Buffer.from(b).toString('base64').replace(/\+/g,'-').replace(/\//g,'_').replace(/=/g,'');
}
function makeJwt() {
  const now = Math.floor(Date.now()/1000);
  const h = base64url(JSON.stringify({alg:'RS256',typ:'JWT'}));
  const p = base64url(JSON.stringify({iss:SA.client_email,scope:'https://www.googleapis.com/auth/datastore',aud:'https://oauth2.googleapis.com/token',iat:now,exp:now+3600}));
  const s = crypto.createSign('RSA-SHA256').update(`${h}.${p}`).sign(SA.private_key);
  return `${h}.${p}.${base64url(s)}`;
}
async function getToken() {
  const body = Buffer.from(`grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=${makeJwt()}`);
  return new Promise((res,rej) => {
    const req = https.request({host:'oauth2.googleapis.com',path:'/token',method:'POST',
      headers:{'Content-Type':'application/x-www-form-urlencoded','Content-Length':body.length}
    }, r => { let b=''; r.on('data',c=>b+=c); r.on('end',()=>res(JSON.parse(b).access_token)); });
    req.on('error',rej); req.write(body); req.end();
  });
}

function httpsReq(options, body=null) {
  return new Promise((res,rej) => {
    const req = https.request(options, r => {
      let b=''; r.on('data',c=>b+=c); r.on('end',()=>res({status:r.statusCode,body:b}));
    });
    req.on('error',rej);
    if (body) req.write(body);
    req.end();
  });
}

async function listAll(token, collection) {
  const docs = [];
  let pageToken = '';
  while (true) {
    const qs  = `pageSize=300${pageToken ? '&pageToken='+pageToken : ''}`;
    const r   = await httpsReq({host:FS_HOST, path:`${FS_PATH}/${collection}?${qs}`, headers:{Authorization:`Bearer ${token}`}});
    const data = JSON.parse(r.body);
    if (data.documents) docs.push(...data.documents);
    if (!data.nextPageToken) break;
    pageToken = data.nextPageToken;
  }
  return docs;
}

async function patchRangeRadius(token, docName, radius) {
  const body = Buffer.from(JSON.stringify({fields:{range_radius:{doubleValue:radius}}}));
  const r = await httpsReq({
    host:FS_HOST, path:`/v1/${docName}?updateMask.fieldPaths=range_radius`,
    method:'PATCH',
    headers:{Authorization:`Bearer ${token}`,'Content-Type':'application/json','Content-Length':body.length},
  }, body);
  if (r.status < 200 || r.status >= 300) throw new Error(`PATCH ${r.status}: ${r.body.slice(0,100)}`);
}

async function main() {
  console.log('Получаем токен...');
  const token = await getToken();

  console.log('Читаем range_config...');
  const cfgDocs = await listAll(token, 'range_config');
  if (cfgDocs.length === 0) { console.log('range_config пуст — нечего применять'); return; }

  // Строим карту: "map__agent__ability" → radius
  const cfgMap = {};
  for (const doc of cfgDocs) {
    const f = doc.fields || {};
    const map     = f.map?.stringValue;
    const agent   = f.agent?.stringValue;
    const ability = f.ability?.stringValue;
    const radius  = (f.range_radius?.doubleValue ?? f.range_radius?.integerValue) ?? null;
    if (map && agent && ability && radius != null) {
      cfgMap[`${map}__${agent}__${ability}`] = parseFloat(radius);
    }
  }
  console.log(`Настроек range_config: ${Object.keys(cfgMap).length}`);
  Object.entries(cfgMap).forEach(([k,v]) => console.log(`  ${k} → ${v}`));

  console.log('\nЧитаем lineup-документы...');
  const lineups = await listAll(token, 'lineups');
  console.log(`Всего лайнапов: ${lineups.length}`);

  let updated = 0, skipped = 0, failed = 0;

  for (const doc of lineups) {
    const f       = doc.fields || {};
    const map     = f.map?.stringValue;
    const agent   = f.agent?.stringValue;
    const ability = f.ability?.stringValue;
    const curR    = (f.range_radius?.doubleValue ?? f.range_radius?.integerValue) ?? null;
    const key     = `${map}__${agent}__${ability}`;
    const newR    = cfgMap[key];

    if (newR == null) { skipped++; continue; }
    if (curR != null && Math.abs(parseFloat(curR) - newR) < 0.0001) { skipped++; continue; }

    const name = doc.name.split('/').pop();
    process.stdout.write(`  ${name} (${map}/${agent}) ${curR ?? 'null'} → ${newR} … `);
    try {
      await patchRangeRadius(token, doc.name, newR);
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
