import functools
import json
import tempfile
import threading
import unittest
import wave
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from unittest.mock import MagicMock, patch

import capture_audio
from audio_files import finish, run_ffmpeg
from common import MusicError
from runtime_paths import ffmpeg_path


class CaptureAudioTests(unittest.TestCase):
    def test_rejects_non_web_urls_and_credentials(self):
        for url in ('file:///private/audio.mp3', 'data:audio/mp3;base64,aaa',
                    'https://user:password@example.org/a', 'not-a-url'):
            with self.assertRaises(MusicError):
                capture_audio.page_url(url)

    def test_analysis_is_bounded_and_does_not_download(self):
        extractor = MagicMock()
        extractor.__enter__.return_value = extractor
        extractor.extract_info.return_value = {
            '_type': 'playlist', 'title': 'Lista',
            'entries': [
                {'id': str(i), 'title': f'Áudio {i}',
                 'webpage_url': f'https://example.org/{i}', 'duration': 3}
                for i in range(51)
            ],
        }
        with patch('capture_audio.YoutubeDL', return_value=extractor):
            result = capture_audio.analyze('https://example.org/list')
        self.assertEqual(len(result['items']), 50)
        self.assertTrue(result['truncated'])
        extractor.extract_info.assert_called_once_with(
            'https://example.org/list', download=False)
        extractor.process_info.assert_not_called()
        self.assertLess(len(json.dumps(result).encode()), 32768)

    def test_unavailable_item_does_not_hide_other_audio(self):
        extractor = MagicMock()
        extractor.__enter__.return_value = extractor
        extractor.extract_info.return_value = {
            '_type': 'playlist', 'title': 'Lista', 'entries': [
                {'id': 'live', 'is_live': True, 'url': 'https://example.org/live'},
                {'id': 'audio', 'title': 'Áudio', 'url': 'https://example.org/audio'},
            ],
        }
        with patch('capture_audio.YoutubeDL', return_value=extractor):
            result = capture_audio.analyze('https://example.org/list')
        self.assertEqual(len(result['items']), 1)
        self.assertEqual(result['unavailableCount'], 1)

    def test_refuses_a_different_selected_entry(self):
        with tempfile.TemporaryDirectory() as folder:
            extractor = MagicMock()
            extractor.__enter__.return_value = extractor
            extractor.extract_info.return_value = {
                'id': 'different', 'title': 'Outro áudio',
                'webpage_url': 'https://example.org/audio',
            }
            source = capture_audio.candidate({
                'id': 'chosen', 'title': 'Escolhido',
                'webpage_url': 'https://example.org/audio',
            }, '')
            with patch('capture_audio.YoutubeDL', return_value=extractor):
                with self.assertRaises(MusicError):
                    capture_audio.download(source, Path(folder), None)
            extractor.process_info.assert_not_called()

    def test_generic_identity_changes_when_embedded_media_changes(self):
        first = {'id': 'page-1', 'title': 'Página', 'extractor_key': 'Generic',
                 'webpage_url': 'https://example.org/page',
                 'formats': [{'url': 'https://example.org/first.wav'}]}
        changed = {**first, 'formats': [{'url': 'https://example.org/other.wav'}]}
        self.assertNotEqual(capture_audio.candidate(first, '')['sourceId'],
                            capture_audio.candidate(changed, '')['sourceId'])

    def test_short_capture_keeps_catalog_duration_validation(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            source = root / 'short.wav'
            with wave.open(str(source), 'wb') as audio:
                audio.setnchannels(1)
                audio.setsampwidth(2)
                audio.setframerate(16000)
                audio.writeframes(bytes(3200))
            actual = capture_audio.candidate({
                'id': 'short', 'title': 'Curto',
                'webpage_url': 'https://example.org/short.wav', 'duration': .1,
            }, '')
            captured = root / 'captured'
            captured.mkdir()
            result = finish(source, actual, captured, ffmpeg_path(), 100,
                            require_cover=False)
            self.assertTrue(0 < result['durationMs'] < 1000)
            strict = root / 'strict'
            strict.mkdir()
            with self.assertRaisesRegex(MusicError, 'Duração diferente'):
                finish(source, actual, strict, ffmpeg_path(), 100)

    def test_real_local_page_selection_and_mp3_conversion(self):
        class Handler(SimpleHTTPRequestHandler):
            def log_message(self, *_):
                pass

        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            for name in ('first', 'second'):
                with wave.open(str(root / f'{name}.wav'), 'wb') as audio:
                    audio.setnchannels(1)
                    audio.setsampwidth(2)
                    audio.setframerate(22050)
                    audio.writeframes(bytes(22050 * 2 * 2))
            run_ffmpeg(ffmpeg_path(), [
                '-f', 'lavfi', '-i', 'color=c=black:s=32x32:r=5',
                '-i', str(root / 'first.wav'), '-t', '2',
                '-c:v', 'mpeg4', '-c:a', 'aac', str(root / 'clip.mp4')])
            (root / 'page.html').write_text(
                '<html><head><title>Captura local</title></head><body>'
                '<audio controls src="first.wav"></audio>'
                '<audio controls src="second.wav"></audio>'
                '<video controls src="clip.mp4"></video>'
                '</body></html>', encoding='utf-8')
            server = ThreadingHTTPServer(
                ('127.0.0.1', 0), functools.partial(Handler, directory=folder))
            thread = threading.Thread(target=server.serve_forever, daemon=True)
            thread.start()
            url = f'http://127.0.0.1:{server.server_port}/page.html'
            try:
                result = capture_audio.analyze(url)
                self.assertEqual(len(result['items']), 3)
                work = root / 'work'
                work.mkdir()
                selected = result['items'][2]
                path, actual = capture_audio.download(selected, work, None)
                self.assertEqual(path.suffix, '.mp4')
                verified = finish(path, actual, work, ffmpeg_path(), 0,
                                  require_cover=False)
                self.assertEqual(actual['sourceId'], selected['sourceId'])
                self.assertTrue(verified['decoded'])
                self.assertFalse(verified['coverEmbedded'])
                self.assertGreater(verified['durationMs'], 1000)
                self.assertTrue(Path(verified['path']).is_file())
            finally:
                server.shutdown()
                server.server_close()
                thread.join(timeout=3)
