"""Star Fox USA SBN/SPC effects -> signed PCM for the Mega Drive DAC.

Original driver executes OFFLINE in FFmpeg/libgme, never in the port. The SPC
harness sends one request through fl3/293F, then normal port polling resumes.
After the final effect releases its voice, KOFF prevents an absent music voice
from sustaining a restored instrument. No SFX patterns/instruments are replaced.
Requires FFmpeg with libgme: MEGASVP_FFMPEG or ffmpeg on PATH.
"""
from starfox_rom import rom_hex
import concurrent.futures
import hashlib
import json
import os
import shutil
import struct
import subprocess
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SHA = '3857b5294ea8f7468849437bb2d8271564e8a0ff30774622e9c872bcbd53a84d'
RATE = 5327  # NTSC YM timer A=1019, half rate: (7670453/144)/5/2.
IDS = list(range(1, 0xb0))  # original port3 range; B0..BF are included by the driver chains
BANKS = [0xc0000, 0xc28c2, 0xc9c8e, 0xcd202, 0xcffb2, 0xd127e,
         0xda6a2, 0xdb5be, 0xe0fa5, 0xe9575, 0xea6f3]


def upload(rom, begin, ram):
    at, blocks = begin, []
    while True:
        length, address = struct.unpack_from('<HH', rom, at)
        at += 4
        if not length:
            return at, blocks
        assert address + length <= 65536 and at + length <= len(rom)
        ram[address:address + length] = rom[at:at + length]
        blocks.append(dict(rom_offset=at, address=address, length=length))
        at += length


