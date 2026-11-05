"""Bounded public SoundCloud metadata. Never reads browser/account state."""
import json
import re
from urllib.parse import urlparse, urljoin
import requests
from common import MusicError, clean_text, allowed_url, bounded_response


def track_url(value):
    p = urlparse(value if isinstance(value, str) else '')
    if (p.scheme != 'https' or p.hostname != 'soundcloud.com' or p.username or p.password
            or p.port not in (None, 443) or p.query or p.fragment
            or not re.fullmatch(r'/[A-Za-z0-9_-]{1,200}/[A-Za-z0-9_-]{1,200}', p.path)
            or p.path.split('/')[-1] in ('sets', 'likes', 'tracks', 'albums', 'reposts')):
        raise MusicError('Link público de faixa SoundCloud inválido.')
    return value


def candidate(row):
    if not isinstance(row, dict):
        raise MusicError('Metadados SoundCloud inválidos.')
    source_id = str(row.get('id') or '')
    if not re.fullmatch(r'[1-9][0-9]{0,18}', source_id):
        raise MusicError('ID SoundCloud inválido.')
    page = track_url(row.get('permalink_url'))
    full = int(row.get('full_duration') or row.get('duration') or 0)
    streams = (row.get('media') or {}).get('transcodings') or []
    usable = any(isinstance(t, dict) and not t.get('snipped')
        and (t.get('format') or {}).get('protocol') in ('hls', 'progressive')
        and '/preview/' not in str(t.get('url', '')) for t in streams)
    if (row.get('public') is False or row.get('sharing') == 'private'
            or row.get('policy') != 'ALLOW' or row.get('streamable') is not True
            or abs(full - int(row.get('duration') or full)) > 2000
            or not usable or not 1000 <= full <= 3600000):
        raise MusicError('SoundCloud oferece somente prévia ou a faixa está indisponível para obtenção completa.')
    publisher = row.get('publisher_metadata') or {}
    if not isinstance(publisher, dict) or not isinstance(row.get('title'), str) or not row['title'].strip():
        raise MusicError('Metadados SoundCloud inválidos.')
    return {'kind': 'soundcloud', 'sourceId': source_id, 'recordingType': 'SOUNDCLOUD_TRACK',
        'title': clean_text(row.get('title')), 'artist': clean_text(publisher.get('artist')),
        'album': clean_text(publisher.get('release_title')), 'durationMs': full,
        'pageUrl': page, 'coverUrl': clean_text(row.get('artwork_url') or (row.get('user') or {}).get('avatar_url')),
        'isrc': clean_text(publisher.get('isrc')), 'explicit': None}


class PublicCatalog:
    def __init__(self):
        self.session = requests.Session()
        self.session.headers['User-Agent'] = 'Mozilla/5.0 DefinitiveDownloader/0.1'

    def close(self):
        self.session.close()

    def get(self, url, maximum=2_000_000):
        for _ in range(4):
            allowed_url(url, ['soundcloud.com', 'a-v2.sndcdn.com'])
            p = urlparse(url)
            if p.hostname == 'api-v2.soundcloud.com' and p.path != '/search/tracks':
                raise MusicError('Destino de catálogo SoundCloud inválido.')
            with self.session.get(url, timeout=(10, 20), stream=True, allow_redirects=False) as response:
                if response.is_redirect:
                    url = urljoin(url, response.headers.get('Location', ''))
                    continue
                return bounded_response(response, maximum)
        raise MusicError('Muitos redirecionamentos no SoundCloud.')

    def resolve(self, url):
        page = self.get(track_url(url)).decode('utf-8')
        marker = re.search(r'window\.__sc_hydration\s*=\s*', page)
        if not marker:
            raise MusicError('O leitor público SoundCloud não encontrou a faixa.')
        try:
            rows, _ = json.JSONDecoder().raw_decode(page[marker.end():])
            row = next(r['data'] for r in rows if r.get('hydratable') == 'sound')
            result = candidate(row)
        except (ValueError, KeyError, StopIteration, TypeError, AttributeError):
            raise MusicError('Resposta pública SoundCloud inválida.') from None
        if result['pageUrl'] != url:
            raise MusicError('A faixa SoundCloud mudou de referência; confira a versão.')
        return result

    def search(self, query):
        page = self.get('https://soundcloud.com/').decode('utf-8')
        client_id = None
        assets = re.findall(r'<script[^>]+src="(https://a-v2\.sndcdn\.com/assets/[^"?]+\.js)"', page)
        for asset in assets[-3:][::-1]:
            script = self.get(asset, 4_000_000).decode('utf-8')
            match = re.search(r'client_id\s*:\s*["\x27]([A-Za-z0-9]{32})["\x27]', script)
            if match:
                client_id = match[1]
                break
        if client_id is None:
            raise MusicError('O identificador público SoundCloud mudou.')
        url = requests.Request('GET', 'https://api-v2.soundcloud.com/search/tracks',
            params={'q': query, 'limit': 8, 'offset': 0, 'client_id': client_id}).prepare().url
        payload = json.loads(self.get(url))
        rows = payload.get('collection')
        if not isinstance(rows, list) or len(rows) > 8:
            raise MusicError('Resposta de busca SoundCloud inválida.')
        result = []
        for row in rows:
            try:
                result.append(candidate(row))
            except MusicError:
                continue
        return result


def search(query):
    catalog = PublicCatalog()
    try:
        return catalog.search(query)
    finally:
        catalog.close()
