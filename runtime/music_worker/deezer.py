"""Account session kept in memory; catalog, account and CDN transports are separate."""
import json
import re
from pathlib import Path
from urllib.parse import urlparse, urljoin
import requests
from common import MusicError, allowed_url, bounded_response, clean_text, emit, identifier, json_response
from deezer_audio import decoded_blocks


def catalog_track(row):
    return {'kind': 'deezerFull', 'recordingType': 'DEEZER_TRACK',
            'title': clean_text(row.get('title')), 'artist': clean_text(row.get('artist', {}).get('name')),
            'album': clean_text(row.get('album', {}).get('title')), 'durationMs': int(row.get('duration') or 0) * 1000,
            'pageUrl': 'https://www.deezer.com/track/' + identifier(row.get('id'), r'[1-9][0-9]{0,18}'),
            'coverUrl': row.get('album', {}).get('cover_big', ''),
            'isrc': clean_text(row.get('isrc')), 'explicit': row.get('explicit_lyrics')}


def search(query, isrc=''):
    with requests.Session() as public:
        if re.fullmatch(r'[A-Za-z]{2}[A-Za-z0-9]{3}[0-9]{7}', isrc or ''):
            with public.get('https://api.deezer.com/track/isrc:' + isrc, timeout=15, stream=True, allow_redirects=False) as r:
                row = json_response(r)
            if row.get('id') and not row.get('error'):
                return [catalog_track(row)]
        with public.get('https://api.deezer.com/search', params={'q': query, 'limit': 8},
                        timeout=15, stream=True, allow_redirects=False) as r:
            payload = json_response(r)
        return [catalog_track(row) for row in payload.get('data', [])[:8] if row.get('id')]


def track_state(html):
    # Decode exactly one JSON object. Scripts may omit the semicolon or append
    # more assignments; braces/semicolons inside JSON strings are ordinary text.
    anchor = re.search(r'window\.__DZR_APP_STATE__\s*=\s*', html)
    if not anchor:
        raise MusicError('A Deezer não forneceu os dados de reprodução desta faixa.')
    try:
        state, _ = json.JSONDecoder().raw_decode(html[anchor.end():].lstrip())
    except ValueError:
        raise MusicError('A Deezer retornou dados de reprodução inválidos.') from None
    if not isinstance(state, dict) or not isinstance(state.get('DATA'), dict):
        raise MusicError('A Deezer não forneceu os dados da faixa.')
    return state['DATA']


class DeezerSession:
    def __init__(self, arl):
        if not re.fullmatch(r'[A-Za-z0-9_-]{80,2048}', str(arl)):
            raise MusicError('Sessão Deezer inválida. Informe o valor localmente em Conexões.')
        self.account = requests.Session()
        self.account.headers.update({'Origin': 'https://www.deezer.com', 'Referer': 'https://www.deezer.com/'})
        self.account.cookies.set('arl', arl, domain='www.deezer.com', path='/', secure=True)
        self.media = requests.Session()  # No account cookies on license/media/CDN requests.

    def user(self):
        with self.account.get('https://www.deezer.com/ajax/gw-light.php',
                              params={'method': 'deezer.getUserData', 'input': 3, 'api_version': '1.0', 'api_token': ''},
                              timeout=15, stream=True, allow_redirects=False) as r:
            user = json_response(r).get('results', {}).get('USER', {})
        options = user.get('OPTIONS', {})
        if not user.get('USER_ID') or not options.get('license_token'):
            raise MusicError('A sessão Deezer expirou ou não foi autorizada.')
        return options

    def close(self):
        self.account.close()
        self.media.close()

    def download(self, candidate, directory):
        page = urlparse(candidate['pageUrl'])
        if page.scheme != 'https' or page.hostname != 'www.deezer.com':
            raise MusicError('Endereço Deezer inválido.')
        match = re.fullmatch(r'/track/([1-9][0-9]{0,18})', page.path)
        if not match:
            raise MusicError('Identificador Deezer inválido.')
        track_id = match[1]
        options = self.user()
        quality = 'MP3_320' if options.get('can_stream_hq') or options.get('web_sound_quality', {}).get('high') else 'MP3_128'
        with self.account.get('https://www.deezer.com/us/track/' + track_id, timeout=20,
                              stream=True, allow_redirects=False) as r:
            html = bounded_response(r, 5_000_000).decode('utf8', errors='replace')
        row = track_state(html)
        if not row.get('TRACK_TOKEN') or str(row.get('SNG_ID')) != track_id:
            raise MusicError('A Deezer não forneceu uma faixa completa compatível.')
        with self.media.post('https://media.deezer.com/v1/get_url', json={
            'license_token': options['license_token'], 'track_tokens': [row['TRACK_TOKEN']],
            'media': [{'type': 'FULL', 'formats': [{'cipher': 'BF_CBC_STRIPE', 'format': quality}]}],
        }, timeout=20, stream=True, allow_redirects=False) as r:
            data = json_response(r).get('data', [])
        if not data or data[0].get('errors'):
            raise MusicError('A Deezer não autorizou a faixa completa neste formato.')
        try:
            url = data[0]['media'][0]['sources'][0]['url']
        except (KeyError, IndexError, TypeError):
            raise MusicError('A Deezer não retornou uma fonte completa.') from None
        path = Path(directory) / 'received.mp3'
        emit('stage', message='Recebendo faixa da Deezer')
        for _ in range(4):
            allowed_url(url, ['dzcdn.net'])
            with self.media.get(url, timeout=(10, 20), stream=True, allow_redirects=False) as r:
                if r.is_redirect:
                    url = urljoin(url, r.headers.get('Location', ''))
                    continue
                if r.status_code != 200:
                    raise MusicError('A Deezer recusou o fluxo de áudio.')
                received = 0
                def bounded_chunks():
                    nonlocal received
                    for chunk in r.iter_content(65536):
                        received += len(chunk)
                        if received > 80_000_000:
                            raise MusicError('O áudio ultrapassou o limite de tamanho.')
                        yield chunk
                with path.open('xb') as target:
                    for block in decoded_blocks(bounded_chunks(), track_id):
                        target.write(block)
                expected = r.headers.get('Content-Length', '')
                if expected.isdigit() and received != int(expected):
                    raise MusicError('O arquivo recebido está incompleto.')
                actual = dict(candidate)
                actual.update(title=clean_text(row.get('SNG_TITLE')), artist=clean_text(row.get('ART_NAME')),
                              album=clean_text(row.get('ALB_TITLE')))
                return path, actual
        raise MusicError('Muitos redirecionamentos na mídia.')
