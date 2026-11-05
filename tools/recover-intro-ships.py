"""Recover the three opening old_type ships; original code is the oracle.

First two strategies are recovered through removal. Third stops at an external
effect request, rather than substituting explosions, smoke or RNG behavior.
"""
from starfox_rom import rom_hex
from pathlib import Path
import hashlib
import json
import re
import runpy

ROOT = Path(__file__).resolve().parents[1]
CAMERA = runpy.run_path(str(ROOT / 'tools/recover-intro-camera.py'))
SHA = '3857b5294ea8f7468849437bb2d8271564e8a0ff30774622e9c872bcbd53a84d'
INITIALIZERS = [0x38a90, 0x38b3b, 0x388ea]
STRATEGIES = [0x38acf, 0x38b7a, 0x38933]


def signed(v, bits=8):
    return (v & ((1 << bits)-1)) - ((1 << bits) if v & (1 << (bits-1)) else 0)


def chase(current, target, shift):
    delta = signed(target-current)
    if not delta:
        return current
    step = max(abs(delta) >> shift, 1)
    return (current + (-step if delta < 0 else step)) & 255


def vectors(rom, pitch, yaw):
    def mul(a, b):
        result = abs(a)*abs(b)//128
        return -result if (a < 0) != (b < 0) else result
    sin_y = signed(rom[0x18a5 + ((-yaw) & 255)])
    cos_y = signed(rom[0x18e5 + ((-yaw) & 255)])
    sin_p = signed(rom[0x18a5 + pitch])
    cos_p = signed(rom[0x18e5 + pitch])
    return [mul(mul(120, sin_y), cos_p) & 65535, mul(120, sin_p) & 65535,
            mul(mul(120, cos_y), cos_p) & 65535]


