import unittest
import io
import json
from contextlib import redirect_stdout
from unittest.mock import patch
from transfer_progress import TransferProgress
import youtube_music


class ProgressTests(unittest.TestCase):
    def test_throttles_and_reports_real_bytes_and_rate(self):
        now, sent = [0.0], []
        meter = TransferProgress(clock=lambda: now[0], send=lambda event, **data: sent.append((event, data)))
        meter.update(0, 8192, force=True)
        now[0] = 0.1
        meter.update(100, 8192)
        self.assertEqual(len(sent), 1)
        now[0] = 1.0
        meter.update(4096, 8192)
        self.assertEqual(sent[-1], ('progress', {'received': 4096, 'total': 8192,
            'estimatedTotal': False, 'bytesPerSecond': 4096.0}))
        now[0] = 1.1
        meter.update(8192, 8192, force=True)
        self.assertEqual(sent[-1][1]['received'], 8192)

    def test_unknown_or_stale_total_is_not_fabricated(self):
        sent = []
        meter = TransferProgress(send=lambda event, **data: sent.append(data))
        meter.update(1024, force=True)
        self.assertIsNone(sent[-1]['total'])
        meter.update(2048, 1024, estimated=True, force=True)
        self.assertIsNone(sent[-1]['total'])
        self.assertTrue(sent[-1]['estimatedTotal'])

    def test_youtube_hook_forwards_final_measurement_without_urls(self):
        class Client:
            def get_song(self, video):
                return {'videoDetails': {'videoId': video, 'lengthSeconds': '180',
                    'musicVideoType': 'MUSIC_VIDEO_TYPE_ATV', 'title': 'Faixa', 'author': 'Autor'},
                    'playabilityStatus': {'status': 'OK'}}

        class Downloader:
            def __init__(self, options): self.options = options
            def __enter__(self): return self
            def __exit__(self, *_): pass
            def extract_info(self, url, download):
                self.options['progress_hooks'][0]({'status': 'finished',
                    'downloaded_bytes': 8192, 'total_bytes': 8192,
                    'url': 'https://example.invalid/private?signature=never-log'})
                return {'id': 'abcdefghijk', 'duration': 180}
            def prepare_filename(self, info): return 'received.m4a'

        candidate = {'kind': 'youtubeMusic', 'recordingType': 'MUSIC_VIDEO_TYPE_ATV',
            'pageUrl': 'https://music.youtube.com/watch?v=abcdefghijk', 'durationMs': 180000}
        output = io.StringIO()
        with patch.object(youtube_music, 'music_client', return_value=Client()), \
                patch.object(youtube_music.yt_dlp, 'YoutubeDL', Downloader), redirect_stdout(output):
            youtube_music.download(candidate, '.', 'ffmpeg')
        events = [json.loads(line) for line in output.getvalue().splitlines()]
        progress = [event for event in events if event['event'] == 'progress']
        self.assertEqual(progress[-1]['received'], 8192)
        self.assertEqual(progress[-1]['total'], 8192)
        self.assertFalse(progress[-1]['estimatedTotal'])
        self.assertNotIn('signature', output.getvalue())


if __name__ == '__main__':
    unittest.main()
