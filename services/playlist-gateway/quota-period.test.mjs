import assert from 'node:assert/strict';
import { DatabaseSync } from 'node:sqlite';
import { test } from 'node:test';
import {
  addMonths, defaultQuota, periodStart, prepareQuota, quotaConfig, recordReset, reserveCalls, resetSeconds,
} from './quota-period.mjs';

// Same shape as the Durable Object `ctx.storage.sql` handle.
function storage() {
  const db = new DatabaseSync(':memory:');
  const sql = {
    exec(query, ...bindings) {
      if (!bindings.length && !/RETURNING|^\s*SELECT/i.test(query)) {
        db.exec(query);
        return { toArray: () => [] };
      }
      const rows = db.prepare(query).all(...bindings);
      return { toArray: () => rows };
    },
  };
  prepareQuota(sql);
  return { sql, db };
}

const at = text => Date.parse(text);
const config = { limit: 1000, anchor: at('2026-11-12T00:00:00Z') };

test('monthly period follows the subscription day and clamps short months', () => {
  assert.equal(periodStart(at('2026-11-26T13:00:00Z'), config.anchor), at('2026-11-12T00:00:00Z'));
  assert.equal(periodStart(at('2026-12-11T23:59:59Z'), config.anchor), at('2026-11-12T00:00:00Z'));
  assert.equal(periodStart(at('2026-12-12T00:00:00Z'), config.anchor), at('2026-12-12T00:00:00Z'));
  assert.equal(periodStart(at('2027-01-05T00:00:00Z'), config.anchor), at('2026-12-12T00:00:00Z'));
  const lastDay = at('2027-01-31T10:00:00Z');
  assert.equal(addMonths(lastDay, 1), at('2027-02-28T10:00:00Z'));
  assert.equal(periodStart(at('2027-03-01T00:00:00Z'), lastDay), at('2027-02-28T10:00:00Z'));
  assert.equal(periodStart(at('2027-03-31T10:00:00Z'), lastDay), at('2027-03-31T10:00:00Z'));
  // A future anchor (the next reset reported by the provider) works the same way.
  assert.equal(periodStart(at('2026-11-26T13:00:00Z'), at('2026-12-12T22:40:00Z')),
    at('2026-11-12T22:40:00Z'));
});

test('existing reservations count toward the current month and the limit is exact', () => {
  const { sql } = storage();
  sql.exec('INSERT INTO reservations (created_at, calls) VALUES (?, ?)', at('2026-11-12T22:40:08Z'), 1);
  sql.exec('INSERT INTO reservations (created_at, calls) VALUES (?, ?)', at('2026-11-25T19:51:27Z'), 52);
  const now = at('2026-11-26T13:00:00Z');
  for (let used = 53; used < 1000; used += 45) {
    assert.equal(reserveCalls(sql, Math.min(45, 1000 - used), now, config), true);
  }
  assert.equal(reserveCalls(sql, 1, now, config), false);
});

test('the whole limit returns on the reset day, not 31 days after each call', () => {
  const { sql } = storage();
  const busy = at('2026-12-11T20:00:00Z');
  for (let i = 0; i < 22; i += 1) reserveCalls(sql, 45, busy, config);
  reserveCalls(sql, 10, busy, config);
  assert.equal(reserveCalls(sql, 1, busy, config), false);
  const reset = at('2026-12-12T00:00:01Z');
  for (let i = 0; i < 22; i += 1) assert.equal(reserveCalls(sql, 45, reset, config), true);
  assert.equal(reserveCalls(sql, 10, reset, config), true);
  assert.equal(reserveCalls(sql, 1, reset, config), false);
});

test('the provider reset header moves the boundary to the provider time', () => {
  const { sql } = storage();
  const before = at('2026-12-12T10:00:00Z');
  sql.exec('INSERT INTO reservations (created_at, calls) VALUES (?, ?)', at('2026-12-01T00:00:00Z'), 1000);
  // Default anchor already reset at 00:00 UTC, but RapidAPI reports 12h40 left.
  assert.equal(recordReset(sql, 12 * 3600 + 40 * 60, before), true);
  assert.equal(reserveCalls(sql, 1, before, config), false);
  assert.equal(reserveCalls(sql, 1, at('2026-12-12T22:40:00Z'), config), true);
  for (const invalid of [0, -1, 1.5, 32 * 86400 + 1, 'x']) {
    assert.equal(recordReset(sql, invalid, before), false);
  }
});

test('rejects invalid reservations and prunes rows older than the previous period', () => {
  const { sql, db } = storage();
  const now = at('2027-01-20T00:00:00Z');
  for (const calls of [0, -1, 46, 1.5, NaN]) assert.equal(reserveCalls(sql, calls, now, config), false);
  sql.exec('INSERT INTO reservations (created_at, calls) VALUES (?, ?)', at('2026-11-20T00:00:00Z'), 5);
  sql.exec('INSERT INTO reservations (created_at, calls) VALUES (?, ?)', at('2026-12-20T00:00:00Z'), 5);
  assert.equal(reserveCalls(sql, 2, now, config), true);
  const rows = db.prepare('SELECT calls FROM reservations ORDER BY created_at').all().map(row => row.calls);
  assert.deepEqual(rows, [5, 2]);
});

test('configuration reads limit and anchor with safe fallbacks', () => {
  assert.deepEqual(quotaConfig({ DD_QUOTA_LIMIT: '1000', DD_QUOTA_ANCHOR: '2026-11-12T00:00:00Z' }), config);
  assert.deepEqual(quotaConfig({ DD_QUOTA_LIMIT: 'abc', DD_QUOTA_ANCHOR: 'never' }), defaultQuota);
  assert.deepEqual(quotaConfig(), defaultQuota);
  assert.equal(resetSeconds('1382400'), 1382400);
  assert.equal(resetSeconds(null), null);
  assert.equal(resetSeconds('2764801'), null);
});
