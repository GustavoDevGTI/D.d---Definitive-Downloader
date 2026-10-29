"""Exercise the installed Zotify engine with a fresh, in-memory OAuth grant.

No saved credentials, password login, credential dump, or token arguments.
The parent enforces a wall-clock timeout on this isolated child process.
"""
import json
import logging
from pathlib import Path
import re
import sys
import traceback

logging.disable(logging.CRITICAL)
stage = "imports"
session = None
try:
    from librespot.core import Session
    from librespot.proto import Authentication_pb2 as Auth
    from librespot.audio.decoders import AudioQuality, VorbisOnlyAudioQuality
    from librespot.metadata import TrackId
    import requests
    from librespot.proto.spotify.login5.v3 import Login5_pb2

    original_request = requests.sessions.Session.request
    def observe_request(self, method, url, **kwargs):
        response = original_request(self, method, url, **kwargs)
        if url == "https://login5.spotify.com/v3/login":
            wire = {"stage": "login5", "status": response.status_code, "bytes": len(response.content)}
            if response.status_code == 200 and len(response.content) < 65536:
                try:
                    message = Login5_pb2.LoginResponse()
                    message.ParseFromString(response.content)
                    wire['fields'] = [field.name for field, _ in message.ListFields()]
                    if not message.HasField('ok'):
                        wire['error_enum'] = int(message.error)
                except Exception as error:
                    wire['diagnostic_parse_error'] = type(error).__name__
            print(json.dumps(wire), flush=True)
        return response
    requests.sessions.Session.request = observe_request

    secret = sys.stdin.readline(16385).strip()
    if not secret or len(secret) > 16384:
        raise ValueError("invalid input")
    configuration = (Session.Configuration.Builder().set_store_credentials(False)
                     .set_cache_enabled(False).build())
    builder = Session.Builder(configuration)
    builder.login_credentials = Auth.LoginCredentials(
        typ=Auth.AuthenticationType.AUTHENTICATION_SPOTIFY_TOKEN,
        auth_data=secret.encode("utf8"),
    )
    del secret
    stage = "session"
    session = builder.create()
    print(json.dumps({"stage": stage, "result": "ok"}), flush=True)
    stage = "audio"
    stream = session.content_feeder().load(
        TrackId.from_base62(sys.argv[1]),
        VorbisOnlyAudioQuality(AudioQuality.HIGH), False, None,
    )
    output = Path(sys.argv[2])
    received = 0
    reader = stream.input_stream.stream()
    with output.open("xb") as target:
        while True:
            block = reader.read(65536)
            if not block:
                break
            received += len(block)
            if received > 30_000_000:
                raise ValueError("size limit")
            target.write(block)
    print(json.dumps({"stage": stage, "result": "eof", "bytes": received}), flush=True)
except Exception as error:
    # Whitelisted classifications only: upstream messages may contain identifiers.
    classifications = re.findall(
        r"BadCredentials|PremiumAccountRequired|PermissionDenied|Unauthenticated|LoginFailed|HTTP (?:400|401|403|429)|ConnectionResetError",
        str(error),
    )
    frames = [{"file": Path(f.filename).name, "line": f.lineno, "function": f.name}
              for f in traceback.extract_tb(error.__traceback__)[-5:]]
    print(json.dumps({"stage": stage, "result": "error", "type": type(error).__name__, "classifications": classifications,
                      "attribute": error.name if isinstance(error, AttributeError) else None,
                      "frames": frames}), flush=True)
finally:
    if session is not None:
        session.close()
