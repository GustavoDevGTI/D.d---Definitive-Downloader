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


class CaptureLoginTests(unittest.TestCase):
    URL = 'https://www.instagram.com/reel/AbC123/'
    SESSION = [
        {'name': 'sessionid', 'value': '123%3Aabc%3A4', 'domain': '.instagram.com',
         'path': '/', 'expires': 2000000000},
        {'name': 'rur', 'value': '"CLN\054123:01f"', 'domain': '.instagram.com',
         'path': '/', 'expires': None},
    ]

    def extractor(self, error=None, info=None):
        extractor = MagicMock()
        extractor.__enter__.return_value = extractor
        if error is not None:
            extractor.extract_info.side_effect = error
        else:
            extractor.extract_info.return_value = info
        return extractor

    def test_only_known_platforms_need_login(self):
        self.assertEqual(capture_audio.login_platform(self.URL), 'instagram')
        self.assertEqual(capture_audio.login_platform('https://instagram.com/p/x/'), 'instagram')
        self.assertIsNone(capture_audio.login_platform('https://notinstagram.com/p/x/'))
        self.assertIsNone(capture_audio.login_platform('https://example.org/a'))

    def test_login_error_is_a_result_not_a_failure(self):
        error = Exception('ERROR: [Instagram] AbC123: Instagram sent an empty media '
                          'response. Check if this post is accessible ... use --cookies')
        with patch('capture_audio.YoutubeDL', return_value=self.extractor(error)):
            result = capture_audio.analyze(self.URL)
        self.assertEqual(result, {'loginRequired': 'instagram', 'sessionRejected': False,
                                  'pageUrl': self.URL})

    def test_session_is_used_and_rejection_reported(self):
        error = Exception('Instagram sent an empty media response')
        extractor = self.extractor(error)
        with patch('capture_audio.YoutubeDL', return_value=extractor):
            result = capture_audio.analyze(self.URL, self.SESSION)
        self.assertTrue(result['sessionRejected'])
        names = [call.args[0].name for call in extractor.cookiejar.set_cookie.call_args_list]
        self.assertEqual(names, ['sessionid', 'rur'])

    def test_session_cookies_stay_on_their_platform(self):
        for bad in (
            [{'name': 'sessionid', 'value': 'x', 'domain': '.example.org'}],
            [{'name': 'sessionid', 'value': 'a;b', 'domain': '.instagram.com'}],
            [{'name': 'bad name', 'value': 'x', 'domain': '.instagram.com'}],
            [{'name': 'a', 'value': 'x', 'domain': '.instagram.com'}] * 61,
            'sessionid=x',
        ):
            with self.assertRaises(MusicError):
                capture_audio.session_cookies('instagram', bad)
        with self.assertRaises(MusicError):
            capture_audio.session_cookies(None, self.SESSION)
        with self.assertRaises(MusicError):
            capture_audio.analyze('https://example.org/a', self.SESSION)

    def test_other_errors_keep_the_generic_message(self):
        with patch('capture_audio.YoutubeDL',
                   return_value=self.extractor(Exception('HTTP Error 404'))):
            with self.assertRaises(MusicError):
                capture_audio.analyze(self.URL)
        with patch('capture_audio.YoutubeDL',
                   return_value=self.extractor(Exception('login required'))):
            with self.assertRaises(MusicError):
                capture_audio.analyze('https://example.org/a')

    def test_successful_session_returns_items(self):
        info = {'id': 'AbC123', 'title': 'Reel', 'webpage_url': self.URL, 'duration': 12}
        with patch('capture_audio.YoutubeDL', return_value=self.extractor(info=info)):
            result = capture_audio.analyze(self.URL, self.SESSION)
        self.assertEqual(result['items'][0]['durationMs'], 12000)
        self.assertNotIn('loginRequired', result)


class PlatformLoginTests(unittest.TestCase):
    def test_platform_domains(self):
        cases = {
            'https://x.com/a/status/1': 'twitter', 'https://twitter.com/a/status/1': 'twitter',
            'https://www.tiktok.com/@a/video/1': 'tiktok', 'https://vm.tiktok.com/x/': 'tiktok',
            'https://www.facebook.com/reel/1': 'facebook', 'https://fb.watch/abc/': 'facebook',
            'https://bsky.app/profile/a/post/b': None, 'https://www.pinterest.com/pin/1/': None,
            'https://xx.com/a': None, 'https://facebook.com.evil.test/a': None,
        }
        for url, platform in cases.items():
            self.assertEqual(capture_audio.login_platform(url), platform, url)

    def test_messages_that_ask_for_login(self):
        asks = {
            'twitter': 'NSFW tweet requires authentication. Use --cookies',
            'tiktok': 'This post may not be comfortable for some audiences. Log in for access.',
            'facebook': 'No video found. Check if this post is accessible in your browser '
                        'without being logged-in.',
        }
        for platform, message in asks.items():
            self.assertTrue(capture_audio.needs_login(platform, Exception(message)), platform)
        self.assertFalse(capture_audio.needs_login(
            'tiktok', Exception('Your IP address is blocked from accessing this post')))
        self.assertFalse(capture_audio.needs_login(
            'twitter', Exception('No video could be found in this tweet')))
        self.assertFalse(capture_audio.needs_login(None, Exception('login required')))

    def test_cookies_of_another_platform_are_refused(self):
        x = [{'name': 'auth_token', 'value': 'a', 'domain': '.x.com'}]
        self.assertEqual(len(capture_audio.session_cookies('twitter', x)), 1)
        with self.assertRaises(MusicError):
            capture_audio.session_cookies('facebook', x)


if __name__ == '__main__':
    unittest.main()
