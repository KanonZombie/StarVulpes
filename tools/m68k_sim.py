"""Minimal MC68000 interpreter for executing routines of the port ROM in tests.

Scope: user-mode integer instructions used by the level code (MOVE/MOVEA/MOVEQ/
MOVEM/LEA/PEA, ADD*/SUB*/CMP*/AND*/OR*/EOR*/NOT/NEG/NEGX/CLR/TST/EXT/SWAP/EXG,
MULU/MULS/DIVU/DIVS, shifts and rotates, BTST/BSET/BCLR/BCHG, Bcc/BRA/BSR/DBcc/
Scc, JMP/JSR/RTS, LINK/UNLK, NOP, MOVE to/from CCR/SR, ANDI/ORI/EORI to CCR).
No timing, no exceptions (an unsupported opcode, an odd word access or an access
outside ROM/RAM raises). Memory: ROM image at $000000, 64 KiB work RAM at
$FF0000 (mirrored over $E00000-$FFFFFF as on the Mega Drive).

Library use:
    cpu = M68K(rom_bytes)
    cpu.call(address, a0=..., d0=...)   # runs until the routine's final RTS
Symbols: load_listing(path) parses an asm68k listing (labels and equates).
"""
import re

MASK = {1: 0xFF, 2: 0xFFFF, 4: 0xFFFFFFFF}
MSB = {1: 0x80, 2: 0x8000, 4: 0x80000000}
SENTINEL = 0x00FFFFF0 & 0xFFFFFE  # return address used by call(); never executed


class SimError(Exception):
    pass


def sx(v, size):
    v &= MASK[size]
    return v - (MASK[size] + 1) if v & MSB[size] else v


def load_listing(path):
    """asm68k /p listing -> {symbol: value} (labels at their address, equates)."""
    syms = {}
    lab = re.compile(r'^([0-9A-F]{8})\s+(?:[0-9A-F ]{0,30}?\s)?\s*([A-Za-z_][A-Za-z0-9_]*):')
    equ = re.compile(r'^[0-9A-F]{8}\s+=([0-9A-F]{8})\s+([A-Za-z_][A-Za-z0-9_]*)\s+(?:equ|=)\s', re.I)
    with open(path, encoding='latin-1') as f:
        for line in f:
            m = equ.match(line)
            if m:
                syms.setdefault(m.group(2), int(m.group(1), 16))
                continue
            m = re.match(r'^([0-9A-F]{8})\s{20,}([A-Za-z_][A-Za-z0-9_]*):', line)
            if m:
                syms.setdefault(m.group(2), int(m.group(1), 16))
    return syms


