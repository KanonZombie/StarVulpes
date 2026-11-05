"""GSU interpreter extension for 8bpp bitmap work (Star Fox USA rev0 route map planets).

Subclass of the minimal GSU interpreter in tools/extract-sprite-textures.py; the base file is not
modified and its users keep working.  Added here (semantics from ares
component/processor/gsu/instructions.cpp and sfc/coprocessor/superfx/core.cpp, see
build/research/route-map-planets.md):

  * PLOT for any SCMR colour mode, honouring POR transparent/dither/freezehigh exactly as ares
    `SuperFX::plot`, and writing the pixel into GSU RAM in SNES character format
    (SCBR/SCMR height, `flushPixelCache` addressing).  The two-entry pixel cache only delays
    writes; plotted pixels are written immediately, which gives the same RAM contents because
    the cache flushes in plot order (last write wins).
  * RPIX (ALT1 $4C): reads a pixel back from RAM (also what flushes the cache on hardware).
  * STOP ($00): ends `run` instead of raising.
  * LJMP (ALT1 $98..$9D).

Research tool, standard library only.  It is NOT a Super FX emulator (no timing, no cache
lines, no RAM/ROM bus arbitration).
"""
import importlib.util
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def _load(name, file):
    spec = importlib.util.spec_from_file_location(name, ROOT / 'tools' / file)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


base = _load('sprite_textures_base', 'extract-sprite-textures.py')
phys, s8, s16, fq, Rom = base.phys, base.s8, base.s16, base.fq, base.Rom


class GSU8(base.GSU):
    """md: SCMR colour mode (0=2bpp, 1=4bpp, 3=8bpp); ht: SCMR height (0=128, 1=160, 2=192)."""

    def __init__(self, rom, ram=None, scbr=0x0B, md=3, ht=0, ram_mask=0x7FFF):
        super().__init__(rom)
        if ram is not None:
            self.ram = ram
        self.scbr, self.md, self.ht, self.ram_mask = scbr, md, ht, ram_mask
        self.halted = False
        self.plot_log = []          # (x, y, colour) of every pixel actually written, in order
        self.plot_calls = 0          # PLOT instructions executed (incl. transparent ones)

    # SNES character addressing of the GSU bitmap (ares flushPixelCache / rpix)
    def pixel_address(self, x, y):
        x &= 0xFF
        y &= 0xFF
        ht = 3 if self.por & 0x10 else self.ht
        if ht == 0:
            cn = ((x & 0xF8) << 1) + ((y & 0xF8) >> 3)
        elif ht == 1:
            cn = ((x & 0xF8) << 1) + ((x & 0xF8) >> 1) + ((y & 0xF8) >> 3)
        elif ht == 2:
            cn = ((x & 0xF8) << 1) + (x & 0xF8) + ((y & 0xF8) >> 3)
        else:
            cn = ((y & 0x80) << 2) + ((x & 0x80) << 1) + ((y & 0x78) << 1) + ((x & 0x78) >> 3)
        bpp = (2, 4, 4, 8)[self.md]
        return (cn * (bpp << 3)) + (self.scbr << 10) + ((y & 7) * 2), bpp, (x & 7) ^ 7

    def write_pixel(self, x, y, colour):
        addr, bpp, bit = self.pixel_address(x, y)
        for n in range(bpp):
            a = (addr + ((n >> 1) << 4) + (n & 1)) & self.ram_mask
            if (colour >> n) & 1:
                self.ram[a] |= 1 << bit
            else:
                self.ram[a] &= ~(1 << bit) & 0xFF

    def read_pixel(self, x, y):
        addr, bpp, bit = self.pixel_address(x, y)
        v = 0
        for n in range(bpp):
            a = (addr + ((n >> 1) << 4) + (n & 1)) & self.ram_mask
            v |= ((self.ram[a] >> bit) & 1) << n
        return v

    def plot(self):
        x, y = self.r[1] & 0xFF, self.r[2] & 0xFF
        self.plot_calls += 1
        write = True
        if not self.por & 1:                           # transparency on
            if self.md == 3:
                write = (self.colr & 0x0F) != 0 if self.por & 8 else self.colr != 0
            else:
                write = (self.colr & 0x0F) != 0
        if write:
            c = self.colr
            if self.por & 2 and self.md != 3:
                if (x ^ y) & 1:
                    c >>= 4
                c &= 0x0F
            self.write_pixel(x, y, c)
            self.plot_log.append((x, y, c))
        self.r[1] = (self.r[1] + 1) & 0xFFFF

    def execute(self, op, addr):
        if op == 0x00:                                 # STOP
            self.halted = True
            self.reset()
            return
        if op == 0x4C and self.alt1:                   # RPIX
            v = self.read_pixel(self.r[1], self.r[2])
            self.setdr(v)
            self.sz(v)
            self.reset()
            return
        if 0x98 <= op <= 0x9D and self.alt1:           # LJMP
            self.pbr = self.r[op - 0x90] & 0x7F
            self.setr(15, self.sr())
            self.reset()
            return
        super().execute(op, addr)

    def run(self, entry, pbr=1, limit=50_000_000):
        self.pbr = pbr
        self.halted = False
        self.pipe_addr = entry
        self.pipeline = self.fetch(entry)
        self.r[15] = (entry + 1) & 0xFFFF
        while not self.halted:
            self.steps += 1
            assert self.steps < limit, 'GSU step limit'
            op, addr = self.pipeline, self.pipe_addr
            self.pipe_addr = self.r[15]
            self.pipeline = self.fetch(self.r[15])
            self.m15 = False
            self.execute(op, addr)
            if self.m14:
                self.m14 = False
                self.romdr = self.rom.data[phys(self.rombr, self.r[14])]
            if self.m15:
                self.m15 = False
            else:
                self.r[15] = (self.r[15] + 1) & 0xFFFF
        return self.plot_log


def decode_bitmap(ram, scbr=0x0B, width=128, height=128, md=3, ht=0):
    """Reads a GSU character-format bitmap from RAM into rows of pixel values."""
    g = GSU8.__new__(GSU8)
    g.ram, g.scbr, g.md, g.ht, g.por, g.ram_mask = ram, scbr, md, ht, 0, 0x7FFF
    return [[g.read_pixel(x, y) for x in range(width)] for y in range(height)]
