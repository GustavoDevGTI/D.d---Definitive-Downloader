import assert from 'node:assert/strict';
import { once } from 'node:events';
import { createServer } from 'node:http';
import { test } from 'node:test';
import { createPlaylistGateway } from './server.mjs';

const id = '1234567890123456789012';
const uri = 'spotify:playlist:' + id;
const track = { id: '0123456789012345678901', title: 'Faixa', artists: ['Artista'], durationMs: 3000 };
const key = 'synthetic-trackhop-token';
const endpoint = '/v1/spotify/playlists/' + id;

function playlistPage(total, { session = true, visible = true } = {}) {
  const item = { __typename: 'Playlist', id, uri, name: 'Coleção', content: { items: [{}], totalCount: total } };
  const state = { session: { isAnonymous: session }, entities: { items: visible ? { [uri]: item } : {} } };
  return new Response('<script id="initialState" type="text/plain">' +
    Buffer.from(JSON.stringify(state)).toString('base64') + '</script>');
}

async function listen(server, context) {
  server.listen(0, '127.0.0.1');
  await once(server, 'listening');
  context.after(() => new Promise(resolve => {
    server.close(resolve);
    server.closeAllConnections();
  }));
  return 'http://127.0.0.1:' + server.address().port;
}

async function setup(context, { rows = [], fetchPage, clientLimit } = {}) {
  const calls = [];
  const upstream = await listen(createServer((request, response) => {
    calls.push({ method: request.method, url: request.url, token: request.headers.authorization });
    response.end(JSON.stringify(rows));
  }), context);
  const gateway = await listen(createPlaylistGateway({
    trackhopOrigin: upstream, trackhopToken: key, fetchPage, clientLimit,
  }), context);
  return { calls, gateway };
}

test('reads a 151-track public playlist in order and returns metadata only', async context => {
  const rows = Array.from({ length: 151 }, (_, index) => ({ ...track,
    title: index === 150 ? 'Última' : 'Faixa',
    previewUrl: 'https://example.test/private',
    authorization: key,
  }));
  const { calls, gateway } = await setup(context, {
    rows,
    fetchPage(url, options) {
      assert.equal(url, 'https://open.spotify.com/playlist/' + id);
      assert.equal(options.headers.cookie, undefined);
      assert.equal(options.headers.authorization, undefined);
      assert.equal(options.redirect, 'manual');
      return playlistPage(rows.length);
    },
  });
  const result = await fetch(gateway + endpoint);
  assert.equal(result.status, 200);
  const body = await result.json();
  assert.equal(body.total, 151);
  assert.equal(body.tracks.length, 151);
  assert.deepEqual(body.tracks[0], body.tracks[149]);
  assert.equal(body.tracks[150].title, 'Última');
  assert.equal(body.tracks[0].previewUrl, undefined);
  assert.equal(JSON.stringify(body).includes(key), false);
  assert.deepEqual(calls, [{
    method: 'GET', url: '/api/v1/services/spotify_bridge/playlists/' + id + '/tracks', token: 'Bearer ' + key,
  }]);
});

test('never calls Trackhop for a private or unverified playlist', async context => {
  for (const [options, status] of [[{ visible: false }, 404], [{ session: false }, 503]]) {
    const { calls, gateway } = await setup(context, { fetchPage: () => playlistPage(1, options) });
    assert.equal((await fetch(gateway + endpoint)).status, status);
    assert.deepEqual(calls, []);
  }
});

test('rejects partial Trackhop responses and limits repeated calls', async context => {
  const { calls, gateway } = await setup(context, {
    rows: [track], fetchPage: () => playlistPage(2), clientLimit: 1,
  });
  assert.equal((await fetch(gateway + endpoint + '?si=private')).status, 404);
  assert.equal((await fetch(gateway + endpoint, { method: 'POST' })).status, 404);
  const incomplete = await fetch(gateway + endpoint);
  assert.equal(incomplete.status, 502);
  assert.deepEqual(await incomplete.json(), { error: 'incomplete_playlist' });
  const limited = await fetch(gateway + endpoint, { headers: { 'x-dd-client-ip': '192.0.2.2' } });
  assert.equal(limited.status, 429);
  assert.ok(Number(limited.headers.get('retry-after')) > 0);
  assert.equal(calls.length, 1);
});

test('checks public Spotify data against a simulated 500-track Trackhop response', {
  skip: process.env.DD_GATEWAY_LIVE_PUBLIC !== '1',
}, async context => {
  const publicId = '1MMAaN2mihkm1AcVMrbnqd';
  const { calls, gateway } = await setup(context, { rows: Array(500).fill(track) });
  const result = await fetch(gateway + '/v1/spotify/playlists/' + publicId);
  assert.equal(result.status, 200, await result.clone().text());
  assert.equal((await result.json()).total, 500);
  assert.equal(calls.length, 1);
});
