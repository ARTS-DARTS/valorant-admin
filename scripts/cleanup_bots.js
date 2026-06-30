/**
 * Ежедневный cron: удаление ботов и альт-аккаунтов.
 *
 * Защита: lineups_viewed >= 5 ИЛИ verified_not_fake = true → никогда не удалять.
 * Кандидат: lineups_viewed < 5 И не верифицирован И зарегистрирован 30+ дней назад.
 *
 * Countdown (deletion_day):
 *   0 → 1: пуш "через 3 дня"
 *   1 → 2: пуш "через 2 дня"
 *   2 → 3: пуш "через 1 день"
 *   3+   : удаление
 */

const admin = require('firebase-admin');

const SERVICE_ACCOUNT  = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
const OS_APP_ID        = process.env.ONESIGNAL_APP_ID;
const OS_REST_KEY      = process.env.ONESIGNAL_REST_KEY;

admin.initializeApp({ credential: admin.credential.cert(SERVICE_ACCOUNT) });
const db   = admin.firestore();
const auth = admin.auth();

// ── Отправка пуша конкретному пользователю ──────────────────────────────────
async function sendPush(uid, title, body) {
  try {
    const res = await fetch('https://api.onesignal.com/notifications', {
      method:  'POST',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Key ${OS_REST_KEY}` },
      body: JSON.stringify({
        app_id:          OS_APP_ID,
        headings:        { en: title, ru: title },
        contents:        { en: body,  ru: body  },
        data:            { type: 'account_deletion_warning' },
        include_aliases: { external_id: [uid] },
        target_channel:  'push',
        priority:        10,
      }),
    });
    return res.ok;
  } catch (e) {
    console.warn(`[push] ${uid}:`, e.message);
    return false;
  }
}

// ── Архивирование и удаление ────────────────────────────────────────────────
async function archiveAndDelete(uid, u) {
  // 1. Сохраняем в deleted_accounts
  await db.collection('deleted_accounts').doc(uid).set({
    name:               u.name             || '',
    user_email:         u.user_email       || '',
    has_push:           !!u.fcm_token,
    last_seen:          u.last_seen        || null,
    time_spent_seconds: u.time_spent_seconds || 0,
    lineups_viewed:     u.lineups_viewed   || 0,
    approved_lineups:   u.approved_lineups || 0,
    created_at:         u.created_at       || null,
    reason:             'Меньше 5 просмотров за 30+ дней (бот/альт)',
    deleted_at:         admin.firestore.FieldValue.serverTimestamp(),
  });

  // 2. Удаляем подколлекции
  for (const sub of ['notifications', 'subscriptions']) {
    const snap = await db.collection('users').doc(uid).collection(sub).get();
    if (!snap.empty) {
      const batch = db.batch();
      snap.docs.forEach(d => batch.delete(d.ref));
      await batch.commit();
    }
  }

  // 3. Удаляем документ пользователя
  await db.collection('users').doc(uid).delete();

  // 4. Удаляем Firebase Auth аккаунт
  await auth.deleteUser(uid);
}

// ── Основная логика ──────────────────────────────────────────────────────────
async function run() {
  const now       = new Date();
  const threshold = new Date(now.getTime() - 30 * 24 * 3600 * 1000); // 30 дней назад

  const snap = await db.collection('users')
    .where('created_at', '<', threshold)
    .get();

  const stats = { total: snap.size, cleared: 0, warned: 0, deleted: 0, errors: 0 };

  for (const doc of snap.docs) {
    const uid = doc.id;
    const u   = doc.data();

    const viewed          = u.lineups_viewed   || 0;
    const verified        = !!u.verified_not_fake;
    const approvedLineups = u.approved_lineups || 0;
    const deletionDay     = u.deletion_day     || 0;

    // Пользователи до 20.06.2026 — до начала трекинга lineups_viewed, считать верифицированными
    const TRACKING_START  = new Date('2026-06-20T00:00:00Z');
    const regDate         = u.created_at?.toDate?.() ?? null;
    const isPreTracking   = regDate !== null && regDate < TRACKING_START;

    // Защищённый пользователь — сбросить countdown если был
    if (viewed >= 5 || verified || approvedLineups > 0 || isPreTracking) {
      if (deletionDay > 0) {
        await doc.ref.update({ deletion_day: admin.firestore.FieldValue.delete() });
        stats.cleared++;
      }
      continue;
    }

    // Кандидат на удаление
    try {
      if (deletionDay === 0) {
        await doc.ref.update({ deletion_day: 1 });
        await sendPush(uid,
          '⚠️ Аккаунт под угрозой удаления',
          'Открой приложение и посмотри 5 лайнапов, чтобы сохранить аккаунт. Осталось 3 дня.'
        );
        stats.warned++;
      } else if (deletionDay === 1) {
        await doc.ref.update({ deletion_day: 2 });
        await sendPush(uid,
          '⚠️ Аккаунт будет удалён через 2 дня',
          'Посмотри 5 лайнапов — и аккаунт будет в безопасности.'
        );
        stats.warned++;
      } else if (deletionDay === 2) {
        await doc.ref.update({ deletion_day: 3 });
        await sendPush(uid,
          '🚨 Последний шанс! Аккаунт удаляется завтра',
          'Открой приложение и посмотри 5 лайнапов прямо сейчас.'
        );
        stats.warned++;
      } else {
        // deletion_day >= 3 → удаляем
        await archiveAndDelete(uid, u);
        stats.deleted++;
        console.log(`[deleted] ${uid} (${u.name || 'no name'}, viewed=${viewed})`);
      }
    } catch (e) {
      console.error(`[error] ${uid}:`, e.message);
      stats.errors++;
    }
  }

  const summary = `✅ Всего кандидатов: ${stats.total} | Предупреждено: ${stats.warned} | Удалено: ${stats.deleted} | Сброшено: ${stats.cleared} | Ошибок: ${stats.errors}`;
  console.log('\n' + summary);

  // Пишем результат в Firestore для отображения в браузере
  await db.collection('cron_logs').add({
    type:         'cleanup_bots',
    triggered_by: process.env.GITHUB_EVENT_NAME || 'schedule',
    run_at:       admin.firestore.FieldValue.serverTimestamp(),
    summary,
    stats: {
      total:   stats.total,
      warned:  stats.warned,
      deleted: stats.deleted,
      cleared: stats.cleared,
      errors:  stats.errors,
    },
    ok: stats.errors === 0,
  });
}

run().catch(e => { console.error(e); process.exit(1); });
