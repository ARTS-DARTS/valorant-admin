const finite = (value, fallback = 0) => {
  const number = Number(value);
  return Number.isFinite(number) ? number : fallback;
};

const seconds = (value, timebase) => finite(value) / timebase;

export function videoProjectV3ToLegacyEdit(value = {}) {
  const wrapper = value && typeof value === 'object' ? value : {};
  const project = wrapper.projectV3?.schemaVersion === 3
    ? wrapper.projectV3
    : wrapper.schemaVersion === 3 ? wrapper : null;
  if (!project) return wrapper;

  const timebase = Math.max(1, finite(project.timebase, 1_000_000));
  const clips = (Array.isArray(project.sequence?.clips) ? project.sequence.clips : [])
    .filter(clip => clip?.enabled !== false)
    .slice()
    .sort((a, b) => finite(a.timelineStartUs) - finite(b.timelineStartUs));
  const trimStart = clips.length ? Math.min(...clips.map(clip => seconds(clip.sourceStartUs, timebase))) : 0;
  const trimEnd = clips.length ? Math.max(...clips.map(clip => seconds(clip.sourceEndUs, timebase))) : 0;
  const splits = clips.slice(1).map(clip => seconds(clip.sourceStartUs, timebase));
  const layers = Array.isArray(project.tracks?.layers) ? project.tracks.layers : [];
  const mapped = kind => layers
    .filter(layer => layer?.kind === kind)
    .map(layer => ({
      ...(layer.payload && typeof layer.payload === 'object' ? layer.payload : {}),
      id:String(layer.id || ''),
      at:seconds(layer.sourceAtUs, timebase),
      outputAt:seconds(layer.timelineStartUs, timebase),
      duration:Math.max(0.2, seconds(layer.durationUs, timebase)),
      track:Math.max(0, Math.floor(finite(layer.track))),
    }));

  return {
    ...wrapper,
    version:Number(wrapper.version) || 2,
    revision:Math.max(0, Math.floor(finite(project.revision, wrapper.revision))),
    trimStart,
    trimEnd,
    splits,
    clips:clips.map(clip => ({
      id:String(clip.id || ''),
      sourceStart:seconds(clip.sourceStartUs, timebase),
      sourceEnd:seconds(clip.sourceEndUs, timebase),
    })),
    effectTracks:Math.max(1, Math.floor(finite(project.tracks?.count, 1))),
    freezeFrames:mapped('freeze'),
    zoomKeyframes:mapped('zoom'),
    footageOverlays:mapped('footage'),
    audio:{
      muted:project.audio?.muted === true,
      volume:Math.max(0, Math.min(2, finite(project.audio?.volume, 1))),
    },
    confirmation:project.confirmation || wrapper.confirmation || { status:'pending' },
  };
}
