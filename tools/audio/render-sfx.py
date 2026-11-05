"""Recover full-band SFX captures from the selected ROM's existing SPC images.

Run by extract_sf.ps1 after extract-sf-sfx.py (FFmpeg with libgme: MEGASVP_FFMPEG or
PATH): renders QUALITY_SFX into build/audio-sfx-quality/. The build only loads them
(load: the SPC and WAV hashes must match the manifest), so it needs no FFmpeg.
"""
import concurrent.futures
import hashlib
import json
import os
import shutil
import subprocess
import wave
from pathlib import Path

import numpy as np
from catalog import ROOT, SF_SHA

# Effects whose MDSDRV PCM comes from these 32000 Hz captures (mdsdrv-content.py).
QUALITY_SFX = {1,2,3,4,0x0d,0x0f,0x10,0x11,0x13,0x15,0x17,0x18,
               *range(0x21,0x2b),*range(0x30,0x36),0x45,0x47,0x48,
               0x49,0x4a,0x4b,*range(0x5f,0x66),0x67,*range(0x7a,0x80),0x8c,0xae}
OUT = ROOT/'build/audio-sfx-quality'


def prepare(ids):
    source = ROOT/'build/sf-sfx'
    out = OUT
    out.mkdir(exist_ok=True)
    original = json.loads((source/'manifest.json').read_text())
    assert original['starfox_sha256'] == SF_SHA
    assert hashlib.sha256((ROOT/'ref/Star Fox (USA).sfc').read_bytes()).hexdigest() == SF_SHA
    ffmpeg = Path(os.environ.get('MEGASVP_FFMPEG') or shutil.which('ffmpeg') or 'ffmpeg')
    assert ffmpeg.is_file(), 'Falta FFmpeg con libgme: defina MEGASVP_FFMPEG o añada ffmpeg al PATH.'
    sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
    renderer = sha(ffmpeg)
    previous = out/'manifest.json'
    cached = json.loads(previous.read_text()).get('effects', {}) if previous.exists() else {}

    def render(sid):
        spc = source/f'{sid:02x}.spc'
        dest = out/f'{sid:02x}.wav'
        key = dict(spc_sha256=sha(spc), renderer_sha256=renderer, rate=32000)
        row = cached.get(str(sid), {})
        if dest.exists() and all(row.get(k) == v for k,v in key.items()) and row.get('wave_sha256') == sha(dest):
            return str(sid), row
        result = subprocess.run([str(ffmpeg), '-v','error','-f','libgme','-sample_rate','32000',
            '-i',str(spc),'-t','20','-ar','32000','-ac','1','-f','s16le','pipe:1'], capture_output=True, check=True)
        data = np.frombuffer(result.stdout, '<i2')
        active = np.flatnonzero(abs(data.astype(np.int32)) > 64)
        assert len(active) and active[-1] < 19*32000, f'Incomplete SFX {sid:02x}'
        # Same source trim policy as extract-sf-sfx, at the native renderer rate.
        start = max(0, int(active[0])-round(27*32000/5327))
        end = min(len(data), int(active[-1])+round(108*32000/5327))
        with wave.open(str(dest), 'wb') as wav:
            wav.setparams((1,2,32000,0,'NONE','not compressed'))
            wav.writeframes(data[start:end].tobytes())
        return str(sid), dict(**key, wave_sha256=sha(dest), frames=end-start,
                             removed_leading_samples=start, source=spc.relative_to(ROOT).as_posix())

    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        rows = dict(pool.map(render, sorted(ids)))
    previous.write_text(json.dumps(dict(source_rom_sha256=SF_SHA, effects=rows,
        scope='Original SPC driver executed offline; full effect envelopes at32000Hz, not upsampling the old5327Hz captures.'), indent=2)+'\n')
    return out


def load(ids):
    """The extraction's captures of `ids`, checked against the current SPC images."""
    manifest = OUT/'manifest.json'
    assert manifest.exists(), 'Faltan los efectos renderizados (build/audio-sfx-quality): ejecute extract_sf.ps1.'
    rows = json.loads(manifest.read_text()).get('effects', {})
    sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
    for sid in sorted(ids):
        row = rows.get(str(sid))
        spc, wav = ROOT/f'build/sf-sfx/{sid:02x}.spc', OUT/f'{sid:02x}.wav'
        assert row and wav.exists() and row['wave_sha256'] == sha(wav) and row['spc_sha256'] == sha(spc),             f'Efecto {sid:02x} sin renderizar o desactualizado: ejecute extract_sf.ps1.'
    return OUT


if __name__ == '__main__':
    out = prepare(QUALITY_SFX)
    print(f'Rendered {len(QUALITY_SFX)} effects at 32000 Hz into {out.relative_to(ROOT)}')
