"""Execute the selected ROM's small-text GSU unit as a bounded pixel oracle.

This is not a console emulator: no timing, bus contention or pixel cache. It
executes msprint and its original projection/division calls; PLOT is captured
as coordinates. Opcode semantics were checked against the local ares GSU core.
"""
from starfox_rom import rom_hex
from pathlib import Path
import hashlib
import json

ROOT = Path(__file__).resolve().parents[1]
ROM_SHA256 = '3857b5294ea8f7468849437bb2d8271564e8a0ff30774622e9c872bcbd53a84d'


def signed(value, bits=16):
    value &= (1 << bits) - 1
    return value - (1 << bits) if value & (1 << (bits - 1)) else value


class TextGSU:
    """Only opcodes reached by ROM msprint, with its one-byte pipeline."""
    def __init__(self, rom, allowed=None):
        self.rom = rom
        self.allowed = allowed or ((0xcef0, 0xd16a), (0x9263, 0x94ba), (0x8183, 0x81aa))
        self.r = [0] * 16
        self.ram = bytearray(65536)
        self.src = self.dst = self.alt = 0
        self.b = self.cy = self.z = self.s = self.ov = False
        self.ramaddr = self.rombank = self.color = 0
        self.plots = []
        self.visited = set()
        self.checkpoints = {}
        self.trace = []

    def word(self, address, value=None):
        if value is None:
            return self.ram[address] | (self.ram[address ^ 1] << 8)
        self.ram[address] = value & 255
        self.ram[address ^ 1] = (value >> 8) & 255

    def reg(self, index, value):
        self.r[index] = value & 65535
        if index == 15:
            self.modified = True

    def flags(self, value):
        self.s = bool(value & 32768)
        self.z = (value & 65535) == 0

    def pipe(self):
        value = self.pipeline
        self.r[15] = (self.r[15] + 1) & 65535
        self.pipeline_address = self.r[15]
        self.pipeline = self.rom[self.pipeline_address]
        self.modified = False
        return value

    def run(self, entry=0xcef0, limit=100000, stop_pc=None):
        self.pipeline_address = entry
        self.pipeline = self.rom[entry]
        self.r[15] = entry + 1
        for count in range(limit):
            address = self.pipeline_address
            self.trace.append((address, self.r.copy(), self.alt, self.src, self.dst))
            self.trace = self.trace[-30:]
            if address == 0 or address == stop_pc:
                return count
            assert any(low <= address < high for low, high in self.allowed), hex(address)
            if address in (0xcf46, 0xcf80, 0xcfa0):
                self.checkpoints[address] = self.r.copy()
            self.visited.add(address)
            op = self.pipeline
            self.pipeline_address = self.r[15]
            self.pipeline = self.rom[self.pipeline_address]
            self.modified = False
            n = op & 15
            a, d = self.r[self.src], self.dst
            reset = True
            if op == 0:
                return count + 1  # STOP: bounded native math calls finish here.
            elif op in (1, 2):
                pass
            elif op in (3, 4, 0x97):
                if op == 3:
                    value, carry = a >> 1, bool(a & 1)
                elif op == 4:
                    value, carry = (a << 1) | int(self.cy), bool(a & 32768)
                else:
                    value, carry = (a >> 1) | (int(self.cy) << 15), bool(a & 1)
                self.reg(d, value)
                self.flags(value)
                self.cy = carry
            elif 5 <= op <= 15:
                # GSU06/07 use the inverse of conventional CPU BLT/BGE.
                # ares component/processor/gsu/instruction.cpp:42-43.
                take = {5: True, 6: self.s == self.ov, 7: self.s != self.ov,
                        8: not self.z, 9: self.z, 10: not self.s, 11: self.s,
                        12: not self.cy, 13: self.cy, 14: not self.ov, 15: self.ov}[op]
                delta = signed(self.pipe(), 8)
                if take:
                    self.reg(15, self.r[15] + delta)
                reset = False
            elif 0x10 <= op <= 0x1f:
                if self.b:
                    self.reg(n, a)
                else:
                    self.dst = n
                    reset = False
            elif 0x20 <= op <= 0x2f:
                self.src = self.dst = n
                self.b = True
                reset = False
            elif 0x30 <= op <= 0x3b:
                assert self.alt in (0,1)
                self.ramaddr = self.r[n]
                if self.alt:self.ram[self.ramaddr]=a & 255
                else:self.word(self.ramaddr, a)
            elif op == 0x3c:
                self.reg(12, self.r[12] - 1)
                self.flags(self.r[12])
                if not self.z:
                    self.reg(15, self.r[13])
            elif op in (0x3d, 0x3e, 0x3f):
                self.alt |= op - 0x3c
                self.b = False
                reset = False
            elif 0x40 <= op <= 0x4b:
                assert self.alt in (0,1)
                self.ramaddr = self.r[n]
                self.reg(d, self.ram[self.ramaddr] if self.alt else self.word(self.ramaddr))
            elif op == 0x4c:
                assert not self.alt
                self.plots.append((self.r[1] & 255, self.r[2] & 255, self.color))
                self.reg(1, self.r[1] + 1)
            elif op in (0x4d, 0x4f, 0x9e, 0xc0):
                value = {0x4d: (a >> 8) | (a << 8), 0x4f: ~a,
                         0x9e: a & 255, 0xc0: a >> 8}[op]
                self.reg(d, value)
                self.flags(value)
                if op in (0x9e, 0xc0):
                    self.s = bool(value & 128)
            elif op == 0x4e:
                if self.alt & 1:
                    assert a == 0  # msprint disables dithering
                else:
                    self.color = a & 255
            elif 0x50 <= op <= 0x6f:
                operand = n if self.alt & 2 and not (op >= 0x60 and self.alt & 1) else self.r[n]
                if op < 0x60:
                    value = a + operand + (self.cy if self.alt & 1 else 0)
                    self.ov = bool((~(a ^ operand) & (operand ^ value)) & 32768)
                    self.cy = value >= 65536
                else:
                    value = a - operand - (not self.cy if self.alt == 1 else 0)
                    self.ov = bool(((a ^ operand) & (a ^ value)) & 32768)
                    self.cy = value >= 0
                self.flags(value)
                if not (op >= 0x60 and self.alt == 3):
                    self.reg(d, value)
            elif 0x71 <= op <= 0x7f:
                operand = n if self.alt & 2 else self.r[n]
                value = a & (~operand if self.alt & 1 else operand)
                self.reg(d, value)
                self.flags(value)
            elif 0x80 <= op <= 0x8f:
                operand = n if self.alt & 2 else self.r[n]
                value = ((a & 255) * (operand & 255) if self.alt & 1
                         else signed(a, 8) * signed(operand, 8))
                self.reg(d, value)
                self.flags(value)
            elif op == 0x9f:
                # ares GSU instructionFMULT_LMULT: high16, carry=product bit15.
                product = signed(a) * signed(self.r[6])
                if self.alt & 1:
                    self.reg(4, product)
                self.reg(d, product >> 16)
                self.flags(self.r[d])
                self.cy = bool(product & 32768)
            elif op == 0x90:
                self.word(self.ramaddr, a)
            elif op == 0x95:
                self.reg(d,signed(a,8))
                self.flags(self.r[d])
            elif 0x91 <= op <= 0x94:
                self.reg(11, self.r[15] + n)
            elif 0x98 <= op <= 0x9d:
                assert not self.alt
                self.reg(15, self.r[op - 0x90])
            elif 0xa0 <= op <= 0xaf:
                operand = self.pipe()
                if self.alt & 1:
                    self.ramaddr = operand * 2
                    self.reg(n, self.word(self.ramaddr))
                elif self.alt & 2:
                    self.ramaddr = operand * 2
                    self.word(self.ramaddr, self.r[n])
                else:
                    self.reg(n, signed(operand, 8))
            elif 0xb0 <= op <= 0xbf:
                if self.b:
                    self.reg(d, self.r[n])
                    self.flags(self.r[d])
                    self.ov = bool(self.r[d] & 128)
                else:
                    self.src = n
                    reset = False
            elif 0xc1 <= op <= 0xcf:
                operand = n if self.alt & 2 else self.r[n]
                value = a ^ operand if self.alt & 1 else a | operand
                self.reg(d, value)
                self.flags(value)
            elif 0xd0 <= op <= 0xde or 0xe0 <= op <= 0xee:
                self.reg(n, self.r[n] + (1 if op < 0xe0 else -1))
                self.flags(self.r[n])
            elif op == 0xdf:
                if self.alt == 3:
                    self.rombank = a & 127
                else:
                    assert self.alt == 2 and a == 0
            elif op == 0xef:
                value = self.rom[self.rombank * 32768 + (self.r[14] & 32767)]
                assert self.alt in (0,1,3)
                self.reg(d, signed(value,8) if self.alt==3 else value if not self.alt else (value << 8) | (a & 255))
            elif 0xf0 <= op <= 0xff:
                operand = self.pipe()
                operand |= self.pipe() << 8
                assert not self.alt
                self.reg(n, operand)
            else:
                raise AssertionError((hex(address), hex(op), self.alt))
            if reset:
                self.src = self.dst = self.alt = 0
                self.b = False
            if not self.modified:
                self.r[15] = (self.r[15] + 1) & 65535
        raise AssertionError('msprint did not return')


