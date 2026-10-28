"""One bounded request per process. No browser profiles, token files or playlists."""
import json
import logging
from pathlib import Path
import sys
import traceback
from common import MusicError, clean_text, emit
import deezer
import youtube_music
from audio_files import finish

logging.disable(logging.CRITICAL)


def execute(request):
    operation = request.get('operation')
    if operation == 'health':
        return {'ready': True, 'protocol': 1}
    if operation == 'deezerConnect':
        session = deezer.DeezerSession(request.get('arl', ''))
        try:
            options = session.user()
            return {'connected': True, 'highQuality': bool(options.get('can_stream_hq') or options.get('web_sound_quality', {}).get('high'))}
        finally:
            session.close()
    if operation == 'search':
        query = request.get('query', '')
        if not isinstance(query, str) or not 2 <= len(query) <= 300:
            raise MusicError('A busca precisa de 2 a 300 caracteres.')
        if request.get('provider') == 'deezerFull':
            return {'candidates': deezer.search(query, clean_text(request.get('isrc')))}
        if request.get('provider') == 'youtubeMusic':
            return {'candidates': youtube_music.search(query)}
        raise MusicError('Fonte musical inválida.')
    if operation == 'download':
        candidate = request.get('candidate', {})
        directory = Path(request.get('directory', ''))
        if not directory.is_absolute() or not directory.is_dir() or any(directory.iterdir()):
            raise MusicError('A pasta temporária precisa estar vazia.')
        ffmpeg = Path(getattr(sys, '_MEIPASS', Path(__file__).parent)) / 'ffmpeg.exe'
        if not getattr(sys, 'frozen', False):
            import imageio_ffmpeg
            ffmpeg = Path(imageio_ffmpeg.get_ffmpeg_exe())
        if not ffmpeg.is_file():
            raise MusicError('O validador de áudio não foi instalado.')
        expected = int(candidate.get('durationMs') or 0)
        if not 1000 <= expected <= 3600000:
            raise MusicError('Duração da faixa não confirmada.')
        if candidate.get('kind') == 'youtubeMusic':
            source, actual = youtube_music.download(candidate, directory, ffmpeg)
        elif candidate.get('kind') == 'deezerFull':
            session = deezer.DeezerSession(request.get('arl', ''))
            try:
                source, actual = session.download(candidate, directory)
            finally:
                session.close()
        else:
            raise MusicError('Não é uma fonte de faixa completa.')
        return finish(source, actual, directory, ffmpeg, expected)
    raise MusicError('Operação musical inválida.')


def main():
    try:
        line = sys.stdin.buffer.readline(32769)
        if not line or len(line) > 32768:
            raise MusicError('Requisição excedeu o limite.')
        request = json.loads(line)
        if not isinstance(request, dict):
            raise MusicError('Requisição inválida.')
        result = execute(request)
        emit('result', result=result)
    except MusicError as error:
        emit('error', message=str(error))
        return 1
    except Exception as error:
        # Never echo exception text, account responses, cookies or signed URLs.
        causes=[]
        current=error
        for _ in range(6):
            causes.append({'type':type(current).__name__,'errno':getattr(current,'errno',None),'winerror':getattr(current,'winerror',None),
                           'missing_file':Path(current.filename).name if getattr(current,'filename',None) else None,
                           'frames':[{'file':Path(f.filename).name,'line':f.lineno,'function':f.name} for f in traceback.extract_tb(current.__traceback__)[-4:]]})
            next_error=getattr(current,'reason',None) or current.__cause__
            if not isinstance(next_error,BaseException):
                next_error=next((value for value in current.args if isinstance(value,BaseException)),None)
            if next_error is None or next_error is current:break
            current=next_error
        emit('diagnostic', category=type(error).__name__, frames=[
            {'file':Path(frame.filename).name,'line':frame.lineno,'function':frame.name}
            for frame in traceback.extract_tb(error.__traceback__)[-5:]],causes=causes)
        emit('error', message='A fonte musical não concluiu a operação. Confira a conexão e tente novamente.')
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
