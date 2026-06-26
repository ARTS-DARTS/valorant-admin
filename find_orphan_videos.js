// Скрипт: найти видео в Bunny Storage без лайнапа и скачать их
// Запуск: node find_orphan_videos.js

const https = require('https');
const fs    = require('fs');
const path  = require('path');

const BUNNY_ZONE    = 'valorant-lineups1';
const BUNNY_HOST    = 'se.storage.bunnycdn.com';
const BUNNY_KEY     = 'fc600980-14fc-40e0-b320651320f6-1a31-4b61';
const BUNNY_CDN     = 'cdn.vlineups.tech';
const FIREBASE_ID   = 'valorant-linemaps';
const DOWNLOAD_DIR  = 'E:\\Монтаж\\Готовые ролики\\валорант лайнапы\\Miss video';

// ── Helpers ───────────────────────────────────────────────────────────────────

function httpsGet(host, path, headers = {}) {
  return new Promise((resolve, reject) => {
    const req = https.request({ host, path, method: 'GET', headers }, res => {
      const chunks = [];
      res.on('data', c => chunks.push(c));
      res.on('end', () => resolve({ status: res.statusCode, body: Buffer.concat(chunks) }));
    });
    req.on('error', reject);
    req.end();
  });
}

async function downloadFile(host, filePath, headers, destPath) {
  return new Promise((resolve, reject) => {
    const req = https.request({ host, path: filePath, method: 'GET', headers }, res => {
      if (res.statusCode !== 200) {
        reject(new Error(`HTTP ${res.statusCode}`));
        res.resume();
        return;
      }
      const out = fs.createWriteStream(destPath);
      res.pipe(out);
      out.on('finish', resolve);
      out.on('error', reject);
    });
    req.on('error', reject);
    req.end();
  });
}

// ── 1. Список файлов в Bunny Storage ─────────────────────────────────────────

async function listBunnyFiles() {
  console.log('Получаем список файлов из Bunny Storage…');
  const res = await httpsGet(BUNNY_HOST, `/${BUNNY_ZONE}/lineups_videos/`, {
    'AccessKey': BUNNY_KEY,
    'Accept': 'application/json',
  });
  if (res.status !== 200) throw new Error(`Bunny list HTTP ${res.status}: ${res.body.toString()}`);
  const files = JSON.parse(res.body.toString());
  return files.map(f => f.ObjectName); // имена файлов
}

// ── 2. Все video_url из Firestore ─────────────────────────────────────────────

async function getAllVideoUrls() {
  console.log('Получаем видео-ссылки из Firestore…');
  const urls = new Set();
  let pageToken = null;

  do {
    const qs = pageToken
      ? `?pageSize=300&pageToken=${encodeURIComponent(pageToken)}`
      : '?pageSize=300';
    const apiPath = `/v1/projects/${FIREBASE_ID}/databases/(default)/documents/lineups${qs}`;
    const res = await httpsGet('firestore.googleapis.com', apiPath);
    if (res.status !== 200) throw new Error(`Firestore HTTP ${res.status}`);

    const data = JSON.parse(res.body.toString());
    for (const doc of (data.documents || [])) {
      const url = doc.fields?.video_url?.stringValue;
      if (url) urls.add(url);
    }
    pageToken = data.nextPageToken || null;
  } while (pageToken);

  console.log(`Найдено ${urls.size} лайнапов с видео`);
  return urls;
}

// ── 3. Найти orphaned и скачать ───────────────────────────────────────────────

async function main() {
  fs.mkdirSync(DOWNLOAD_DIR, { recursive: true });

  const [bunnyFiles, videoUrls] = await Promise.all([listBunnyFiles(), getAllVideoUrls()]);
  console.log(`Файлов в Bunny Storage: ${bunnyFiles.length}`);

  // Извлекаем имена файлов из CDN-ссылок Firestore
  const usedNames = new Set();
  for (const url of videoUrls) {
    if (url.includes(BUNNY_CDN) || url.includes('bunnycdn.com')) {
      const name = url.split('/lineups_videos/')[1]?.split('?')[0];
      if (name) usedNames.add(decodeURIComponent(name));
    }
  }

  const orphans = bunnyFiles.filter(name => !usedNames.has(name));
  console.log(`\nОрфанных видео: ${orphans.length}`);

  if (orphans.length === 0) {
    console.log('Всё чисто!');
    return;
  }

  console.log('\nСписок:');
  orphans.forEach((n, i) => console.log(`  ${i + 1}. ${n}`));
  console.log(`\nСкачиваем в ${DOWNLOAD_DIR}…\n`);

  for (let i = 0; i < orphans.length; i++) {
    const name    = orphans[i];
    const destPath = path.join(DOWNLOAD_DIR, name);
    process.stdout.write(`[${i + 1}/${orphans.length}] ${name} … `);
    try {
      await downloadFile(
        BUNNY_HOST,
        `/${BUNNY_ZONE}/lineups_videos/${encodeURIComponent(name)}`,
        { 'AccessKey': BUNNY_KEY },
        destPath
      );
      console.log('✅');
    } catch (e) {
      console.log(`❌ ${e.message}`);
    }
  }

  console.log('\nУдаляем орфанные видео из Bunny Storage…\n');

  for (let i = 0; i < orphans.length; i++) {
    const name = orphans[i];
    process.stdout.write(`[${i + 1}/${orphans.length}] удаляю ${name} … `);
    try {
      await new Promise((resolve, reject) => {
        const req = https.request({
          host: BUNNY_HOST,
          path: `/${BUNNY_ZONE}/lineups_videos/${encodeURIComponent(name)}`,
          method: 'DELETE',
          headers: { 'AccessKey': BUNNY_KEY },
        }, res => { res.resume(); res.on('end', () => {
          res.statusCode < 300 ? resolve() : reject(new Error(`HTTP ${res.statusCode}`));
        }); });
        req.on('error', reject);
        req.end();
      });
      console.log('✅ удалено');
    } catch (e) {
      console.log(`❌ ${e.message}`);
    }
  }

  console.log('\nГотово!');
}

main().catch(e => { console.error('Ошибка:', e.message); process.exit(1); });
