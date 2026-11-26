import { DurableObject } from 'cloudflare:workers';
import { prepareQuota, quotaConfig, recordReset, reserveCalls } from './quota-period.mjs';
import { servePlaylist } from './rapidapi-route.mjs';

export class RapidApiBudget extends DurableObject {
  constructor(ctx, env) {
    super(ctx, env);
    this.sql = ctx.storage.sql;
    this.config = quotaConfig(env);
    prepareQuota(this.sql);
  }

  reserve(calls) {
    return reserveCalls(this.sql, calls, Date.now(), this.config);
  }

  observeReset(seconds) {
    return recordReset(this.sql, seconds, Date.now());
  }
}

export default {
  fetch(request, env) {
    return servePlaylist(request, env);
  },
};
