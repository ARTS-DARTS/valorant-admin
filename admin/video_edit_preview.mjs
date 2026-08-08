import {
  advanceVideoTimelinePlayback,
  buildVideoTimelineSegments,
  outputTimeToScrubberValue,
  scrubberValueToOutputTime,
  sourceTimeToOutputTime,
  videoTimelineActiveFootageAt,
  videoTimelineEffectOutputStart,
  videoTimelineOutputDuration,
  videoTimelineSegmentAt,
  videoTimelineZoomStateAt,
} from './video_timeline_core.mjs?v=2026-08-02-video-timeline-core-v1';
import { videoProjectV3ToLegacyEdit } from './video_project_v3_adapter.mjs?v=2026-08-06-video-project-v3-adapter-v1';

const clamp = (value, min, max) => Math.max(min, Math.min(max, Number(value) || 0));

export function normalizeAdminVideoEdit(value, sourceDuration = 0) {
  const raw = videoProjectV3ToLegacyEdit(value && typeof value === 'object' ? value : {});
  const duration = Math.max(0, Number(sourceDuration) || Number(raw.trimEnd) || 0);
  const trimStart = clamp(raw.trimStart, 0, duration || Number.MAX_SAFE_INTEGER);
  const trimEnd = duration
    ? clamp(raw.trimEnd || duration, trimStart, duration)
    : Math.max(trimStart, Number(raw.trimEnd) || trimStart);
  const freezeFrames = (Array.isArray(raw.freezeFrames) ? raw.freezeFrames : [])
    .map((item, index) => ({
      id: String(item?.id || `freeze_${index}`),
      at: clamp(item?.at, trimStart, trimEnd),
      duration: clamp(item?.duration || 2, 0.2, 10),
      annotations: Array.isArray(item?.annotations || item?.drawings) ? (item.annotations || item.drawings) : [],
    }))
    .filter(item => item.at >= trimStart && item.at <= trimEnd)
    .sort((a, b) => a.at - b.at);
  const zoomKeyframes = (Array.isArray(raw.zoomKeyframes) ? raw.zoomKeyframes : []).map((item, index) => ({
    ...item,
    id: String(item?.id || `zoom_${index}`),
    at: clamp(item?.at, trimStart, trimEnd),
    duration: clamp(item?.duration || 2, 0.2, 10),
    scaleX: clamp(item?.scaleX ?? item?.scale ?? 1, 1, 2.2),
    scaleY: clamp(item?.scaleY ?? item?.scale ?? 1, 1, 2.2),
    posX: clamp(item?.posX, -100, 100),
    posY: clamp(item?.posY, -100, 100),
    rotation: clamp(item?.rotation, -45, 45),
    anchorX: clamp(item?.anchorX ?? 50, 0, 100),
    anchorY: clamp(item?.anchorY ?? 50, 0, 100),
  }));
  const footageOverlays = (Array.isArray(raw.footageOverlays) ? raw.footageOverlays : [])
    .map((item, index) => ({
      ...item,
      id: String(item?.id || `footage_${index}`),
      url: String(item?.url || ''),
      at: clamp(item?.at, trimStart, trimEnd),
      duration: clamp(item?.duration || 2, 0.2, 10),
      posX: clamp(item?.posX ?? 50, 0, 100),
      posY: clamp(item?.posY ?? 50, 0, 100),
      scale: clamp(item?.scale ?? 0.35, 0.05, 2),
      muted: item?.muted !== false,
      chromaKey: item?.chromaKey && typeof item.chromaKey === 'object' ? item.chromaKey : (item?.chroma || {}),
    }))
    .filter(item => item.url);
  const clips = Array.isArray(raw.clips) ? raw.clips.map((clip, index) => ({
    id:String(clip?.id || `clip_${index}`),
    sourceStart:clamp(clip?.sourceStart, trimStart, trimEnd),
    sourceEnd:clamp(clip?.sourceEnd, trimStart, trimEnd),
  })).filter(clip => clip.sourceEnd - clip.sourceStart > 0.000001) : null;
  return {
    version: Number(raw.version) || 1,
    trimStart,
    trimEnd,
    clips,
    freezeFrames,
    zoomKeyframes,
    footageOverlays,
    audio: {
      muted: raw.audio?.muted === true,
      volume: clamp(raw.audio?.volume ?? 1, 0, 2),
    },
  };
}

