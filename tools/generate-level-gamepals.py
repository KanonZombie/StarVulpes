"""GSU polygon palettes of gamepal 02:F484 (A = n: CGRAM row 7 <- 03:8AAA +
32 n, 16 colours) as MD line-2 colours (component >> 2, the convention of
build/level-scene-palette.md.bin). n = 0..7; the stages write 1 (space,
initmode2), 2 (Titania bg_1_4b_1 03:9877) and 3 (Corneria bg_1_1c).
Output: build/level-gamepals.md.bin (8 x 32 bytes, big-endian WORDs)."""
from starfox_rom import rom_hex
import hashlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
rom = (ROOT / 'ref/Star Fox (USA).sfc').read_bytes()
assert hashlib.sha256(rom).hexdigest() == '3857b5294ea8f7468849437bb2d8271564e8a0ff30774622e9c872bcbd53a84d'
# 02:F484: index = (n << 8) >> 3 = 32 n into 03:8AAA (physical 0x18AAA)
assert rom[0x1749c:0x174a0] == bytes.fromhex(rom_hex(0x1749c, 4))
out = bytearray()
for n in range(8):
    for i in range(16):
        o = 0x18aaa + 32 * n + 2 * i
        c = rom[o] | rom[o + 1] << 8
        r, g, b = c & 31, (c >> 5) & 31, (c >> 10) & 31
        out += (((b >> 2) << 9) | ((g >> 2) << 5) | ((r >> 2) << 1)).to_bytes(2, 'big')
# gamepal 3 equals the Corneria scene palette already in use.
scene = (ROOT / 'build/level-scene-palette.md.bin')
if scene.exists():
    assert out[96:128] == scene.read_bytes(), 'gamepal 3 differs from level-scene-palette'
(ROOT / 'build/level-gamepals.md.bin').write_bytes(bytes(out))
print('Generated 8 gamepal rows (03:8AAA..03:8BA9)')