class OriginalShip:
    """Execute only selected strategy/chase code; stop at external effects."""
    def __init__(self, rom, kind, player_z):
        self.rom, self.kind = rom, kind
        self.ram = {}
        self.x, self.y = 0x336, 0x400
        self.alive = True
        self.pending = None
        self.put(self.x+12, 50, 2)
        self.put(self.x+14, -400, 2)
        self.put(self.x+16, player_z-700, 2)
        self.pc = INITIALIZERS[kind]
        self.initial = True

    def put(self, address, value, size):
        for i in range(size):
            self.ram[address+i] = (value >> (i*8)) & 255

    def get(self, address, size):
        return sum(self.ram.get(address+i, 0) << (i*8) for i in range(size))

    def state(self):
        x = self.x
        return dict(xyz=[self.get(x+i, 2) for i in (12, 14, 16)],
                    velocity=[self.get(x+i, 2) for i in (47, 49, 51)],
                    angles=[self.get(x+i, 1) for i in (18, 19, 20)],
                    smooth=[self.get(x+i, 1) for i in (36, 37)],
                    count=self.get(x+34, 1), life=self.get(x+10, 1),
                    state=self.get(x+0x1cdc, 1), timer=self.get(x+40, 1),
                    alive=self.alive, pending=self.pending)

    def tick(self, frame, delta):
        assert self.alive and self.pending is None
        self.put(0x15bd, frame, 1)
        self.put(0x14f6, delta, 2)
        pc = self.pc if self.initial else STRATEGIES[self.kind]
        self.initial = False
        a = 0
        width = 8
        carry = zero = negative = False
        calls = []

        def flags(v):
            nonlocal zero, negative
            zero = (v & ((1 << width)-1)) == 0
            negative = bool(v & (1 << (width-1)))

        for _ in range(1000):
            if pc == 0xfd501:  # remove_obj_l: no observable object after unlink
                self.alive = False
                return self.state()
            if pc == 0xfdc25:  # original nextstate tail re-enters saved strategy
                assert self.rom[pc:pc+4].hex() == rom_hex(0xfdc25, 4)
                pc = STRATEGIES[self.kind]
                continue
            if pc==0x17c4a and hasattr(self,'effects'):
                a=self.effects.rng();width=8;flags(a);pc=calls.pop();continue
            if pc in (0x36eee,0x30ea8) and hasattr(self,'effects'):
                self.effects.callback(self,pc,frame);pc=calls.pop();continue
            if pc in (0x36eee, 0x30ea8, 0x37157):
                self.pending = {0x36eee: 'medium_explosion', 0x30ea8: 'smoke', 0x37157: 'fast_debris'}[pc]
                return self.state()
            if pc == 0xfd5a7:
                velocity = CAMERA['original_vector'](self.rom, self.get(0x7e, 1),
                                                      self.get(0x15a8, 1), self.get(0x15a9, 1))
                for offset, value in zip((47, 49, 51), velocity):
                    self.put(self.x+offset, value, 2)
                pc = calls.pop()
                continue
            op = self.rom[pc]
            pc += 1
            size, mask = width//8, (1 << width)-1
            if op in (0xc2, 0xe2):
                assert self.rom[pc] == 32
                width = 16 if op == 0xc2 else 8
                a &= (1 << width)-1
                pc += 1
            elif op in (0xa9, 0x09, 0x29, 0x49, 0xc9, 0x69, 0xe9):
                value = int.from_bytes(self.rom[pc:pc+size], 'little')
                pc += size
                if op == 0xa9: a = value
                elif op == 0x09: a |= value
                elif op == 0x29: a &= value
                elif op == 0x49: a ^= value
                elif op == 0xc9:
                    carry = a >= value
                    flags((a-value) & mask)
                    continue
                elif op == 0x69:
                    value += a+carry
                    carry = value > mask
                    a = value & mask
                else:
                    value = a-value-(not carry)
                    carry = value >= 0
                    a = value & mask
                flags(a)
            elif op in (0xb5, 0xbd, 0xa5, 0xad, 0x95, 0x9d, 0x85, 0x8d,
                        0xd6, 0x75, 0x65, 0x6d, 0xc5, 0xe5, 0x9f, 0xb9, 0x99, 0x79):
                length = 3 if op == 0x9f else 2 if op in (0xbd, 0xad, 0x9d, 0x8d, 0x6d, 0xb9, 0x99, 0x79) else 1
                address = int.from_bytes(self.rom[pc:pc+length], 'little')
                pc += length
                if op in (0xb5, 0xbd, 0x95, 0x9d, 0xd6, 0x75, 0x9f): address += self.x
                if op in (0xb9,0x99,0x79): address += self.y
                if address >> 16 == 0x7e: address &= 65535
                value = self.get(address, size)
                if op in (0x95, 0x9d, 0x85, 0x8d, 0x9f, 0x99): self.put(address, a, size)
                elif op == 0xd6:
                    value = (value-1) & mask
                    self.put(address, value, size)
                    flags(value)
                elif op == 0xc5:
                    carry = a >= value
                    flags((a-value) & mask)
                elif op in (0x75, 0x65, 0x6d, 0x79):
                    value += a+carry
                    carry = value > mask
                    a = value & mask
                    flags(a)
                elif op == 0xe5:
                    value = a-value-(not carry)
                    carry = value >= 0
                    a = value & mask
                    flags(a)
                else:
                    a = value
                    flags(a)
            elif op in (0xd0, 0xf0, 0x10, 0x30, 0x80, 0x82):
                length = 2 if op == 0x82 else 1
                delta_pc = int.from_bytes(self.rom[pc:pc+length], 'little', signed=True)
                pc += length
                if op in (0x80, 0x82) or (op == 0xd0 and not zero) or (op == 0xf0 and zero) or (op == 0x10 and not negative) or (op == 0x30 and negative): pc += delta_pc
            elif op in (0x22, 0x5c):
                target = int.from_bytes(self.rom[pc:pc+3], 'little')
                pc += 3
                if op == 0x22: calls.append(pc)
                pc = (target >> 16)*32768+(target & 32767)
            elif op in (0x18, 0x38): carry = op == 0x38
            elif op == 0x1a:
                a = (a+1) & mask
                flags(a)
            elif op == 0x6a:
                bit = a & 1
                a = (a >> 1) | (int(carry) << (width-1))
                carry = bool(bit)
                flags(a)
            elif op == 0x6b:
                if calls: pc = calls.pop()
                else: return self.state()
            else: raise AssertionError((hex(pc-1), hex(op)))
        raise AssertionError('Ship strategy exceeded its bound')


def initial(kind, player_z):
    return dict(xyz=[50, (-400) & 65535, (player_z-700) & 65535], velocity=[0, 0, 0],
                angles=[16, 0, 0], smooth=[0, 16], count=33 if kind == 2 else 30,
                life=0 if kind == 2 else 70, state=0, timer=16 if kind == 2 else 0,
                alive=True, pending=None)


def tick(rom, s, kind, frame, delta):
    assert s['alive'] and s['pending'] is None
    while True:
        if kind != 2:
            s['life'] = (s['life']-1) & 255
            if not s['life']:
                s['alive'] = False
                return s
        if s['state'] == 0:
            if not s['count']:
                s['state'] += 1
                continue  # nextstate tail-dispatch, including life decrement
            s['count'] -= 1
            if kind == 2: s['angles'][2] = (s['angles'][2]+1) & 255
            if frame & 3 == 0:
                s['angles'][0] = (s['angles'][0]-1) & 255
                if kind != 2: s['angles'][1] = (s['angles'][1] + (1 if kind == 0 else -1)) & 255
        if s['state'] == 1:
            if kind == 2:
                s['timer'] = 20
                s['pending'] = 'medium_explosion'
                return s
            s['angles'][1] = chase(s['angles'][1], 64 if kind == 0 else 192, 4)
            s['angles'][0] = chase(s['angles'][0], 0, 4)
            s['angles'][2] = chase(s['angles'][2], 32 if kind == 0 else 224, 3)
        s['smooth'][0] = chase(s['smooth'][0], s['angles'][1], 5)
        s['smooth'][1] = chase(s['smooth'][1], s['angles'][0], 5)
        s['velocity'] = vectors(rom, s['smooth'][1], s['smooth'][0])
        s['xyz'] = [(p+v) & 65535 for p, v in zip(s['xyz'], s['velocity'])]
        s['xyz'][2] = (s['xyz'][2]+delta) & 65535
        return s


