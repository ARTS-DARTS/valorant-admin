import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

import {
  adminVideoOutputDuration,
  adminVideoSegmentAt,
  adminZoomStateAt,
  buildAdminVideoSegments,
} from './video_edit_preview.mjs';

const edit = {
  trimStart: 2,
  trimEnd: 10,
  freezeFrames: [{ id: 'freeze-1', at: 5, duration: 2, annotations: [{ type: 'line', points: [{ x: 0, y: 0 }, { x: 1, y: 1 }] }] }],
  zoomKeyframes: [{ id: 'zoom-1', at: 5, outputAt: 3, duration: 2, scale: 1.8 }],
};

test('admin preview timeline applies trimming and freeze-frame duration', () => {
  const segments = buildAdminVideoSegments(edit, 14);
  assert.deepEqual(segments.map(item => [item.type, item.duration, item.outputStart]), [
    ['video', 3, 0],
    ['freeze', 2, 3],
    ['video', 5, 5],
  ]);
  assert.equal(adminVideoOutputDuration(edit, 14), 10);
  assert.equal(adminVideoSegmentAt(edit, 14, 3.5).type, 'freeze');
  assert.equal(adminVideoSegmentAt(edit, 14, 7).sourceStart, 5);
});

test('admin preview uses the same eased zoom ramp as upload editor', () => {
  assert.equal(adminZoomStateAt(edit, 14, 3).mix, 0);
  assert.equal(adminZoomStateAt(edit, 14, 4).mix, 1);
  assert.equal(adminZoomStateAt(edit, 14, 5).mix, 0);
});

test('admin player binds saved video_edit instead of a raw video only', async () => {
  const root = new URL('../', import.meta.url);
  const [html, css] = await Promise.all([
    readFile(new URL('admin_panel.html', root), 'utf8'),
    readFile(new URL('admin_panel.css', root), 'utf8'),
  ]);
  assert.match(html, /_adminEditedVideoHtml\(l/);
  assert.match(html, /_bindAdminEditedVideoPreviews/);
  assert.match(html, /Монтаж автора/);
  assert.match(html, /drawAdminFreezeAnnotations/);
  assert.match(html, /video\.addEventListener\('durationchange', initializeTimeline\)/);
  assert.match(html, /savedDuration = Number\(lineup\.video_edit\?\.trimEnd\)/);
  assert.match(html, /if \(!edit \|\| !sourceDuration\) return/);
  const scrubberHandler = html.slice(html.indexOf("scrubber.addEventListener('input'"), html.indexOf("muteButton?.addEventListener", html.indexOf("scrubber.addEventListener('input'")));
  assert.ok(scrubberHandler.indexOf('const nextOutputTime') < scrubberHandler.indexOf('stop();'));
  assert.match(scrubberHandler, /outputTime = nextOutputTime/);
  assert.match(html, /const playback = adminTimelinePlaybackPosition\(playbackStartOutput/);
  assert.match(html, /initializeTimeline\(\);/);
  assert.match(css, /\.admin-edited-video-stage/);
});
