"""Discover media on a requested page and download only the selected entry."""
import hashlib
import json
from pathlib import Path
from urllib.parse import urlparse

from yt_dlp import YoutubeDL
from common import MusicError, clean_text, emit
from runtime_paths import extractor_options
from transfer_progress import TransferProgress

MAX_ITEMS = 50
MAX_BYTES = 500 * 1024 * 1024
MAX_DURATION = 24 * 60 * 60 * 1000


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
        **extractor_options(),
    }


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


def analyze(url):
    url = page_url(url)
    emit('stage', message='Procurando áudios na página')
    try:
        with YoutubeDL(options()) as extractor:
            info = extractor.extract_info(url, download=False)
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


def download(source, directory, control):
    url = page_url(source.get('pageUrl'))
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
            info = extractor.extract_info(url, download=False)
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