def recover():
    rom = (ROOT/'ref/Star Fox (USA).sfc').read_bytes()
    assert hashlib.sha256(rom).hexdigest() == SHA
    fragments = [(0x38a90, rom_hex(0x388ea, 16)),
                 (0x38acf, rom_hex(0x38acf, 12)),
                 (0x38b7a, rom_hex(0x38b7a, 12)),
                 (0xfdb66, rom_hex(0xfdb66, 10)),
                 (0xfdc69, rom_hex(0xfdc69, 13))]
    for address, data in fragments:
        assert rom[address:address+len(bytes.fromhex(data))] == bytes.fromhex(data)
    trajectories = []
    for kind in range(3):
        for start_frame, delta, player_z in [(0, 63, 3000), (1, 60, 65500), (2, 65535, 0), (3, 63, 2000)]:
            source = OriginalShip(rom, kind, player_z)
            own = initial(kind, player_z)
            records = []
            for step in range(75):
                frame = (start_frame+step) & 255
                actual = source.tick(frame, delta)
                expected = tick(rom, own, kind, frame, delta)
                assert actual == expected, (kind, step, actual, expected)
                records.append(json.loads(json.dumps(actual)))
                if not actual['alive'] or actual['pending']: break
            trajectories.append(dict(kind=kind, start_frame=start_frame, delta_z=delta, player_z=player_z, records=records))
    table = rom[0x18a5:0x19e5]
    (ROOT/'build/intro-ships-sine.bin').write_bytes(table)
    header = rom[0x65f0:0x660c]
    assert header.hex() == rom_hex(0x065f0, 28)
    model = dict(header_offset=0x65f0, header_bytes=header.hex(), points_offset=0x8d120,
                 faces_offset=0x8d15e, coordinate_shift=2, material_pointer=0x8213)
    report = dict(rom_sha256=SHA, initializers=INITIALIZERS, strategies=STRATEGIES,
                  fragments=[dict(offset=a, bytes=b) for a,b in fragments], model=model,
                  sine_offset=0x18a5, sine_bytes=320, gen_vector_offset=0xfc41e,
                  chase_helpers={3:0xfd8bd,4:0xfd8f7,5:0xfd938},
                  trajectories=trajectories,
                  source='SF/STRAT/GISTRATS.ASM:playerdown[2/3]intro; SF/SHAPES/SHAPES5.ASM:old_type',
                  scope='First two ships through removal; third through first medium-explosion request. Original creation/smoke/RNG/debris consumers are required to continue third ship.')
    (ROOT/'build/intro-ships-origin.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    # Exact destination layout for an onboard comparison after EACH real
    # 68000 update, not only a final pose that could hide divergent arithmetic.
    lines = [f'M4_INTRO_SHIP_CASES equ {sum(len(t["records"]) for t in trajectories)}',
             f'M4_INTRO_SHIP_TRAJECTORIES equ {len(trajectories)}', 'M4IntroShipVectorsCases:']
    for trajectory in trajectories:
        lines += ['        dc.w '+','.join(str(trajectory[k]) for k in
                    ('kind', 'start_frame', 'delta_z', 'player_z'))+f',{len(trajectory["records"])}']
        for state in trajectory['records']:
            data = bytearray(32)
            for i, value in enumerate(state['xyz']+state['velocity']):
                data[i*2:i*2+2] = value.to_bytes(2, 'big')
            data[12:15] = bytes(state['angles'])
            data[15] = 120
            data[16:18] = bytes(state['smooth'])
            data[18:22] = bytes((state['count'], state['life'], state['state'], trajectory['kind']))
            data[22:24] = int(state['alive']).to_bytes(2, 'big')
            event = 2 if state['pending'] else 5 if not state['alive'] else 0
            data[24:26] = event.to_bytes(2, 'big')
            data[26:28] = (2 if state['pending'] else 0).to_bytes(2, 'big')
            data[28] = state['timer']
            data[30:32] = (3).to_bytes(2, 'big')
            lines += ['        dc.b '+','.join(f'${v:02x}' for v in data)]
    (ROOT/'build/intro-ships-cases.inc').write_text('\n'.join(lines)+'\n',encoding='ascii')
    print('PASS original ship strategies:',sum(len(t['records']) for t in trajectories),'states')
    return rom, report


if __name__ == '__main__': recover()
