import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

test('admin lineups refresh from lightweight moderation events', async () => {
  const html = await readFile(new URL('../admin_panel.html', import.meta.url), 'utf8');
  assert.match(html, /collection\(db, 'moderator_logs'\)/);
  assert.match(html, /_moderationSyncActions = new Set\(\['reject'/);
  assert.match(html, /getDoc\(doc\(db, 'lineups', lineupId\)\)/);
  assert.match(html, /if \(_selectedId === lineupId && snap\.exists\(\)\) selectLineup\(lineupId\)/);
  assert.match(html, /if \(snap\.metadata\.fromCache\) return/);
  assert.match(html, /startLineupsRealtime\(\);/);
});
