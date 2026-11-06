"""Real force-stop/restart of only the isolated D.d package; no production hooks."""
import argparse
import json
import re
import shlex
import subprocess
import tempfile
import threading
import time
import uuid
import xml.etree.ElementTree as ET
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import unquote


def main():
    parser = argparse.ArgumentParser()
    for name in ('root', 'adb', 'device', 'logs'):
        parser.add_argument('--' + name, required=True)
    parser.add_argument('--renamed-journal', action='store_true')
    args = parser.parse_args()
    root, logs = Path(args.root), Path(args.logs)
    logs.mkdir(parents=True, exist_ok=True)
    package = 'br.com.definitivedownloader.app.integration'
    prefix = [args.adb, '-s', args.device]
    token = uuid.uuid4().hex[:12]
    destination = '/sdcard/Documents/DdInterrupt-' + token
    audio = (root / 'assets/demo/tone.mp3').read_bytes()
    release = threading.Event()
    counts = {'publicado': 0, 'interrompido': 0}
    process = None

    def adb(*parts):
        return subprocess.check_output(prefix + list(parts), stderr=subprocess.STDOUT, timeout=35)

    def shell(*parts):
        return adb('shell', ' '.join(shlex.quote(str(p)) for p in parts)).decode('utf-8')

    if args.device != 'emulator-5560' or not adb('emu', 'avd', 'name').decode().startswith('Definitive_API_36'):
        raise RuntimeError('Use only the dedicated D.d emulator')

    class AudioHandler(BaseHTTPRequestHandler):
        def do_GET(self):
            name = self.path.removeprefix('/').removesuffix('.mp3')
            if name not in counts:
                self.send_error(404)
                return
            counts[name] += 1
            self.send_response(200)
            self.send_header('Content-Type', 'audio/mpeg')
            self.send_header('Content-Length', str(len(audio)))
            self.end_headers()
            try:
                if name == 'interrompido' and counts[name] == 1:
                    for offset in range(0, 16384, 2048):
                        self.wfile.write(audio[offset:offset+2048])
                        self.wfile.flush()
                        time.sleep(.12)
                    if not release.wait(90):
                        return
                    self.wfile.write(audio[16384:])
                else:
                    self.wfile.write(audio)
            except (BrokenPipeError, ConnectionResetError):
                pass  # Expected only when this fixture's client process stops.

        def log_message(self, *_):
            pass

    server = ThreadingHTTPServer(('127.0.0.1', 0), AudioHandler)
    server.daemon_threads = True
    port = server.server_port
    threading.Thread(target=server.serve_forever, daemon=True).start()
    adb('reverse', 'tcp:' + str(port), 'tcp:' + str(port))

    def put_config(phase):
        with tempfile.TemporaryDirectory(prefix='dd-interruption-config-') as folder:
            path = Path(folder) / 'config.json'
            path.write_text(json.dumps({'token': token, 'phase': phase, 'port': port, 'renamed': args.renamed_journal}), encoding='utf-8')
            remote = '/data/local/tmp/dd-interruption-' + token + '.json'
            adb('push', str(path), remote)
            shell('run-as', package, 'cp', remote, 'files/dd-interruption-config.tmp')
            shell('run-as', package, 'mv', 'files/dd-interruption-config.tmp', 'files/dd-interruption-config.json')
            shell('rm', remote)

    def wait_marker(log, marker, timeout=420):
        end = time.monotonic() + timeout
        while time.monotonic() < end:
            text = log.read_text(encoding='utf-8-sig', errors='replace')
            if re.search(r'(?m)^' + re.escape(marker) + r'\s*$', text):
                return
            if process.poll() is not None:
                raise RuntimeError('Test exited before ' + marker + ':\n' + text[-5000:])
            time.sleep(.15)
        raise TimeoutError(marker)

    def tap(*names):
        end = time.monotonic() + 35
        while time.monotonic() < end:
            try:
                result = shell('uiautomator', 'dump', '/data/local/tmp/dd-interruption-ui.xml')
                if 'dumped' not in result.lower():
                    continue
                state = ET.fromstring(shell('cat', '/data/local/tmp/dd-interruption-ui.xml'))
                for node in state.iter('node'):
                    if node.get('enabled') == 'true' and any(node.get(key, '').casefold() in [n.casefold() for n in names] for key in ('text', 'content-desc')):
                        box = [int(n) for n in re.findall(r'\d+', node.get('bounds', ''))]
                        if len(box) == 4:
                            shell('input', 'tap', (box[0]+box[2])//2, (box[1]+box[3])//2)
                            return
            except (subprocess.SubprocessError, ET.ParseError):
                pass
            time.sleep(.5)
        raise TimeoutError('DocumentsUI: ' + repr(names))

    def stop_at(log, marker, expected):
        wait_marker(log, marker)
        if counts != expected:
            raise RuntimeError('Unexpected automatic network work: ' + repr(counts))
        shell('am', 'force-stop', package)
        code = process.wait(timeout=45)
        if code == 0:
            raise RuntimeError('A killed test phase must not be reported as a passed Flutter test')
        alive = subprocess.run(prefix + ['shell', 'pidof', package], stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=15)
        if alive.stdout.strip():
            raise RuntimeError('Isolated process still alive')

    try:
        shell('mkdir', '-p', destination)
        for phase in ((1, 2) if args.renamed_journal else (1, 2, 3, 4)):
            log = logs / ('android-interruption-' + token + '-phase-' + str(phase) + '.log')
            with log.open('w', encoding='utf-8') as output:
                shell('am', 'force-stop', package)
                process = subprocess.Popen(['pwsh', '-NoProfile', '-File', str(root / 'tools/test_android.ps1'),
                    '-WorkspaceRoot', str(root), '-Device', args.device,
                    '-TestFile', 'integration_test/android_interruption_test.dart'], stdout=output, stderr=subprocess.STDOUT)
                wait_marker(log, 'DD_INTERRUPT_CONFIG')
                put_config(phase)
                if phase == 1:
                    wait_marker(log, 'DD_INTERRUPT_CHOOSE')
                    tap('Pasta pública ou cartão SD')
                    tap('DdInterrupt-' + token)
                    tap('Use this folder', 'Usar esta pasta')
                    tap('Allow', 'Permitir')
                    stop_at(log, 'DD_INTERRUPT_PUBLISHED', {'publicado': 1, 'interrompido': 0})
                elif phase == 2:
                    if args.renamed_journal:
                        wait_marker(log, 'DD_INTERRUPT_RENAMED_VERIFIED')
                        if counts != {'publicado': 1, 'interrompido': 0}:
                            raise RuntimeError('Rename recovery performed network work')
                        public = shell('find', destination, '-type', 'f').splitlines()
                        if len([p for p in public if p.endswith('.mp3')]) != 1 or len([p for p in public if p.endswith('.m3u8')]) != 1:
                            raise RuntimeError('Rename recovery duplicated or lost public files')
                        shell('run-as', package, 'touch', 'files/dd-interruption-inspected')
                        if process.wait(timeout=45) != 0:
                            raise RuntimeError('Rename recovery did not pass:\n' + log.read_text(encoding='utf-8', errors='replace')[-5000:])
                    else:
                        stop_at(log, 'DD_INTERRUPT_NETWORK', {'publicado': 1, 'interrompido': 1})
                        release.set()
                elif phase == 3:
                    wait_marker(log, 'DD_INTERRUPT_RETRY')
                    if counts != {'publicado': 1, 'interrompido': 1}:
                        raise RuntimeError('Startup performed network work')
                    shell('run-as', package, 'touch', 'files/dd-interruption-retry-checked')
                    wait_marker(log, 'DD_INTERRUPT_DELETE')
                    plan = json.loads(shell('run-as', package, 'cat', 'files/dd-interruption-delete.json'))
                    document = unquote(plan['uri'].split('/document/', 1)[1])
                    if not document.startswith('primary:Documents/DdInterrupt-' + token + '/') or not document.endswith('.mp3'):
                        raise RuntimeError('Deletion outside the exact fixture destination')
                    shell('rm', '/sdcard/' + document.removeprefix('primary:'))
                    shell('run-as', package, 'rm', 'files/dd-interruption-delete.json')
                    shell('run-as', package, 'touch', 'files/dd-interruption-deleted')
                    stop_at(log, 'DD_INTERRUPT_REVIEW', {'publicado': 1, 'interrompido': 2})
                else:
                    wait_marker(log, 'DD_INTERRUPT_APPROVED')
                    if counts != {'publicado': 1, 'interrompido': 2}:
                        raise RuntimeError('Review/startup/approval performed network work')
                    shell('run-as', package, 'touch', 'files/dd-interruption-approve-checked')
                    wait_marker(log, 'DD_INTERRUPT_VERIFIED')
                    if counts != {'publicado': 2, 'interrompido': 2}:
                        raise RuntimeError('Unexpected retry counts: ' + repr(counts))
                    public = shell('find', destination, '-type', 'f').splitlines()
                    mp3 = [p for p in public if p.endswith('.mp3')]
                    m3u = [p for p in public if p.endswith('.m3u8')]
                    if len(mp3) != 2 or len(m3u) != 1:
                        raise RuntimeError('Incomplete final public files: ' + repr(public))
                    playlist = shell('cat', m3u[0])
                    if not all(Path(path).name in playlist for path in mp3):
                        raise RuntimeError('Missing M3U8 reference')
                    shell('run-as', package, 'touch', 'files/dd-interruption-inspected')
                    if process.wait(timeout=45) != 0:
                        raise RuntimeError('Final verification did not pass:\n' + log.read_text(encoding='utf-8', errors='replace')[-5000:])
            stopped = phase == 1 or (not args.renamed_journal and phase in (2, 3))
            print('Phase', phase, 'verified; intentional stop' if stopped else 'passed', flush=True)
        print('Rename-journal fixture plus real stop verified.' if args.renamed_journal else 'Three real force-stops and four process starts verified.', 'HTTP requests:', counts, flush=True)
    finally:
        release.set()
        if process is not None and process.poll() is None:
            shell('am', 'force-stop', package)
            try:
                process.wait(timeout=20)
            except subprocess.TimeoutExpired:
                process.terminate()
        server.shutdown()
        server.server_close()
        adb('reverse', '--remove', 'tcp:' + str(port))
        if re.fullmatch(r'/sdcard/Documents/DdInterrupt-[a-f0-9]{12}', destination):
            shell('rm', '-rf', destination)
        # Preserve failed private journals for diagnosis; successful phase 4
        # removed only its exact database, registry rows and staging directory.
        print('Private logs:', logs, 'token:', token, flush=True)


if __name__ == '__main__':
    main()
