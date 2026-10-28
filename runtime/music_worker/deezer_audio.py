"""Streaming decoder for the provider's 2048-byte striped block format."""
import hashlib
from Crypto.Cipher import Blowfish
from common import identifier


def recording_key(track_id):
    track_id = identifier(track_id, r'[1-9][0-9]{0,18}')
    digest = hashlib.md5(track_id.encode('ascii')).hexdigest().encode('ascii')
    format_seed = b'g4el58wc0zvf9na1'
    return bytes(digest[i] ^ digest[i + 16] ^ format_seed[i] for i in range(16))


def decoded_blocks(chunks, track_id):
    key = recording_key(track_id)
    pending = bytearray()
    index = 0
    for chunk in chunks:
        pending.extend(chunk)
        while len(pending) >= 2048:
            block = bytes(pending[:2048])
            del pending[:2048]
            if index % 3 == 0:
                block = Blowfish.new(key, Blowfish.MODE_CBC, bytes(range(8))).decrypt(block)
            yield block
            index += 1
    if pending:
        yield bytes(pending)
