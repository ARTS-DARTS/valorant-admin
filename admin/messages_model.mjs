export function messageTimestamp(message) {
  const raw =
    message?.ts ??
    message?.created_at ??
    message?.createdAt ??
    0;
  if (typeof raw === 'number') return raw;
  if (raw?.toMillis) return raw.toMillis();
  if (raw?.toDate) return raw.toDate().getTime();
  const parsed = Date.parse(raw);
  return Number.isFinite(parsed) ? parsed : 0;
}

export function isMessageNew(message) {
  if (message.admin_unread === true) return true;
  if (message.admin_unread === false) return false;
  return !message.reply;
}

export function messageThread(message) {
  const createdAt = messageTimestamp({
    ts: message.created_at || message.createdAt,
  });
  const repliedAt =
    messageTimestamp({
      ts: message.replied_at || message.updated_at,
    }) || createdAt;

  if (Array.isArray(message.thread) && message.thread.length) {
    const thread = [...message.thread];
    const originalText = String(message.text || '').trim();
    const hasOriginal =
      !originalText ||
      thread.some(
        (item) =>
          item.from !== 'admin' &&
          String(item.text || '').trim() === originalText,
      );
    if (!hasOriginal) {
      thread.unshift({
        from: 'user',
        text: originalText,
        ts: createdAt,
      });
    }
    return thread;
  }

  const thread = [
    { from: 'user', text: message.text || '', ts: createdAt },
  ];
  if (message.reply) {
    thread.push({
      from: 'admin',
      text: message.reply,
      ts: repliedAt,
    });
  }
  return thread;
}

export function lastThreadMessage(message) {
  const thread = messageThread(message);
  return thread.reduce(
    (latest, item) =>
      messageTimestamp(item) >= messageTimestamp(latest)
        ? item
        : latest,
    thread[0] || {},
  );
}

export function buildMessageConversations(source) {
  const consumed = new Set();
  const result = [];
  const applicationByUser = new Map();

  source.forEach((item) => {
    if (
      item.user_id &&
      (item.source === 'moderator_application' ||
        item.category === 'заявка модератора')
    ) {
      applicationByUser.set(item.user_id, item);
    }
  });

  for (const item of source) {
    if (consumed.has(item.id)) continue;
    const canonical =
      item.user_id && applicationByUser.get(item.user_id);
    if (canonical && canonical.id !== item.id) {
      consumed.add(item.id);
      continue;
    }
    if (!canonical) {
      result.push(item);
      consumed.add(item.id);
      continue;
    }

    const parts = source.filter(
      (other) =>
        other.user_id === canonical.user_id &&
        other.status !== 'closed',
    );
    parts.forEach((part) => consumed.add(part.id));
    const seen = new Set();
    const thread = parts
      .flatMap(messageThread)
      .filter((message) => {
        const key = [
          message.from,
          String(message.text || '').trim(),
          messageTimestamp(message),
        ].join('|');
        if (seen.has(key)) return false;
        seen.add(key);
        return true;
      })
      .sort(
        (left, right) =>
          messageTimestamp(left) - messageTimestamp(right),
      );
    const readSource =
      parts.find((part) => part.user_read_at) || canonical;
    result.push({
      ...canonical,
      thread,
      _mergedIds: parts.map((part) => part.id),
      admin_unread: parts.some(isMessageNew),
      user_unread: canonical.user_unread,
      user_read_at:
        canonical.user_read_at || readSource.user_read_at || null,
    });
  }

  return result;
}

export function filterMessageConversations(
  conversations,
  filter,
  searchTerm = '',
) {
  let items = conversations;
  if (filter === 'new') {
    items = conversations.filter(
      (message) =>
        message.status !== 'closed' && isMessageNew(message),
    );
  } else if (filter === 'answered') {
    items = conversations.filter(
      (message) =>
        messageThread(message).some(
          (item) => item.from === 'admin',
        ) && message.status !== 'closed',
    );
  } else if (filter === 'closed') {
    items = conversations.filter(
      (message) => message.status === 'closed',
    );
  }

  const search = String(searchTerm || '')
    .toLocaleLowerCase('ru-RU')
    .trim();
  if (!search) return items;

  return items.filter((message) => {
    const threadText = messageThread(message)
      .map((item) => item.text || '')
      .join(' ');
    const haystack = [
      message.username,
      message.user_id,
      message.category,
      message.source,
      threadText,
    ]
      .map((value) =>
        String(value || '').toLocaleLowerCase('ru-RU'),
      )
      .join(' ');
    return haystack.includes(search);
  });
}

export function pendingModeratorApplications(applications) {
  return applications.filter(
    (application) => application.status === 'pending',
  );
}
