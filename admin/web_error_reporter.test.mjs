import test from 'node:test';
import assert from 'node:assert/strict';
import { createWebErrorReporter, webErrorFingerprint } from './web_error_reporter.mjs';

function harness() {
  const listeners = {}, writes = [];
  const consoleRef = { error() {}, warn() {} };
  const windowRef = { location: { href: 'https://example.test/admin' }, navigator: { userAgent: 'test' },
    addEventListener(name, callback) { listeners[name] = callback; } };
  const reporter = createWebErrorReporter({ windowRef, consoleRef, now: () => 1000,
    getUser: () => ({ uid: 'admin-1' }), getBuildVersion: () => 'build-a',
    writeError: async data => writes.push(data) });
  return { consoleRef, listeners, reporter, writes };
}

test('captures console errors as web app_errors data', async () => {
  const h = harness(); h.reporter.install();
  h.consoleRef.error('load failed', new Error('boom'));
  await new Promise(resolve => setTimeout(resolve, 0));
  assert.equal(h.writes.length, 1); assert.equal(h.writes[0].platform, 'web');
  assert.equal(h.writes[0].uid, 'admin-1'); assert.match(h.writes[0].message, /load failed.*boom/s);
});

test('deduplicates the same error during the configured window', async () => {
  const h = harness();
  await h.reporter.report({ message: 'same', source: 'test' });
  await h.reporter.report({ message: 'same', source: 'test' });
  assert.equal(h.writes.length, 1);
});

test('captures rejected promises and failed resources', async () => {
  const h = harness(); h.reporter.install();
  h.listeners.unhandledrejection({ reason: new Error('rejected') });
  await new Promise(resolve => setTimeout(resolve, 0));
  h.listeners.error({ target: { src: 'https://cdn.test/a.png', tagName: 'IMG' } });
  await new Promise(resolve => setTimeout(resolve, 0));
  assert.equal(h.writes.length, 2); assert.match(h.writes[0].message, /rejected/); assert.match(h.writes[1].message, /a\.png/);
});

test('normalizes long numeric ids in fingerprints', () => {
  assert.equal(webErrorFingerprint({ level: 'error', source: 'x', message: 'request 123456789 failed' }), 'error|x|request # failed');
});
