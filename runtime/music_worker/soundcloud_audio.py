"""Exact public SoundCloud occurrence; reject previews before transferring audio."""
from pathlib import Path
import re
import yt_dlp
from common import MusicError, check_duration, emit, allowed_url
from soundcloud_catalog import PublicCatalog, track_url
from audio_files import run_ffmpeg
from transfer_progress import TransferProgress


class QuietLogger:
    def debug(self, *_): pass
    def warning(self, *_): pass
    def error(self, *_): pass


def choose_format(info):
    formats = [f for f in info.get('formats', [])
        if f.get('vcodec') == 'none' and not f.get('has_drm')
        and 'preview' not in str(f.get('format_id', '')).lower()
        and 'preview' not in str(f.get('format_note', '')).lower()
        and '/preview/' not in str(f.get('url', '')).lower()
        and f.get('protocol') in ('m3u8_native', 'http', 'https')]
    allowed = []
    for f in formats:
        try:
            allowed_url(f.get('url', ''), ['sndcdn.com', 'playback.media-streaming.soundcloud.cloud'])
            allowed.append(f)
        except MusicError:
            continue
    if not allowed:
        raise MusicError('O SoundCloud não entregou áudio completo utilizável.')
    return max(allowed, key=lambda f: (f.get('ext') == 'm4a', f.get('abr') or 0))


def download(candidate, directory, ffmpeg, control=None):
    url = track_url(candidate.get('pageUrl'))
    source_id = str(candidate.get('sourceId') or '')
    if (candidate.get('kind') != 'soundcloud' or candidate.get('recordingType') != 'SOUNDCLOUD_TRACK'
            or not re.fullmatch(r'[1-9][0-9]{0,18}', source_id)):
        raise MusicError('Identificação da versão SoundCloud inválida.')
    catalog = PublicCatalog()
    try:
        actual = catalog.resolve(url)
    finally:
        catalog.close()
    if actual['sourceId'] != source_id:
        raise MusicError('A faixa SoundCloud não corresponde ao ID escolhido.')
    check_duration(actual['durationMs'], candidate['durationMs'])
    emit('stage', message='Recebendo áudio do SoundCloud')
    meter = TransferProgress()
    received = 0
    def progress(info):
        nonlocal received
        count = int(info.get('downloaded_bytes') or 0)
        if count > 80_000_000:
            raise MusicError('O áudio ultrapassa o limite de 80 MB.')
        if control is not None:
            control.consume(max(0, count - received))
        received = max(received, count)
        total = info.get('total_bytes') or info.get('total_bytes_estimate')
        meter.update(count, int(total) if total else None,
            estimated=not bool(info.get('total_bytes')), force=info.get('status') == 'finished')
    options = {'noplaylist': True, 'quiet': True, 'no_warnings': True,
        'logger': QuietLogger(), 'cachedir': False, 'usenetrc': False,
        'cookiefile': None, 'cookiesfrombrowser': None, 'username': None, 'password': None,
        'socket_timeout': 20, 'retries': 1, 'fragment_retries': 1,
        'max_filesize': 80_000_000, 'progress_hooks': [progress], 'overwrites': False,
        'ffmpeg_location': str(ffmpeg), 'outtmpl': str(Path(directory) / 'received.%(ext)s')}
    with yt_dlp.YoutubeDL(options) as engine:
        info = engine.extract_info(url, download=False)
        if info.get('id') != source_id or info.get('is_live'):
            raise MusicError('A mídia não corresponde à faixa SoundCloud escolhida.')
        check_duration(round(float(info.get('duration') or 0) * 1000), candidate['durationMs'])
        chosen = choose_format(info)
        engine.params['format'] = chosen['format_id']
        result = engine.process_ie_result(info, download=True)
        path = Path(engine.prepare_filename(result))
    run_ffmpeg(ffmpeg, ['-xerror', '-i', str(path), '-map', '0:a:0', '-f', 'null', '-'])
    return path, actual
