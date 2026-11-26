import { maxReservation, resetSeconds } from './quota-period.mjs';

const host = 'spotify81.p.rapidapi.com';
const pageSize = 100;
// Keep the metadata call, two budget reservations, one reset observation and
// all pages within the Workers Free limit of 50 subrequests per invocation.
export const maxTracks = maxReservation * pageSize;
const spotifyId = /^[A-Za-z0-9]{22}$/;
const imageUrl = /^https:\/\/i\.scdn\.co\/image\/[A-Za-z0-9]+$/;
const maxPageBytes = 2 * 1024 * 1024;

export class PlaylistFailure extends Error {
  constructor(status, code) {
    super(code);
    this.status = status;
  }
}

function text(value, limit) {
  return typeof value === 'string' ? value.trim().slice(0, limit) : '';
}

function cover(images) {
  const value = Array.isArray(images) ? images[0]?.url : null;
  return typeof value === 'string' && imageUrl.test(value) ? value : '';
}

function track(entry) {
  const item = entry?.track;
  if (!item || item.type !== 'track' || entry.is_local === true || item.is_local === true) {
    return null;
  }
  const title = text(item.name, 400);
  const artists = Array.isArray(item.artists)
    ? item.artists.slice(0, 32).map(artist => text(artist?.name, 200)).filter(Boolean)
    : [];
  if (!title || !artists.length || typeof item.id !== 'string' || !spotifyId.test(item.id)) {
    return null;
  }
  return {
    id: item.id,
    title,
    artists,
    album: text(item.album?.name, 400),
    durationMs: Number.isSafeInteger(item.duration_ms) && item.duration_ms > 0
      ? item.duration_ms : null,
    isrc: text(item.external_ids?.isrc, 32),
    explicit: typeof item.explicit === 'boolean' ? item.explicit : null,
    coverUrl: cover(item.album?.images),
  };
}

async function readJson(response) {
  const reader = response.body?.getReader();
  if (!reader) throw new PlaylistFailure(502, 'incomplete_playlist');
  const decoder = new TextDecoder('utf-8', { fatal: true });
  const pieces = [];
  let bytes = 0;
  try {
    while (true) {
      const { value, done } = await reader.read();
      if (done) break;
      bytes += value.byteLength;
      if (bytes > maxPageBytes) {
        await reader.cancel();
        throw new PlaylistFailure(502, 'response_too_large');
      }
      pieces.push(decoder.decode(value, { stream: true }));
    }
    pieces.push(decoder.decode());
    return JSON.parse(pieces.join(''));
  } finally {
    reader.releaseLock();
  }
}

export async function readCheckLeakedPlaylist(id, {
  key, reserve, observeReset, signal, fetchUpstream = fetch,
}) {
  const headers = { 'x-rapidapi-key': key, 'x-rapidapi-host': host, accept: 'application/json' };
  async function request(path, parameters) {
    const url = new URL('https://' + host + path);
    url.search = new URLSearchParams({ id, ...parameters }).toString();
    const response = await fetchUpstream(url, {
      headers, redirect: 'manual',
      signal: AbortSignal.any([signal, AbortSignal.timeout(18_000)]),
    });
    if (!response.ok) {
      await response.body?.cancel();
      if (response.status === 404 && path === '/playlist') {
        throw new PlaylistFailure(404, 'public_playlist_required');
      }
      if (response.status === 429) throw new PlaylistFailure(429, 'provider_limit');
      throw new PlaylistFailure(503, 'service_unavailable');
    }
    const body = await readJson(response);
    if (!body || body.success === false || body.error) {
      throw new PlaylistFailure(503, 'service_unavailable');
    }
    const remaining = response.headers.get('x-ratelimit-requests-remaining');
    return {
      data: body.data ?? body,
      remaining: /^\d+$/.test(remaining ?? '') ? Number(remaining) : null,
      reset: resetSeconds(response.headers.get('x-ratelimit-requests-reset')),
    };
  }

  if (!await reserve(1)) throw new PlaylistFailure(429, 'monthly_limit');
  const { data: playlist, remaining, reset } = await request('/playlist');
  // Align the project budget with the provider period before reserving pages.
  if (reset != null && observeReset) await observeReset(reset);
  if (playlist?.id !== id || playlist?.public !== true) {
    throw new PlaylistFailure(404, 'public_playlist_required');
  }
  const total = playlist.tracks?.total;
  if (!Number.isSafeInteger(total) || total < 0) {
    throw new PlaylistFailure(502, 'incomplete_playlist');
  }
  if (total === 0) throw new PlaylistFailure(422, 'empty_playlist');
  if (total > maxTracks) throw new PlaylistFailure(422, 'playlist_too_large');
  const pages = Math.ceil(total / pageSize);
  if ((remaining != null && remaining < pages) || !await reserve(pages)) {
    throw new PlaylistFailure(429, 'monthly_limit');
  }

  const tracks = [];
  for (let offset = 0; offset < total; offset += pageSize) {
    const { data: page, remaining: quota } = await request('/playlist_tracks', {
      offset, limit: pageSize,
    });
    if (page?.offset !== offset || page.total !== total ||
        !Array.isArray(page.items) || page.items.length !== Math.min(pageSize, total - offset)) {
      throw new PlaylistFailure(502, 'incomplete_playlist');
    }
    for (const entry of page.items) {
      const normalized = track(entry);
      if (normalized) tracks.push(normalized);
    }
    if (quota === 0 && offset + pageSize < total) {
      throw new PlaylistFailure(429, 'monthly_limit');
    }
  }
  if (!tracks.length) throw new PlaylistFailure(422, 'no_music_tracks');
  return {
    id, name: text(playlist.name, 400) || 'Playlist Spotify',
    total: tracks.length, skipped: total - tracks.length, tracks,
  };
}
