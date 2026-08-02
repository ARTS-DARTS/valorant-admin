import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const projectRoot = new URL('../', import.meta.url);

test('video frame editor exposes brush and straight-line drawing controls', async () => {
  const html = await readFile(new URL('admin_panel.html', projectRoot), 'utf8');

  assert.match(html, /class="vfe-canvas"/);
  assert.match(html, /data-vfe-tool="brush"/);
  assert.match(html, /data-vfe-tool="line"/);
  assert.match(html, /id="\$\{prefix\}-vundo"/);
  assert.match(html, /id="\$\{prefix\}-vclear"/);
  assert.match(html, /Добавить кадр/);
});

test('captured JPEG composites the selected video frame before annotations', async () => {
  const html = await readFile(new URL('admin_panel.html', projectRoot), 'utf8');
  const videoDraw = html.indexOf('outputCtx.drawImage(vid');
  const annotationDraw = html.indexOf('outputCtx.drawImage(canvas');
  const jpegExport = html.indexOf("output.toBlob(res, 'image/jpeg'");

  assert.ok(videoDraw > -1, 'video frame draw is missing');
  assert.ok(annotationDraw > videoDraw, 'annotations must be drawn after the video frame');
  assert.ok(jpegExport > annotationDraw, 'JPEG export must happen after compositing');
});

test('drawing canvas supports pointer input and reduced motion', async () => {
  const [html, css] = await Promise.all([
    readFile(new URL('admin_panel.html', projectRoot), 'utf8'),
    readFile(new URL('admin_panel.css', projectRoot), 'utf8'),
  ]);

  assert.match(html, /canvas\?\.addEventListener\('pointerdown'/);
  assert.match(html, /canvas\.setPointerCapture\(event\.pointerId\)/);
  assert.match(css, /\.vfe-canvas[^}]*touch-action:none/);
  assert.match(css, /@media \(prefers-reduced-motion:reduce\)/);
});
