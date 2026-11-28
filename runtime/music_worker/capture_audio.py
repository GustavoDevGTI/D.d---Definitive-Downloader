"""Discover media on a requested page and download only the selected entry."""
import hashlib
from http.cookiejar import Cookie
import json
from pathlib import Path
import re
from urllib.parse import urlparse

from yt_dlp import YoutubeDL
from common import MusicError, clean_text, emit
from runtime_paths import extractor_options
from transfer_progress import TransferProgress

MAX_ITEMS = 50
MAX_BYTES = 500 * 1024 * 1024
MAX_DURATION = 24 * 60 * 60 * 1000

# Platforms whose media may need the user's own session. The session comes only
# from the app's private login window; browser profiles are never read.
# Public posts of these platforms work without a session; private, restricted
# or age-gated ones ask for it (verified with yt-dlp 2026.11.23).
LOGIN_PLATFORMS = {
    'instagram': ('instagram.com',),
    'twitter': ('x.com', 'twitter.com'),
    'tiktok': ('tiktok.com',),
    'facebook': ('facebook.com', 'fb.watch'),
}
LOGIN_HINTS = ('empty media response', 'login required', 'logged-in', 'logged in',
               'locked behind the login', '--cookies', 'log in', 'requires authentication',
               'authentication required', 'sign in to')
MAX_COOKIES = 60


def login_platform(url):
    host = (urlparse(url).hostname or '').lower()
    for name, domains in LOGIN_PLATFORMS.items():
        if any(host == domain or host.endswith('.' + domain) for domain in domains):
            return name
    return None


def session_cookies(platform, session):
    """Validates cookies captured by the app for this platform only."""
    if session is None:
        return []
    if platform is None or not isinstance(session, list) or not 0 < len(session) <= MAX_COOKIES:
        raise MusicError('Sessão de login inválida para este endereço.')
    domains = LOGIN_PLATFORMS[platform]
    cookies = []
    for row in session:
        if not isinstance(row, dict):
            raise MusicError('Sessão de login inválida para este endereço.')
        name, value = row.get('name'), row.get('value')
        domain = str(row.get('domain') or '').lower()
        path = row.get('path') or '/'
        expires = row.get('expires')
        bare = domain.lstrip('.')
        if (not isinstance(name, str) or not re.fullmatch(r'[A-Za-z0-9_.-]{1,64}', name)
                or not isinstance(value, str) or len(value) > 4096
                or not re.fullmatch(r'[!-:<-~]*', value)
                or not any(bare == d or bare.endswith('.' + d) for d in domains)
                or not isinstance(path, str) or not path.startswith('/') or len(path) > 256
                or (expires is not None and (not isinstance(expires, int) or expires < 0))):
            raise MusicError('Sessão de login inválida para este endereço.')
        cookies.append(Cookie(
            version=0, name=name, value=value, port=None, port_specified=False,
            domain=domain, domain_specified=True, domain_initial_dot=domain.startswith('.'),
            path=path, path_specified=True, secure=True, expires=expires,
            discard=expires is None, comment=None, comment_url=None, rest={}))
    return cookies


def needs_login(platform, error):
    text = str(error).lower()
    return platform is not None and any(hint in text for hint in LOGIN_HINTS)


def page_url(value):
    if not isinstance(value, str) or len(value) > 2048 or any(ord(c) < 32 for c in value):
        raise MusicError('Endereço de captura inválido.')
    try:
        parsed = urlparse(value)
        if (parsed.scheme not in ('http', 'https') or not parsed.hostname
                or parsed.username or parsed.password):
            raise ValueError()
        parsed.port
    except ValueError:
        raise MusicError('Use um endereço HTTP ou HTTPS sem credenciais.') from None
    return value


def options(flat=True):
    return {
        'quiet': True, 'no_warnings': True, 'noprogress': True,
        'socket_timeout': 15, 'retries': 1, 'extractor_retries': 1,
        'fragment_retries': 1, 'skip_unavailable_fragments': False,
        'cachedir': False,
        'playlistend': MAX_ITEMS + 1, 'lazy_playlist': True,
        'extract_flat': 'in_playlist' if flat else False,
        'format': 'bestaudio/best', 'enable_file_urls': False,
        'allow_unplayable_formats': False,
        'cookiefile': None,
        **extractor_options(),
    }


def use_session(extractor, cookies):
    for cookie in cookies:
        extractor.cookiejar.set_cookie(cookie)


def entries(info):
    if not isinstance(info, dict):
        return
    if info.get('_type') in ('playlist', 'multi_video'):
        for index, item in enumerate(info.get('entries') or []):
            if index > MAX_ITEMS:
                break
            if isinstance(item, dict):
                yield item
    else:
        yield info


