"""Status Saver: extracts the audio of a WhatsApp status the app copied locally.

Only the app's own copy is read (the Android adapter checks its location); the
result is a validated MP3 in an empty staging directory, like a download.
"""
from pathlib import Path

from audio_files import finish
from common import MusicError

EXTENSIONS = {'.mp4', '.3gp', '.mkv', '.webm', '.opus', '.ogg', '.m4a', '.aac', '.mp3'}
MAX_BYTES = 200 * 1024 * 1024


def extract(request, ffmpeg):
    path = Path(str(request.get('path') or ''))
    directory = Path(str(request.get('directory') or ''))
    title = request.get('title')
    if (not path.is_absolute() or not path.is_file()
            or path.suffix.lower() not in EXTENSIONS
            or not 1024 <= path.stat().st_size <= MAX_BYTES):
        raise MusicError('Status inválido ou acima de 200 MB.')
    if not directory.is_absolute() or not directory.is_dir() or any(directory.iterdir()):
        raise MusicError('A pasta temporária precisa estar vazia.')
    if (not isinstance(title, str) or not title.strip() or len(title) > 200
            or any(ord(c) < 32 for c in title)):
        raise MusicError('Nome do status inválido.')
    if not Path(ffmpeg).is_file():
        raise MusicError('O conversor de áudio não foi instalado.')
    actual = {'title': title, 'artist': 'WhatsApp', 'album': 'Status do WhatsApp',
              'pageUrl': '', 'coverUrl': ''}
    try:
        return finish(path, actual, directory, ffmpeg, 0, title, require_cover=False)
    except Exception:
        # Video statuses without sound end here, as well as damaged files.
        raise MusicError('Este status não tem áudio que possa ser extraído.') from None
