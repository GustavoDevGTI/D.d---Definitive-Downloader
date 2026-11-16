import { createServer } from 'node:http';
import { isIP } from 'node:net';
import { pathToFileURL } from 'node:url';

const maxTracks = 10_000;
const maxResponse = 12 * 1024 * 1024;
const playlistRoute = /^\/v1\/spotify\/playlists\/([a-zA-Z0-9]{22})$/;
const spotifyId = /^[a-zA-Z0-9]{22}$/;

class RequestFailure extends Error {
  constructor(status, code) {
    super(code);
    this.status = status;
  }
}

async function readText(response, limit) {
  const chunks = [];
  let size = 0;
  for await (const chunk of response.body) {
    size += chunk.length;
    if (size > limit) throw new RequestFailure(502, 'response_too_large');
    chunks.push(chunk);
  }
  return Buffer.concat(chunks, size).toString('utf8');
}

async function publicPlaylist(id, fetchPage, signal) {
  // The request uses a fixed Spotify host and receives no session or invite token.
  const page = await fetchPage('https://open.spotify.com/playlist/' + id, {
    redirect: 'manual', signal: AbortSignal.any([signal, AbortSignal.timeout(12_000)]),
    headers: { accept: 'text/html', 'accept-language': 'en-US' },
  });
  if ([403, 404, 410].includes(page.status)) {
    await page.body?.cancel();
    throw new RequestFailure(404, 'public_playlist_required');
  }
  if (!page.ok) {
    await page.body?.cancel();
    throw new RequestFailure(503, 'service_unavailable');
  }
  const html = await readText(page, 4 * 1024 * 1024);
  const encoded = html.match(/<script\b[^>]*\bid="initialState"[^>]*>\s*([A-Za-z0-9+/=]+)\s*<\/script>/)?.[1];
  if (!encoded) throw new RequestFailure(503, 'public_check_unavailable');
  const state = JSON.parse(Buffer.from(encoded, 'base64').toString('utf8'));
  const uri = 'spotify:playlist:' + id;
  const playlist = state.entities?.items?.[uri];
  if (state.session?.isAnonymous !== true) {
    throw new RequestFailure(503, 'public_check_unavailable');
  }
  if (playlist?.__typename !== 'Playlist' || playlist.id !== id || playlist.uri !== uri ||
      !Array.isArray(playlist.content?.items)) {
    throw new RequestFailure(404, 'public_playlist_required');
  }
  const total = playlist.content.totalCount;
  if (!Number.isSafeInteger(total) || total < playlist.content.items.length) {
    throw new RequestFailure(503, 'public_check_unavailable');
  }
  if (total === 0) throw new RequestFailure(422, 'empty_playlist');
  if (total > maxTracks) throw new RequestFailure(422, 'playlist_too_large');
  if (!playlist.content.items.length) {
    throw new RequestFailure(404, 'public_playlist_required');
  }
  return { name: clean(playlist.name, 400) || 'Playlist Spotify', total };
}

function clean(value, limit) {
  return typeof value === 'string' ? value.trim().slice(0, limit) : '';
}

function trackMetadata(row) {
  const title = clean(row?.title, 400);
  const artists = Array.isArray(row?.artists)
    ? row.artists.slice(0, 32).map(artist => clean(artist, 200)).filter(Boolean)
    : [];
  if (!title || !artists.length) throw new RequestFailure(502, 'incomplete_playlist');
  return {
    id: typeof row.id === 'string' && spotifyId.test(row.id) ? row.id : '',
    title,
    artists,
    album: clean(row.album, 400),
    durationMs: Number.isSafeInteger(row.durationMs) && row.durationMs > 0
      ? row.durationMs : null,
    isrc: clean(row.isrc, 32),
  };
}

function send(response, status, body) {
  response.writeHead(status, {
    'content-type': 'application/json; charset=utf-8',
    'cache-control': 'no-store',
    'x-content-type-options': 'nosniff',
  });
  response.end(body);
}

