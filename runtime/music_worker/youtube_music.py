"""Audio first; explicit consent for last-resort clips or manually supplied YouTube links."""
from pathlib import Path
from ytmusicapi import YTMusic
import yt_dlp
import requests
from common import MusicError, check_duration, clean_text, emit, identifier

ATV = 'MUSIC_VIDEO_TYPE_ATV'


class TimedSession(requests.Session):
    def request(self, method, url, **kwargs):
        kwargs.setdefault('timeout', 20)
        return super().request(method, url, **kwargs)


def music_client():
    return YTMusic(requests_session=TimedSession())


def accept_song(row):
    return (row.get('resultType') == 'song' and row.get('videoType') == ATV
            and bool(row.get('album')) and not row.get('isLive'))


def search(query):
    rows = music_client().search(query, filter='songs', limit=8)
    result = []
    for row in rows[:24]:
        if not accept_song(row):
            continue
        video = identifier(row.get('videoId'), r'[A-Za-z0-9_-]{11}')
        result.append({
            'kind': 'youtubeMusic', 'recordingType': ATV,
            'title': clean_text(row.get('title')),
            'artist': ', '.join(clean_text(a.get('name')) for a in row.get('artists', [])[:8]),
            'album': clean_text(row.get('album', {}).get('name')),
            'durationMs': int(row.get('duration_seconds') or 0) * 1000,
            'pageUrl': 'https://music.youtube.com/watch?v=' + video,
            'coverUrl': (row.get('thumbnails') or [{}])[-1].get('url', ''),
            'explicit': row.get('isExplicit'), 'isrc': '',
        })
        if len(result) == 8:
            break
    return result


def verify_recording(details, authorization='catalog', kind='youtubeMusic', expected_type=None):
    if details.get('isLiveContent') or details.get('isLive') or details.get('isTvfilmVideo'):
        raise MusicError('Transmissão ao vivo ou filme não aceito como faixa.')
    media_type = details.get('musicVideoType')
    if kind == 'youtubeMusic':
        if media_type != ATV:
            raise MusicError('Tipo de faixa do catálogo não confirmado.')
    elif kind != 'youtube' or authorization not in ('manualLink', 'approvedVideo'):
        raise MusicError('Esta versão do YouTube precisa de escolha manual ou aprovação.')
    elif authorization == 'approvedVideo' and (media_type != 'MUSIC_VIDEO_TYPE_OMV' or expected_type != media_type):
        raise MusicError('O videoclipe não corresponde à versão aprovada.')


def source_video(candidate, authorization):
    from urllib.parse import urlparse, parse_qs
    page = urlparse(candidate.get('pageUrl', ''))
    kind = candidate.get('kind')
    host = 'music.youtube.com' if kind == 'youtubeMusic' else 'www.youtube.com'
    if (kind not in ('youtubeMusic', 'youtube') or page.scheme != 'https' or page.hostname != host
            or page.username or page.password or page.port not in (None, 443) or page.path != '/watch'
            or page.fragment or set(parse_qs(page.query)) != {'v'}):
        raise MusicError('Link do YouTube inválido.')
    video = identifier(parse_qs(page.query).get('v', [''])[0], r'[A-Za-z0-9_-]{11}')
    if kind == 'youtubeMusic' and candidate.get('recordingType') != ATV:
        raise MusicError('Tipo musical não confirmado.')
    if kind == 'youtube' and authorization not in ('manualLink', 'approvedVideo'):
        raise MusicError('Videoclipe sem aprovação. Download bloqueado.')
    if kind == 'youtube' and authorization == 'approvedVideo' and candidate.get('recordingType') != 'MUSIC_VIDEO_TYPE_OMV':
        raise MusicError('Versão aprovada inválida.')
    return video


def search_videos(query):
    # Separate operation: the Dart resolver calls this only after audio options.
    rows = music_client().search(query, filter='videos', limit=8)
    result = []
    for row in rows[:24]:
        if row.get('resultType') != 'video' or row.get('videoType') != 'MUSIC_VIDEO_TYPE_OMV' or row.get('isLive'):
            continue
        duration = int(row.get('duration_seconds') or 0) * 1000
        if not 1000 <= duration <= 3600000:
            continue
        video = identifier(row.get('videoId'), r'[A-Za-z0-9_-]{11}')
        result.append({'kind':'youtube', 'recordingType':'MUSIC_VIDEO_TYPE_OMV',
            'title':clean_text(row.get('title')), 'artist':', '.join(clean_text(a.get('name')) for a in row.get('artists', [])[:8]),
            'album':'', 'durationMs':duration, 'pageUrl':'https://www.youtube.com/watch?v='+video,
            'coverUrl':(row.get('thumbnails') or [{}])[-1].get('url',''), 'isrc':'', 'explicit':row.get('isExplicit')})
        if len(result) == 8: break
    return result


class QuietLogger:
    def debug(self, *_): pass
    def warning(self, *_): pass
    def error(self, *_): pass


def download(candidate, directory, ffmpeg, control=None, authorization='catalog'):
    video = source_video(candidate, authorization)
    song = music_client().get_song(video)
    details = song.get('videoDetails', {})
    verify_recording(details, authorization, candidate.get('kind'), candidate.get('recordingType'))
    if details.get('videoId') != video or song.get('playabilityStatus', {}).get('status') != 'OK':
        raise MusicError('Esta faixa não está disponível no YouTube Music.')
    check_duration(int(details.get('lengthSeconds') or 0) * 1000, candidate['durationMs'])
    emit('stage', message='Recebendo áudio do YouTube')
    received = 0
    def progress(info):
        nonlocal received
        current = int(info.get('downloaded_bytes') or 0)
        if current > 80_000_000: raise MusicError('O áudio ultrapassa o limite de 80 MB.')
        if control is not None:
            control.consume(max(0, current - received))
        received = current
        if info.get('status') == 'finished':
            emit('stage', message='Validando áudio e capa')
    options = {
        'format': 'bestaudio[ext=m4a]/bestaudio', 'noplaylist': True,
        'outtmpl': str(Path(directory) / 'received.%(ext)s'),
        'ffmpeg_location': str(ffmpeg), 'quiet': True, 'no_warnings': True,
        'logger': QuietLogger(), 'cachedir': False, 'socket_timeout': 20,
        'retries': 1, 'fragment_retries': 1, 'max_filesize': 80_000_000,
        'progress_hooks': [progress], 'overwrites': False,
    }
    with yt_dlp.YoutubeDL(options) as engine:
        info = engine.extract_info(candidate['pageUrl'], download=True)
        if info.get('id') != video or info.get('is_live') or info.get('live_status') in ('is_live', 'post_live'):
            raise MusicError('A fonte não corresponde à faixa musical escolhida.')
        check_duration(round(float(info.get('duration') or 0) * 1000), candidate['durationMs'])
        path = Path(engine.prepare_filename(info))
    actual = dict(candidate)
    actual['title'] = clean_text(details.get('title'))
    actual['artist'] = clean_text(details.get('author')).removesuffix(' - Topic')
    actual['recordingType'] = clean_text(details.get('musicVideoType'))
    return path, actual
