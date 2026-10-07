// Tiny request handler. Kept separate from the server so it is easy to test.
export function handle(req) {
  if (req.url === '/healthz') {
    return {
      status: 200,
      body: { ok: true, version: process.env.APP_VERSION || 'dev' },
    };
  }
  return { status: 404, body: { error: 'not found' } };
}
