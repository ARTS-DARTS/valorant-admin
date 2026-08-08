function isMissingAuthUser(error) {
  const code = String(error?.code || '').toLowerCase();
  const message = String(error?.message || '').toLowerCase();
  return code === 'auth/user-not-found'
    || message.includes('no user record corresponding to the provided identifier');
}

async function deleteAuthUserIfPresent(auth, uid) {
  try {
    await auth.deleteUser(uid);
    return 'deleted';
  } catch (error) {
    if (isMissingAuthUser(error)) return 'already_missing';
    throw error;
  }
}

module.exports = { deleteAuthUserIfPresent, isMissingAuthUser };
