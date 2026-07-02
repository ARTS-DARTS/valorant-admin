/**
 * Ежедневный cron: удаление ботов и альт-аккаунтов.
 *
 * Защита: lineups_viewed >= 5 ИЛИ verified_not_fake = true → никогда не удалять.
 * Испытательный срок: 7 дней после регистрации, нужно посмотреть 5 лайнапов.
 * Напоминания: за 3, 2 и 1 день до удаления.
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
    reason:             'Меньше 5 просмотров за 7 дней испытательного срока',
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
  const REQUIRED_VIEWS = 5;
  const TRIAL_DAYS = 7;
  const WARNING_DAYS = 3;
  const msPerDay = 24 * 3600 * 1000;
  const threshold = new Date(now.getTime() - (TRIAL_DAYS - WARNING_DAYS) * msPerDay);

  const snap = await db.collection('users')
    .where('created_at', '<', threshold)
    .get();

  const stats = { total: snap.size, cleared: 0, warned: 0, deleted: 0, errors: 0 };

  for (const doc of snap.docs) {
    const uid = doc.id;
    const u   = doc.data();

    const viewed          = Number(u.lineups_viewed || 0);
    const verified        = !!u.verified_not_fake;
    const approvedLineups = u.approved_lineups || 0;
    const deletionDay     = u.deletion_day     || 0;

    // Пользователи до 20.06.2026 — до начала трекинга lineups_viewed, считать верифицированными
    const TRACKING_START  = new Date('2026-06-20T00:00:00Z');
    const regDate         = u.created_at?.toDate?.() ?? null;
    const isPreTracking   = regDate !== null && regDate < TRACKING_START;

    // Защищённый пользователь — сбросить countdown если был
    if (viewed >= REQUIRED_VIEWS || verified || approvedLineups > 0 || isPreTracking) {
      const clear = {};
      if (deletionDay > 0) clear.deletion_day = admin.firestore.FieldValue.delete();
      if (!verified && (viewed >= REQUIRED_VIEWS || isPreTracking)) {
        clear.verified_not_fake = true;
        clear.verified_at = admin.firestore.FieldValue.serverTimestamp();
        clear.verification_reason = isPreTracking ? 'pre_tracking_user' : 'viewed_5_lineups';
      }
      if (Object.keys(clear).length) {
        await doc.ref.update(clear);
        stats.cleared++;
      }
      continue;
    }

    const daysSinceReg = regDate
      ? Math.floor((now.getTime() - regDate.getTime()) / msPerDay)
      : TRIAL_DAYS;
    const daysLeft = TRIAL_DAYS - daysSinceReg;

    // Ещё не подошли последние 3 дня испытательного срока
    if (daysLeft > WARNING_DAYS) {
      if (deletionDay > 0) {
        await doc.ref.update({ deletion_day: admin.firestore.FieldValue.delete() });
        stats.cleared++;
      }
      continue;
    }

    // Кандидат на предупреждение или удаление.
    // Если старый аккаунт уже просрочен, но раньше не получал предупреждения,
    // сначала выдаём полный 3-дневный grace-период вместо мгновенного удаления.
    try {
      const warningStep = daysLeft > 0
        ? WARNING_DAYS - daysLeft + 1 // 3д → 1, 2д → 2, 1д → 3
        : deletionDay + 1;

      if (warningStep > WARNING_DAYS) {
        await archiveAndDelete(uid, u);
        stats.deleted++;
        console.log(`[deleted] ${uid} (${u.name || 'no name'}, viewed=${viewed})`);
      } else {
        if (deletionDay >= warningStep) continue;
        const pushDaysLeft = WARNING_DAYS - warningStep + 1;
        await doc.ref.update({
          deletion_day: warningStep,
          trial_days_left: Math.max(1, daysLeft),
          trial_required_views: REQUIRED_VIEWS,
          trial_updated_at: admin.firestore.FieldValue.serverTimestamp(),
        });

        if (pushDaysLeft === 3) {
          await sendPush(uid,
            '⚠️ Аккаунт под угрозой удаления',
            'Открой приложение и посмотри 5 лайнапов, чтобы сохранить аккаунт. Осталось 3 дня.'
          );
        } else if (pushDaysLeft === 2) {
          await sendPush(uid,
            '⚠️ Аккаунт будет удалён через 2 дня',
            'Посмотри 5 лайнапов — и аккаунт будет в безопасности.'
          );
        } else {
          await sendPush(uid,
            '🚨 Последний шанс! Аккаунт удаляется завтра',
            'Открой приложение и посмотри 5 лайнапов прямо сейчас.'
          );
        }
        stats.warned++;
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
