import { test } from 'node:test';
import assert from 'node:assert/strict';
import { handle } from '../src/app.js';

test('healthz returns ok', () => {
  const res = handle({ url: '/healthz' });
  assert.equal(res.status, 200);
  assert.equal(res.body.ok, true);
});

test('unknown routes return 404', () => {
  assert.equal(handle({ url: '/nope' }).status, 404);
});
