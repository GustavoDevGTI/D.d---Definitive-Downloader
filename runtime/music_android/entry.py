"""APK-owned Android bootstrap for the shared bounded worker protocol."""
import json
import os
from pathlib import Path
import sys

# Establish a new group before importing providers or spawning FFmpeg. The
# parent receives the PID over its private pipe and can stop only this job tree.
if os.getpgrp() != os.getpid():
    os.setsid()
print(json.dumps({'event': 'started', 'pid': os.getpid(),
                  'group': os.getpgrp(),
                  'nonce': os.environ.get('DD_JOB_NONCE', '')}), flush=True)

# No provider code or child process runs before the parent validates ownership.
ack = json.loads(sys.stdin.buffer.raw.readline(1025))
if ack != {'start': os.environ.get('DD_JOB_NONCE', '')}:
    sys.exit(1)

bundle = Path(__file__).resolve().parent
sys.path[:0] = [str(bundle / 'core'), str(bundle / 'deps')]
os.environ['DD_ANDROID_RUNTIME'] = '1'

try:
    import main as worker
    sys.exit(worker.main())
except Exception:
    # Startup failures may contain local paths and dependency diagnostics.
    # Keep those out of logs/UI, just as account/provider failures are bounded.
    print(json.dumps({'event': 'error',
                      'message': 'Não foi possível iniciar o motor musical Android.'}), flush=True)
    sys.exit(1)