def main():
    rom = (ROOT / 'ref/Star Fox (USA).sfc').read_bytes()
    assert hashlib.sha256(rom).hexdigest() == SHA
    out = ROOT / 'build/sf-sfx'
    out.mkdir(exist_ok=True, parents=True)
    ram, banks = bytearray(65536), []
    for n, at in enumerate(BANKS):
        end, blocks = upload(rom, at, bytearray(65536))
        data = rom[at:end]
        (out / f'sgsound{n:x}.sbn').write_bytes(data)
        banks.append(dict(offset=at, bytes=len(data), sha256=hashlib.sha256(data).hexdigest(), blocks=blocks))
    assert hashlib.sha1(rom[BANKS[0]:BANKS[1]]).hexdigest() == '84a3411c5c6406b53716d40d64b59f1e55f0f27f'
    for at in [*BANKS[:3], BANKS[4]]:
        upload(rom, at, ram)  # core driver, common samples, orchestra samples
    original_call = bytes.fromhex(rom_hex(0xc00c3, 3))
    original_keyoff = bytes.fromhex(rom_hex(0xc02a7, 7))
    assert ram[0x4a3:0x4a6] == original_call
    ram[0x4a3:0x4a6] = bytes.fromhex('3f003f')
    header = bytearray(256)
    header[:33] = b'SNES-SPC700 Sound File Data v0.30'
    header[0x21:0x25] = bytes([0x1a, 0x1a, 0x1a, 30])
    header[0x25:0x27] = struct.pack('<H', 0x400)
    header[0x2b] = 0xef
    ffmpeg = os.environ.get('MEGASVP_FFMPEG') or shutil.which('ffmpeg')
    if not ffmpeg or not Path(ffmpeg).is_file():
        raise SystemExit('Falta FFmpeg con libgme: defina MEGASVP_FFMPEG o añada ffmpeg al PATH.')
    version = subprocess.run([ffmpeg, '-version'], check=True, capture_output=True, text=True).stdout.splitlines()[0]

    def render(sid):
        memory = bytearray(ram)
        profile = 'common_orchestra_plus_sound4'
        if sid == 0x0d:  # Corneria scramble voice bank, SOUND.ASM snd_data 10/20/30
            upload(rom, BANKS[5], memory)
            profile = 'corneria_voice'
        if sid in (0x13, 0x2a, 0xae): # map sound6: SRC28 = "good luck", including chains
            upload(rom, BANKS[6], memory)
            profile = 'map_voice'
        if sid == 0x67: # continue SBN9: SRC1C = "let's go"
            upload(rom, BANKS[9], memory)
            profile = 'continue_voice'
        stub = (bytearray.fromhex('e5803fd00ce801c5803f8f00033f3f296f') + original_call
                + bytes.fromhex('e407d007') + original_keyoff + bytes([0x6f]))
        stub[11] = sid
        memory[0x3f00:0x3f00 + len(stub)] = stub
        spc = out / f'{sid:02x}.spc'
        spc.write_bytes(header + memory + bytes(256))
        result = subprocess.run([ffmpeg, '-v', 'error', '-f', 'libgme', '-sample_rate', '32000',
            '-i', str(spc), '-t', '20', '-ar', str(RATE), '-ac', '1', '-f', 's16le', 'pipe:1'], capture_output=True, check=True)
        samples = struct.unpack('<' + 'h' * (len(result.stdout) // 2), result.stdout)
        active = [i for i, v in enumerate(samples) if abs(v) > 64]
        assert not active or active[-1] < RATE * 19, f'SFX {sid:02x} has not finished; extend capture'
        start, end = (max(0, active[0] - 27), min(len(samples), active[-1] + 108)) if active else (0, 0)
        pcm = bytes(max(-128, min(127, round(v / 256))) & 255 for v in samples[start:end])
        pcm += bytes((-len(pcm)) % 256)
        (out / f'{sid:02x}.pcm').write_bytes(pcm)
        with wave.open(str(out / f'{sid:02x}.wav'), 'wb') as wav:
            wav.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
            wav.writeframes(result.stdout[2 * start:2 * end])
        return dict(id=sid, pointer=struct.unpack_from('<H', ram, 0x109f + (sid - 1) * 2)[0],
                    priority=ram[0xfe0 + sid - 1] & 15, voice=ram[0xfe0 + sid - 1] >> 4, bytes=len(pcm),
                    removed_leading_samples=start, last_signal=active[-1] / RATE if active else 0,
                    rendered_silence=not active, bank_profile=profile,
                    pcm_sha256=hashlib.sha256(pcm).hexdigest())

    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        sounds = list(pool.map(render, IDS))
    # Continuous SPC ports are not port3 effect IDs. Capture steady-state noise
    # and loop short windows on MD; random evolution/stereo are deliberate DAC
    # adaptations, not additional SPC code executed by the cartridge.
    def engine(job):
        port, value, size = job
        memory = bytearray(ram)
        memory[0x3f00:0x3f04] = bytes([0x8f, value, port, 0x6f])
        tag = f'p{port}-{value:02x}'
        spc = out / f'{tag}.spc'
        spc.write_bytes(header + memory + bytes(256))
        result = subprocess.run([ffmpeg, '-v', 'error', '-f', 'libgme', '-sample_rate', '32000',
            '-i', str(spc), '-t', '2', '-ar', str(RATE), '-ac', '1', '-f', 's16le', 'pipe:1'], capture_output=True, check=True)
        samples = struct.unpack('<' + 'h' * (len(result.stdout) // 2), result.stdout)
        window = samples[RATE:RATE + size]
        assert any(abs(v) > 64 for v in window), tag
        pcm = bytes(max(-128, min(127, round(v / 256))) & 255 for v in window)
        (out / f'{tag}.pcm').write_bytes(pcm)
        return dict(port=port, value=value, bytes=size, tag=tag, pcm_sha256=hashlib.sha256(pcm).hexdigest())
    jobs = [(1, v, 512) for v in range(256) if v and v & 0x3f < 16]
    jobs += [(2, 0x80 | v, 768) for v in range(1, 16)]
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        engines = list(pool.map(engine, jobs))
    table = ['; Generated by extract-sf-sfx.py; record = pointer.l, length.l, priority.w, reserved.w', 'M4SfxTable:']
    data = ['; Generated effects, signed PCM, 5327 Hz, 256-byte alignment.',
            '; Skip Genplus in-ROM SVP state at 200000..240xxx, physical DRAM and cell windows.']
    for sid in range(0xb0):
        s = next((v for v in sounds if v['id'] == sid), None)
        table.append(f'        dc.l M4Sfx{sid:02X},{s["bytes"]}\n        dc.w {s["priority"]},{s["voice"]}' if s and s['bytes'] else '        dc.l 0,0\n        dc.w 0,0')
    table += ['M4EngineTable:']
    for v in range(256):
        e = next((s for s in engines if s['port'] == 1 and s['value'] == v), None)
        table.append(f'        dc.l M4Loop_{e["tag"].replace("-", "_")}' if e else '        dc.l 0')
    table += ['M4ObjectSoundTable:', '        dc.l 0']
    table += [f'        dc.l M4Loop_p2_{0x80 | v:02x}' for v in range(1, 16)]
    backgrounds = json.loads((ROOT / 'build/level-backgrounds.json').read_text())['backgrounds']
    table += ['M4SoundBgTable:']
    for number in range(256):
        bg = next((b['params'] for b in backgrounds if b['number'] == number), {})
        table.append(f'        dc.b {bg.get("inatunnel_16CB") or 0},{bg.get("gamemode_18C4") or 0}')
    assets = [dict(s, tag=f'{s["id"]:02x}', label=f'M4Sfx{s["id"]:02X}') for s in sounds if s['bytes']]
    assets += [dict(s, label=f'M4Loop_{s["tag"].replace("-", "_")}') for s in engines]
    unique = {}
    for s in assets:
        unique.setdefault(s['pcm_sha256'], []).append(s)
    # First-fit decreasing in explicit ROM banks, filling gaps with smaller
    # samples rather than discarding a bank's tail at the first large sample.
    # Genplus svp_t = $40000 bytes IRAM/DRAM + $500 SSP state (svp.h/ssp16.h).
    # Reserve through $241000, including $B00 margin, rather than $250000.
    banks_pcm = [[0x16000, 0x20000, []], [0x1b0000, 0x200000, []],
                 [0x241000, 0x300000, []], [0x320000, 0x390000, []],
                 [0x3b0000, 0x400000, []]]
    groups = list(unique.values())
    for aliases in sorted(groups, key=lambda a: -a[0]['bytes']):
        size = aliases[0]['bytes']
        if not size:
            continue
        for bank in banks_pcm:
            address = (bank[0] + 255) & ~255
            if address + size <= bank[1]:
                bank[2].append((address, aliases)); bank[0] = address + size
                break
        else:
            raise ValueError(f'Audio does not fit 4 MiB ROM: {aliases[0]["label"]}')
    def emit(bank):
        result = []
        for address, aliases in bank[2]:
            result += [f'        if *>${address:x}', '        inform 3,"Audio ROM bank overlap"', '        endif', f'        dcb.b ${address:x}-*,0']
            result += [f'{a["label"]}:' for a in aliases]
            source = aliases[0].get('file', f'../build/sf-sfx/{aliases[0].get("tag")}.pcm')
            result += [f'        incbin "{source}"']
        return result
    (ROOT / 'build/sf-sfx-early.inc').write_text('\n'.join(emit(banks_pcm[0])) + '\n')
    data += ['        if def(M4_EXTERNAL_AUDIO)']
    for bank in banks_pcm[1:]:
        for address, aliases in bank[2]:
            data += [f'{a["label"]} equ ${address:x}' for a in aliases]
    data += ['        else']
    for bank in banks_pcm[1:]:
        data += emit(bank)
    data += ['        endif']
    data += ['M4SfxDataEnd:', '        if *>ROM_BYTES', '        inform 3,"PCM catalog exceeds ROM"', '        endif']
    (ROOT / 'build/sf-sfx-table.inc').write_text('\n'.join(table) + '\n')
    (ROOT / 'build/sf-sfx-data.inc').write_text('\n'.join(data) + '\n')
    report = dict(starfox_sha256=SHA, banks=banks, source_driver_sha1='84a3411c5c6406b53716d40d64b59f1e55f0f27f',
                  renderer=version, rate=RATE, format='mono signed 8-bit PCM', integrated=sounds,
                  samples_bytes=sum(s['bytes'] for s in sounds),
                  scope='all 175 port3 IDs with their original chained voices; no music; mono DAC adaptation',
                  timer_a=1019, rom_holes=[[0x200000,0x241000],[0x300000,0x320000],[0x390000,0x3b0000]])
    report['rom_banks'] = [dict(end=b[0], limit=b[1]) for b in banks_pcm]
    report['continuous'] = engines
    report['continuous_adaptation'] = 'Steady-state mono loops: port1 512 samples, port2 768 samples; no evolving SPC noise or stereo/distance gain.'
    report['unique_pcm_bytes'] = sum(a[0]['bytes'] for a in unique.values())
    (out / 'manifest.json').write_text(json.dumps(report, indent=2) + '\n')
    print(f'Extracted 11 original SBN banks; rendered {len(sounds)} effects, {report["samples_bytes"]} PCM bytes')


if __name__ == '__main__':
    main()
