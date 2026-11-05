"""Inventory the supplied score and match original SBNs against Star Fox USA.

No ROM or reference is modified. Runtime song numbers are bank dependent;
the soundtrack's file numbers are not SPC port-0 commands.
"""
import hashlib
import json
import re
import struct
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SF_SHA = '3857b5294ea8f7468849437bb2d8271564e8a0ff30774622e9c872bcbd53a84d'
REF = ROOT / 'ref/ultrastarfox-main/ultrastarfox-main/SF'  # native-inputs.py only
# SPC sound banks (SBN) inside Star Fox USA: name, ROM offset, size, SHA-256.
# Names follow the SF/SND/SG*.BIN files of UltraStarFox; all 38 are byte-
# identical to these ranges, which sbootapu's sndtbl (03:AEDE) uploads.
SBN_ROM = {
    'sgbgmd': (0x472b6, 2302, 'd5eae93e91bfcdf15a1a5a0d6a04c735469a83d369ccdfcb264102678f14527e'),
    'sgbgm11': (0x4fdfe, 301, '720e20f23ecebbf29d1ebdb3204b8fd24ae5714930516af62915a7ea8da04469'),
    'sgbgml': (0x57c53, 424, '2002d75ba93a64df797c8512d265ead5416adc8d810f7f596bf7360ed004ff42'),
    'sgbgmm': (0x67a33, 1372, '72ecb9e5ff04b0522438bd23ba483cfebb332648f29a6075095c814d760e9332'),
    'sgbgm2': (0x77c62, 894, '2945c933b7767f19b972c82cd787c9ec2a7f057b9b75c1c5c2e41706140fede0'),
    'sgbgmn': (0x7fbcd, 1054, 'fc5175c80305c7bd70167df9aa6cec8b38b5768d1310da914a8e6ca7d6e3aab7'),
    'sgbgmj': (0x87879, 1866, 'c631f306acbf19ca1f25bcb2035610493b7494ab0d52d6baf813887e4f1480db'),
    'sgbgm7': (0x8fb89, 683, 'fa341622e3e8166738c7f4ac57d5a0a47003a0345e1301b4db52dcca5162b808'),
    'sgbgm3': (0x8fe34, 453, '07c4a2fdcb1981454e7e15e15a16fa8eee6dcbe64e27661d5f68d7242ded7aa2'),
    'sgsound0': (0xc0000, 10434, '484e59b12907bd78d728d73f4c088e156a0b8f36fc587ebc143487e76adcea05'),
    'sgsound1': (0xc28c2, 29644, 'c75a25549e68e683afb28b16300c06c58141a36457094048863a92c73e85b3a5'),
    'sgsound2': (0xc9c8e, 13684, 'ecbc95f7767ec6bd8581f2e66c16a9f7e2629fd5cb5683f6cd1e5fb992920305'),
    'sgsound3': (0xcd202, 11696, 'bbee65106848ef2b243894b3da55d93518f477de720d503e18ea317794afc3fc'),
    'sgsound4': (0xcffb2, 4812, '5616078d4a37bc4789d99ceb4903fcc1226b21d3df7a30c1e8b335f7e9cd4e4d'),
    'sgsound5': (0xd127e, 37924, '62e10cb959d8bd08eb6457274b735c4400ed956387c418f630368c7517349519'),
    'sgsound6': (0xda6a2, 3868, 'bf53ccf658c257fd7df5043ccde0209eb2c7833d14b48b73c7fe2f6241d0ba1a'),
    'sgsound7': (0xdb5be, 23015, '86d160b133c7895c4d045b053bd3d3fb018b116a8d68515268611d81972e18a2'),
    'sgsound8': (0xe0fa5, 34256, '2a401f4c489b753956f70c9398af9e9878ec98dc074fd71bea14396465460d25'),
    'sgsound9': (0xe9575, 4478, 'ddddcf6915e9b4654777032405bdc91b7524fa2b137c56d29aa89cda37649670'),
    'sgsounda': (0xea6f3, 28103, '7bda7f11fafd498a6272b2f0fa8792ad6ec54751186fb9cbe3844de10d6c129d'),
    'sgbgma': (0xf14ba, 2983, '211fcb1b060b8a0a6e3feec713c86fe716095898edf165b221dfd20ec1c23aa2'),
    'sgbgmb': (0xf2061, 3262, '50056b5179084becf19892a130e5df71fae9d93007e2fcb8eebe9e90b5e8da91'),
    'sgbgmc': (0xf2d1f, 3110, '69cc0ca7fa5f1e29e2caa3cc1186de0dfa651b0fb7d611d4e2976a857fb2d05a'),
    'sgbgmo': (0xf3945, 2035, '065031fada62857862d8d681016aa4bfe361435f494a34cb11e879be319a99c1'),
    'sgbgme': (0xf4138, 3209, '7ed8cc38a5ddacbc8b3fd089dd6ad2ba83ce9be85a654f3b5d0c8ff8ebc70ca5'),
    'sgbgmf': (0xf4dc1, 3138, 'fc552c68b37416b6bbcfa7293bfb6188cc892785be01578322e234b11228af90'),
    'sgbgmg': (0xf5a03, 1715, '58b08ffbdd02ef9eca6dce1ee75fe9fa71494f55a96b71d36e26d28ea08ac571'),
    'sgbgmh': (0xf60b6, 2806, '6aba166fa8afeabd57fba5743de1006bd88a35a669a402a705a60aba8a3bd54a'),
    'sgbgmi': (0xf6bac, 1432, 'ff040b20e4d5d9a27e2cea39edff845d4256dba124b1818f1787509c71203b7a'),
    'sgbgmk': (0xf7144, 1794, '435540826fc06c6cbcd3327ea3c57bf1b78034822468d3b344b1599aa96afcce'),
    'sgbgmp': (0xf7846, 5681, 'b481b0b6d49eb5e83bb59272dd929df7908a912e592a723e8e8a794297d21185'),
    'sgbgm1': (0xf8e77, 1482, 'b7e2f7aa45ba52ac8e543babeff48f33149da255c0b5cf1703ea8ef2cd83ab82'),
    'sgbgm4': (0xf9441, 1527, '94f5e8cb4601139aea87fa87d580cff3a9bba6906535dcb43f67b74a1b82fc17'),
    'sgbgm5': (0xf9a38, 1298, 'f73faf77a556c3f9f27027ebcab97785561d72ce3f6dba1ca6f620ed88a6c513'),
    'sgbgm6': (0xf9f4a, 1086, 'c4feadc54025e0e9634dbebff063310dc9f3593e090c0923d7542eca12c22962'),
    'sgbgm8': (0xfa388, 1019, '9524cadf575f3e0b9ac646f01ed581590dbf91da46a59c490954f72a4d378d45'),
    'sgbgm9': (0xfa783, 2093, '19fdfd93c62cdc56b61dddc92f614de5dac4b5e39fb24e4e92c35dc4bb9d32a7'),
    'sgbgm10': (0xfafb0, 2101, '19f9f5310aa4ce326be1668c929c75f57bf2ece4ab199e17dba426788ffdd943'),
}


