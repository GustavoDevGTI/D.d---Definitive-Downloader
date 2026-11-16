import assert from 'node:assert/strict';
import { test } from 'node:test';
import { servePlaylist } from './rapidapi-route.mjs';

const id = '1234567890123456789012';
const song = '0123456789012345678901';
const key = 'synthetic-checkleaked-key';
const origin = 'https://dd.example.test';
const path = '/v1/spotify/playlists/' + id;

function fixture({
  total = 232, publicPlaylist = true, allowance = 900, remaining = 1000,
  errorAt, withEpisode, malformedPage, limited = false,
} = {}) {
  const calls = [];
  const reserved = [];
  const env = {
    DD_RAPIDAPI_KEY: key,
    IMPORTS: { limit: async () => ({ success: !limited }) },
    BUDGET: { getByName: () => ({
      async reserve(count) {
        reserved.push(count);
        if (allowance < count) return false;
        allowance -= count;
        return true;
      },
    }) },
  };
  const fetchUpstream = async (url, options) => {
    assert.equal(url.origin, 'https://spotify81.p.rapidapi.com');
    assert.equal(url.searchParams.get('id'), id);
    assert.equal(options.headers['x-rapidapi-key'], key);
    assert.equal(options.headers['x-rapidapi-host'], url.host);
    assert.equal(options.redirect, 'manual');
    assert.equal(options.headers.cookie, undefined);
    const offset = Number(url.searchParams.get('offset'));
    calls.push({ path: url.pathname, offset });
    if (url.pathname === '/playlist') {
      return Response.json({ success: true, data: {
        id, name: 'Fifa de teste', public: publicPlaylist, tracks: { total },
      } }, { headers: { 'x-ratelimit-requests-remaining': String(remaining) } });
    }
    assert.equal(url.pathname, '/playlist_tracks');
    assert.equal(url.searchParams.get('limit'), '100');
    if (errorAt === offset) return Response.json({ secret: key }, { status: 503 });
    const items = Array.from({ length: Math.min(100, total - offset) }, (_, index) => ({
      added_by: { secret: key },
      track: { id: song, type: 'track', name: offset + index === total - 1 ? 'Última' : 'Repetida',
        duration_ms: 180000, explicit: false, artists: [{ name: 'Artista' }],
        external_ids: { isrc: 'BRAAA2600001' },
        album: { name: 'Álbum', images: [{ url: 'https://i.scdn.co/image/abc123' }] } },
    }));
    if (withEpisode && offset === 100) items[0] = { track: { type: 'episode' } };
    if (malformedPage && offset === 100) items.pop();
    return Response.json({ offset, total, items });
  };
  const request = (url = path, init) => servePlaylist(new Request(origin + url, init), env, fetchUpstream);
  return { request, calls, reserved, env };
}

test('imports 232 occurrences in four RapidAPI calls with no caller credentials', async () => {
  const { request, calls, reserved } = fixture();
  const result = await request();
  assert.equal(result.status, 200);
  assert.equal(result.headers.get('cache-control'), 'no-store');
  const body = await result.json();
  assert.equal(body.name, 'Fifa de teste');
  assert.equal(body.total, 232);
  assert.equal(body.skipped, 0);
  assert.equal(body.tracks[231].title, 'Última');
  assert.deepEqual(body.tracks[0], body.tracks[230]);
  assert.equal(body.tracks[0].isrc, 'BRAAA2600001');
  assert.equal(body.tracks[0].explicit, false);
  assert.equal(body.tracks[0].coverUrl, 'https://i.scdn.co/image/abc123');
  assert.equal(JSON.stringify(body).includes(key), false);
  assert.deepEqual(calls, [
    { path: '/playlist', offset: 0 }, ...[0, 100, 200].map(offset => ({ path: '/playlist_tracks', offset })),
  ]);
  assert.deepEqual(reserved, [1, 3]);
});

test('counts episodes skipped and preserves music occurrences', async () => {
  const { request } = fixture({ withEpisode: true });
  const body = await (await request()).json();
  assert.equal(body.total, 231);
  assert.equal(body.skipped, 1);
  assert.equal(body.tracks.at(-1).title, 'Última');
});

test('refuses private playlists and ignores arbitrary routes and methods', async () => {
  const { request, calls } = fixture({ publicPlaylist: false });
  for (const invalid of [path + '?si=private', path + '/extra', '/api/v1/services']) {
    assert.equal((await request(invalid)).status, 404);
  }
  assert.equal((await request(path, { method: 'POST' })).status, 404);
  assert.equal(calls.length, 0);
  const denied = await request();
  assert.equal(denied.status, 404);
  assert.deepEqual(await denied.json(), { error: 'public_playlist_required' });
  assert.equal(calls.length, 1);
});

test('refuses a partial page or an upstream error without returning any tracks', async () => {
  for (const [options, status] of [[{ malformedPage: true }, 502], [{ errorAt: 100 }, 503]]) {
    const { request, calls } = fixture(options);
    const result = await request();
    assert.equal(result.status, status);
    const body = await result.text();
    assert.ok(!body.includes(key) && !body.includes('tracks'));
    assert.equal(calls.length, 3);
  }
});

test('rejects over-limit playlists before requesting their first page', async () => {
  const { request, calls } = fixture({ total: 4501 });
  const result = await request();
  assert.equal(result.status, 422);
  assert.deepEqual(await result.json(), { error: 'playlist_too_large' });
  assert.equal(calls.length, 1);
});

test('checks both project budget and provider quota before requesting pages', async () => {
  for (const options of [{ allowance: 3 }, { remaining: 2 }]) {
    const { request, calls } = fixture(options);
    const result = await request();
    assert.equal(result.status, 429);
    assert.deepEqual(await result.json(), { error: 'monthly_limit' });
    assert.equal(calls.length, 1);
  }
  const exhausted = fixture({ allowance: 0 });
  assert.equal((await exhausted.request()).status, 429);
  assert.equal(exhausted.calls.length, 0);
});

test('stops when the key is absent or the edge rate limit is reached', async () => {
  const { request, env, calls } = fixture({ limited: true });
  assert.equal((await request()).status, 429);
  assert.equal(calls.length, 0);
  delete env.DD_RAPIDAPI_KEY;
  assert.equal((await request('/health')).status, 503);
  assert.equal((await request()).status, 503);
  assert.equal(calls.length, 0);
});
