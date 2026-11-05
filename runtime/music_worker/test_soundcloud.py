import tempfile
import unittest
from pathlib import Path
from unittest.mock import Mock, patch
from common import MusicError
from soundcloud_catalog import candidate, track_url
from soundcloud_audio import choose_format, download


def row(**values):
    return dict(id=123, title='Example', permalink_url='https://soundcloud.com/person/example',
        public=True, policy='ALLOW', streamable=True, duration=180000, full_duration=180000,
        artwork_url='https://i1.sndcdn.com/cover.jpg', user={'username':'Not necessarily the artist'},
        publisher_metadata=None, media={'transcodings':[
            {'url':'https://api-v2.soundcloud.com/media/example','format':{'protocol':'hls'}}]}, **values)


def audio_format(**values):
    result = dict(format_id='hls_aac_160k', ext='m4a', abr=160, vcodec='none',
        acodec='mp4a.40.2', protocol='m3u8_native', url='https://cf-media.sndcdn.com/stream.m3u8')
    result.update(values)
    return result


class SoundCloudPolicyTests(unittest.TestCase):
    def test_metadata_does_not_promote_uploader_to_artist(self):
        result = candidate(row())
        self.assertEqual(result['sourceId'], '123')
        self.assertEqual(result['artist'], '')
        self.assertNotIn('media', result)
        self.assertEqual(result['recordingType'], 'SOUNDCLOUD_TRACK')

    def test_reject_private_preview_drm_and_incomplete_metadata(self):
        base = row()
        for changes in [{'policy':'SNIP'}, {'policy':'BLOCK'}, {'public':False},
                {'duration':30000}, {'streamable':False}, {'id':'not-an-id'},
                {'media':{'transcodings':[{'snipped':True,'format':{'protocol':'hls'}}]}},
                {'media':{'transcodings':[{'format':{'protocol':'ctr-encrypted'}}]}}]:
            with self.subTest(changes=changes), self.assertRaises(MusicError):
                candidate({**base, **changes})

    def test_only_canonical_track_urls(self):
        for url in ['http://soundcloud.com/a/b','https://soundcloud.com.evil.org/a/b',
                'https://user:pass@soundcloud.com/a/b','https://soundcloud.com/a/b?secret_token=private',
                'https://soundcloud.com/a/sets/mix','https://soundcloud.com/a/b/s-private']:
            with self.subTest(url=url), self.assertRaises(MusicError):
                track_url(url)

    def test_complete_format_excludes_preview_and_unrelated_hosts(self):
        valid = audio_format()
        bad = [audio_format(format_id='hls_preview'),audio_format(has_drm=True),
            audio_format(url='https://evil.org/media'),audio_format(url='https://cf-media.sndcdn.com/preview/audio'),
            audio_format(protocol='m3u8'),audio_format(vcodec='h264')]
        self.assertEqual(choose_format({'formats':[*bad, valid]}), valid)
        current_cdn = audio_format(url='https://playback.media-streaming.soundcloud.cloud/media/stream.m3u8')
        self.assertEqual(choose_format({'formats':[current_cdn]}), current_cdn)
        for item in bad:
            with self.assertRaises(MusicError):choose_format({'formats':[item]})

    @patch('soundcloud_audio.yt_dlp.YoutubeDL')
    @patch('soundcloud_audio.PublicCatalog')
    def test_changed_source_id_rejected_before_transfer(self, catalog, ydl):
        selected = candidate(row())
        catalog.return_value.resolve.return_value = {**selected,'sourceId':'999'}
        with self.assertRaises(MusicError):download(selected, Path('unused'), Path('ffmpeg'))
        ydl.assert_not_called()

    @patch('soundcloud_audio.run_ffmpeg')
    @patch('soundcloud_audio.yt_dlp.YoutubeDL')
    @patch('soundcloud_audio.PublicCatalog')
    def test_exact_source_progress_pause_and_safe_result(self, catalog, ydl, ffmpeg):
        selected = candidate(row())
        catalog.return_value.resolve.return_value = selected
        engine = ydl.return_value.__enter__.return_value
        engine.params = {}
        info = {'id':'123','duration':180,'formats':[audio_format()]}
        engine.extract_info.return_value = info
        engine.process_ie_result.return_value = info
        engine.prepare_filename.return_value = 'received.m4a'
        control = Mock()
        path, actual = download(selected, Path('unused'), Path('ffmpeg'), control)
        options = ydl.call_args.args[0]
        options['progress_hooks'][0]({'downloaded_bytes':1000, 'total_bytes':2000})
        options['progress_hooks'][0]({'downloaded_bytes':2000,'total_bytes':2000,'status':'finished'})
        self.assertEqual([c.args[0] for c in control.consume.call_args_list], [1000,1000])
        self.assertIsNone(options['cookiesfrombrowser'])
        self.assertIsNone(options['cookiefile'])
        self.assertEqual(engine.params['format'], 'hls_aac_160k')
        self.assertEqual(actual, selected)
        ffmpeg.assert_called_once()
        self.assertIn('-xerror', ffmpeg.call_args.args[1])
        self.assertEqual(path, Path('received.m4a'))


if __name__ == '__main__':unittest.main()
