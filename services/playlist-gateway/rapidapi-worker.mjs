import { DurableObject } from 'cloudflare:workers';
import { servePlaylist } from './rapidapi-route.mjs';

const callBudget = 900;
const windowMs = 31 * 24 * 60 * 60 * 1000;

export class RapidApiBudget extends DurableObject {
  constructor(ctx, env) {
    super(ctx, env);
    this.sql = ctx.storage.sql;
    this.sql.exec('CREATE TABLE IF NOT EXISTS reservations (created_at INTEGER NOT NULL, calls INTEGER NOT NULL)');
  }

  reserve(calls) {
    if (!Number.isSafeInteger(calls) || calls < 1 || calls > 45) return false;
    const now = Date.now();
    this.sql.exec('DELETE FROM reservations WHERE created_at <= ?', now - windowMs);
    const rows = this.sql.exec(
      'INSERT INTO reservations (created_at, calls) SELECT ?, ? ' +
      'WHERE (SELECT COALESCE(SUM(calls), 0) FROM reservations) + ? <= ? RETURNING calls',
      now, calls, calls, callBudget,
    ).toArray();
    return rows.length === 1;
  }
}

export default {
  fetch(request, env) {
    return servePlaylist(request, env);
  },
};
