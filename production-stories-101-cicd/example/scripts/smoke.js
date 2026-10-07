// Post-deploy smoke check: hit one real endpoint and fail loudly.
const url = process.env.SMOKE_URL;
if (!url) {
  console.error('SMOKE_URL is not set');
  process.exit(1);
}
const res = await fetch(`${url.replace(/\/$/, '')}/healthz`);
const body = await res.json().catch(() => ({}));
if (!res.ok || body.ok !== true) {
  console.error(`Smoke check failed: HTTP ${res.status}`, body);
  process.exit(1);
}
console.log('Smoke check passed, version:', body.version);
