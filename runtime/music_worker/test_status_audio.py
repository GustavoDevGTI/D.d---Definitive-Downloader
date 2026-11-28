import tempfile
import unittest
from pathlib import Path

from mutagen.mp3 import MP3

import status_audio
from audio_files import run_ffmpeg
from common import MusicError
from runtime_paths import ffmpeg_path


class StatusAudioTests(unittest.TestCase):
    def setUp(self):
        self.ffmpeg = ffmpeg_path()
        if not self.ffmpeg.is_file():
            self.skipTest('FFmpeg do motor ausente neste ambiente.')
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)

    def tearDown(self):
        self.temp.cleanup()

    def video(self, name, audio=True):
        path = self.root / name
        inputs = ['-f', 'lavfi', '-i', 'color=c=red:s=160x120:d=2']
        if audio:
            inputs += ['-f', 'lavfi', '-i', 'sine=frequency=440:duration=2']
        run_ffmpeg(self.ffmpeg, [*inputs, '-shortest', '-c:v', 'mpeg4',
                                 *(['-c:a', 'aac'] if audio else []), str(path)])
        return path

    def staging(self):
        directory = self.root / f'out-{len(list(self.root.iterdir()))}'
        directory.mkdir()
        return directory

    def test_video_status_becomes_tagged_mp3(self):
        result = status_audio.extract(
            {'path': str(self.video('status.mp4')), 'directory': str(self.staging()),
             'title': 'Status 27/11 14:30'}, self.ffmpeg)
        mp3 = MP3(result['path'])
        self.assertTrue(1500 <= result['durationMs'] <= 2500)
        self.assertEqual(str(mp3.tags['TIT2']), 'Status 27/11 14:30')
        self.assertEqual(str(mp3.tags['TALB']), 'Status do WhatsApp')
        self.assertTrue(result['decoded'])

    def test_video_without_sound_is_explained(self):
        with self.assertRaisesRegex(MusicError, 'não tem áudio'):
            status_audio.extract(
                {'path': str(self.video('mudo.mp4', audio=False)),
                 'directory': str(self.staging()), 'title': 'Mudo'}, self.ffmpeg)

    def test_inputs_are_validated(self):
        good = self.video('ok.mp4')
        text = self.root / 'nota.txt'
        text.write_bytes(b'x' * 2048)
        busy = self.staging()
        (busy / 'old.mp3').write_bytes(b'x')
        cases = [
            {'path': str(text), 'directory': str(self.staging()), 'title': 'A'},
            {'path': 'relativo.mp4', 'directory': str(self.staging()), 'title': 'A'},
            {'path': str(good), 'directory': str(busy), 'title': 'A'},
            {'path': str(good), 'directory': str(self.staging()), 'title': 'a\nb'},
            {'path': str(good), 'directory': str(self.staging()), 'title': ''},
        ]
        for request in cases:
            with self.assertRaises(MusicError):
                status_audio.extract(request, self.ffmpeg)


if __name__ == '__main__':
    unittest.main()
