"""Execute the verified USA SBNs offline; retain original bank/command identity.

The interpreter and DSP-register stub are conversion tools, never cartridge
code. Infinite repeats are recovered at ks20, not inferred from a WAV fade.
"""
import concurrent.futures
import hashlib
import json
import os
import struct
import subprocess
from pathlib import Path
from catalog import ROOT, inventory, sbn, upload

OUT = ROOT / 'build/audio-native'


def memory(bank):
    ram = bytearray(65536)
    # The initial intro/map establishes the common/orchestral sample set.
    names = ['sgsound0', 'sgsound1', 'sgsound2']
    # Corneria 2/3 enter after the shared scramble bank; their helpers only
    # replace common instruments, retaining the Corneria score itself.
    if bank['name'] in ('21', '31'):
        names += ['sgbgma', 'sgbgm1']
    for name in names + bank['loaded']:
        upload(sbn(name), ram)
    return ram


def capture():
    OUT.mkdir(parents=True, exist_ok=True)
    data = inventory(include_arrangements=False)
    jobs, banks = {}, []
    interpreter = Path(os.environ['MEGASVP_SPC_CORE'])
    digest = hashlib.sha256((ROOT / 'tools/audio/spc-trace.cpp').read_bytes())
    for path in sorted(interpreter.rglob('*')):
        if path.suffix in ('.cpp', '.hpp'):
            digest.update(path.relative_to(interpreter).as_posix().encode())
            digest.update(path.read_bytes())
    version = digest.hexdigest()
    for bank in data['original_banks']:
        if bank['name'] == 'init':
            continue
        ram = memory(bank)
        rhash = hashlib.sha256(ram).hexdigest()
        ramfile = OUT / (rhash + '.ram')
        ramfile.write_bytes(ram)
        slots = {}
        for cmd in range(1, 20):
            pointer = struct.unpack_from('<H', ram, 0xfdc0 + 2 * (cmd - 1))[0]
            if not 0x400 <= pointer < 0xfdc0:
                continue
            # Alias commands can alter original starts (2/3/4, 5/6), so
            # retain the command even when their GFT pointer is identical.
            key = hashlib.sha256(bytes.fromhex(version) + ram + bytes([cmd])).hexdigest()[:24]
            jobs[key] = (ramfile, cmd)
            slots[cmd] = key
        banks.append(dict(**bank, slots=slots, ram_sha256=rhash))

    def run(item):
        key, (ramfile, cmd) = item
        metadata, trace = OUT / (key + '.json'), OUT / (key + '.trace')
        if metadata.exists() and trace.exists():
            old=json.loads(metadata.read_text())
            # SGSOUNDA's original credits score has a finite $63-repeat
            # tail and finishes after ~802 seconds. A 240-second capture
            # is not a licence to invent an infinite loop or truncate it.
            if old['loop_end']>=0 or old['song_end']>=0 or old.get('limit_seconds')==900:
                return key,old
        result = subprocess.run([str(OUT / 'spc-trace.exe'), str(ramfile), str(trace), '0', str(cmd), '900'],
                                capture_output=True, text=True)
        if result.returncode:
            raise RuntimeError(f'SPC trace {key}, command {cmd}: {result.stderr.strip()}')
        row = json.loads(result.stdout)
        assert row['echoed'], (key, cmd)
        row.update(command=cmd, ram=ramfile.name, trace=trace.name,limit_seconds=900,
                   trace_sha256=hashlib.sha256(trace.read_bytes()).hexdigest())
        metadata.write_text(json.dumps(row, indent=2) + '\n')
        return key, row

    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        results = dict(pool.map(run, jobs.items()))
    (OUT / 'score-traces.json').write_text(json.dumps(dict(rom_sha256=data['rom_sha256'],
        converter_sha256=version, banks=banks, traces=results), indent=2) + '\n')
    print(f'{len(banks)} banks, {len(results)} original command traces')
    unresolved = [k for k, v in results.items() if v['loop_end'] < 0 and v['song_end'] < 0]
    print('Commands without end/loop:', len(unresolved))


if __name__ == '__main__':
    capture()
