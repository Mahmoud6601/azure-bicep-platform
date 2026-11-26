async function loadTelemetry() {
  try {
    const healthRes = await fetch('/health.json', { cache: 'no-store' });
    const health = await healthRes.json();
    document.getElementById('meta-health').textContent = health.status === 'ok' ? 'OK (200)' : 'Degraded';
  } catch {
    document.getElementById('meta-health').textContent = 'Unavailable';
  }

  try {
    const versionRes = await fetch('/version.json', { cache: 'no-store' });
    const v = await versionRes.json();
    document.getElementById('meta-version').textContent = v.version || 'unknown';
    document.getElementById('meta-sha').textContent = v.git_sha || 'unknown';
    document.getElementById('meta-track').textContent = v.deployment_track || 'unknown';
    document.getElementById('meta-env').textContent = v.environment || 'unknown';
    document.getElementById('meta-built').textContent = v.built_at || 'unknown';
  } catch {
    document.getElementById('meta-version').textContent = 'Unavailable';
  }
}

document.addEventListener('DOMContentLoaded', loadTelemetry);
