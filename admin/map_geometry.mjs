export function clamp01(value) {
  const number = Number(value);
  return Number.isFinite(number)
    ? Math.max(0, Math.min(1, number))
    : 0;
}

export function cloneCollisionObjects(value, now = Date.now) {
  if (!Array.isArray(value)) return [];
  return value
    .map((item, index) => ({
      id: String(item?.id || `wall-${now()}-${index}`),
      kind: ['wall', 'box', 'segment'].includes(item?.kind)
        ? item.kind
        : 'wall',
      closed:
        item?.closed !== false && item?.kind !== 'segment',
      points: (Array.isArray(item?.points) ? item.points : [])
        .map((point) => ({
          x: clamp01(point?.x),
          y: clamp01(point?.y),
        }))
        .filter(
          (point) =>
            Number.isFinite(point.x) &&
            Number.isFinite(point.y),
        ),
    }))
    .filter((item) => item.points.length >= 2);
}

export function normalizedPointForTurns({
  clientX,
  clientY,
  rect,
  turns = 0,
}) {
  if (!rect?.width || !rect?.height) return null;
  const screenX = clamp01((clientX - rect.left) / rect.width);
  const screenY = clamp01((clientY - rect.top) / rect.height);
  const normalizedTurns = ((Number(turns) || 0) % 4 + 4) % 4;
  if (normalizedTurns === 1) {
    return { x: screenY, y: 1 - screenX };
  }
  if (normalizedTurns === 2) {
    return { x: 1 - screenX, y: 1 - screenY };
  }
  if (normalizedTurns === 3) {
    return { x: 1 - screenY, y: screenX };
  }
  return { x: screenX, y: screenY };
}

export function screenPoint(point, width, height) {
  return {
    x: point.x * width,
    y: point.y * height,
  };
}

export function coordinateToWrapper(
  normalizedX,
  normalizedY,
  imageRect,
  wrapperWidth,
  wrapperHeight,
) {
  return {
    x:
      (imageRect.left + Number(normalizedX) * imageRect.width) /
      (wrapperWidth || 1),
    y:
      (imageRect.top + Number(normalizedY) * imageRect.height) /
      (wrapperHeight || 1),
  };
}

export function pointsToWrapper(
  points,
  imageRect,
  wrapperWidth,
  wrapperHeight,
) {
  return (Array.isArray(points) ? points : [])
    .map((point) =>
      coordinateToWrapper(
        point.x,
        point.y,
        imageRect,
        wrapperWidth,
        wrapperHeight,
      ),
    )
    .filter(
      (point) =>
        Number.isFinite(point.x) && Number.isFinite(point.y),
    );
}

export function trajectoryFromPosition(points, x, y) {
  if (!Array.isArray(points) || points.length === 0) return [];
  if (!Number.isFinite(Number(x)) || !Number.isFinite(Number(y))) {
    return points;
  }
  const trajectory = points.map((point) => ({
    x: Number(point.x),
    y: Number(point.y),
  }));
  trajectory[0] = { x: Number(x), y: Number(y) };
  return trajectory;
}

export function eventToMapNormalized({
  clientX,
  clientY,
  wrapperRect,
  imageRect,
  translateX = 0,
  translateY = 0,
  scale = 1,
}) {
  const localX =
    (clientX - wrapperRect.left - translateX) / scale;
  const localY =
    (clientY - wrapperRect.top - translateY) / scale;
  const clampedX = Math.max(
    imageRect.left,
    Math.min(imageRect.left + imageRect.width, localX),
  );
  const clampedY = Math.max(
    imageRect.top,
    Math.min(imageRect.top + imageRect.height, localY),
  );
  return {
    x: imageRect.width
      ? (clampedX - imageRect.left) / imageRect.width
      : 0,
    y: imageRect.height
      ? (clampedY - imageRect.top) / imageRect.height
      : 0,
  };
}