export function createPlaylistGateway({
  trackhopOrigin, trackhopToken, serviceId = 'spotify_bridge',
  trustProxy = false, fetchPage = fetch, clientLimit = 12,
}) {
  const upstream = new URL(trackhopOrigin);
  if (!['http:', 'https:'].includes(upstream.protocol) || upstream.username ||
      upstream.password || upstream.pathname !== '/' || upstream.search ||
      upstream.hash || !/^[A-Za-z0-9_.~+/=-]{12,256}$/.test(trackhopToken ?? '') ||
      !/^spotify_bridge(?:@[0-9]+)?$/.test(serviceId)) {
    throw new Error('Invalid Trackhop configuration');
  }
  let windowStart = Date.now();
  let totalRequests = 0;
  let active = 0;
  const clients = new Map();
  return createServer({ requestTimeout: 10_000, headersTimeout: 8_000, maxHeaderSize: 8192 },
    async (request, response) => {
      const json = (status, body) => send(response, status, JSON.stringify(body));
      if (request.method === 'GET' && request.url === '/health') {
        return json(200, { status: 'ok' });
      }
      const route = playlistRoute.exec(request.url ?? '');
      if (!route || request.method !== 'GET') return json(404, { error: 'route_not_found' });
      if (request.headers['transfer-encoding'] ||
          (request.headers['content-length'] && request.headers['content-length'] !== '0')) {
        response.setHeader('connection', 'close');
        return json(400, { error: 'invalid_request' });
      }
      const now = Date.now();
      if (now - windowStart >= 60_000) {
        windowStart = now;
        totalRequests = 0;
        clients.clear();
      }
      const forwarded = request.headers['x-dd-client-ip'];
      const peer = trustProxy && typeof forwarded === 'string' && isIP(forwarded)
        ? forwarded : request.socket.remoteAddress;
      const used = clients.get(peer) ?? 0;
      if (totalRequests >= 120 || used >= clientLimit || active >= 4) {
        const retry = active >= 4 ? 3 : Math.max(1, Math.ceil((windowStart + 60_000 - now) / 1000));
        response.setHeader('retry-after', retry);
        return json(429, { error: 'busy' });
      }
      clients.set(peer, used + 1);
      totalRequests++;
      active++;
      const cancelled = new AbortController();
      response.once('close', () => cancelled.abort());
      const signal = AbortSignal.any([cancelled.signal, AbortSignal.timeout(80_000)]);
      const id = route[1];
      try {
        const { name, total } = await publicPlaylist(id, fetchPage, signal);
        const url = new URL('/api/v1/services/' + serviceId + '/playlists/' + id + '/tracks', upstream);
        const reply = await fetch(url, {
          redirect: 'manual', signal,
          headers: { authorization: 'Bearer ' + trackhopToken, accept: 'application/json' },
        });
        if (!reply.ok) {
          await reply.body?.cancel();
          throw new RequestFailure(503, 'service_unavailable');
        }
        const rows = JSON.parse(await readText(reply, maxResponse));
        if (!Array.isArray(rows) || rows.length !== total) {
          throw new RequestFailure(502, 'incomplete_playlist');
        }
        const body = JSON.stringify({ id, name, total, tracks: rows.map(trackMetadata) });
        if (Buffer.byteLength(body) > maxResponse) {
          throw new RequestFailure(502, 'response_too_large');
        }
        send(response, 200, body);
      } catch (error) {
        if (!response.destroyed) {
          const known = error instanceof RequestFailure;
          json(known ? error.status : 503, { error: known ? error.message : 'service_unavailable' });
        }
      } finally {
        active--;
      }
    });
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const server = createPlaylistGateway({
    trackhopOrigin: process.env.DD_TRACKHOP_ORIGIN ?? 'http://127.0.0.1:8642',
    trackhopToken: process.env.DD_TRACKHOP_TOKEN,
    serviceId: process.env.DD_TRACKHOP_SERVICE,
    trustProxy: process.env.DD_TRUST_PROXY === '1',
  });
  server.listen(Number(process.env.PORT ?? 8081), process.env.HOST ?? '127.0.0.1');
}
