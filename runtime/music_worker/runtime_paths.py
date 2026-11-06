"""Platform-owned executables, never paths or shell options supplied by a link."""
import os
from pathlib import Path
import sys


def android_runtime():
    return os.name == 'posix' and os.environ.get('DD_ANDROID_RUNTIME') == '1'


def ffmpeg_path():
    if android_runtime():
        path = Path(os.environ.get('DD_ANDROID_FFMPEG', ''))
        if not path.is_absolute() or path.name != 'libffmpeg.so':
            raise RuntimeError('Invalid Android media runtime')
        return path
    path = Path(getattr(sys, '_MEIPASS', Path(__file__).parent)) / 'ffmpeg.exe'
    if not getattr(sys, 'frozen', False):
        import imageio_ffmpeg
        path = Path(imageio_ffmpeg.get_ffmpeg_exe())
    return path


def extractor_options():
    if not android_runtime():
        return {}
    path = Path(os.environ.get('DD_ANDROID_QJS', ''))
    if not path.is_absolute() or path.name != 'libqjs.so':
        raise RuntimeError('Invalid Android JavaScript runtime')
    return {'js_runtimes': {'quickjs': {'path': str(path)}}}


def android_health():
    if not android_runtime():
        return {}
    import subprocess
    from portable_crypto import block_decoder
    from common import MusicError
    decoded = block_decoder(bytes(8))(bytes.fromhex('4ef997456198dd78'), bytes(8))
    if decoded != bytes(8):
        raise MusicError('O processamento musical Android não passou na validação.')
    result = subprocess.run([str(ffmpeg_path()), '-nostdin', '-hide_banner', '-loglevel', 'error',
                             '-f', 'lavfi', '-i', 'anullsrc=r=44100:cl=mono', '-t', '0.05',
                             '-codec:a', 'libmp3lame', '-f', 'null', '-'],
                            stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                            stderr=subprocess.DEVNULL, timeout=15)
    if result.returncode:
        raise MusicError('O codec musical Android não passou na validação.')
    return {'platform': 'android', 'python': '.'.join(str(n) for n in sys.version_info[:3]),
            'codecValidated': True, 'blockVectorValidated': True}
