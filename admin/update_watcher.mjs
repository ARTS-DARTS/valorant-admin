export function extractAdminBuildVersion(html) {
  return String(html || '')
    .match(
      /<span class="admin-version" id="admin-build-version">([^<]+)<\/span>/,
    )?.[1]
    ?.trim() || '';
}

export function createAdminUpdateWatcher({
  documentRef,
  windowRef,
  fetchFn,
  saveDraft,
  pollMs = 60_000,
  now = Date.now,
  setIntervalFn = setInterval,
  logger = console,
}) {
  let started = false;

  const currentVersion = () =>
    String(
      documentRef
        .getElementById('admin-build-version')
        ?.textContent || '',
    ).trim();

  const setBannerVisible = (visible) => {
    documentRef
      .getElementById('admin-update-banner')
      ?.classList.toggle('show', visible);
  };

  const check = async () => {
    const current = currentVersion();
    if (!current || current === 'local') return;

    try {
      const response = await fetchFn(
        `./admin_panel.html?admin_update_check=${now()}`,
        {
          cache: 'no-store',
          headers: { 'Cache-Control': 'no-cache' },
        },
      );
      if (!response.ok) return;

      const live = extractAdminBuildVersion(await response.text());
      setBannerVisible(Boolean(live && live !== current));
    } catch (error) {
      logger.warn('admin update check failed', error);
    }
  };

  const reload = () => {
    saveDraft();
    const url = new URL(windowRef.location.href);
    url.searchParams.set('admin_refresh', now().toString());
    windowRef.location.replace(url.toString());
  };

  const start = () => {
    if (started) return;
    started = true;
    documentRef
      .getElementById('admin-update-reload')
      ?.addEventListener('click', reload);
    void check();
    setIntervalFn(check, pollMs);
  };

  return { check, currentVersion, start };
}
