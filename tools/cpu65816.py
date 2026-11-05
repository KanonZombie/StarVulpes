"""Complete 65816 core (native/emulation flags, no cycle timing) for ROM oracles.

Executes the selected Star Fox ROM's own 65816 bytes. It is NOT a console
emulator: no PPU/APU/DMA/IRQ. The bus models only what strategy code touches:
LoROM mapping (no copier header), WRAM 7E/7F (+low mirror), Super FX RAM
(70/71 and the $6000-$7FFF window), and the CPU multiply/divide registers.
Writes to other I/O are logged in `bus.io_writes`; unknown reads return 0 and
are logged in `bus.io_reads`. Decimal mode is rejected (never used by the
studied units). Calls into routines that need a coprocessor or that the caller
wants to observe are intercepted through `hooks` (24-bit PC -> callable).
"""


class Bus:
    def __init__(self, rom):
        self.rom = rom
        self.wram = bytearray(0x20000)
        self.gsuram = bytearray(0x20000)
        self.io = {}
        self.io_writes = []
        self.io_reads = []
        self.rom_writes = []

    def _map(self, addr):
        bank, off = (addr >> 16) & 0xff, addr & 0xffff
        if bank in (0x7e, 0x7f):
            return 'w', ((bank - 0x7e) << 16) | off
        if bank in (0x70, 0x71):
            return 'g', ((bank - 0x70) << 16) | off
        lb = bank & 0x7f
        if lb < 0x40:
            if off < 0x2000:
                return 'w', off
            if off < 0x6000:
                return 'io', off
            if off < 0x8000:
                return 'g', off - 0x6000
            return 'r', lb * 0x8000 + (off - 0x8000)
        if 0x40 <= lb < 0x60:
            return 'r', ((lb - 0x40) * 0x10000 + off) % len(self.rom)
        if off >= 0x8000:
            return 'r', (lb * 0x8000 + (off - 0x8000)) % len(self.rom)
        raise AssertionError(f'unmapped read/write {addr:06X}')

    def read(self, addr):
        kind, a = self._map(addr & 0xffffff)
        if kind == 'w':
            return self.wram[a]
        if kind == 'g':
            return self.gsuram[a]
        if kind == 'r':
            return self.rom[a]
        if a in self.io:
            return self.io[a]
        self.io_reads.append(a)
        return 0

    def write(self, addr, v):
        kind, a = self._map(addr & 0xffffff)
        v &= 0xff
        if kind == 'w':
            self.wram[a] = v
        elif kind == 'g':
            self.gsuram[a] = v
        elif kind == 'r':
            self.rom_writes.append(addr)
        else:
            self.io[a] = v
            if a == 0x4203:
                p = self.io.get(0x4202, 0) * v
                self.io[0x4216], self.io[0x4217] = p & 0xff, p >> 8
            elif a == 0x4206:
                d = self.io.get(0x4204, 0) | (self.io.get(0x4205, 0) << 8)
                q, r = (d // v, d % v) if v else (0xffff, d)
                self.io[0x4214], self.io[0x4215] = q & 0xff, q >> 8
                self.io[0x4216], self.io[0x4217] = r & 0xff, r >> 8
            elif a not in (0x4202, 0x4204, 0x4205):
                self.io_writes.append((a, v))


class Halt(Exception):
    pass


class CPU:
    def __init__(self, bus, hooks=None):
        self.bus = bus
        self.hooks = hooks or {}
        self.watch = {}   # 24-bit PC -> observer called before the instruction executes
        self.a = self.x = self.y = 0
        self.s = 0x1fff
        self.d = 0
        self.db = 0x7e
        self.pb = 0
        self.pc = 0
        self.n = self.v = self.z = self.c = False
        self.m = True   # 8-bit accumulator
        self.xf = False  # 16-bit index
        self.i = True
        self.dec = False
        self.steps = 0
        self.trace = []
        self.visited = set()

    # ---- memory helpers
    def r8(self, a): return self.bus.read(a & 0xffffff)
    def r16(self, a): return self.r8(a) | (self.r8(a + 1) << 8)
    def r24(self, a): return self.r16(a) | (self.r8(a + 2) << 16)
    def w8(self, a, v): self.bus.write(a & 0xffffff, v)
    def w16(self, a, v): self.w8(a, v); self.w8(a + 1, v >> 8)
    def rb0_16(self, a): return self.r8(a & 0xffff) | (self.r8((a + 1) & 0xffff) << 8)

    def fetch8(self):
        v = self.r8((self.pb << 16) | self.pc)
        self.pc = (self.pc + 1) & 0xffff
        return v

    def fetch16(self):
        return self.fetch8() | (self.fetch8() << 8)

    def fetch24(self):
        return self.fetch16() | (self.fetch8() << 16)

    def push8(self, v):
        self.w8(self.s, v)
        self.s = (self.s - 1) & 0xffff

    def pull8(self):
        self.s = (self.s + 1) & 0xffff
        return self.r8(self.s)

    def push16(self, v): self.push8(v >> 8); self.push8(v)
    def pull16(self): return self.pull8() | (self.pull8() << 8)

    @property
    def p(self):
        return (self.n << 7) | (self.v << 6) | (self.m << 5) | (self.xf << 4) | (self.dec << 3) | (self.i << 2) | (self.z << 1) | int(self.c)

    @p.setter
    def p(self, v):
        self.n, self.v, self.m, self.xf = bool(v & 128), bool(v & 64), bool(v & 32), bool(v & 16)
        self.dec, self.i, self.z, self.c = bool(v & 8), bool(v & 4), bool(v & 2), bool(v & 1)
        if self.xf:
            self.x &= 0xff; self.y &= 0xff

    def nz(self, v, wide):
        if wide:
            self.z = (v & 0xffff) == 0; self.n = bool(v & 0x8000)
        else:
            self.z = (v & 0xff) == 0; self.n = bool(v & 0x80)

    # ---- addressing
    def ea(self, mode):
        D, X, Y, DB = self.d, self.x, self.y, self.db << 16
        if mode == 'dp': return (D + self.fetch8()) & 0xffff
        if mode == 'dpx': return (D + self.fetch8() + X) & 0xffff
        if mode == 'dpy': return (D + self.fetch8() + Y) & 0xffff
        if mode == 'idp': return DB | self.rb0_16(D + self.fetch8())
        if mode == 'ildp': return self.r24((D + self.fetch8()) & 0xffff)
        if mode == 'idpx': return DB | self.rb0_16(D + self.fetch8() + X)
        if mode == 'idpy': return ((DB | self.rb0_16(D + self.fetch8())) + Y) & 0xffffff
        if mode == 'ildpy': return (self.r24((D + self.fetch8()) & 0xffff) + Y) & 0xffffff
        if mode == 'abs': return DB | self.fetch16()
        if mode == 'absx': return (DB | self.fetch16()) + X & 0xffffff
        if mode == 'absy': return (DB | self.fetch16()) + Y & 0xffffff
        if mode == 'long': return self.fetch24()
        if mode == 'longx': return (self.fetch24() + X) & 0xffffff
        if mode == 'sr': return (self.s + self.fetch8()) & 0xffff
        if mode == 'isry': return ((DB | self.rb0_16(self.s + self.fetch8())) + Y) & 0xffffff
        raise AssertionError(mode)

    def rd(self, a, wide): return self.r16(a) if wide else self.r8(a)

    def wr(self, a, v, wide):
        if wide: self.w16(a, v)
        else: self.w8(a, v)

    # ---- ALU
    def adc(self, v):
        assert not self.dec, 'decimal mode'
        wide = not self.m
        mask = 0xffff if wide else 0xff
        a = self.a & mask
        r = a + v + self.c
        self.v = bool(~(a ^ v) & (a ^ r) & (0x8000 if wide else 0x80))
        self.c = r > mask
        r &= mask
        self.a = r if wide else (self.a & 0xff00) | r
        self.nz(r, wide)

    def sbc(self, v):
        self.adc(v ^ (0xffff if not self.m else 0xff))

    def cmp(self, reg, v, wide):
        mask = 0xffff if wide else 0xff
        r = (reg & mask) - v
        self.c = r >= 0
        self.nz(r & mask, wide)

    def seta(self, v):
        if self.m:
            self.a = (self.a & 0xff00) | (v & 0xff); self.nz(v, False)
        else:
            self.a = v & 0xffff; self.nz(v, True)

    def rmw(self, op, v, wide):
        mask = 0xffff if wide else 0xff
        top = 0x8000 if wide else 0x80
        if op == 'asl': self.c = bool(v & top); v = (v << 1) & mask
        elif op == 'lsr': self.c = bool(v & 1); v >>= 1
        elif op == 'rol': c = self.c; self.c = bool(v & top); v = ((v << 1) | c) & mask
        elif op == 'ror': c = self.c; self.c = bool(v & 1); v = (v >> 1) | (top if c else 0)
        elif op == 'inc': v = (v + 1) & mask
        elif op == 'dec': v = (v - 1) & mask
        self.nz(v, wide)
        return v

    # ---- execution
    def run(self, until, limit=2_000_000):
        """Run until full 24-bit PC equals `until`."""
        for _ in range(limit):
            pc24 = (self.pb << 16) | self.pc
            if pc24 == until:
                return
            if pc24 in self.hooks:
                self.hooks[pc24](self)
                continue
            if pc24 in self.watch:
                self.watch[pc24](self)
            self.step()
        raise AssertionError(f'step limit at {(self.pb << 16) | self.pc:06X}')

    def call_long(self, target, ret=0xfffff0, **regs):
        """JSL-like call; returns when RTL comes back to `ret`+1."""
        self.push8(ret >> 16)
        self.push16((ret & 0xffff))
        for k, v in regs.items():
            setattr(self, k, v)
        self.pb, self.pc = target >> 16, target & 0xffff
        self.run(((ret >> 16) << 16) | ((ret + 1) & 0xffff))

    def do_rtl(self):
        self.pc = (self.pull16() + 1) & 0xffff
        self.pb = self.pull8()

    def do_rts(self):
        self.pc = (self.pull16() + 1) & 0xffff

    ALU = {0x00: 'ora', 0x20: 'and', 0x40: 'eor', 0x60: 'adc', 0x80: 'sta', 0xa0: 'lda', 0xc0: 'cmp', 0xe0: 'sbc'}
    ALUMODE = {0x01: 'idpx', 0x03: 'sr', 0x05: 'dp', 0x07: 'ildp', 0x09: 'imm', 0x0d: 'abs', 0x0f: 'long', 0x11: 'idpy',
               0x12: 'idp', 0x13: 'isry', 0x15: 'dpx', 0x17: 'ildpy', 0x19: 'absy', 0x1d: 'absx', 0x1f: 'longx'}
    RMW = {0x06: ('asl', 'dp'), 0x0e: ('asl', 'abs'), 0x16: ('asl', 'dpx'), 0x1e: ('asl', 'absx'),
           0x26: ('rol', 'dp'), 0x2e: ('rol', 'abs'), 0x36: ('rol', 'dpx'), 0x3e: ('rol', 'absx'),
           0x46: ('lsr', 'dp'), 0x4e: ('lsr', 'abs'), 0x56: ('lsr', 'dpx'), 0x5e: ('lsr', 'absx'),
           0x66: ('ror', 'dp'), 0x6e: ('ror', 'abs'), 0x76: ('ror', 'dpx'), 0x7e: ('ror', 'absx'),
           0xc6: ('dec', 'dp'), 0xce: ('dec', 'abs'), 0xd6: ('dec', 'dpx'), 0xde: ('dec', 'absx'),
           0xe6: ('inc', 'dp'), 0xee: ('inc', 'abs'), 0xf6: ('inc', 'dpx'), 0xfe: ('inc', 'absx')}
    ACC = {0x0a: 'asl', 0x2a: 'rol', 0x4a: 'lsr', 0x6a: 'ror', 0x1a: 'inc', 0x3a: 'dec'}

    def step(self):
        pc24 = (self.pb << 16) | self.pc
        self.visited.add(pc24)
        self.steps += 1
        op = self.fetch8()
        wa = not self.m
        wi = not self.xf
        lo = op & 0x1f
        if (op & 0xe0) in self.ALU and (lo in self.ALUMODE) and op != 0x89:
            name = self.ALU[op & 0xe0]
            mode = self.ALUMODE[lo]
            if name == 'sta':
                self.wr(self.ea(mode), self.a, wa)
                return
            if mode == 'imm':
                v = self.fetch16() if wa else self.fetch8()
            else:
                v = self.rd(self.ea(mode), wa)
            mask = 0xffff if wa else 0xff
            if name == 'lda': self.seta(v)
            elif name == 'ora': self.seta((self.a | v) & mask)
            elif name == 'and': self.seta(self.a & v & mask)
            elif name == 'eor': self.seta((self.a ^ v) & mask)
            elif name == 'adc': self.adc(v)
            elif name == 'sbc': self.sbc(v)
            elif name == 'cmp': self.cmp(self.a, v, wa)
            return
        if op in self.RMW:
            name, mode = self.RMW[op]
            a = self.ea(mode)
            self.wr(a, self.rmw(name, self.rd(a, wa), wa), wa)
            return
        if op in self.ACC:
            mask = 0xffff if wa else 0xff
            self.seta(self.rmw(self.ACC[op], self.a & mask, wa))
            return
        h = getattr(self, f'op_{op:02x}', None)
        if h is None:
            raise AssertionError(f'unsupported opcode {op:02X} at {pc24:06X}')
        h()

    # branches
    def _br(self, cond):
        d = self.fetch8()
        if cond:
            self.pc = (self.pc + (d - 256 if d & 128 else d)) & 0xffff
    def op_10(self): self._br(not self.n)
    def op_30(self): self._br(self.n)
    def op_50(self): self._br(not self.v)
    def op_70(self): self._br(self.v)
    def op_90(self): self._br(not self.c)
    def op_b0(self): self._br(self.c)
    def op_d0(self): self._br(not self.z)
    def op_f0(self): self._br(self.z)
    def op_80(self): self._br(True)
    def op_82(self):
        d = self.fetch16(); self.pc = (self.pc + (d - 65536 if d & 0x8000 else d)) & 0xffff

    # jumps / calls
    def op_4c(self): self.pc = self.fetch16()
    def op_5c(self): t = self.fetch24(); self.pb, self.pc = t >> 16, t & 0xffff
    def op_6c(self): a = self.fetch16(); self.pc = self.r16(a)
    def op_7c(self): a = self.fetch16(); self.pc = self.r16((self.pb << 16) | ((a + self.x) & 0xffff))
    def op_dc(self): a = self.fetch16(); t = self.r24(a); self.pb, self.pc = t >> 16, t & 0xffff
    def op_20(self):
        t = self.fetch16(); self.push16((self.pc - 1) & 0xffff); self.pc = t
    def op_fc(self):
        a = self.fetch16(); self.push16((self.pc - 1) & 0xffff)
        self.pc = self.r16((self.pb << 16) | ((a + self.x) & 0xffff))
    def op_22(self):
        t = self.fetch24(); self.push8(self.pb); self.push16((self.pc - 1) & 0xffff)
        self.pb, self.pc = t >> 16, t & 0xffff
    def op_60(self): self.do_rts()
    def op_6b(self): self.do_rtl()
    def op_40(self): self.p = self.pull8(); self.pc = self.pull16(); self.pb = self.pull8()

    # loads/stores index
    def _ld(self, reg, mode):
        wi = not self.xf
        v = (self.fetch16() if wi else self.fetch8()) if mode == 'imm' else self.rd(self.ea(mode), wi)
        setattr(self, reg, v); self.nz(v, wi)
    def op_a2(self): self._ld('x', 'imm')
    def op_a6(self): self._ld('x', 'dp')
    def op_ae(self): self._ld('x', 'abs')
    def op_b6(self): self._ld('x', 'dpy')
    def op_be(self): self._ld('x', 'absy')
    def op_a0(self): self._ld('y', 'imm')
    def op_a4(self): self._ld('y', 'dp')
    def op_ac(self): self._ld('y', 'abs')
    def op_b4(self): self._ld('y', 'dpx')
    def op_bc(self): self._ld('y', 'absx')
    def op_86(self): self.wr(self.ea('dp'), self.x, not self.xf)
    def op_8e(self): self.wr(self.ea('abs'), self.x, not self.xf)
    def op_96(self): self.wr(self.ea('dpy'), self.x, not self.xf)
    def op_84(self): self.wr(self.ea('dp'), self.y, not self.xf)
    def op_8c(self): self.wr(self.ea('abs'), self.y, not self.xf)
    def op_94(self): self.wr(self.ea('dpx'), self.y, not self.xf)
    def op_64(self): self.wr(self.ea('dp'), 0, not self.m)
    def op_74(self): self.wr(self.ea('dpx'), 0, not self.m)
    def op_9c(self): self.wr(self.ea('abs'), 0, not self.m)
    def op_9e(self): self.wr(self.ea('absx'), 0, not self.m)
    def _cpi(self, reg, mode):
        wi = not self.xf
        v = (self.fetch16() if wi else self.fetch8()) if mode == 'imm' else self.rd(self.ea(mode), wi)
        self.cmp(getattr(self, reg), v, wi)
    def op_e0(self): self._cpi('x', 'imm')
    def op_e4(self): self._cpi('x', 'dp')
    def op_ec(self): self._cpi('x', 'abs')
    def op_c0(self): self._cpi('y', 'imm')
    def op_c4(self): self._cpi('y', 'dp')
    def op_cc(self): self._cpi('y', 'abs')

    # bit / tsb / trb
    def _bit(self, mode):
        wa = not self.m
        if mode == 'imm':
            v = self.fetch16() if wa else self.fetch8()
            self.z = (self.a & v & (0xffff if wa else 0xff)) == 0
            return
        v = self.rd(self.ea(mode), wa)
        self.z = (self.a & v & (0xffff if wa else 0xff)) == 0
        top = 0x8000 if wa else 0x80
        self.n, self.v = bool(v & top), bool(v & (top >> 1))
    def op_89(self): self._bit('imm')
    def op_24(self): self._bit('dp')
    def op_2c(self): self._bit('abs')
    def op_34(self): self._bit('dpx')
    def op_3c(self): self._bit('absx')
    def _tsb(self, mode, setbits):
        wa = not self.m
        a = self.ea(mode); v = self.rd(a, wa)
        self.z = (self.a & v & (0xffff if wa else 0xff)) == 0
        self.wr(a, (v | self.a) if setbits else (v & ~self.a), wa)
    def op_04(self): self._tsb('dp', True)
    def op_0c(self): self._tsb('abs', True)
    def op_14(self): self._tsb('dp', False)
    def op_1c(self): self._tsb('abs', False)

    # stack
    def _pushr(self, v, wide):
        if wide: self.push16(v)
        else: self.push8(v)
    def _pullr(self, wide): return self.pull16() if wide else self.pull8()
    def op_48(self): self._pushr(self.a, not self.m)
    def op_da(self): self._pushr(self.x, not self.xf)
    def op_5a(self): self._pushr(self.y, not self.xf)
    def op_08(self): self.push8(self.p)
    def op_8b(self): self.push8(self.db)
    def op_0b(self): self.push16(self.d)
    def op_4b(self): self.push8(self.pb)
    def op_f4(self): self.push16(self.fetch16())
    def op_d4(self): self.push16(self.rb0_16(self.d + self.fetch8()))
    def op_62(self):
        d = self.fetch16(); self.push16((self.pc + (d - 65536 if d & 0x8000 else d)) & 0xffff)
    def op_68(self):
        v = self._pullr(not self.m); self.seta(v)
    def op_fa(self): v = self._pullr(not self.xf); self.x = v; self.nz(v, not self.xf)
    def op_7a(self): v = self._pullr(not self.xf); self.y = v; self.nz(v, not self.xf)
    def op_28(self): self.p = self.pull8()
    def op_ab(self): self.db = self.pull8(); self.nz(self.db, False)
    def op_2b(self): self.d = self.pull16(); self.nz(self.d, True)

    # transfers
    def _ti(self, v):
        wi = not self.xf
        v &= 0xffff if wi else 0xff
        self.nz(v, wi); return v
    def op_aa(self): self.x = self._ti(self.a)
    def op_a8(self): self.y = self._ti(self.a)
    def op_9b(self): self.y = self._ti(self.x)
    def op_bb(self): self.x = self._ti(self.y)
    def op_ba(self): self.x = self._ti(self.s)
    def op_8a(self): self.seta(self.x if not self.m else (self.x & 0xff))
    def op_98(self): self.seta(self.y if not self.m else (self.y & 0xff))
    def op_9a(self): self.s = self.x
    def op_5b(self): self.d = self.a & 0xffff; self.nz(self.d, True)
    def op_7b(self): self.a = self.d; self.nz(self.a, True)
    def op_1b(self): self.s = self.a & 0xffff
    def op_3b(self): self.a = self.s; self.nz(self.a, True)
    def op_eb(self):
        self.a = ((self.a & 0xff) << 8) | (self.a >> 8); self.nz(self.a & 0xff, False)

    def _idx(self, reg, d):
        wi = not self.xf
        v = (getattr(self, reg) + d) & (0xffff if wi else 0xff)
        setattr(self, reg, v); self.nz(v, wi)
    def op_e8(self): self._idx('x', 1)
    def op_c8(self): self._idx('y', 1)
    def op_ca(self): self._idx('x', -1)
    def op_88(self): self._idx('y', -1)

    # flags
    def op_18(self): self.c = False
    def op_38(self): self.c = True
    def op_58(self): self.i = False
    def op_78(self): self.i = True
    def op_d8(self): self.dec = False
    def op_f8(self): self.dec = True
    def op_b8(self): self.v = False
    def op_c2(self): self.p = self.p & ~self.fetch8()
    def op_e2(self): self.p = self.p | self.fetch8()
    def op_fb(self):
        assert not self.c, 'emulation mode not supported'
    def op_ea(self): pass
    def op_42(self): self.fetch8()

    def _mv(self, step):
        dst, src = self.fetch8(), self.fetch8()
        self.db = dst
        while True:
            self.w8((dst << 16) | self.y, self.r8((src << 16) | self.x))
            self.x = (self.x + step) & 0xffff; self.y = (self.y + step) & 0xffff
            self.a = (self.a - 1) & 0xffff
            if self.a == 0xffff:
                break
    def op_54(self): self._mv(1)
    def op_44(self): self._mv(-1)
    def op_00(self): raise Halt(f'BRK at {(self.pb << 16) | self.pc:06X}')
    def op_02(self): raise Halt(f'COP at {(self.pb << 16) | self.pc:06X}')
    def op_db(self): raise Halt('STP')
    def op_cb(self): raise Halt('WAI')
