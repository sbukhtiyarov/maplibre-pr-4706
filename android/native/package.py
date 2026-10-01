"""Preserve published JVM/resources and replace native libraries with patched builds."""
import hashlib
import json
from pathlib import Path
import sys
import zipfile

def sha(data):
    return hashlib.sha256(data).hexdigest()

def verify(work):
    manifest = json.loads((work / 'manifest.json').read_text())
    if sha((work / 'patched.aar').read_bytes()) != manifest['aarSha256']:
        raise SystemExit('Cached patched AAR checksum mismatch')
    print('Patched AAR checksum verified')

def build(work, recipe, key):
    abis = ('x86_64', 'arm64-v8a')
    libs = {f'jni/{abi}/libmaplibre.so': (work / 'libs' / abi / 'libmaplibre.so').read_bytes() for abi in abis}
    if not all(data.startswith(b'\x7fELF') for data in libs.values()):
        raise SystemExit('Invalid native library')
    with zipfile.ZipFile(work / 'upstream.aar') as source:
        # Do not leave any unpatched ABI in the fixed artifact.
        entries = {n: source.read(n) for n in source.namelist() if not n.endswith('/') and not n.startswith('jni/')}
    originals = entries.copy()
    entries.update(libs)
    entries['META-INF/maplibre-4706/fix.patch'] = (recipe / 'fix.patch').read_bytes()
    entries['META-INF/maplibre-4706/LICENSE'] = (recipe / 'LICENSE').read_bytes()
    output = work / 'patched.aar'
    with zipfile.ZipFile(output, 'w', compression=zipfile.ZIP_DEFLATED) as archive:
        for name, data in sorted(entries.items()):
            info = zipfile.ZipInfo(name, (2026, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            archive.writestr(info, data)
    with zipfile.ZipFile(output) as archive:
        assert all(archive.read(n) == data for n, data in originals.items())
        assert {n for n in archive.namelist() if n.startswith('jni/')} == set(libs)
    manifest = {
        'sourceCommit': '753b7ae79563a1d5da27135d0f496fdce6aeb651',
        'sdkVersion': '11.11.0', 'recipeSha256': key,
        'patchSha256': sha((recipe / 'fix.patch').read_bytes()),
        'upstreamAarSha256': sha((work / 'upstream.aar').read_bytes()),
        'aarSha256': sha(output.read_bytes()),
        'ndk': '28.1.13356709', 'cmake': '3.31.6', 'buildType': 'Release',
        'nativeLibraries': {name: sha(data) for name, data in libs.items()},
    }
    (work / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    verify(work)

if __name__ == '__main__':
    if sys.argv[1] == 'verify':
        verify(Path(sys.argv[2]))
    elif sys.argv[1] == 'build':
        build(Path(sys.argv[2]), Path(sys.argv[3]), sys.argv[4])
    else:
        raise SystemExit('Expected build or verify')
