"""Numeric, credential-free progress, throttled below the protocol output limit."""
import time
from common import emit


class TransferProgress:
    def __init__(self, clock=time.monotonic, send=emit):
        self.clock, self.send = clock, send
        self.last_time, self.last_bytes = clock(), 0

    def update(self, received, total=None, estimated=False, force=False):
        now = self.clock()
        elapsed = now - self.last_time
        if not force and elapsed < 0.5:
            return
        rate = (received - self.last_bytes) / elapsed if elapsed > 0 and received >= self.last_bytes else None
        self.send('progress', received=received,
                  total=total if total and total >= received else None,
                  estimatedTotal=bool(estimated), bytesPerSecond=rate)
        self.last_time, self.last_bytes = now, received
