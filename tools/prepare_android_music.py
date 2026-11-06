"""Reproducible Android worker data; binaries are supplied by Android AARs.

Normal builds require the checked-in lock. --resolve-lock is a maintainer action
for an explicit dependency change; no package is installed in the host Python.
"""
import argparse
import email.parser
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import subprocess
import sys
import tarfile
import urllib.request
import zipfile


def fetch(url, maximum=12_000_000):
    if not url.startswith(('https://pypi.org/', 'https://files.pythonhosted.org/')):
        raise ValueError('Dependency origin not allowed')
    with urllib.request.urlopen(url, timeout=40) as response:
        data = response.read(maximum + 1)
    if len(data) > maximum:
        raise ValueError('Dependency exceeds size limit')
    return data


def metadata(name, version):
    return json.loads(fetch(f'https://pypi.org/pypi/{name}/{version}/json', 2_000_000))


def safe_name(name):
    path = PurePosixPath(name)
    if path.is_absolute() or '..' in path.parts or '\\' in name or ':' in name:
        raise ValueError('Unsafe archive entry')
    return str(path)


def requirements(root):
    pins = [line.strip() for line in (root / 'runtime/music_android/requirements.txt').read_text().splitlines()
            if line.strip() and not line.lstrip().startswith('#')]
    if any(pin.count('==') != 1 for pin in pins):
        raise ValueError('Android dependencies must have exact versions')
    return {pin.split('==')[0].lower().replace('_', '-'): pin.split('==')[1] for pin in pins}


def pinned_files(cache, lock):
    for item in lock['packages']:
        name = item['filename']
        if Path(name).name != name:
            raise ValueError('Invalid dependency filename')
        path = cache / name
        if not path.is_file():
            path.write_bytes(fetch(item['url']))
        data = path.read_bytes()
        if hashlib.sha256(data).hexdigest() != item['sha256']:
            raise ValueError(f'Dependency checksum mismatch: {name}')
        yield item, data


def resolve(root, cache, lock_path):
    expected = requirements(root)
    pins = [f'{name}=={version}' for name, version in expected.items()]
    subprocess.run([sys.executable, '-m', 'pip', 'download', '--dest', str(cache),
                    '--only-binary=:all:', '--platform', 'any', '--python-version', '312',
                    *[pin for pin in pins if not pin.startswith('blowfish==')]], check=True)
    packages = []
    for path in sorted(cache.glob('*.whl')):
        with zipfile.ZipFile(path) as wheel:
            entry = next(n for n in wheel.namelist() if n.endswith('.dist-info/METADATA'))
            info = email.parser.BytesParser().parsebytes(wheel.read(entry))
        name, version = info['Name'], info['Version']
        if expected.get(name.lower().replace('_', '-')) != version:
            continue
        rows = metadata(name, version)['urls']
        row = next(r for r in rows if r['filename'] == path.name)
        packages.append({'name': name, 'version': version, 'filename': path.name,
                         'sha256': row['digests']['sha256'], 'url': row['url'], 'kind': 'wheel'})
    row = next(r for r in metadata('blowfish', expected['blowfish'])['urls'] if r['packagetype'] == 'sdist')
    packages.append({'name': 'blowfish', 'version': expected['blowfish'],
                     'filename': row['filename'], 'url': row['url'],
                     'sha256': row['digests']['sha256'], 'kind': 'source'})
    actual = {p['name'].lower().replace('_', '-'): p['version'] for p in packages}
    if actual != expected:
        raise ValueError('Dependency lock is incomplete')
    lock_path.write_text(json.dumps({'schema': 1, 'androidSdk': '0.18.1', 'packages': packages},
                                    indent=2) + '\n', encoding='utf-8')


def bundle(root, cache, lock_path, output):
    lock = json.loads(lock_path.read_text())
    actual = {item['name'].lower().replace('_', '-'): item['version'] for item in lock['packages']}
    if (lock.get('schema') != 1 or lock.get('androidSdk') != '0.18.1'
            or actual != requirements(root) or len(actual) != len(lock['packages'])):
        raise ValueError('Android dependency lock does not match the pinned requirements')
    files = {'entry.py': (root / 'runtime/music_android/entry.py').read_bytes()}
    for path in (root / 'runtime/music_worker').glob('*.py'):
        if not path.name.startswith('test_'):
            files[f'core/{path.name}'] = path.read_bytes()
    for item, data in pinned_files(cache, lock):
        if item['kind'] == 'wheel':
            if not item['filename'].endswith('-none-any.whl'):
                raise ValueError('Android dependency must be a portable wheel')
            with zipfile.ZipFile(io.BytesIO(data)) as wheel:
                if sum(entry.file_size for entry in wheel.infolist()) > 60_000_000:
                    raise ValueError('Dependency expands beyond the Android bundle limit')
                for entry in wheel.infolist():
                    if entry.is_dir():
                        continue
                    name = safe_name(entry.filename)
                    if name.endswith(('.so', '.dll', '.pyd', '.exe')) or entry.file_size > 20_000_000:
                        raise ValueError('Android data bundle must contain only portable modules')
                    files[f'deps/{name}'] = wheel.read(entry)
        elif item['kind'] == 'source' and item['name'] == 'blowfish':
            with tarfile.open(fileobj=io.BytesIO(data), mode='r:*') as source:
                for entry in source.getmembers():
                    name = PurePosixPath(safe_name(entry.name)).name
                    if entry.isfile() and (name == 'blowfish.py' or name.upper().startswith('LICENSE')):
                        if entry.size > 2_000_000:
                            raise ValueError('Portable source exceeds size limit')
                        files['deps/blowfish.py' if name == 'blowfish.py'
                              else 'licenses/blowfish-' + name] = source.extractfile(entry).read()
        else:
            raise ValueError('Unsupported Android dependency format')
    files['dependencies.lock.json'] = lock_path.read_bytes()
    if sum(len(value) for value in files.values()) > 80_000_000:
        raise ValueError('Android worker data bundle is too large')
    output.mkdir(parents=True, exist_ok=True)
    destination = output / 'dd_music_bundle.zip'
    temporary = output / 'dd_music_bundle.zip.part'
    with zipfile.ZipFile(temporary, 'w', compression=zipfile.ZIP_DEFLATED) as archive:
        for name, data in sorted(files.items()):
            item = zipfile.ZipInfo(safe_name(name), (1980, 1, 1, 0, 0, 0))
            item.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(item, data)
    temporary.replace(destination)
    digest = hashlib.sha256(destination.read_bytes()).hexdigest()
    (output / 'dd_music_bundle.sha256').write_text(digest + '\n', encoding='ascii')
    print(f'Android worker data: {len(files)} entries, {destination.stat().st_size} bytes, SHA-256 {digest}')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--root', type=Path, required=True)
    parser.add_argument('--cache', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--resolve-lock', action='store_true')
    args = parser.parse_args()
    args.cache.mkdir(parents=True, exist_ok=True)
    lock = args.root / 'runtime/music_android/dependencies.lock.json'
    if args.resolve_lock:
        resolve(args.root, args.cache, lock)
    bundle(args.root, args.cache, lock, args.output)


if __name__ == '__main__':
    main()
