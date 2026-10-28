import unittest
from unittest.mock import patch
import requests
from Crypto.Cipher import Blowfish
from common import MusicError, allowed_url, check_duration
from deezer import DeezerSession, track_state
from deezer_audio import recording_key, decoded_blocks
from youtube_music import accept_song, verify_recording


class MusicPolicyTests(unittest.TestCase):
    def test_striped_audio_known_vector_and_fragmented_transport(self):
        key = bytes.fromhex('6c32636d67367064637d716c3d3b6363')
        self.assertEqual(recording_key('123'), key)
        blocks = [bytes([n]) * 2048 for n in range(7)]
        tail = b'partial tail' * 7
        encoded = b''.join(Blowfish.new(key, Blowfish.MODE_CBC, bytes(range(8))).encrypt(b)
            if i % 3 == 0 else b for i,b in enumerate(blocks)) + tail
        for chunk_size in [1, 137, 2048, 6144, 65536]:
            fragments = (encoded[i:i+chunk_size] for i in range(0,len(encoded),chunk_size))
            self.assertEqual(b''.join(decoded_blocks(fragments,'123')),b''.join(blocks)+tail)

    def test_track_state_decodes_json_without_evaluating_script(self):
        for tail in [';</script>', '</script>', ';window.other = {};</script>']:
            self.assertEqual(track_state('<script>window.__DZR_APP_STATE__ = '
                '{"DATA":{"SNG_ID":"123","SNG_TITLE":"A }; B"}}'+tail)['SNG_TITLE'], 'A }; B')
        for invalid in ['window.__DZR_APP_STATE__=alert(1)', 'window.__DZR_APP_STATE__=[]',
                        'window.__DZR_APP_STATE__={"DATA":null}', '<script>nothing</script>']:
            with self.assertRaises(MusicError):track_state(invalid)

    def test_only_catalog_audio_is_accepted(self):
        song={'resultType':'song','videoType':'MUSIC_VIDEO_TYPE_ATV','album':{'name':'Album'}}
        self.assertTrue(accept_song(song))
        for media in ['MUSIC_VIDEO_TYPE_OMV','MUSIC_VIDEO_TYPE_UGC','',None]:
            self.assertFalse(accept_song({**song,'videoType':media}))
            with self.assertRaises(MusicError):verify_recording({'musicVideoType':media})
        with self.assertRaises(MusicError):verify_recording({'musicVideoType':'MUSIC_VIDEO_TYPE_ATV','isLiveContent':True})

    def test_cookie_never_reaches_media_or_unrelated_host(self):
        session=DeezerSession('a'*192)
        try:
            prepare=lambda s,url:s.prepare_request(requests.Request('GET',url)).headers.get('Cookie','')
            self.assertIn('arl=',prepare(session.account,'https://www.deezer.com/'))
            for url in ['https://media.deezer.com/v1/get_url','https://example.invalid/','https://e-cdns-proxy-0.dzcdn.net/file']:
                self.assertNotIn('arl=',prepare(session.account,url))
                self.assertNotIn('arl=',prepare(session.media,url))
        finally:session.close()

    def test_media_destinations_and_duration_fail_closed(self):
        for url in ['http://x.dzcdn.net/a','https://dzcdn.net.evil.invalid/a','https://user:pass@x.dzcdn.net/a','https://127.0.0.1/a']:
            with self.assertRaises(MusicError):allowed_url(url,['dzcdn.net'])
        self.assertEqual(allowed_url('https://a.dzcdn.net/a',['dzcdn.net']),'https://a.dzcdn.net/a')
        for duration in [0,30000,215000]:
            with self.assertRaises(MusicError):check_duration(duration,212000)
        check_duration(212040,212000)


if __name__=='__main__':unittest.main()