def candidate(info, fallback):
    if info.get('is_live') or info.get('live_status') in ('is_live', 'is_upcoming'):
        raise MusicError('Escolha um conteúdo concluído para extrair o áudio.')
    if info.get('has_drm'):
        raise MusicError('A fonte exige acesso protegido para este conteúdo.')
    reference = page_url(info.get('webpage_url') or info.get('original_url')
                         or info.get('url') or fallback)
    identity = str(info.get('id') or reference)
    if str(info.get('extractor_key') or info.get('extractor') or '').lower() == 'generic':
        streams = sorted({value.get('url') for value in info.get('formats') or []
                          if isinstance(value, dict) and isinstance(value.get('url'), str)})
        if not streams and isinstance(info.get('url'), str):
            streams = [info['url']]
        identity += '\0' + json.dumps(streams)
    duration = info.get('duration')
    milliseconds = round(duration * 1000) if isinstance(duration, (int, float)) else 0
    if not 0 <= milliseconds <= MAX_DURATION:
        raise MusicError('A duração está fora do limite de captura.')
    title = clean_text(info.get('track') or info.get('title') or info.get('id') or 'Áudio')[:200]
    return {
        'sourceId': hashlib.sha256((reference + '\0' + identity).encode()).hexdigest(),
        'kind': 'webAudio', 'recordingType': 'WEB_AUDIO',
        'title': title, 'artist': clean_text(info.get('artist') or info.get('uploader'))[:160],
        'album': clean_text(info.get('album'))[:160], 'durationMs': milliseconds,
        'pageUrl': reference, 'coverUrl': '', 'isrc': '',
    }


def analyze(url, session=None):
    url = page_url(url)
    platform = login_platform(url)
    cookies = session_cookies(platform, session)
    emit('stage', message='Procurando áudios na página')
    try:
        with YoutubeDL(options()) as extractor:
            use_session(extractor, cookies)
            try:
                info = extractor.extract_info(url, download=False)
            except Exception as error:
                if needs_login(platform, error):
                    # A normal result: the app opens its login window and retries.
                    return {'loginRequired': platform, 'sessionRejected': bool(cookies),
                            'pageUrl': url}
                raise
            result, seen = [], set()
            truncated = False
            unavailable = 0
            for item in entries(info):
                if len(result) == MAX_ITEMS:
                    truncated = True
                    break
                try:
                    source = candidate(item, url)
                except MusicError:
                    unavailable += 1
                    continue
                if source['sourceId'] in seen:
                    continue
                if len(json.dumps(result + [source]).encode()) > 24000:
                    truncated = True
                    break
                seen.add(source['sourceId'])
                result.append(source)
        if not result:
            raise MusicError('Nenhum áudio compatível foi encontrado nesta página.')
        return {'title': clean_text(info.get('title') or 'Capturas de áudio')[:160],
                'pageUrl': url, 'items': result, 'truncated': truncated,
                'unavailableCount': unavailable}
    except MusicError:
        raise
    except Exception:
        raise MusicError('Não foi possível analisar este endereço. Confira o link e o acesso ao conteúdo.') from None


def download(source, directory, control, session=None):
    url = page_url(source.get('pageUrl'))
    platform = login_platform(url)
    cookies = session_cookies(platform, session)
    meter = TransferProgress()

    def progress(event):
        received = event.get('downloaded_bytes') or 0
        total = event.get('total_bytes')
        if received > MAX_BYTES or (total and total > MAX_BYTES):
            raise MusicError('O áudio ultrapassa o limite de 500 MB.')
        if control is not None:
            previous = progress.received
            control.consume(max(0, received - previous))
        progress.received = received
        meter.update(received, total or event.get('total_bytes_estimate'),
                     estimated=not total, force=event.get('status') == 'finished')

    progress.received = 0
    config = options(flat=False)
    config.update({
        'outtmpl': str(directory / 'source.%(ext)s'),
        'progress_hooks': [progress], 'max_filesize': MAX_BYTES,
        'overwrites': False, 'continuedl': False,
        'hls_prefer_native': True,
    })
    emit('stage', message='Recebendo o áudio escolhido')
    try:
        with YoutubeDL(config) as extractor:
            use_session(extractor, cookies)
            try:
                info = extractor.extract_info(url, download=False)
            except Exception as error:
                if needs_login(platform, error):
                    raise MusicError('A plataforma pediu login novamente. Analise o link em '
                                     'Capturar áudio para entrar.') from None
                raise
            chosen = None
            for item in entries(info):
                actual = candidate(item, url)
                if actual['sourceId'] == source.get('sourceId'):
                    chosen = item
                    break
            if chosen is None:
                raise MusicError('O áudio escolhido mudou. Analise a página novamente.')
            extractor.process_info(chosen)
            path = Path(extractor.prepare_filename(chosen)).resolve()
        if (not path.is_file() or not path.is_relative_to(directory.resolve())
                or not 1024 <= path.stat().st_size <= MAX_BYTES):
            raise MusicError('A fonte não entregou um arquivo de áudio utilizável.')
        return path, actual
    except MusicError:
        raise
    except Exception:
        raise MusicError('Não foi possível receber este áudio. Analise o link novamente ou verifique o acesso à fonte.') from None