def sha(data):
    return hashlib.sha256(data).hexdigest()


def upload(data, ram):
    at, blocks = 0, []
    while at + 4 <= len(data):
        length, address = struct.unpack_from('<HH', data, at)
        at += 4
        if not length:
            break
        assert at + length <= len(data) and address + length <= 65536
        ram[address:address + length] = data[at:at + length]
        blocks.append(dict(address=address, size=length))
        at += length
    return blocks


def music_banks(rom, sources):
    """Decode the USA boot helpers and their *actual* sndtbl records."""
    names = ('init title ops training map 10 11 12 13 13b 14 15 16 20 21 22 23 '
             '24 25 26 30 31 32 33 34 35 36 37 continue bhole intro endseq staff '
             'gameover special').split()
    # sbootapu reads sndtbl via LDA.l at 03:B0F8 (operand at 03:B0F9).
    assert rom[0x1b0f8] == 0xbf
    pointer = int.from_bytes(rom[0x1b0f9:0x1b0fc], 'little')
    assert pointer & 0x8000
    table = (pointer >> 16) * 0x8000 + (pointer & 0x7fff)
    # All helpers share the first helper's prologue and tail, with a varying LDX operand.
    prefix, suffix = rom[0x1ad5d:0x1ad61], rom[0x1ad63:0x1ad68]
    result = []
    for index, name in enumerate(names):
        helper = 0x1ad5d + 11 * index
        code = rom[helper:helper + 11]
        assert code[:4] == prefix and code[6:] == suffix
        entry = struct.unpack_from('<H', code, 4)[0]
        at = table + entry
        initial = rom[at]; at += 1
        ram, loaded = bytearray(65536), []
        while True:
            pointer = int.from_bytes(rom[at:at + 3], 'little'); at += 3
            if pointer == 0:
                break
            size = struct.unpack_from('<H', rom, at)[0]; at += 2
            assert pointer & 0x8000
            offset = (pointer >> 16) * 0x8000 + (pointer & 0x7fff)
            data = rom[offset:offset + size]
            source = next((n for n, row in sources.items() if row.get('matches_selected_rom')
                           and row['offset'] == offset and row['size'] == size), None)
            assert source is not None, (name, hex(offset), size)
            upload(data, ram)
            loaded.append(source)
        songs = {number: struct.unpack_from('<H', ram, 0xfdc0 + (number - 1) * 2)[0]
                 for number in range(1, 20)}
        result.append(dict(name=name, helper=0x030000 | (helper & 0xffff),
            table_offset=entry, initial_command=initial, loaded=loaded, song_pointers=songs))
    return result