def original_render(rom, name, x=0, y=-100, z=4000, size=0, color=14):
    """Coordinates are already camera transformed, as at original msprint entry."""
    gsu = TextGSU(rom)
    gsu.r[10] = 0x7000
    gsu.r[0] = color
    values = {0x26: x, 0x28: y, 0x2a: z, 0x1a: 0xc8e3 if name == 'nintendo' else 0xc8f6,
              0x1c: 0x14, 0xb6: size, 0x34: 112, 0x36: 96,
              0x38: 0, 0x3a: 223, 0x3c: 0, 0x3e: 191}
    for address, value in values.items():
        gsu.word(address, value)
    gsu.run()
    pixels = bytearray(224 * 192)
    for px, py, color in gsu.plots:
        assert 0 <= px < 224 and 0 <= py < 192, (px, py)
        pixels[py * 224 + px] = color
    return pixels, gsu


def descriptor(x, y, z, size, color=14):
    """Semantic translation of the proven small-text numeric range."""
    assert 3500 <= z <= 5000 and size in (0, -32) and 1 <= color <= 14
    def project(v):
        value = abs(signed(v)) * 256 // z
        return -value if signed(v) < 0 else value
    character = (127 + size) * 256 // z
    width = (127 + size) * 2048 // z
    return dict(x=112 + project(x) - (width + 1) // 2,
                y=96 + project(y) - (character + 1) // 2,
                scale=width * 512, color=color, char_width=character)


