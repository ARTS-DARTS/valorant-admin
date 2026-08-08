const assert = require('node:assert/strict');
const test = require('node:test');
const { deleteAuthUserIfPresent, isMissingAuthUser } = require('./cleanup_auth');

test('missing Firebase Auth user is an idempotent cleanup success', async () => {
  const auth = { deleteUser: async () => { const error = new Error('There is no user record corresponding to the provided identifier.'); error.code = 'auth/user-not-found'; throw error; } };
  assert.equal(await deleteAuthUserIfPresent(auth, 'uid'), 'already_missing');
  assert.equal(isMissingAuthUser({ code:'auth/user-not-found' }), true);
});

test('unexpected Firebase Auth errors still fail cleanup', async () => {
  const auth = { deleteUser: async () => { throw new Error('network down'); } };
  await assert.rejects(deleteAuthUserIfPresent(auth, 'uid'), /network down/);
});
