"""Selected-ROM intro camera primitives; execute original bytes as the oracle.

This does not choose a VBlank cadence or emulate player controls. The camera
primitive consumes the previous player position cached by 06:81D5. The caller
must preserve that original order.
"""
from starfox_rom import rom_hex
from pathlib import Path
import hashlib
import json
import runpy
import sys

ROOT = Path(__file__).resolve().parents[1]


def execute(rom, pc, stop, ram, x=0x336):
    """Bounded 65816 executor of the two asserted arithmetic fragments."""
    a = y = 0
    width = 8
    index_width = 16
    carry = zero = negative = False
    stack = []

    def get(address, size):
        if address >= 0x8000:
            return int.from_bytes(rom[address & 0x7fff:(address & 0x7fff)+size], 'little')
        return sum(ram.get(address+i, 0) << (8*i) for i in range(size))

    def put(address, value, size):
        for i in range(size):
            ram[address+i] = (value >> (8*i)) & 255
        if address == 0x4203:
            product = ram[0x4202] * ram[0x4203]
            ram[0x4216] = product & 255
            ram[0x4217] = product >> 8

    def flags(value):
        nonlocal zero, negative
        zero = value == 0
        negative = bool(value & (1 << (width-1)))

    for _ in range(500):
        if pc == stop:
            return ram
        op = rom[pc]
        pc += 1
        size = width // 8
        mask = (1 << width)-1
        if op in (0xc2, 0xe2):
            bits = rom[pc]
            pc += 1
            if bits & 32:
                width = 16 if op == 0xc2 else 8
                a &= (1 << width)-1
            if bits & 16:
                index_width = 16 if op == 0xc2 else 8
                x &= (1 << index_width)-1
                y &= (1 << index_width)-1
        elif op in (0xa9, 0x49, 0xc9, 0x69, 0xe9):
            value = int.from_bytes(rom[pc:pc+size], 'little')
            pc += size
            if op == 0xa9:
                a = value
                flags(a)
            elif op == 0x49:
                a ^= value
                flags(a)
            elif op == 0xc9:
                carry = a >= value
                flags((a-value) & mask)
            elif op == 0x69:
                value += a+carry
                carry = value > mask
                a = value & mask
                flags(a)
            else:
                value = a-value-(not carry)
                carry = value >= 0
                a = value & mask
                flags(a)
        elif op in (0xad, 0xbd, 0xb9, 0xa5, 0xb5, 0x8d, 0x85,
                    0x86, 0x84, 0xa6, 0xa4, 0x64, 0xc6,
                    0x6d, 0xed, 0xcd, 0xd5):
            absolute = op in (0xad, 0xbd, 0xb9, 0x8d, 0x6d, 0xed, 0xcd)
            length = 2 if absolute else 1
            address = int.from_bytes(rom[pc:pc+length], 'little')
            pc += length
            if op in (0xbd, 0xb5, 0xd5):
                address += x
            elif op == 0xb9:
                address += y
            if op in (0x8d, 0x85):
                put(address, a, size)
            elif op in (0x86, 0x84):
                put(address, x if op == 0x86 else y, index_width//8)
            elif op in (0xa6, 0xa4):
                value = get(address, index_width//8)
                if op == 0xa6:
                    x = value
                else:
                    y = value
            elif op == 0x64:
                put(address, 0, size)
            elif op == 0xc6:
                value = (get(address, size)-1) & mask
                put(address, value, size)
                flags(value)
            elif op in (0xcd, 0xd5):
                value = get(address, size)
                carry = a >= value
                flags((a-value) & mask)
            elif op in (0x6d, 0xed):
                value = get(address, size)
                if op == 0x6d:
                    value += a+carry
                    carry = value > mask
                else:
                    value = a-value-(not carry)
                    carry = value >= 0
                a = value & mask
                flags(a)
            else:
                a = get(address, size)
                flags(a)
        elif op in (0x10, 0x30, 0xf0, 0xd0, 0x80):
            delta = int.from_bytes(rom[pc:pc+1], 'little', signed=True)
            pc += 1
            if (op == 0x10 and not negative) or (op == 0x30 and negative) or (op == 0xf0 and zero) or (op == 0xd0 and not zero) or op == 0x80:
                pc += delta
        elif op == 0x4c:
            pc = (pc & ~0x7fff) | (int.from_bytes(rom[pc:pc+2], 'little') & 0x7fff)
        elif op == 0x5c:
            address = int.from_bytes(rom[pc:pc+3], 'little')
            pc = (address >> 16)*32768+(address & 32767)
        elif op in (0x18, 0x38):
            carry = op == 0x38
        elif op == 0x1a:
            a = (a+1) & mask
            flags(a)
        elif op == 0x0a:
            carry = bool(a & (1 << (width-1)))
            a = (a << 1) & mask
            flags(a)
        elif op == 0x6a:
            bit = a & 1
            a = (a >> 1) | (int(carry) << (width-1))
            carry = bool(bit)
            flags(a)
        elif op in (0xaa, 0xa8):
            if op == 0xaa:
                x = a & ((1 << index_width)-1)
            else:
                y = a & ((1 << index_width)-1)
        elif op == 0x48:
            stack.append(a)
        elif op == 0x8b:
            stack.append(0)
        elif op == 0xab:
            stack.pop()
        elif op == 0xea:
            pass
        elif op == 0x6b:
            return ram
        else:
            raise AssertionError(f'Unsupported opcode {op:02X} at {pc-1:06X}')
    raise AssertionError('Original camera fragment exceeded its bound')


def put(ram, address, value, size=2):
    for i in range(size):
        ram[address+i] = (value >> (8*i)) & 255


def word(ram, address):
    return ram.get(address, 0) | (ram.get(address+1, 0) << 8)


def original_vector(rom, speed, pitch=0, yaw=0):
    ram = {0x7e: speed, 0x15a8: pitch, 0x15a9: yaw}
    execute(rom, 0xfc41e, 0xfc5e4, ram)
    return [word(ram, a) for a in (2, 8, 0x90)]


def original_viewmove(rom, pview, velocity, cached_player, object_vz=63, boost=0):
    ram = {0x336+0x23: boost}
    for a, v in [(0x14fc, pview), (0x14f6, velocity), (0x1513, cached_player),
                 (0x336+0x33, object_vz)]:
        put(ram, a, v)
    execute(rom, 0x5d111, 0x5d1bd, ram)
    return word(ram, 0x14fc), word(ram, 0x14f6)


def trajectory(rom, end_frame=72):
    """Post-background playercred initialization; frames2..72, no invented clock.

    06:835D cached63 before bg_intro_1's installed initializer runs. The
    initializer resets world/pview, but deliberately preserves that cache.
    """
    vz = original_vector(rom, 65)[2]
    pview, velocity = 0, 65
    states = []
    for frame in range(2, end_frame + 1):
        world = (frame-1)*vz
        cached = vz if frame == 2 else world-vz
        pview, velocity = original_viewmove(rom, pview, velocity, cached, vz)
        states.append(dict(frame=frame, world_z=world, cached_z=cached,
                           pview_z=pview, velocity=velocity, view_z=(pview-120)&65535))
    return states


def check_observation(rom):
    observed = json.loads((ROOT/'evidence/starfox-intro-camera.json').read_text())
    assert observed['rom_sha256'] == hashlib.sha256(rom).hexdigest()
    matched = []
    for state in trajectory(rom):
        if any(all(sample[key] == value for key, value in state.items()) for sample in observed['samples']):
            matched.append(state['frame'])
    assert len(matched) >= 60, matched
    return matched


def check_target_records(rom, manifest, head, numeric, poses):
    """Verify actual camera_test.asm memory; caller validates the ROM/session."""
    cases = manifest['numeric_cases']
    states = trajectory(rom)
    assert head == b'M4CM'+b''.join(v.to_bytes(2, 'big') for v in [1, len(cases), len(states)]), head.hex()
    expected_numeric = b''.join(v.to_bytes(2, 'big') for case in cases for v in original_viewmove(rom, *case[:3], *case[3:5]))
    assert numeric == expected_numeric, (numeric.hex(), expected_numeric.hex())
    expected_poses = b''.join(s[key].to_bytes(2, 'big') for s in states for key in ('world_z', 'pview_z', 'velocity', 'view_z'))
    assert poses == expected_poses, (poses.hex(), expected_poses.hex())
    return dict(actual_camera_cases=len(cases), actual_camera_frames=len(states),
                matched_original_frames=check_observation(rom))


def recover():
    rom, authority = runpy.run_path(str(ROOT/'tools/extract-intro.py'))['recover']()
    # Every fragment follows the selected ROM, rather than auxiliary offsets.
    blocks = {
        'playercred_initializer': (0x5b566, 0x5b6ea),
        'playercred_strategy': (0x5b6ea, 0x5b719),
        'gen_3d_vectors': (0xfc41e, 0xfc5e4),
        'viewmove_z': (0x5d111, 0x5d1bd),
        'cache_previous_player': (0x3035d, 0x3037c),
    }
    assert rom[0x5b6ea:0x5b6f0] == bytes.fromhex(rom_hex(0x5b6ea, 6))
    assert rom[0x5b6c8:].startswith(bytes.fromhex(rom_hex(0x5b6c8, 16)))
    assert rom[0x5d111:].startswith(bytes.fromhex(rom_hex(0x59527, 14)))
    assert rom[0x3035d:].startswith(bytes.fromhex(rom_hex(0x3035d, 22)))
    assert rom[0x18a5] == 0 and rom[0x18e5] == 127
    background = rom[0x1a8db:0x1a938]
    assert bytes.fromhex(rom_hex(0x1a805, 11)) in background
    assert original_vector(rom, 65) == [0, 0, 63]
    values = [0, 1, 7, 8, 49, 50, 63, 64, 65, 199, 200, 32767, 32768, 65535]
    cases = []
    for v in values:
        for pview, velocity, player, vz, boost in [
            (v, 65, 0, 63, 0), (0, v, 0, 63, 0),
            (50, 63, v, 63, 0), (65500, 65, v, 63, 11),
        ]:
            result = original_viewmove(rom, pview, velocity, player, vz, boost)
            cases.append([pview, velocity, player, vz, boost, *result])
    (ROOT/'build/intro-camera-cases.inc').write_text(
        f'M4_CAMERA_CASES equ {len(cases)}\n'+''.join('        dc.w '+','.join(f'${v:04x}' for v in case)+'\n' for case in cases), encoding='utf-8')
    states = trajectory(rom)
    manifest = dict(rom=authority, scope='Zero-angle playercred interval; no VBlank cadence, input, later camera strategies or whole boot reproduction',
                    source={name: dict(offset=a, end=b, sha256=hashlib.sha256(rom[a:b]).hexdigest(), bytes=rom[a:b].hex()) for name,(a,b) in blocks.items()},
                    background_installs_initializer=dict(offset=0x1a8db, bytes=background.hex()),
                    vector_zero_angles=original_vector(rom, 65), numeric_cases=cases, trajectory=states)
    (ROOT/'build/intro-camera-origin.json').write_text(json.dumps(manifest, indent=2)+'\n', encoding='utf-8')
    return rom, manifest


if __name__ == '__main__':
    rom, result = recover()
    report = dict(vector=result['vector_zero_angles'], cases=len(result['numeric_cases']))
    if '--check-observed' in sys.argv:
        report['matched_original_frames'] = check_observation(rom)
    print(json.dumps(report))
