import { PlaylistFailure, readCheckLeakedPlaylist } from './checkleaked.mjs';

const route = /^\/v1\/spotify\/playlists\/([A-Za-z0-9]{22})$/;
const maxResponse = 12 * 1024 * 1024;
const headers = {
  'cache-control': 'no-store',
  'x-content-type-options': 'nosniff',
};

export async function servePlaylist(request, env, fetchUpstream = fetch) {
  const json = (body, status = 200) => Response.json(body, { status, headers });
  const url = new URL(request.url);
  if (request.method === 'GET' && url.pathname === '/health' && !url.search) {
    return json({ status: env.DD_RAPIDAPI_KEY ? 'ok' : 'configuration_required' },
      env.DD_RAPIDAPI_KEY ? 200 : 503);
  }
  const match = route.exec(url.pathname);
  if (!match || url.search || request.method !== 'GET') {
    return json({ error: 'route_not_found' }, 404);
  }
  if (!env.DD_RAPIDAPI_KEY) return json({ error: 'service_unavailable' }, 503);
  try {
    // Cloudflare sets this header at the edge. The rate limiter stores no IPs
    // in the durable call budget, whose rows contain only counts and timestamps.
    const ip = request.headers.get('cf-connecting-ip') ?? 'unknown';
    const { success } = await env.IMPORTS.limit({ key: ip });
    if (!success) return json({ error: 'busy' }, 429);
    const budget = env.BUDGET.getByName('checkleaked');
    const playlist = await readCheckLeakedPlaylist(match[1], {
      key: env.DD_RAPIDAPI_KEY,
      reserve: calls => budget.reserve(calls),
      observeReset: seconds => budget.observeReset(seconds),
      fetchUpstream,
      signal: AbortSignal.any([request.signal, AbortSignal.timeout(80_000)]),
    });
    const body = JSON.stringify(playlist);
    if (new TextEncoder().encode(body).byteLength > maxResponse) {
      return json({ error: 'response_too_large' }, 502);
    }
    return new Response(body, { headers: { ...headers, 'content-type': 'application/json; charset=utf-8' } });
  } catch (error) {
    const known = error instanceof PlaylistFailure;
    return json({ error: known ? error.message : 'service_unavailable' }, known ? error.status : 503);
  }
}