class M68K:
    def __init__(self, rom):
        self.rom = bytearray(rom)
        self.ram = bytearray(0x10000)
        self.d = [0] * 8
        self.a = [0] * 8
        self.pc = 0
        self.x = self.n = self.z = self.v = self.c = 0
        self.steps = 0
        self.hooks = {}          # pc -> callable(cpu); the hook must emulate an RTS itself
        self.trace = None

    # ------------------------------------------------------------ memory
    def _loc(self, addr):
        addr &= 0xFFFFFF
        if addr < len(self.rom):
            return self.rom, addr
        if addr >= 0xE00000:
            return self.ram, addr & 0xFFFF
        raise SimError('access outside ROM/RAM: %06X (pc %06X)' % (addr, self.pc))

    def rb(self, addr):
        m, o = self._loc(addr)
        return m[o]

    def rw(self, addr):
        if addr & 1:
            raise SimError('odd word read %06X at pc %06X' % (addr, self.pc))
        m, o = self._loc(addr)
        return (m[o] << 8) | m[o + 1]

    def rl(self, addr):
        return (self.rw(addr) << 16) | self.rw(addr + 2)

    def wb(self, addr, v):
        m, o = self._loc(addr)
        if m is self.rom:
            raise SimError('write to ROM %06X at pc %06X' % (addr, self.pc))
        m[o] = v & 0xFF

    def ww(self, addr, v):
        if addr & 1:
            raise SimError('odd word write %06X at pc %06X' % (addr, self.pc))
        self.wb(addr, v >> 8)
        self.wb(addr + 1, v)

    def wl(self, addr, v):
        self.ww(addr, (v >> 16) & 0xFFFF)
        self.ww(addr + 2, v & 0xFFFF)

    def read(self, addr, size):
        return (self.rb, self.rw, None, self.rl)[size - 1](addr)

    def write(self, addr, v, size):
        (self.wb, self.ww, None, self.wl)[size - 1](addr, v & MASK[size])

    def fetch(self):
        v = self.rw(self.pc)
        self.pc = (self.pc + 2) & 0xFFFFFF
        return v

    def fetchl(self):
        return (self.fetch() << 16) | self.fetch()

    def push(self, v):
        self.a[7] = (self.a[7] - 4) & 0xFFFFFFFF
        self.wl(self.a[7], v)

    def pop(self):
        v = self.rl(self.a[7])
        self.a[7] = (self.a[7] + 4) & 0xFFFFFFFF
        return v

    # ------------------------------------------------------------ flags
    @property
    def ccr(self):
        return (self.x << 4) | (self.n << 3) | (self.z << 2) | (self.v << 1) | self.c

    @ccr.setter
    def ccr(self, v):
        self.x, self.n, self.z, self.v, self.c = (v >> 4) & 1, (v >> 3) & 1, (v >> 2) & 1, (v >> 1) & 1, v & 1

    def nz(self, r, size):
        r &= MASK[size]
        self.n = 1 if r & MSB[size] else 0
        self.z = 1 if r == 0 else 0

    def logic(self, r, size):
        self.nz(r, size)
        self.v = self.c = 0

    def cond(self, cc):
        n, z, v, c = self.n, self.z, self.v, self.c
        return [True, False, not c and not z, c or z, not c, c, not z, z, not v, v, not n, n,
                n == v, n != v, (n == v) and not z, z or (n != v)][cc]

    def add(self, d, s, size, xin=0, keepz=False):
        m = MASK[size]
        r = d + s + xin
        res = r & m
        self.c = self.x = 1 if r > m else 0
        self.v = 1 if ((s ^ res) & (d ^ res) & MSB[size]) else 0
        self.n = 1 if res & MSB[size] else 0
        if keepz:
            if res:
                self.z = 0
        else:
            self.z = 1 if res == 0 else 0
        return res

    def sub(self, d, s, size, xin=0, keepz=False, cmp=False):
        m = MASK[size]
        res = (d - s - xin) & m
        c = 1 if (s + xin) > d else 0
        self.c = c
        if not cmp:
            self.x = c
        self.v = 1 if ((s ^ d) & (res ^ d) & MSB[size]) else 0
        self.n = 1 if res & MSB[size] else 0
        if keepz:
            if res:
                self.z = 0
        else:
            self.z = 1 if res == 0 else 0
        return res

    # ------------------------------------------------------------ effective addresses
    def ea(self, mode, reg, size):
        """-> ('d', n) | ('a', n) | ('m', addr) | ('i', value)."""
        if mode == 0:
            return ('d', reg)
        if mode == 1:
            return ('a', reg)
        if mode == 2:
            return ('m', self.a[reg] & 0xFFFFFF)
        if mode == 3:
            addr = self.a[reg]
            inc = 2 if (size == 1 and reg == 7) else size
            self.a[reg] = (addr + inc) & 0xFFFFFFFF
            return ('m', addr & 0xFFFFFF)
        if mode == 4:
            dec = 2 if (size == 1 and reg == 7) else size
            self.a[reg] = (self.a[reg] - dec) & 0xFFFFFFFF
            return ('m', self.a[reg] & 0xFFFFFF)
        if mode == 5:
            disp = sx(self.fetch(), 2)
            return ('m', (self.a[reg] + disp) & 0xFFFFFF)
        if mode == 6:
            return ('m', self._index(self.a[reg]))
        if reg == 0:
            return ('m', sx(self.fetch(), 2) & 0xFFFFFF)
        if reg == 1:
            return ('m', self.fetchl() & 0xFFFFFF)
        if reg == 2:
            base = self.pc
            disp = sx(self.fetch(), 2)
            return ('m', (base + disp) & 0xFFFFFF)
        if reg == 3:
            return ('m', self._index(self.pc))
        if reg == 4:
            if size == 4:
                return ('i', self.fetchl())
            w = self.fetch()
            return ('i', w & 0xFF if size == 1 else w)
        raise SimError('bad EA %d/%d at %06X' % (mode, reg, self.pc))

    def _index(self, base):
        ext = self.fetch()
        r = (ext >> 12) & 7
        xv = self.a[r] if ext & 0x8000 else self.d[r]
        xv = xv if ext & 0x800 else sx(xv, 2)
        return (base + sx(ext & 0xFF, 1) + xv) & 0xFFFFFF

    def get(self, loc, size):
        k, v = loc
        if k == 'd':
            return self.d[v] & MASK[size]
        if k == 'a':
            return self.a[v] & MASK[size]
        if k == 'm':
            return self.read(v, size)
        return v & MASK[size]

    def put(self, loc, val, size):
        k, v = loc
        if k == 'd':
            self.d[v] = (self.d[v] & ~MASK[size] & 0xFFFFFFFF) | (val & MASK[size])
        elif k == 'a':
            self.a[v] = val & 0xFFFFFFFF
        elif k == 'm':
            self.write(v, val, size)
        else:
            raise SimError('write to immediate at %06X' % self.pc)

    # ------------------------------------------------------------ execution
    def call(self, addr, max_steps=2_000_000, **regs):
        for k, v in regs.items():
            (self.d if k[0] == 'd' else self.a)[int(k[1])] = v & 0xFFFFFFFF
        if not self.a[7]:
            self.a[7] = 0x00FFFF00
        self.push(SENTINEL)
        self.pc = addr & 0xFFFFFF
        n = 0
        while self.pc != SENTINEL:
            if self.pc in self.hooks:
                self.hooks[self.pc](self)
                continue
            self.step()
            n += 1
            if n > max_steps:
                raise SimError('no return after %d steps (pc %06X)' % (n, self.pc))
        self.steps += n

    def rts(self):
        self.pc = self.pop() & 0xFFFFFF

    def step(self):
        pc0 = self.pc
        if self.trace is not None:
            self.trace.append(pc0)
        op = self.fetch()
        hi = op >> 12
        try:
            getattr(self, '_g%X' % hi)(op)
        except SimError:
            raise
        except (IndexError, KeyError, TypeError) as ex:
            raise SimError('decode failure %04X at %06X: %s' % (op, pc0, ex))

    def bad(self, op):
        raise SimError('unsupported opcode %04X at %06X' % (op, (self.pc - 2) & 0xFFFFFF))

    # group 0: immediate ops, bit ops
    def _g0(self, op):
        if op & 0x100 or (op & 0xF00) == 0x800:
            return self._bitop(op)
        kind = (op >> 9) & 7
        sz = (op >> 6) & 3
        mode, reg = (op >> 3) & 7, op & 7
        if op in (0x003C, 0x023C, 0x0A3C):         # ORI/ANDI/EORI to CCR
            imm = self.fetch() & 0xFF
            self.ccr = {0x003C: self.ccr | imm, 0x023C: self.ccr & imm, 0x0A3C: self.ccr ^ imm}[op]
            return
        if op in (0x007C, 0x027C, 0x0A7C):         # to SR: only the CCR part is modelled
            imm = self.fetch()
            self.ccr = {0x007C: self.ccr | imm, 0x027C: self.ccr & imm, 0x0A7C: self.ccr ^ imm}[op] & 0x1F
            return
        if sz == 3:
            self.bad(op)
        size = (1, 2, 4)[sz]
        imm = self.fetchl() if size == 4 else (self.fetch() & MASK[size])
        loc = self.ea(mode, reg, size)
        d = self.get(loc, size)
        if kind == 0:
            r = d | imm; self.logic(r, size); self.put(loc, r, size)
        elif kind == 1:
            r = d & imm; self.logic(r, size); self.put(loc, r, size)
        elif kind == 2:
            self.put(loc, self.sub(d, imm, size), size)
        elif kind == 3:
            self.put(loc, self.add(d, imm, size), size)
        elif kind == 5:
            r = d ^ imm; self.logic(r, size); self.put(loc, r, size)
        elif kind == 6:
            self.sub(d, imm, size, cmp=True)
        else:
            self.bad(op)

    def _bitop(self, op):
        mode, reg = (op >> 3) & 7, op & 7
        kind = (op >> 6) & 3
        if op & 0x100:
            if mode == 1:
                self.bad(op)                         # MOVEP
            bit = self.d[(op >> 9) & 7]
        else:
            bit = self.fetch() & 0xFF
        if mode == 0:
            bit &= 31
            loc, size = ('d', reg), 4
        else:
            bit &= 7
            size = 1
            loc = self.ea(mode, reg, 1)
        v = self.get(loc, size)
        self.z = 0 if (v >> bit) & 1 else 1
        if kind == 1:
            v ^= 1 << bit
        elif kind == 2:
            v &= ~(1 << bit)
        elif kind == 3:
            v |= 1 << bit
        if kind:
            self.put(loc, v, size)

    # MOVE
    def _move(self, op, size):
        src = self.get(self.ea((op >> 3) & 7, op & 7, size), size)
        dmode, dreg = (op >> 6) & 7, (op >> 9) & 7
        if dmode == 1:
            self.a[dreg] = sx(src, size) & 0xFFFFFFFF
            return
        self.logic(src, size)
        self.put(self.ea(dmode, dreg, size), src, size)

    def _g1(self, op): self._move(op, 1)
    def _g3(self, op): self._move(op, 2)
    def _g2(self, op): self._move(op, 4)

    # group 4: miscellaneous
    def _g4(self, op):
        mode, reg = (op >> 3) & 7, op & 7
        if op == 0x4E75:
            return self.rts()
        if op == 0x4E71:
            return
        if (op & 0xFFF8) == 0x4E50:                  # LINK
            disp = sx(self.fetch(), 2)
            self.push(self.a[reg])
            self.a[reg] = self.a[7]
            self.a[7] = (self.a[7] + disp) & 0xFFFFFFFF
            return
        if (op & 0xFFF8) == 0x4E58:                  # UNLK
            self.a[7] = self.a[reg]
            self.a[reg] = self.pop()
            return
        if (op & 0xFFC0) == 0x4E80:                  # JSR
            loc = self.ea(mode, reg, 4)
            self.push(self.pc)
            self.pc = loc[1]
            return
        if (op & 0xFFC0) == 0x4EC0:                  # JMP
            self.pc = self.ea(mode, reg, 4)[1]
            return
        if (op & 0xF1C0) == 0x41C0:                  # LEA
            self.a[(op >> 9) & 7] = self.ea(mode, reg, 4)[1]
            return
        if (op & 0xFFC0) == 0x4840 and mode != 0:    # PEA
            self.push(self.ea(mode, reg, 4)[1])
            return
        if (op & 0xFFF8) == 0x4840:                  # SWAP
            v = self.d[reg]
            v = ((v << 16) | (v >> 16)) & 0xFFFFFFFF
            self.d[reg] = v
            self.logic(v, 4)
            return
        if (op & 0xFFB8) == 0x4880:                  # EXT.w / EXT.l
            if op & 0x40:
                v = sx(self.d[reg], 2) & 0xFFFFFFFF
                self.d[reg] = v
                self.logic(v, 4)
            else:
                v = sx(self.d[reg], 1) & 0xFFFF
                self.d[reg] = (self.d[reg] & 0xFFFF0000) | v
                self.logic(v, 2)
            return
        if (op & 0xFB80) == 0x4880:                  # MOVEM
            return self._movem(op)
        if (op & 0xFFC0) == 0x44C0:                  # MOVE to CCR
            self.ccr = self.get(self.ea(mode, reg, 2), 2) & 0x1F
            return
        if (op & 0xFFC0) == 0x46C0:                  # MOVE to SR (CCR part)
            self.ccr = self.get(self.ea(mode, reg, 2), 2) & 0x1F
            return
        if (op & 0xFFC0) == 0x40C0:                  # MOVE from SR
            self.put(self.ea(mode, reg, 2), 0x2700 | self.ccr, 2)
            return
        sz = (op >> 6) & 3
        if sz == 3:
            self.bad(op)
        size = (1, 2, 4)[sz]
        top = op & 0xFF00
        if top == 0x4A00:                            # TST
            self.logic(self.get(self.ea(mode, reg, size), size), size)
            return
        loc = self.ea(mode, reg, size)
        if top == 0x4200:                            # CLR
            self.put(loc, 0, size)
            self.n = self.v = self.c = 0
            self.z = 1
        elif top == 0x4400:                          # NEG
            self.put(loc, self.sub(0, self.get(loc, size), size), size)
        elif top == 0x4000:                          # NEGX
            self.put(loc, self.sub(0, self.get(loc, size), size, xin=self.x, keepz=True), size)
        elif top == 0x4600:                          # NOT
            r = ~self.get(loc, size) & MASK[size]
            self.logic(r, size)
            self.put(loc, r, size)
        else:
            self.bad(op)

    def _movem(self, op):
        size = 4 if op & 0x40 else 2
        mask = self.fetch()
        mode, reg = (op >> 3) & 7, op & 7
        regs = list(range(16))                       # d0..d7, a0..a7
        if op & 0x400:                               # memory -> registers
            if mode == 3:
                addr = self.a[reg]
            else:
                addr = self.ea(mode, reg, size)[1]
            for i in regs:
                if mask & (1 << i):
                    v = sx(self.read(addr & 0xFFFFFF, size), size) & 0xFFFFFFFF
                    if i < 8:
                        self.d[i] = v if size == 4 else (v & 0xFFFFFFFF)
                    else:
                        self.a[i - 8] = v
                    addr += size
            if mode == 3:
                self.a[reg] = addr & 0xFFFFFFFF
        else:
            if mode == 4:
                addr = self.a[reg]
                for i in range(16):                  # mask bit 0 = a7 ... bit 15 = d0
                    if mask & (1 << i):
                        r = 15 - i
                        v = self.d[r] if r < 8 else self.a[r - 8]
                        addr -= size
                        self.write(addr & 0xFFFFFF, v, size)
                self.a[reg] = addr & 0xFFFFFFFF
            else:
                addr = self.ea(mode, reg, size)[1]
                for i in regs:
                    if mask & (1 << i):
                        v = self.d[i] if i < 8 else self.a[i - 8]
                        self.write(addr & 0xFFFFFF, v, size)
                        addr += size

    # group 5: ADDQ/SUBQ/Scc/DBcc
    def _g5(self, op):
        mode, reg = (op >> 3) & 7, op & 7
        if (op & 0xC0) == 0xC0:
            cc = (op >> 8) & 15
            if mode == 1:                            # DBcc
                disp = sx(self.fetch(), 2)
                if not self.cond(cc):
                    w = (self.d[reg] - 1) & 0xFFFF
                    self.d[reg] = (self.d[reg] & 0xFFFF0000) | w
                    if w != 0xFFFF:
                        self.pc = (self.pc - 2 + disp) & 0xFFFFFF
                return
            self.put(self.ea(mode, reg, 1), 0xFF if self.cond(cc) else 0, 1)
            return
        size = (1, 2, 4)[(op >> 6) & 3]
        q = (op >> 9) & 7 or 8
        if mode == 1:
            self.a[reg] = (self.a[reg] + (-q if op & 0x100 else q)) & 0xFFFFFFFF
            return
        loc = self.ea(mode, reg, size)
        d = self.get(loc, size)
        self.put(loc, self.sub(d, q, size) if op & 0x100 else self.add(d, q, size), size)

    # group 6: branches
    def _g6(self, op):
        cc = (op >> 8) & 15
        base = self.pc
        disp = op & 0xFF
        if disp == 0:
            disp = sx(self.fetch(), 2)
        else:
            disp = sx(disp, 1)
        target = (base + disp) & 0xFFFFFF
        if cc == 1:                                  # BSR
            self.push(self.pc)
            self.pc = target
        elif cc == 0 or self.cond(cc):
            self.pc = target

    def _g7(self, op):
        if op & 0x100:
            self.bad(op)
        v = sx(op & 0xFF, 1) & 0xFFFFFFFF
        self.d[(op >> 9) & 7] = v
        self.logic(v, 4)

    # arithmetic groups
    def _arith(self, op, kind):
        rn = (op >> 9) & 7
        opm = (op >> 6) & 7
        mode, reg = (op >> 3) & 7, op & 7
        if opm in (3, 7) and kind in ('add', 'sub', 'cmp'):      # ADDA/SUBA/CMPA
            size = 4 if opm == 7 else 2
            s = sx(self.get(self.ea(mode, reg, size), size), size) & 0xFFFFFFFF
            if kind == 'add':
                self.a[rn] = (self.a[rn] + s) & 0xFFFFFFFF
            elif kind == 'sub':
                self.a[rn] = (self.a[rn] - s) & 0xFFFFFFFF
            else:
                self.sub(self.a[rn], s, 4, cmp=True)
            return
        size = (1, 2, 4)[opm & 3]
        if kind in ('add', 'sub') and opm >= 4 and mode in (0, 1):  # ADDX/SUBX
            if mode == 1:
                self.bad(op)
            f = self.add if kind == 'add' else self.sub
            self.put(('d', rn), f(self.d[rn] & MASK[size], self.d[reg] & MASK[size], size, xin=self.x, keepz=True), size)
            return
        if kind == 'cmp':
            if opm >= 4:                             # EOR (CMPM not supported)
                if mode == 1:
                    self.bad(op)
                loc = self.ea(mode, reg, size)
                r = self.get(loc, size) ^ self.d[rn]
                self.logic(r, size)
                self.put(loc, r, size)
                return
            self.sub(self.d[rn] & MASK[size], self.get(self.ea(mode, reg, size), size), size, cmp=True)
            return
        if opm < 4:                                  # <ea> op Dn -> Dn
            s = self.get(self.ea(mode, reg, size), size)
            d = self.d[rn] & MASK[size]
            loc = ('d', rn)
            a, b = d, s
        else:                                        # Dn op <ea> -> <ea>
            loc = self.ea(mode, reg, size)
            a, b = self.get(loc, size), self.d[rn] & MASK[size]
        if kind == 'add':
            r = self.add(a, b, size)
        elif kind == 'sub':
            r = self.sub(a, b, size)
        elif kind == 'and':
            r = a & b; self.logic(r, size)
        elif kind == 'or':
            r = a | b; self.logic(r, size)
        self.put(loc, r, size)

    def _g8(self, op):
        opm = (op >> 6) & 7
        mode, reg = (op >> 3) & 7, op & 7
        if opm in (3, 7):                            # DIVU / DIVS
            rn = (op >> 9) & 7
            s = self.get(self.ea(mode, reg, 2), 2)
            dv = self.d[rn]
            if s == 0:
                raise SimError('division by zero at %06X' % self.pc)
            if opm == 3:
                q, r = divmod(dv, s)
            else:
                a, b = sx(dv, 4), sx(s, 2)
                q = int(a / b)
                r = a - q * b
            if (opm == 3 and q > 0xFFFF) or (opm == 7 and not -0x8000 <= q <= 0x7FFF):
                self.v = 1; self.c = 0
                return
            self.d[rn] = ((r & 0xFFFF) << 16) | (q & 0xFFFF)
            self.nz(q, 2); self.v = self.c = 0
            return
        if opm >= 4 and mode in (0, 1):
            self.bad(op)                             # SBCD
        self._arith(op, 'or')

    def _g9(self, op): self._arith(op, 'sub')
    def _gB(self, op): self._arith(op, 'cmp')
    def _gD(self, op): self._arith(op, 'add')

    def _gC(self, op):
        opm = (op >> 6) & 7
        mode, reg = (op >> 3) & 7, op & 7
        rn = (op >> 9) & 7
        if opm in (3, 7):                            # MULU / MULS
            s = self.get(self.ea(mode, reg, 2), 2)
            d = self.d[rn] & 0xFFFF
            r = (s * d) if opm == 3 else (sx(s, 2) * sx(d, 2))
            r &= 0xFFFFFFFF
            self.d[rn] = r
            self.logic(r, 4)
            return
        if opm >= 4 and mode in (0, 1):
            if (op & 0x1F8) == 0x140:                # EXG Dx,Dy
                self.d[rn], self.d[reg] = self.d[reg], self.d[rn]; return
            if (op & 0x1F8) == 0x148:                # EXG Ax,Ay
                self.a[rn], self.a[reg] = self.a[reg], self.a[rn]; return
            if (op & 0x1F8) == 0x188:                # EXG Dx,Ay
                self.d[rn], self.a[reg] = self.a[reg], self.d[rn]; return
            self.bad(op)                             # ABCD
        self._arith(op, 'and')

    def _gE(self, op):
        if (op & 0xC0) == 0xC0:                      # memory shift by 1 (word)
            kind = (op >> 9) & 3
            left = op & 0x100
            loc = self.ea((op >> 3) & 7, op & 7, 2)
            self.put(loc, self._shift(kind, left, self.get(loc, 2), 1, 2), 2)
            return
        size = (1, 2, 4)[(op >> 6) & 3]
        kind = (op >> 3) & 3
        left = op & 0x100
        reg = op & 7
        cnt = (op >> 9) & 7
        cnt = (self.d[cnt] & 63) if op & 0x20 else (cnt or 8)
        self.put(('d', reg), self._shift(kind, left, self.d[reg] & MASK[size], cnt, size), size)

    def _shift(self, kind, left, v, cnt, size):
        bits = size * 8
        m = MASK[size]
        msb = MSB[size]
        if cnt == 0:
            self.c = self.x if kind == 2 else 0
            self.nz(v, size)
            self.v = 0
            return v
        vflag = 0
        if kind == 0:                                # AS
            if left:
                for _ in range(cnt):
                    c = 1 if v & msb else 0
                    nv = (v << 1) & m
                    if (nv & msb) != (v & msb):
                        vflag = 1
                    v = nv
                self.c = self.x = c
            else:
                for _ in range(cnt):
                    c = v & 1
                    v = (v >> 1) | (v & msb)
                self.c = self.x = c
        elif kind == 1:                              # LS
            for _ in range(cnt):
                if left:
                    c = 1 if v & msb else 0
                    v = (v << 1) & m
                else:
                    c = v & 1
                    v >>= 1
            self.c = self.x = c
        elif kind == 2:                              # ROX
            x = self.x
            for _ in range(cnt):
                if left:
                    c = 1 if v & msb else 0
                    v = ((v << 1) | x) & m
                else:
                    c = v & 1
                    v = (v >> 1) | (msb if x else 0)
                x = c
            self.c = self.x = x
        else:                                        # RO
            for _ in range(cnt):
                if left:
                    c = 1 if v & msb else 0
                    v = ((v << 1) | c) & m
                else:
                    c = v & 1
                    v = (v >> 1) | (msb if c else 0)
            self.c = c
        self.v = vflag
        self.nz(v, size)
        return v

    def _gA(self, op): self.bad(op)
    def _gF(self, op): self.bad(op)


