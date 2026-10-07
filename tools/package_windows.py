"""Package Windows viewers plus their transitive non-system DLL imports.

Copies only verified import dependencies and bundled dependency notices.
A failed collection never leaves a partially published output directory.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

API_PREFIXES = ('api-ms-win-', 'ext-ms-win-')

def imports(binary, objdump):
    output = subprocess.check_output([objdump, '-p', str(binary)], text=True)
    if 'file format pei-x86-64' not in output:
        raise ValueError(f'Not an x86-64 PE executable or DLL: {binary.name}')
    return re.findall(r'DLL Name:\s*(\S+)', output)

def collect(binaries, dll_dir, system_dir, objdump):
    available = {p.name.lower(): p for p in dll_dir.iterdir() if p.is_file()}
    system_names = {p.name.lower() for p in system_dir.iterdir() if p.is_file()}
    collected = {}
    pending = list(binaries)
    visited = set()
    while pending:
        binary = pending.pop()
        key = binary.resolve()
        if key in visited:
            continue
        visited.add(key)
        for name in imports(binary, objdump):
            lower = name.lower()
            if lower.startswith(API_PREFIXES):
                continue
            if lower in collected:
                continue
            source = available.get(lower)
            if source is None and lower in system_names:
                continue
            if source is None:
                raise FileNotFoundError(f'{binary.name} requires missing DLL {name}')
            collected[lower] = source
            pending.append(source)
    return sorted(collected.values(), key=lambda p: p.name.lower())

def package(viewer, headless, dll_dir, system_dir, license_dir, output, objdump, commit):
    if output.exists():
        raise FileExistsError(f'Refusing to replace existing output: {output}')
    if not license_dir.is_dir() or not any(p.is_file() for p in license_dir.rglob('*')):
        raise FileNotFoundError('Dependency license directory is missing or empty')
    dependencies = collect([viewer, headless], dll_dir, system_dir, objdump)
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='voxela-package-', dir=output.parent) as temporary:
        staging = Path(temporary) / 'package'
        staging.mkdir()
        shutil.copy2(viewer, staging / 'VoxelA.exe')
        shutil.copy2(headless, staging / 'VoxelA-headless.exe')
        for source in dependencies:
            shutil.copy2(source, staging / source.name)
        shutil.copytree(license_dir, staging / 'THIRD_PARTY_LICENSES')
        (staging / 'README.txt').write_text(
            'VoxelA Windows x64 terrain viewer prototype\n'
            'Extract the complete archive, then run VoxelA.exe.\n'
            'Requires Windows 10/11 x64 and an OpenGL 3.3-capable graphics driver.\n'
            'Mouse: left break, right place; 1-6: select block. Edits are not saved.\n'
            'WASD: pan; Space/Left Ctrl: height; Q/E: turn; +/-: zoom.\n'
            'Left Shift: faster movement; R: reset view; Escape: exit.\n'
            'This is a bounded editable terrain prototype; survival is unfinished.\n'
            'Keep the supplied DLLs beside the executable.\n'
            'VoxelA-headless.exe runs the terrain-generation demonstration.\n', encoding='utf-8')
        hashes = {str(p.relative_to(staging)).replace(os.sep, '/'):
                  hashlib.sha256(p.read_bytes()).hexdigest()
                  for p in sorted(staging.rglob('*')) if p.is_file()}
        (staging / 'build-info.json').write_text(json.dumps({
            'commit': commit, 'target': 'windows-x86_64', 'sha256': hashes,
        }, indent=2) + '\n', encoding='utf-8')
        staging.rename(output)
    return dependencies

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('viewer', 'headless', 'dll-dir', 'license-dir', 'output'):
        parser.add_argument('--' + name, type=Path, required=True)
    default_system = Path(os.environ.get('SystemRoot', 'C:/Windows')) / 'System32' if os.name == 'nt' else None
    parser.add_argument('--system-dir', type=Path, default=default_system)
    parser.add_argument('--objdump', default='objdump')
    parser.add_argument('--commit', required=True)
    args = parser.parse_args()
    if args.system_dir is None:
        parser.error("--system-dir is required outside Windows")
    dlls = package(args.viewer, args.headless, args.dll_dir, args.system_dir,
                   args.license_dir, args.output, args.objdump, args.commit)
    print(f'Packaged two executables and {len(dlls)} dependency DLLs in {args.output}')

if __name__ == '__main__':
    main()
