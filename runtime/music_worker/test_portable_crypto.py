"""Independent vectors for the native and Android portable block backends."""
import os
import sys
import unittest
from unittest.mock import patch
from portable_crypto import block_decoder


class PortableBlockTests(unittest.TestCase):
    def test_known_blowfish_vector(self):
        self.assertEqual(block_decoder(bytes(8))(bytes.fromhex('4ef997456198dd78'), bytes(8)), bytes(8))

    @unittest.skipUnless(os.environ.get('DD_ANDROID_BUNDLE'), 'Android bundle opt-in')
    def test_android_bundle_backend_matches_fragmented_native_vector(self):
        from Crypto.Cipher import Blowfish
        from deezer_audio import decoded_blocks, recording_key
        bundle = os.environ['DD_ANDROID_BUNDLE']
        sys.path.insert(0, bundle + '/deps')
        self.addCleanup(sys.path.remove, bundle + '/deps')
        key = recording_key('123')
        blocks = [bytes([i]) * 2048 for i in range(7)]
        encoded = b''.join(Blowfish.new(key, Blowfish.MODE_CBC, bytes(range(8))).encrypt(block)
                           if i % 3 == 0 else block for i, block in enumerate(blocks)) + b'tail'
        with patch.dict(sys.modules, {'Crypto': None, 'Crypto.Cipher': None}):
            for chunk in [137, 2048, 65536]:
                parts = (encoded[i:i + chunk] for i in range(0, len(encoded), chunk))
                self.assertEqual(b''.join(decoded_blocks(parts, '123')), b''.join(blocks) + b'tail')


if __name__ == '__main__':
    unittest.main()