def selftest():
    """Small instruction checks (hand-assembled)."""
    rom = bytearray(0x1000)
    prog = bytes.fromhex(
        '7005'          # moveq #5,d0
        '7203'          # moveq #3,d1
        'D041'          # add.w d1,d0      -> 8
        'E548'          # lsl.w #2,d0      -> 32
        '4440'          # neg.w d0         -> -32
        'E240'          # asr.w #1,d0      -> -16
        '48C0'          # ext.l d0
        'C1FC0003'      # muls.w #3,d0     -> -48
        '4E75')
    rom[0x100:0x100 + len(prog)] = prog
    cpu = M68K(rom)
    cpu.call(0x100)
    assert sx(cpu.d[0], 4) == -48, hex(cpu.d[0])
    prog2 = bytes.fromhex('41F900FF0000' '30BC1234' '08D00003' '0C501A34' '57C1' '4E75')
    # lea $FF0000,a0 ; move.w #$1234,(a0) ; bset #3,(a0) ; cmpi.w #$1A34,(a0) ; seq d1 ; rts
    cpu.rom[0x200:0x200 + len(prog2)] = prog2
    cpu.call(0x200)
    assert cpu.rw(0xFF0000) == 0x1A34 and cpu.d[1] & 0xFF == 0xFF
    return True


if __name__ == '__main__':
    print('m68k_sim selftest', selftest())
