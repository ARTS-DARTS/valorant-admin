const clamp = (value, min, max) => Math.max(min, Math.min(max, Number(value) || 0));

export function normalizeAdminVideoEdit(value, sourceDuration = 0) {
  const raw = value && typeof value === 'object' ? value : {};
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
  return {
    version: Number(raw.version) || 1,
    trimStart,
    trimEnd,
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
  const segments = [];
  let sourceCursor = edit.trimStart;
  edit.freezeFrames.forEach(freeze => {
    if (freeze.at > sourceCursor) {
      segments.push({ type: 'video', sourceStart: sourceCursor, sourceEnd: freeze.at, duration: freeze.at - sourceCursor });
    }
    segments.push({ type: 'freeze', id: freeze.id, sourceAt: freeze.at, duration: freeze.duration, annotations: freeze.annotations });
    sourceCursor = freeze.at;
  });
  if (sourceCursor < edit.trimEnd) {
    segments.push({ type: 'video', sourceStart: sourceCursor, sourceEnd: edit.trimEnd, duration: edit.trimEnd - sourceCursor });
  }
  let outputStart = 0;
  return segments.map(segment => {
    const result = { ...segment, outputStart };
    outputStart += segment.duration;
    return result;
  });
}

export function adminVideoOutputDuration(editValue, sourceDuration = 0) {
  return buildAdminVideoSegments(editValue, sourceDuration).reduce((total, segment) => total + segment.duration, 0);
}

export function adminVideoSegmentAt(editValue, sourceDuration, outputTime) {
  const segments = buildAdminVideoSegments(editValue, sourceDuration);
  const time = Math.max(0, Number(outputTime) || 0);
  return segments.find((segment, index) => {
    const end = segment.outputStart + segment.duration;
    return time >= segment.outputStart && (time < end || index === segments.length - 1);
  }) || segments.at(-1) || null;
}

export function adminSourceToOutputTime(editValue, sourceDuration, sourceTime) {
  const edit = normalizeAdminVideoEdit(editValue, sourceDuration);
  let output = Math.max(0, Number(sourceTime || 0) - edit.trimStart);
  edit.freezeFrames.forEach(freeze => {
    if (freeze.at < Number(sourceTime || 0)) output += freeze.duration;
  });
  return output;
}

export function adminEffectOutputStart(item, editValue, sourceDuration) {
  const explicit = Number(item?.outputAt);
  return Number.isFinite(explicit)
    ? Math.max(0, explicit)
    : adminSourceToOutputTime(editValue, sourceDuration, item?.at || 0);
}

export function adminZoomStateAt(editValue, sourceDuration, outputTime) {
  const edit = normalizeAdminVideoEdit(editValue, sourceDuration);
  const clip = edit.zoomKeyframes.slice().reverse().find(item => {
    const start = adminEffectOutputStart(item, edit, sourceDuration);
    return outputTime >= start && outputTime <= start + item.duration;
  }) || null;
  if (!clip) return { clip: null, mix: 0 };
  const start = adminEffectOutputStart(clip, edit, sourceDuration);
  const local = clamp(outputTime - start, 0, clip.duration);
  const ramp = Math.max(0.08, Math.min(0.4, clip.duration / 2));
  const linear = clamp(Math.min(local / ramp, (clip.duration - local) / ramp), 0, 1);
  return { clip, mix: linear * linear * (3 - 2 * linear) };
}

export function adminActiveFootageAt(editValue, sourceDuration, outputTime) {
  const edit = normalizeAdminVideoEdit(editValue, sourceDuration);
  return edit.footageOverlays.slice().reverse().find(item => {
    const start = adminEffectOutputStart(item, edit, sourceDuration);
    return outputTime >= start && outputTime <= start + item.duration;
  }) || null;
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
