"""Pack the converted 2D assets with the ZX0 tools already used by MDSDRV."""
import hashlib
import json
import os
import re
import struct
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / 'build'
OUT = BUILD / 'packed-2d'
SCRATCH_BYTES = 0x1800
MAP_BYTES = 0x2000


def take_payload(source, label):
    """Remove a numeric dc.w/dc.l payload from a generated include."""
    start = re.search(rf'^{re.escape(label)}:[^\n]*\n', source, re.M)
    assert start, label
    end = start.end()
    data = bytearray()
    for line in source[end:].splitlines(keepends=True):
        fields = re.fullmatch(r'\s+dc\.([wl])\s+([^;\n]+)(?:;[^\n]*)?\n', line)
        if not fields:
            break
        size = 2 if fields[1] == 'w' else 4
        for value in fields[2].split(','):
            data.extend(int(value.strip().removeprefix('$'), 16).to_bytes(size, 'big'))
        end += len(line)
    assert data, label
    return source[:start.start()] + source[end:], bytes(data)


def main():
    driver = Path(os.environ.get('MEGASVP_MDSDRV', ROOT.parent / 'MDSDRV')).resolve()
    salvador = driver / 'tools/salvador.exe'
    source = driver / 'src/mdssub.inc'
    if not salvador.is_file() or not source.is_file():
        raise FileNotFoundError('Configure MEGASVP_MDSDRV con MDSDRV 0.6 y Salvador.')
    macros = source.read_text(encoding='latin-1')
    unpack = re.search(r'^mds_z80_unpack[ \t]+macro\b.*?^[ \t]+endm\b[^\n]*', macros, re.M | re.S)
    if not unpack:
        raise RuntimeError('Configure MEGASVP_MDSDRV con Salvador y el decodificador ZX0 de MDSDRV 0.6.')
    OUT.mkdir(exist_ok=True)
    (OUT / 'zx0.inc').write_text(unpack[0] + '\n', encoding='ascii')
    packed = bytearray()
    assets = {}
    shared = {}

    with tempfile.TemporaryDirectory(dir=OUT) as tmp:
        raw, stream = Path(tmp) / 'raw.bin', Path(tmp) / 'packed.zx0'

        def add(label, data, source, limit=SCRATCH_BYTES):
            assert 0 < len(data) <= limit and len(data) % 4 == 0, (label, len(data), limit)
            assert label not in assets
            if data not in shared:
                raw.write_bytes(data)
                subprocess.run([str(salvador), '-c', str(raw), str(stream)],
                               check=True, stdout=subprocess.DEVNULL)
                start = len(packed)
                packed.extend(struct.pack('>H', len(data)))
                packed.extend(stream.read_bytes())
                if len(packed) % 2:
                    packed.append(0)
                shared[data] = (start, len(packed) - start)
            offset, size = shared[data]
            assets[label] = dict(source=source, offset=offset, bytes=size, raw_bytes=len(data),
                                 sha256=hashlib.sha256(data).hexdigest())

        def include(filename, labels):
            text = (BUILD / filename).read_text(encoding='ascii')
            for label in labels:
                text, data = take_payload(text, label)
                add(label, data, filename)
            (OUT / filename).write_text(text, encoding='ascii')

        filename = 'level-backgrounds.inc'
        text = (BUILD / filename).read_text(encoding='ascii')
        for label in re.findall(r'^(M4LbgImg[0-9A-F]+)(?=Tiles:)', text, re.M):
            text, tiles = take_payload(text, label + 'Tiles')
            text, tilemap = take_payload(text, label + 'Map')
            assert len(tilemap) in (4096, 8192), label
            add(label + 'Tiles', tiles, filename)
            add(label + 'Map', tilemap, filename, MAP_BYTES)
        (OUT / filename).write_text(text, encoding='ascii')

        for screen in ('controls', 'gameover', 'routemap', 'pepper', 'continue', 'space12'):
            filename = f'screen-{screen}.inc'
            prefix = f'M4Scr{screen.capitalize()}'
            text = (BUILD / filename).read_text(encoding='ascii')
            text, tiles = take_payload(text, prefix + 'Tiles')
            add(prefix + 'Tiles', tiles, filename)
            maps = []
            for label in re.findall(rf'^{prefix}Map\d+(?=:)', text, re.M):
                text, tilemap = take_payload(text, label)
                assert len(tilemap) == 2048, label
                if screen == 'space12':
                    maps.append(tilemap)
                else:
                    add(label, tilemap, filename)
            if screen == 'space12':
                assert len(maps) == 4
                # Four 32x32 views become one row-major 64x64 map.
                combined = b''.join(left[row:row + 64] + right[row:row + 64]
                                    for left, right in (maps[:2], maps[2:])
                                    for row in range(0, 2048, 64))
                add(prefix + 'Map', combined, filename, MAP_BYTES)
            (OUT / filename).write_text(text, encoding='ascii')

        include('screen-controls-obj.inc', ('M4CtlObjTiles',))
        include('continue-obj.inc', ('M4CnObjTiles',))
        include('routemap-data.inc', ('M4RmObjTiles', 'M4RmPlaneA'))
        include('level-messages.inc', ('M4LvMsgTiles',))

        filename = 'title-bg-tiles.md.bin'
        title = (BUILD / filename).read_bytes()
        assert len(title) == (302 + 10) * 32
        split = SCRATCH_BYTES
        add('M4TitlePatternsA1', title[:split], filename)
        add('M4TitlePatternsA2', title[split:302 * 32], filename)
        add('M4TitlePatternsB', title[302 * 32:], filename)
        for label, filename in (
            ('M4TitlePlaneB', 'title-bg-planeb.md.bin'),
            ('M4LevelBgTiles', 'corneria-bg-tiles.md.bin'),
            ('M4LevelBgPlaneB', 'corneria-bg-planeb.md.bin'),
            ('M4LevelHudTiles', 'level-hud-tiles.bin'),
        ):
            add(label, (BUILD / filename).read_bytes(), filename)

    (OUT / 'assets.bin').write_bytes(packed)
    lines = [
        '; Generated by tools/pack-backgrounds.py from local extraction outputs.',
        f'M4TitlePatternsA1Bytes equ {split}',
        'M4Packed2D:',
        "        incbin '../build/packed-2d/assets.bin'",
        'M4Packed2DEnd:',
    ]
    lines.extend(f'{label} equ M4Packed2D+${asset["offset"]:x}' for label, asset in assets.items())
    (OUT / 'assets.inc').write_text('\n'.join(lines) + '\n', encoding='ascii')
    raw_bytes = sum(row['raw_bytes'] for row in assets.values())
    report = dict(codec='ZX0', raw_bytes=raw_bytes, packed_bytes=len(packed), assets=assets)
    (OUT / 'assets.json').write_text(json.dumps(report, indent=2) + '\n', encoding='ascii')
    print(f'2D assets: {raw_bytes} -> {len(packed)} bytes ({len(assets)} resources)')


if __name__ == '__main__':
    main()
