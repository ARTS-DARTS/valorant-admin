import test from 'node:test';
import assert from 'node:assert/strict';

import {
  buildMessageConversations,
  filterMessageConversations,
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

test('does not invent a user message for an admin-initiated chat', () => {
  const thread = messageThread({
    source: 'admin_message',
    text: 'Сообщение от администратора',
    created_at: 10,
    thread: [{ from: 'admin', text: 'Сообщение от администратора', ts: 10 }],
  });
  assert.deepEqual(thread, [
    { from: 'admin', text: 'Сообщение от администратора', ts: 10 },
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
