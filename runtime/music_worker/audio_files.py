"""Validation before publication, with source metadata kept separate from Spotify."""
from pathlib import Path
import subprocess
from mutagen.mp3 import MP3
from mutagen.id3 import APIC, TALB, TIT2, TPE1, TSRC, TXXX
from common import MusicError, check_duration, emit, public_bytes


def run_ffmpeg(ffmpeg, arguments):
    result = subprocess.run([str(ffmpeg), '-nostdin', '-hide_banner', '-loglevel', 'error', *arguments],
                            stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                            timeout=90, creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
    if result.returncode:
        raise MusicError('Não foi possível validar o áudio recebido.')


def finish(source, actual, directory, ffmpeg, expected_ms):
    emit('stage', message='Conferindo áudio completo e metadados')
    source = Path(source)
    if not source.is_file() or source.stat().st_size < 1024:
        raise MusicError('A fonte não entregou um arquivo de áudio completo.')
    target = Path(directory) / 'verified.mp3'
    if target.exists():
        raise MusicError('O arquivo temporário já existe.')
    run_ffmpeg(ffmpeg, ['-i', str(source), '-map', '0:a:0', '-vn', '-c:a', 'libmp3lame', '-q:a', '2', str(target)])
    media = MP3(target)
    duration = round(media.info.length * 1000)
    check_duration(duration, expected_ms)
    cover = public_bytes(actual.get('coverUrl', ''))
    if not (cover.startswith(b'\xff\xd8') or cover.startswith(b'\x89PNG\r\n\x1a\n')):
        raise MusicError('Não foi recebida uma capa válida para a faixa.')
    if media.tags is None:
        media.add_tags()
    media.tags.add(TIT2(encoding=3, text=actual['title']))
    media.tags.add(TPE1(encoding=3, text=actual['artist']))
    media.tags.add(TALB(encoding=3, text=actual['album']))
    if actual.get('isrc'):
        media.tags.add(TSRC(encoding=3, text=actual['isrc']))
    media.tags.add(TXXX(encoding=3, desc='Actual source', text=actual['pageUrl']))
    media.tags.add(APIC(encoding=3, mime='image/png' if cover.startswith(b'\x89PNG') else 'image/jpeg',
                        type=3, desc='Cover', data=cover))
    media.save(v2_version=3)
    run_ffmpeg(ffmpeg, ['-xerror', '-i', str(target), '-map', '0:a:0', '-f', 'null', '-'])
    if len(MP3(target).tags.getall('APIC')) != 1:
        raise MusicError('A capa não foi vinculada ao MP3.')
    return {'path': str(target.resolve()), 'actual': actual, 'durationMs': duration,
            'bytes': target.stat().st_size, 'coverEmbedded': True, 'decoded': True}
