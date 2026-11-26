// Monthly RapidAPI call budget, aligned with the subscription period instead of
// a rolling window. The Durable Object passes its SQLite handle here so the
// rules stay testable outside the Workers runtime.

// The BASIC subscription started on 2026-11-12. Until the provider reports its
// own reset time, the period turns at 00:00 UTC on that day of each month.
export const defaultQuota = { limit: 1000, anchor: Date.UTC(2026, 10, 12) };
export const maxReservation = 45;
const maxResetSeconds = 32 * 24 * 60 * 60;

export function addMonths(ms, months) {
  const date = new Date(ms);
  const year = date.getUTCFullYear();
  const month = date.getUTCMonth() + months;
  const lastDay = new Date(Date.UTC(year, month + 1, 0)).getUTCDate();
  return Date.UTC(year, month, Math.min(date.getUTCDate(), lastDay),
    date.getUTCHours(), date.getUTCMinutes(), date.getUTCSeconds(), date.getUTCMilliseconds());
}

export function periodStart(now, anchor) {
  const from = new Date(anchor);
  const to = new Date(now);
  let months = (to.getUTCFullYear() - from.getUTCFullYear()) * 12 +
    to.getUTCMonth() - from.getUTCMonth();
  if (addMonths(anchor, months) > now) months -= 1;
  return addMonths(anchor, months);
}

export function quotaConfig(env = {}) {
  const limit = Number(env.DD_QUOTA_LIMIT);
  const anchor = Date.parse(env.DD_QUOTA_ANCHOR ?? '');
  return {
    limit: Number.isSafeInteger(limit) && limit > 0 && limit <= 100_000 ? limit : defaultQuota.limit,
    anchor: Number.isFinite(anchor) ? anchor : defaultQuota.anchor,
  };
}

// RapidAPI reports the seconds left until the quota resets.
export function resetSeconds(header) {
  if (!/^\d{1,8}$/.test(header ?? '')) return null;
  const seconds = Number(header);
  return seconds > 0 && seconds <= maxResetSeconds ? seconds : null;
}

export function prepareQuota(sql) {
  sql.exec('CREATE TABLE IF NOT EXISTS reservations (created_at INTEGER NOT NULL, calls INTEGER NOT NULL)');
  sql.exec('CREATE TABLE IF NOT EXISTS quota_state (name TEXT PRIMARY KEY, value INTEGER NOT NULL)');
}

function anchorOf(sql, fallback) {
  const [row] = sql.exec("SELECT value FROM quota_state WHERE name = 'anchor'").toArray();
  return row ? row.value : fallback;
}

export function recordReset(sql, seconds, now) {
  const valid = resetSeconds(String(seconds));
  if (valid == null) return false;
  sql.exec("INSERT INTO quota_state (name, value) VALUES ('anchor', ?) " +
    'ON CONFLICT (name) DO UPDATE SET value = excluded.value', now + valid * 1000);
  return true;
}

export function reserveCalls(sql, calls, now, config) {
  if (!Number.isSafeInteger(calls) || calls < 1 || calls > maxReservation) return false;
  const start = periodStart(now, anchorOf(sql, config.anchor));
  // Keep the previous period for auditing; older rows no longer matter.
  sql.exec('DELETE FROM reservations WHERE created_at < ?', addMonths(start, -1));
  const rows = sql.exec(
    'INSERT INTO reservations (created_at, calls) SELECT ?, ? WHERE ' +
    '(SELECT COALESCE(SUM(calls), 0) FROM reservations WHERE created_at >= ?) + ? <= ? RETURNING calls',
    now, calls, start, calls, config.limit,
  ).toArray();
  return rows.length === 1;
}
