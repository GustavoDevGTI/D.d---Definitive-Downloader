"""Music catalog only: no video search, no arbitrary URLs, no browser cookies."""
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


def verify_recording(details):
    if (details.get('musicVideoType') != ATV or details.get('isLiveContent')
            or details.get('isLive') or details.get('isTvfilmVideo')):
        raise MusicError('Videoclipe ou tipo de gravação não confirmado. Download bloqueado.')


class QuietLogger:
    def debug(self, *_): pass
    def warning(self, *_): pass
    def error(self, *_): pass


def download(candidate, directory, ffmpeg):
    from urllib.parse import urlparse, parse_qs
    page = urlparse(candidate['pageUrl'])
    if page.scheme != 'https' or page.hostname != 'music.youtube.com' or page.path != '/watch':
        raise MusicError('Somente faixas do catálogo YouTube Music são aceitas.')
    video = identifier(parse_qs(page.query).get('v', [''])[0], r'[A-Za-z0-9_-]{11}')
    if candidate.get('recordingType') != ATV:
        raise MusicError('Tipo musical não confirmado.')
    song = music_client().get_song(video)
    details = song.get('videoDetails', {})
    verify_recording(details)
    if details.get('videoId') != video or song.get('playabilityStatus', {}).get('status') != 'OK':
        raise MusicError('Esta faixa não está disponível no YouTube Music.')
    check_duration(int(details.get('lengthSeconds') or 0) * 1000, candidate['durationMs'])
    emit('stage', message='Recebendo faixa do YouTube Music')
    def progress(info):
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
        info = engine.extract_info('https://music.youtube.com/watch?v=' + video, download=True)
        if info.get('id') != video or info.get('is_live') or info.get('live_status') in ('is_live', 'post_live'):
            raise MusicError('A fonte não corresponde à faixa musical escolhida.')
        check_duration(round(float(info.get('duration') or 0) * 1000), candidate['durationMs'])
        path = Path(engine.prepare_filename(info))
    actual = dict(candidate)
    actual['title'] = clean_text(details.get('title'))
    actual['artist'] = clean_text(details.get('author')).removesuffix(' - Topic')
    actual['recordingType'] = ATV
    return path, actual
