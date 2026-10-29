"""Credential-free controls for this owned operation only; no disk state."""
import json
import threading
import time


class TransferControl:
    def __init__(self, clock=time.monotonic, sleep=time.sleep):
        self._clock, self._sleep = clock, sleep
        self._lock = threading.Lock()
        self._paused = False
        self._generation = 0
        self._bytes = 0
        self._start = clock()

    def set_pause(self, enabled):
        with self._lock:
            if self._paused == enabled:
                return
            self._paused = enabled
            self._generation += 1
            self._bytes = 0
            self._start = self._clock()

    def consume(self, count):
        with self._lock:
            if not self._paused:
                return
            generation = self._generation
            self._bytes += max(0, count)
            target = self._start + self._bytes / 10240
        while True:
            with self._lock:
                if not self._paused or generation != self._generation:
                    return
            remaining = target - self._clock()
            if remaining <= 0:
                return
            self._sleep(min(0.1, remaining))

    def listen(self, stream):
        def read():
            while True:
                line = stream.readline(1025)
                if not line or len(line) > 1024:
                    return
                try:
                    message = json.loads(line)
                    if (isinstance(message, dict) and message.get('control') == 'pause'
                            and type(message.get('enabled')) is bool):
                        self.set_pause(message['enabled'])
                except (ValueError, TypeError):
                    return
        threading.Thread(target=read, daemon=True).start()