def render_small(rom, name, desc):
    """Translation of the selected small-scale loop, including whole-char clips."""
    offset = 0xa48e3 if name == 'nintendo' else 0xa48f6
    chars = rom[offset:offset + 8]
    pixels = bytearray(224 * 192)
    source_y = 0
    y = desc['y']
    yacc = 0
    scale = desc['scale']
    while source_y < 16:
        if 0 <= y <= 191:
            x = desc['x']
            xacc = 0
            for char in chars:
                if x <= 0:
                    x += desc['char_width']
                    continue
                if x > 222 - desc['char_width']:
                    break
                row_address = 0xa3eda + (char - 1) * 32 + source_y * 2
                row = int.from_bytes(rom[row_address:row_address + 2], 'little')
                for source_x in range(16):
                    borrow = xacc < scale
                    xacc = (xacc - scale) & 65535
                    if borrow:
                        if row & (32768 >> source_x):
                            pixels[y * 224 + x] = desc['color']
                        x += 1
        while source_y < 16:
            borrow = yacc < scale
            yacc = (yacc - scale) & 65535
            source_y += 1
            if borrow:
                y += 1
                break
    return pixels


def recover():
    rom = (ROOT / 'ref/Star Fox (USA).sfc').read_bytes()
    assert hashlib.sha256(rom).hexdigest() == ROM_SHA256
    fragments = [(0xcef0, rom_hex(0x0cef0, 24)),
                 (0xcf10, rom_hex(0x0cf10, 5)), (0xcf41, rom_hex(0x0cf41, 5)),
                 (0xcf91, rom_hex(0x0cf91, 5)),
                 (0xcfd1, rom_hex(0x0cfd1, 16)),
                 (0xadc8, rom_hex(0x0adc8, 9)),
                 (0x10060, rom_hex(0x10060, 9)),
                 (0x1749c, rom_hex(0x1749c, 19))]
    for offset, hexdata in fragments:
        assert rom[offset:offset + len(bytes.fromhex(hexdata))] == bytes.fromhex(hexdata), hex(offset)
    palette = rom[0x18aca:0x18aea]
    assert palette.hex() == rom_hex(0x18aca, 32)
    md_palette = []
    for i in range(0, 32, 2):
        value = int.from_bytes(palette[i:i + 2], 'little')
        md_palette.append(((value & 31) >> 2) << 1 | (((value >> 5) & 31) >> 2) << 5 |
                          (((value >> 10) & 31) >> 2) << 9)
    (ROOT / 'build/intro-text-palette.md.bin').write_bytes(b''.join(v.to_bytes(2, 'big') for v in md_palette))
    original_capture = ROOT / 'evidence/starfox-original-bg.wram.bin'
    palette_observed = False
    if original_capture.exists():
        wram = original_capture.read_bytes()
        assert wram[0x8578:0x8598] == palette and wram[0x186b:0x188b] == palette
        palette_observed = True
    cases = []
    for name, y, size in [('nintendo', -100, 0), ('presents', 100, -32)]:
        for x in (0, -1000, 1000):
            pixels, gsu = original_render(rom, name, x=x, y=y, size=size)
            desc = descriptor(x, y, 4000, size)
            assert pixels == render_small(rom, name, desc)
            case = dict(name=name, x=x, y=y, z=4000, size=size,
                        origin=[signed(gsu.word(0x26)), signed(gsu.word(0x28))],
                        char_width=gsu.word(0xb6), scale=gsu.checkpoints[0xcfa0][9],
                        plotted_pixels=len(gsu.plots), pixels_sha256=hashlib.sha256(pixels).hexdigest())
            cases.append(case)
            if x == 0:
                (ROOT / f'build/intro-{name}-pixels.bin').write_bytes(pixels)
    projection_vectors = []
    tested = 0
    for name, size in [('nintendo', 0), ('presents', -32)]:
        for x, y, z in [(x, y, z) for z in (3500, 3937, 3941, 4000, 4400, 5000)
                        for x, y in ((-3000, -100), (-1700, 0), (0, 100), (1800, 0), (3000, 0), (0, -1600), (0, 1600))]:
            desc = descriptor(x, y, z, size)
            pixels, gsu = original_render(rom, name, x=x, y=y, z=z, size=size)
            assert pixels == render_small(rom, name, desc), (name, x, y, z)
            assert (gsu.word(0x26), gsu.word(0x28), gsu.word(0xb6), gsu.checkpoints[0xcfa0][9]) == (
                desc['x'] & 65535, desc['y'] & 65535, desc['char_width'], desc['scale'])
            projection_vectors.append([x & 65535, y & 65535, z, size & 255,
                                       desc['x'] & 65535, desc['y'] & 65535, desc['scale'], desc['char_width']])
            tested += 1
    (ROOT / 'build/intro-text-project.inc').write_text(
        f'M4_TEXT_PROJECT_CASES equ {len(projection_vectors)}\n' + '\n'.join(
            '        dc.w ' + ','.join(f'${v:04x}' for v in row) for row in projection_vectors) + '\n', encoding='utf-8')
    report = dict(rom_sha256=ROM_SHA256, entry_offset=0xcef0,
                  projection_offset=0x9263, positive_projection_offset=0x942f,
                  projection_divide_offset=0x9493, scale_divide_offset=0x8183,
                  font_offset=0xa3eda, fragments=[dict(offset=o, bytes=b) for o, b in fragments],
                  cases=cases, semantic_pixel_cases=tested,
                  palette=dict(offset=0x18aca, bytes=palette.hex(), md_words=md_palette,
                               load_routine=0x17484, normal_select=0x10060, index=1,
                               table=0x18aaa, gamepalbuff=0x8578, palette_copy=0x186b,
                               original_capture_verified=palette_observed),
                  source='SF/MARIO/MDSPRITE.MC:msprint; MOBJ.MC:mprojectpnt,mpdivu3216; MDRAWLIS.MC:.notpart; ASM/IRQ.ASM:irqsetmode1; MAIN.ASM:setgamepal_l',
                  scope='Selected ROM small-text GSU execution and PLOT coordinates; no camera transform, scheduler, timing or title large-scale support.')
    (ROOT / 'build/intro-font-origin.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(cases, indent=2))
    return rom, report


if __name__ == '__main__':
    recover()
