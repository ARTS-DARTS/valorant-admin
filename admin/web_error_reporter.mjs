const DEFAULT_DEDUPE_MS = 5 * 60 * 1000;
const DEFAULT_MAX_PER_MINUTE = 30;

function serialize(value) {
  if (value instanceof Error) return `${value.name}: ${value.message}${value.stack ? `\n${value.stack}` : ''}`;
  if (typeof value === 'string') return value;
  if (value == null || typeof value === 'number' || typeof value === 'boolean') return String(value);
  try {
    return JSON.stringify(value, (_key, nested) => nested instanceof Error
      ? { name: nested.name, message: nested.message, stack: nested.stack }
      : nested);
  } catch (_) {
    return String(value);
  }
}

export function webErrorFingerprint({ level, message, source = '' }) {
  return `${level}|${source}|${String(message).replace(/\b\d{6,}\b/g, '#').slice(0, 1000)}`;
}

export function createWebErrorReporter({
  windowRef, consoleRef, writeError, getUser, getBuildVersion = () => '',
  now = Date.now, dedupeMs = DEFAULT_DEDUPE_MS, maxPerMinute = DEFAULT_MAX_PER_MINUTE,
}) {
  const originals = { error: consoleRef.error.bind(consoleRef), warn: consoleRef.warn.bind(consoleRef) };
  const seen = new Map();
  const pending = [];
  let minuteStartedAt = now();
  let minuteCount = 0;
  let installed = false;

  const allowed = () => {
    const time = now();
    if (time - minuteStartedAt >= 60_000) { minuteStartedAt = time; minuteCount = 0; }
    if (minuteCount >= maxPerMinute) return false;
    minuteCount += 1;
    return true;
  };

  const report = async ({ level = 'error', message, stack = '', source = 'console', context = {} }) => {
    if (!message || !getUser?.() || !allowed()) return false;
    const fingerprint = webErrorFingerprint({ level, message, source });
    const last = seen.get(fingerprint);
    if (last !== undefined && now() - last < dedupeMs) return false;
    seen.set(fingerprint, now());
    try {
      const user = getUser();
      await writeError({
        type: 'web', platform: 'web', level,
        source_app: 'admin_panel',
        message: String(message).slice(0, 8000), stack: String(stack || '').slice(0, 16000),
        operation: source, fingerprint, uid: user?.uid || '',
        build_version: getBuildVersion(), page_url: windowRef.location?.href || '',
        user_agent: windowRef.navigator?.userAgent || '', context,
      });
      return true;
    } catch (error) {
      originals.warn('[web error reporter] write failed:', error);
      return false;
    }
  };

  const enqueue = data => {
    if (!getUser?.()) { if (pending.length < 50) pending.push(data); return; }
    void report(data);
  };
  const flush = () => {
    if (!getUser?.()) return;
    pending.splice(0).forEach(item => void report(item));
  };
  const install = () => {
    if (installed) return;
    installed = true;
    for (const level of ['error', 'warn']) {
      consoleRef[level] = (...args) => {
        originals[level](...args);
        const error = args.find(arg => arg instanceof Error);
        enqueue({ level, message: args.map(serialize).join(' '), stack: error?.stack || '', source: `console.${level}` });
      };
    }
    windowRef.addEventListener('error', event => {
      const target = event.target;
      if (target && target !== windowRef && (target.src || target.href)) {
        enqueue({ level: 'error', message: `Resource failed to load: ${target.src || target.href}`,
          source: 'window.resource_error', context: { tag: target.tagName || '' } });
        return;
      }
      enqueue({ level: 'error', message: event.message || event.error?.message || 'Uncaught window error',
        stack: event.error?.stack || '', source: 'window.error',
        context: { filename: event.filename || '', line: event.lineno || 0, column: event.colno || 0 } });
    }, true);
    windowRef.addEventListener('unhandledrejection', event => enqueue({
      level: 'error', message: `Unhandled promise rejection: ${serialize(event.reason)}`,
      stack: event.reason?.stack || '', source: 'window.unhandledrejection',
    }));
  };
  return { flush, install, report };
}
