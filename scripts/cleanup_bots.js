/**
 * Ежедневный cron: удаление ботов и альт-аккаунтов.
 *
 * Защита: lineups_viewed >= 5 ИЛИ approved_lineups > 0 ИЛИ verified_not_fake = true → никогда не удалять.
 * Испытательный срок: Google — 30 дней, остальные — 7 дней после регистрации.
 * Нужно посмотреть 5 лайнапов или иметь хотя бы 1 одобренный лайнап.
 * Напоминания: за 3, 2 и 1 день до удаления: push + email-задача в коллекцию mail.
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

const REQUIRED_VIEWS = 5;
const GOOGLE_TRIAL_DAYS = 30;
const DEFAULT_TRIAL_DAYS = 30;
const WARNING_DAYS = 3;
const TRACKING_START = new Date('2026-06-20T00:00:00Z');
const PRIVACY_URL = 'https://vlineups.ru/privacy_policy.html';

function userAuthKind(u) {
  const provider = String(u.auth_provider || u.auth_provider_linked || '').toLowerCase();
  const email = String(u.user_email || '').toLowerCase();
  if (provider.includes('yandex') || u.yandex_id || u.yandex_email) return 'yandex';
  if (provider.includes('google') || (!email && !u.yandex_id)) return 'google';
  return 'email';
}

function trialDaysForUser(u) {
  return DEFAULT_TRIAL_DAYS;
}

function userEmail(u) {
  const email = String(u.user_email || u.yandex_email || '').trim();
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return '';
  if (email.endsWith('@valorantlineups.app')) return '';
  return email;
}

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

async function queueEmail(uid, u, subject, text) {
  const email = userEmail(u);
  if (!email) return false;
  try {
    await db.collection('mail').add({
      to: email,
      uid,
      template: 'account_cleanup',
      message: {
        subject,
        text,
        html: text
          .split('\n')
          .map(line => `<p>${line.replace(/[<>&]/g, ch => ({ '<': '&lt;', '>': '&gt;', '&': '&amp;' }[ch]))}</p>`)
          .join(''),
      },
      created_at: admin.firestore.FieldValue.serverTimestamp(),
    });
    return true;
  } catch (e) {
    console.warn(`[email] ${uid}:`, e.message);
    return false;
  }
}

// ── Архивирование и удаление ────────────────────────────────────────────────
async function archiveAndDelete(uid, u) {
  const trialDays = trialDaysForUser(u);
  await queueEmail(
    uid,
    u,
    'Ваш аккаунт Valorant Lineups удалён',
    [
      `Здравствуйте${u.name ? ', ' + u.name : ''}.`,
      'Ваш аккаунт был удалён как неактивный: за испытательный срок не было минимум 5 просмотренных лайнапов.',
      'Мы удаляем неактивные аккаунты, чтобы ограничивать ботов и заброшенные регистрации.',
      `Испытательный срок для этого аккаунта: ${trialDays} дней.`,
      `Подробнее: ${PRIVACY_URL}`,
    ].join('\n')
  );

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
    reason:             `Меньше ${REQUIRED_VIEWS} просмотров за ${trialDays} дней испытательного срока`,
    privacy_url:        PRIVACY_URL,
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
  const msPerDay = 24 * 3600 * 1000;
  const threshold = new Date(now.getTime() - (DEFAULT_TRIAL_DAYS - WARNING_DAYS) * msPerDay);

  const snap = await db.collection('users')
    .where('created_at', '<', threshold)
    .get();

  const stats = { total: snap.size, cleared: 0, warned: 0, deleted: 0, errors: 0 };

  for (const doc of snap.docs) {
    const uid = doc.id;
    const u   = doc.data();

    const viewed          = Number(u.lineups_viewed || 0);
    const verified        = !!u.verified_not_fake;
    const approvedLineups = Number(u.approved_lineups || 0);
    const deletionDay     = u.deletion_day     || 0;
    const trialDays       = trialDaysForUser(u);

    // Пользователи до 20.06.2026 — до начала трекинга lineups_viewed, считать верифицированными
    const regDate         = u.created_at?.toDate?.() ?? null;
    const isPreTracking   = regDate !== null && regDate < TRACKING_START;

    // Защищённый пользователь — сбросить countdown если был
    if (viewed >= REQUIRED_VIEWS || verified || approvedLineups > 0 || isPreTracking) {
      const clear = {};
      if (deletionDay > 0) {
        clear.deletion_day = admin.firestore.FieldValue.delete();
        clear.trial_days_left = admin.firestore.FieldValue.delete();
      }
      if (!verified && (viewed >= REQUIRED_VIEWS || approvedLineups > 0 || isPreTracking)) {
        clear.verified_not_fake = true;
        clear.verified_at = admin.firestore.FieldValue.serverTimestamp();
        clear.verification_reason = approvedLineups > 0
          ? 'approved_lineups'
          : isPreTracking ? 'pre_tracking_user' : 'viewed_5_lineups';
      }
      if (Object.keys(clear).length) {
        await doc.ref.update(clear);
        stats.cleared++;
      }
      continue;
    }

    const daysSinceReg = regDate
      ? Math.floor((now.getTime() - regDate.getTime()) / msPerDay)
      : trialDays;
    const daysLeft = trialDays - daysSinceReg;

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
      let warningStep = daysLeft > 0
        ? WARNING_DAYS - daysLeft + 1 // 3д → 1, 2д → 2, 1д → 3
        : deletionDay + 1;

      // Старые записи могли получить deletion_day до появления логов уведомлений.
      // Не удаляем такие аккаунты сразу: сначала запускаем полный цикл предупреждений.
      if (daysLeft <= 0 && deletionDay > 0 && !u.trial_warning_3d_sent_at && !u.trial_warning_1d_sent_at) {
        warningStep = 1;
      } else if (daysLeft <= 0 && warningStep > WARNING_DAYS && !u.trial_warning_1d_sent_at) {
        warningStep = WARNING_DAYS;
      }

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
          trial_days_total: trialDays,
          trial_policy_url: PRIVACY_URL,
          [`trial_warning_${pushDaysLeft}d_sent_at`]: admin.firestore.FieldValue.serverTimestamp(),
          trial_updated_at: admin.firestore.FieldValue.serverTimestamp(),
        });

        let pushOk = false;
        if (pushDaysLeft === 3) {
          pushOk = await sendPush(uid,
            '⚠️ Аккаунт под угрозой удаления',
            'Открой приложение и посмотри 5 лайнапов, чтобы сохранить аккаунт. Осталось 3 дня.'
          );
          await queueEmail(
            uid,
            u,
            'Аккаунт Valorant Lineups может быть удалён через 3 дня',
            [
              `Здравствуйте${u.name ? ', ' + u.name : ''}.`,
              `Ваш аккаунт будет удалён через 3 дня, если не посмотреть минимум ${REQUIRED_VIEWS} лайнапов.`,
              'Это проверка активности, которая помогает нам ограничивать ботов и заброшенные аккаунты.',
              `Испытательный срок для этого аккаунта: ${trialDays} дней.`,
              `Подробнее: ${PRIVACY_URL}`,
            ].join('\n')
          );
        } else if (pushDaysLeft === 2) {
          pushOk = await sendPush(uid,
            '⚠️ Аккаунт будет удалён через 2 дня',
            'Посмотри 5 лайнапов — и аккаунт будет в безопасности.'
          );
        } else {
          pushOk = await sendPush(uid,
            '🚨 Последний шанс! Аккаунт удаляется завтра',
            'Открой приложение и посмотри 5 лайнапов прямо сейчас.'
          );
          await queueEmail(
            uid,
            u,
            'Аккаунт Valorant Lineups может быть удалён завтра',
            [
              `Здравствуйте${u.name ? ', ' + u.name : ''}.`,
              `Ваш аккаунт будет удалён завтра, если не посмотреть минимум ${REQUIRED_VIEWS} лайнапов.`,
              'Мы удаляем неактивные аккаунты, чтобы ограничивать ботов и заброшенные регистрации.',
              `Подробнее: ${PRIVACY_URL}`,
            ].join('\n')
          );
        }
        await doc.ref.update({
          [`trial_warning_${pushDaysLeft}d_push_ok`]: pushOk,
        });
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