def sbn(name, rom=None):
    """SBN bytes of the named sound bank, read from Star Fox USA."""
    rom = rom or (ROOT / 'ref/Star Fox (USA).sfc').read_bytes()
    offset, size, digest = SBN_ROM[name]
    data = rom[offset:offset + size]
    assert sha(data) == digest, name
    return data


def inventory(*, include_arrangements=True):
    rom = (ROOT / 'ref/Star Fox (USA).sfc').read_bytes()
    assert sha(rom) == SF_SHA
    sources = {}
    for name in sorted(SBN_ROM):
        data = sbn(name, rom)
        offset = SBN_ROM[name][0]
        ram = bytearray(65536)
        blocks = upload(data, ram)
        pointers = {}
        for block in blocks:
            start, end = block['address'], block['address'] + block['size']
            for number in range(1, 20):
                entry = 0xfdc0 + (number - 1) * 2
                if start <= entry and entry + 2 <= end:
                    pointers[number] = struct.unpack_from('<H', ram, entry)[0]
        sources[name] = dict(matches_selected_rom=True,
            offset=offset, size=len(data), sha256=sha(data), blocks=blocks,
            song_pointers=pointers)
    tracks, samples = [], {}
    folders = (ROOT / 'mdsdrv-final').glob('[0-9]*') if include_arrangements else ()
    for folder in sorted(folders):
        mml = next(folder.glob('*.mml'))
        vgm = next(folder.glob('*.vgm'))
        text = mml.read_text()
        used = []
        for sid, name, rate in re.findall(r'@(\d+)\s+pcm\s+"([^"]+)"\s+rate=(\d+)', text):
            path = (folder / name).resolve()
            with wave.open(str(path)) as wav:
                size = round(wav.getnframes() * 5327 / wav.getframerate())
            identity = (sha(path.read_bytes()), int(rate))
            samples[identity] = size
            used.append(dict(instrument=int(sid), file=path.relative_to(ROOT).as_posix(),
                sha256=identity[0], rate=int(rate), bytes_at_5327=size))
        decisions = json.loads((folder / 'decisions.json').read_text())
        tracks.append(dict(key=folder.name.split('-', 1)[1], number=int(folder.name[:2]),
            title=vgm.stem, mml=mml.relative_to(ROOT).as_posix(), mml_sha256=sha(mml.read_bytes()),
            vgm=vgm.relative_to(ROOT).as_posix(), vgm_sha256=sha(vgm.read_bytes()),
            kind=decisions.get('Kind', 'fm-psg-pcm-arrangement'), samples=used,
            frames=struct.unpack_from('<I', vgm.read_bytes(), 0x18)[0] / 735))
    return dict(rom_sha256=SF_SHA, sbn_sources=sources, original_banks=music_banks(rom, sources), tracks=tracks,
        unique_music_pcm_bytes_at_5327=sum(samples.values()), unique_music_samples=len(samples),
        warning='PCM captures have no reconstructed loop. File numbers are not runtime music commands.')


def main():
    result = inventory()
    out = ROOT / 'build/audio-release'
    out.mkdir(parents=True, exist_ok=True)
    (out / 'catalog.json').write_text(json.dumps(result, indent=2) + '\n')
    print(f"{len(result['tracks'])} supplied cues; {result['unique_music_samples']} unique samples; "
          f"{result['unique_music_pcm_bytes_at_5327']} PCM bytes at 5327 Hz")
    for name, row in result['sbn_sources'].items():
        print(name, hex(row.get('offset', -1)), row.get('song_pointers', 'DIFFERS FROM USA'))


if __name__ == '__main__':
    main()
