"""Real SAF destination automation, confined to a UUID fixture on the D.d AVD."""
import argparse
import json
import re
import shlex
import subprocess
import time
import uuid
import xml.etree.ElementTree as ET
from pathlib import Path
from urllib.parse import unquote


def main():
    parser = argparse.ArgumentParser()
    for name in ('adb', 'device', 'log', 'audio'):
        parser.add_argument('--' + name, required=True)
    args = parser.parse_args()
    prefix = [args.adb, '-s', args.device]
    package = 'br.com.definitivedownloader.app.integration'

    def adb(*items):
        return subprocess.check_output(prefix + list(items), stderr=subprocess.STDOUT, timeout=30).decode('utf-8')

    def shell(*items):
        return adb('shell', ' '.join(shlex.quote(str(item)) for item in items))

    if not adb('emu', 'avd', 'name').startswith('Definitive_API_36'):
        raise RuntimeError('Dedicated emulator required')

    def marker(name):
        end = time.monotonic() + 300
        while name not in Path(args.log).read_text(encoding='utf-8-sig', errors='replace'):
            if time.monotonic() > end:
                raise TimeoutError(name)
            time.sleep(.25)

    def tap(*names):
        end = time.monotonic() + 35
        while time.monotonic() < end:
            try:
                state = shell('uiautomator', 'dump', '/data/local/tmp/dd-managed-ui.xml')
                if 'dumped' not in state.lower():
                    continue
                root = ET.fromstring(shell('cat', '/data/local/tmp/dd-managed-ui.xml'))
                for node in root.iter('node'):
                    if node.get('enabled') != 'true':
                        continue
                    if any(node.get(key, '').casefold() in [n.casefold() for n in names] for key in ('text', 'content-desc')):
                        bounds = [int(n) for n in re.findall(r'\d+', node.get('bounds', ''))]
                        if len(bounds) == 4:
                            shell('input', 'tap', (bounds[0]+bounds[2])//2, (bounds[1]+bounds[3])//2)
                            return
            except (subprocess.SubprocessError, ET.ParseError):
                pass
            time.sleep(.5)
        raise TimeoutError(repr(names))

    token = uuid.uuid4().hex[:12]
    destination = '/sdcard/Documents/DdManaged-' + token
    def choose():
        tap('Pasta pública ou cartão SD')
        tap('DdManaged-' + token)
        tap('Use this folder', 'Usar esta pasta')
        tap('Allow', 'Permitir')
    try:
        shell('mkdir', '-p', destination)
        marker('ANDROID_MANAGED_CHOOSE')
        choose()
        marker('ANDROID_MANAGED_HIDE_DESTINATION')
        shell('rmdir', destination)  # Must still be empty; never recursive here.
        shell('run-as', package, 'touch', 'files/managed-hidden')
        marker('ANDROID_MANAGED_RESTORE_DESTINATION')
        shell('mkdir', destination)
        shell('run-as', package, 'touch', 'files/managed-restored')
        marker('ANDROID_MANAGED_DELETE_MEDIA')
        plan = json.loads(shell('run-as', package, 'cat', 'files/managed-plan.json'))
        document = unquote(plan['uri'].split('/document/', 1)[1])
        if not document.startswith('primary:Documents/DdManaged-' + token + '/') or not document.endswith('.mp3'):
            raise RuntimeError('Document outside the fixture destination')
        exact_file = '/sdcard/' + document.removeprefix('primary:')
        shell('rm', exact_file)
        shell('run-as', package, 'rm', 'files/managed-plan.json')
        shell('run-as', package, 'touch', 'files/managed-deleted')
        marker('ANDROID_MANAGED_REAUTHORIZE')
        choose()
        marker('ANDROID_MANAGED_VERIFIED')
        media = shell('find', destination, '-type', 'f').splitlines()
        audio = [f for f in media if f.endswith('.mp3')]
        manifests = [f for f in media if f.endswith('.m3u8')]
        if len(audio) != 1 or len(manifests) != 1:
            raise RuntimeError('Unexpected public files after replacement: ' + repr(media))
        if Path(audio[0]).name not in shell('cat', manifests[0]):
            raise RuntimeError('M3U8 does not refer to retained local media')
        shell('run-as', package, 'touch', 'files/managed-inspected')
        print('Verified public destination, write-only retry, content playback, manual recovery and exact replacement.')
    finally:
        if re.fullmatch(r'/sdcard/Documents/DdManaged-[a-f0-9]{12}', destination):
            shell('rm', '-rf', destination)


if __name__ == '__main__':
    main()