export function buildAdminVideoSegments(editValue, sourceDuration = 0) {
  const edit = normalizeAdminVideoEdit(editValue, sourceDuration);
  return buildVideoTimelineSegments(edit, sourceDuration);
}

export function adminVideoOutputDuration(editValue, sourceDuration = 0) {
  return videoTimelineOutputDuration(normalizeAdminVideoEdit(editValue, sourceDuration), sourceDuration);
}

export function adminVideoSegmentAt(editValue, sourceDuration, outputTime) {
  return videoTimelineSegmentAt(normalizeAdminVideoEdit(editValue, sourceDuration), sourceDuration, outputTime);
}

export function adminSourceToOutputTime(editValue, sourceDuration, sourceTime) {
  const edit = normalizeAdminVideoEdit(editValue, sourceDuration);
  return sourceTimeToOutputTime(edit, sourceDuration, sourceTime);
}

export function adminEffectOutputStart(item, editValue, sourceDuration) {
  const edit = normalizeAdminVideoEdit(editValue, sourceDuration);
  return videoTimelineEffectOutputStart(item, edit, sourceDuration);
}

export function adminZoomStateAt(editValue, sourceDuration, outputTime) {
  const edit = normalizeAdminVideoEdit(editValue, sourceDuration);
  return videoTimelineZoomStateAt(edit, sourceDuration, outputTime);
}

export function adminActiveFootageAt(editValue, sourceDuration, outputTime) {
  const edit = normalizeAdminVideoEdit(editValue, sourceDuration);
  return videoTimelineActiveFootageAt(edit, sourceDuration, outputTime);
}

export function adminScrubberToOutputTime(value, maximum, outputDuration) {
  return scrubberValueToOutputTime(value, maximum, outputDuration);
}

export function adminOutputTimeToScrubberValue(outputTime, maximum, outputDuration) {
  return outputTimeToScrubberValue(outputTime, maximum, outputDuration);
}

export function adminTimelinePlaybackPosition(startOutputTime, elapsedMilliseconds, outputDuration) {
  return advanceVideoTimelinePlayback(startOutputTime, elapsedMilliseconds, outputDuration);
}

export function drawAdminFreezeAnnotations(ctx, value, width, height) {
  if (!ctx || !width || !height || !Array.isArray(value)) return;
  value.slice(0, 40).forEach(raw => {
    const points = (Array.isArray(raw?.points) ? raw.points : []).slice(0, raw?.type === 'line' ? 2 : 240);
    if (!points.length) return;
    const color = /^#[0-9a-f]{6}$/i.test(String(raw?.color || '')) ? raw.color : '#00d4ff';
    const lineWidth = Math.max(1, clamp(raw?.width || 0.006, 0.0015, 0.03) * width);
    ctx.save();
    ctx.strokeStyle = color;
    ctx.fillStyle = color;
    ctx.lineWidth = lineWidth;
    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';
    ctx.beginPath();
    const first = points[0];
    if (points.length === 1) {
      ctx.arc(clamp(first?.x, 0, 1) * width, clamp(first?.y, 0, 1) * height, lineWidth / 2, 0, Math.PI * 2);
      ctx.fill();
    } else {
      ctx.moveTo(clamp(first?.x, 0, 1) * width, clamp(first?.y, 0, 1) * height);
      points.slice(1).forEach(point => ctx.lineTo(clamp(point?.x, 0, 1) * width, clamp(point?.y, 0, 1) * height));
      ctx.stroke();
    }
    ctx.restore();
  });
}
