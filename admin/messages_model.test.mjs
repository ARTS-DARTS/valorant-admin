import test from 'node:test';
import assert from 'node:assert/strict';

import {
  buildMessageConversations,
  filterMessageConversations,
  isAdminThreadMessageRead,
  isMessageNew,
  lastThreadMessage,
  messageThread,
  messageTimestamp,
  pendingModeratorApplications,
} from './messages_model.mjs';

test('normalizes Firestore-like and ISO timestamps', () => {
  assert.equal(messageTimestamp({ ts: 12 }), 12);
  assert.equal(messageTimestamp({ ts: { toMillis: () => 34 } }), 34);
  assert.equal(
    messageTimestamp({ ts: '2026-01-01T00:00:00.000Z' }),
    Date.parse('2026-01-01T00:00:00.000Z'),
  );
});

test('preserves legacy reply conversations and unread fallback', () => {
  const message = {
    text: 'Вопрос',
    reply: 'Ответ',
    created_at: 10,
    replied_at: 20,
  };
  assert.deepEqual(
    messageThread(message).map((item) => item.from),
    ['user', 'admin'],
  );
  assert.equal(lastThreadMessage(message).text, 'Ответ');
  assert.equal(isMessageNew(message), false);
  assert.equal(isMessageNew({ text: 'Без ответа' }), true);
});

test('adds a missing original message to a modern thread', () => {
  const thread = messageThread({
    text: 'Первое',
    created_at: 10,
    thread: [{ from: 'admin', text: 'Ответ', ts: 20 }],
  });
  assert.deepEqual(
    thread.map((item) => item.text),
    ['Первое', 'Ответ'],
  );
});

test('calculates read receipts per admin message', () => {
  const conversation = {
    user_read_at: 25,
    thread: [
      { from: 'admin', text: 'Прочитано открытием', ts: 20 },
      { from: 'admin', text: 'Прочитано ответом', ts: 30 },
      { from: 'user', text: 'Ответ', ts: 40 },
      { from: 'admin', text: 'Ещё не прочитано', ts: 50 },
    ],
  };
  assert.equal(
    isAdminThreadMessageRead(conversation, conversation.thread[0]),
    true,
  );
  assert.equal(
    isAdminThreadMessageRead(conversation, conversation.thread[1]),
    true,
  );
  assert.equal(
    isAdminThreadMessageRead(conversation, conversation.thread[3]),
    false,
  );
});

test('does not invent a user message for an admin-initiated chat', () => {
  const thread = messageThread({
    id: 'admin_chat_u1',
    source: 'admin_message',
    text: 'Сообщение от администратора',
    created_at: 10,
    thread: [{ from: 'admin', text: 'Сообщение от администратора', ts: 10 }],
  });
  assert.deepEqual(thread, [
    { from: 'admin', text: 'Сообщение от администратора', ts: 10 },
  ]);
  assert.deepEqual(
    messageThread({
      id: 'admin_chat_u1',
      source: 'admin_message',
      text: 'Чат с администрацией',
      thread: [],
    }),
    [],
  );
});

test('restores original feedback misclassified as an admin message after reply', () => {
  const thread = messageThread({
    id: 'legacy_feedback_1',
    source: 'admin_message',
    text: 'Думаю, можно закреплять вот тут сверху по середине.',
    created_at: 10,
    thread: [{ from: 'admin', text: 'Отличная идея.', ts: 20 }],
  });
  assert.deepEqual(thread, [
    {
      from: 'user',
      text: 'Думаю, можно закреплять вот тут сверху по середине.',
      ts: 10,
    },
    { from: 'admin', text: 'Отличная идея.', ts: 20 },
  ]);
});

test('merges moderator application feedback by user and deduplicates thread', () => {
  const conversations = buildMessageConversations([
    {
      id: 'feedback',
      user_id: 'u1',
      text: 'Хочу помогать',
      created_at: 10,
    },
    {
      id: 'application',
      user_id: 'u1',
      source: 'moderator_application',
      text: 'Хочу помогать',
      created_at: 10,
      admin_unread: true,
    },
  ]);
  assert.equal(conversations.length, 1);
  assert.equal(conversations[0].id, 'application');
  assert.deepEqual(
    conversations[0]._mergedIds.sort(),
    ['application', 'feedback'],
  );
  assert.equal(conversations[0].thread.length, 1);
  assert.equal(conversations[0].admin_unread, true);
});

test('keeps a direct admin chat separate from a moderator application', () => {
  const conversations = buildMessageConversations([
    {
      id: 'admin_chat_u1',
      user_id: 'u1',
      source: 'admin_message',
      text: 'Чат с администрацией',
      thread: [{ from: 'admin', text: 'Привет', ts: 30 }],
      created_at: 30,
    },
    {
      id: 'moderator_application_u1',
      user_id: 'u1',
      source: 'moderator_application',
      text: 'Хочу помогать',
      created_at: 10,
    },
  ]);
  assert.deepEqual(
    conversations.map((item) => item.id),
    ['admin_chat_u1', 'moderator_application_u1'],
  );
  assert.equal(conversations[0].thread[0].text, 'Привет');
});

test('filters conversations by state and localized search', () => {
  const conversations = [
    {
      id: 'new',
      username: 'Игрок',
      category: 'баг',
      text: 'Не работает карта',
      admin_unread: true,
    },
    {
      id: 'closed',
      username: 'Tester',
      text: 'Done',
      status: 'closed',
      admin_unread: false,
    },
  ];
  assert.deepEqual(
    filterMessageConversations(conversations, 'new').map(
      (item) => item.id,
    ),
    ['new'],
  );
  assert.deepEqual(
    filterMessageConversations(
      conversations,
      'all',
      'КАРТА',
    ).map((item) => item.id),
    ['new'],
  );
});

test('selects pending moderator applications', () => {
  assert.deepEqual(
    pendingModeratorApplications([
      { id: 1, status: 'pending' },
      { id: 2, status: 'approved' },
    ]).map((item) => item.id),
    [1],
  );
});
