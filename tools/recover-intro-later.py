"""Selected-ROM late intro/title entries and bounded arithmetic correspondence.

No emulator, scene approximation or alternative movement. The bounded 65816
runner executes only the asserted boss motion, title, animation, state0/1
and final Z comparison fragments. Zaco aiming/RNG/weapon/allocator remain
explicit integration dependencies; their ROM addresses are recorded.
"""
from starfox_rom import rom_hex, title_demo, title_rotation
from pathlib import Path
import hashlib
import json

ROOT = Path(__file__).resolve().parents[1]
SHA256 = '3857b5294ea8f7468849437bb2d8271564e8a0ff30774622e9c872bcbd53a84d'
OBJ = 0x336


def put(ram, address, value, size=2):
    for index in range(size):
        ram[address + index] = (value >> (index * 8)) & 255


def get(ram, address, size=2):
    return sum(ram.get(address + index, 0) << (index * 8) for index in range(size))


def execute(rom, start, ram, stop=None):
    """Actual ROM byte execution, M=8/X=16 initially, fixed object DP index."""
    pc, a, x, y, width = start, 0, OBJ, 0, 8
    carry = zero = negative = False
    calls = []
    for _ in range(1000):
        if pc == stop:
            return ram
        op = rom[pc]
        pc += 1
        size, mask = width // 8, (1 << width) - 1
        av = a & mask
        def flags(value):
            nonlocal zero, negative
            zero = (value & mask) == 0
            negative = bool(value & (1 << (width - 1)))
        def set_a(value):
            nonlocal a
            a = (a & ~mask) | (value & mask)
            flags(value)
        if op in (0xc2, 0xe2):
            assert rom[pc] == 0x20
            width = 16 if op == 0xc2 else 8
            pc += 1
        elif op in (0xa9, 0xc9, 0x29, 0x09, 0x69, 0xe9, 0x49):
            value = int.from_bytes(rom[pc:pc + size], 'little')
            pc += size
            if op == 0xa9: set_a(value)
            elif op == 0xc9: carry = av >= value; flags(av - value)
            elif op == 0x29: set_a(av & value)
            elif op == 0x09: set_a(av | value)
            elif op == 0x49: set_a(av ^ value)
            elif op == 0x69:
                value += av + carry; carry = value > mask; set_a(value)
            else:
                value = av - value - (not carry); carry = value >= 0; set_a(value)
        elif op in (0xad, 0xbd, 0xb5, 0x8d, 0x9d, 0x95, 0xd6,
                    0x75, 0x6d, 0xac, 0xd9):
            length = 1 if op in (0xb5, 0x95, 0xd6, 0x75) else 2
            address = int.from_bytes(rom[pc:pc + length], 'little'); pc += length
            if op in (0xbd, 0xb5, 0x9d, 0x95, 0xd6, 0x75): address += x
            if op == 0xd9: address += y
            value = get(ram, address, size)
            if op in (0x8d, 0x9d, 0x95): put(ram, address, av, size)
            elif op == 0xd6:
                value = (value - 1) & mask; put(ram, address, value, size); flags(value)
            elif op in (0x75, 0x6d):
                value += av + carry; carry = value > mask; set_a(value)
            elif op == 0xd9: carry = av >= value; flags(av - value)
            elif op == 0xac: y = get(ram, address)
            else: set_a(value)
        elif op in (0x10, 0x30, 0xf0, 0xd0, 0x90, 0xb0, 0x80, 0x82):
            count = 2 if op == 0x82 else 1
            delta = int.from_bytes(rom[pc:pc + count], 'little', signed=True); pc += count
            if {0x10: not negative, 0x30: negative, 0xf0: zero, 0xd0: not zero,
                0x90: not carry, 0xb0: carry, 0x80: True, 0x82: True}[op]: pc += delta
        elif op in (0x22, 0x5c):
            target = int.from_bytes(rom[pc:pc + 3], 'little'); pc += 3
            if op == 0x22: calls.append(pc)
            pc = ((target >> 16) & 127) * 32768 + (target & 32767)
        elif op in (0x18, 0x38): carry = op == 0x38
        elif op == 0x1a: set_a(av + 1)
        elif op == 0x6b:
            if calls: pc = calls.pop()
            else: return ram
        else:
            raise AssertionError(('Unsupported original opcode', hex(pc - 1), hex(op)))
    raise AssertionError('Original fragment exceeded instruction bound')


def negative_difference(a, b):
    return bool((a - b) & 32768)


def boss_motion(x, y, z, vx, vy, vz, scroll, gameframe, player_velocity):
    """07:8D4E..8DFA, including calls 1F:C7BB and 1F:DC69; word wrap."""
    if negative_difference(scroll, 160):
        scroll = (scroll + 1) & 65535
    elif negative_difference(scroll, 200):
        scroll = (scroll + (not gameframe & 1)) & 65535
    elif scroll == 232 or negative_difference(scroll, 232):
        scroll = (scroll + (not gameframe & 3)) & 65535
    if not negative_difference(y, 0xfe34) and not gameframe & 3 and vy:
        vy = (vy - 1) & 65535
    return [(x + vx) & 65535, (y + vy) & 65535,
            (z + vz + player_velocity) & 65535, vx, vy, vz, scroll]


def animation(value):
    """07:8F0C..8F24, also byte-identical at 07:8FC1."""
    value = (value + 1) & 255
    if not value & 128: value = (value + 12) & 255
    value &= 127
    if value >= 12: value -= 12
    return value | 128


def zaco2_phases01(state, counter, pitch, yaw, roll):
    """07:8FDA..9031; caller MUST execute state2 during this same update."""
    if state == 0:
        roll = (roll + 6) & 255
        counter = (counter - 1) & 255
        if counter == 0: state, counter = 1, 42
    if state == 1:
        pitch, yaw, roll = (pitch + 4) & 255, (yaw + 9) & 255, (roll + 6) & 255
        counter = (counter - 1) & 255
        if counter == 0: state, counter = 2, 20
    return [state, counter, pitch, yaw, roll]


def recover():
    rom = (ROOT / 'ref/Star Fox (USA).sfc').read_bytes()
    assert hashlib.sha256(rom).hexdigest() == SHA256
    scripts = json.loads((ROOT / 'build/m4-scripts.json').read_text())
    assert scripts['sha256'] == SHA256
    events = []
    names = {0x078ca3: 'boss7intro', 0x078ec5: 'zacointro', 0x078f91: 'zaco2intro'}
    for command in scripts['scripts'][0]['commands']:
        if command.get('strategy') in names:
            assert rom[command['offset']:command['offset'] + 14].hex() == command['bytes']
            events.append(dict(command, unit=names[command['strategy']]))
    assert len(events) == 14
    title_object = bytes.fromhex(rom_hex(0x02c01, 4))
    assert rom[0x2c01:0x2c05] == title_object
    _, demo_position = title_demo()
    initial_rotation = title_rotation()
    pitch, yaw, roll = initial_rotation
    fragments = {
        'boss_initializer': (0x38ca3, 0x38d4e), 'boss_motion': (0x38d4e, 0x38dfb),
        'boss_children': (0x38dfb, 0x38ec5), 'zaco_initializer': (0x38ec5, 0x38f0c),
        'zaco_update': (0x38f0c, 0x38f91), 'zaco2_initializer': (0x38f91, 0x38fc1),
        'zaco2_update': (0x38fc1, 0x39194), 'zaco2_phases01': (0x38fda, 0x39032),
        'autoexit_after_motion': (0x3917c, 0x39194),
        'title_initializer_and_tick': (0xff600, 0xff625),
        'add_vectors_to_position': (0xfc7bb, 0xfc7d6), 'add_player_velocity_z': (0xfdc69, 0xfdc76),
        'intro_loop_and_fade': (0xff5c8, 0xff600), 'title_entry_and_loop': (0xff4c8, 0xff586),
    }
    assert rom[0x3917c:0x39194].hex() == rom_hex(0x3917c, 24)
    assert rom[0xff600:0xff625].hex() == rom_hex(0xff600, 37)
    boss_cases = []
    for scroll in (0, 159, 160, 199, 200, 231, 232, 233, 32767, 32768, 65535):
        for frame in range(8):
            for y, vy in ((0xfe33, 5), (0xfe34, 1), (0xfe35, 0), (0x7fff, 65535)):
                state = [65530, y, 65520, 7, vy, 15, scroll, frame, 63]
                ram = {0x15bd: frame}
                for at, val in zip((0x0c, 0x0e, 0x10, 0x2f, 0x31, 0x33), state[:6]): put(ram, OBJ + at, val)
                put(ram, 0x169e, scroll); put(ram, 0x14f6, 63)
                execute(rom, 0x38d4e, ram)
                actual = [get(ram, OBJ + at) for at in (0x0c, 0x0e, 0x10, 0x2f, 0x31, 0x33)] + [get(ram, 0x169e)]
                assert actual == boss_motion(*state), (state, actual, boss_motion(*state))
                boss_cases.append(dict(input=state, expected=actual))
    exit_cases = []
    for obj_z in (0, 1, 32767, 32768, 65534, 65535):
        for player_z in (0, 1, 32767, 32768, 65534, 65535):
            for previous in (0, 1):
                ram = {0x1ffe: previous}
                put(ram, 0x123a, 0x400); put(ram, OBJ + 0x10, obj_z); put(ram, 0x410, player_z)
                execute(rom, 0x3917c, ram)
                expected = 1 if negative_difference(obj_z, player_z) else previous
                assert ram[0x1ffe] == expected
                exit_cases.append([obj_z, player_z, previous, expected])
    phase_cases = []
    for state in (0, 1, 2):
        for counter in (0, 1, 2, 30, 42, 255):
            values = [state, counter, 254, 253, 252]
            ram = {}
            for at, val in zip((0x1cdc + OBJ, OBJ + 0x22, OBJ + 0x12, OBJ + 0x13, OBJ + 0x14), values): put(ram, at, val, 1)
            execute(rom, 0x38fda, ram, stop=0x39032)
            actual = [get(ram, at, 1) for at in (0x1cdc + OBJ, OBJ + 0x22, OBJ + 0x12, OBJ + 0x13, OBJ + 0x14)]
            assert actual == zaco2_phases01(*values), (values, actual)
            phase_cases.append(dict(input=values, expected=actual))
    for value in range(256):
        ram = {0x1ce7 + OBJ: value}
        execute(rom, 0x38f0c, ram, stop=0x38f25)
        assert ram[0x1ce7 + OBJ] == animation(value), value
    title_cases = []
    for z in (0, 64, 32767, 65535):
        for velocity in (0, 63, 65, 65535):
            ram = {}
            put(ram, OBJ + 0x10, z); put(ram, 0x14f6, velocity)
            execute(rom, 0xff600, ram)
            actual = [get(ram, OBJ + at, 1) for at in (0x12, 0x13, 0x14)] + [get(ram, OBJ + 0x10)]
            assert actual == [pitch, yaw, (roll + 2) & 255, (z + velocity) & 65535]
            title_cases.append([z, velocity, *actual])
    report = dict(rom_sha256=SHA256, events=events,
        source_blocks={name: dict(offset=a, end=b, sha256=hashlib.sha256(rom[a:b]).hexdigest(), bytes=rom[a:b].hex()) for name, (a, b) in fragments.items()},
        title=dict(script_index=0x7a18, table_offset=0x2c01, strategy=int.from_bytes(title_object[:3], 'little'),
                   shape_table_index=title_object[3], position=demo_position, initial_rotation=initial_rotation,
                   first_roll=(roll + 2) & 255,
                   background_table_offset=0x1ad3b, background_strategy=0x03a9f5),
        dependencies=dict(vector_wrapper=0x1fd5a7, vector_original=0x1fc41e, random=0x02fc4a,
                          angular_chase_3=0x1fd8bd, angular_chase_4=0x1fd8f7, speed_to=0x1fd60d,
                          aim_pitch=0x1fd03e, aim_yaw=0x1fd021, weapon=0x1fd146, remove_object=0x1fd501,
                          child_make=0x1fd54b, child_link=0x1fd56f),
        cases=dict(boss=boss_cases, exit=exit_cases, phases01=phase_cases, animation_all_byte_values=256, title=title_cases),
        scope='ROM byte execution versus semantic primitives. No target/emulator execution here. Zaco RNG/aim/weapon/allocator and full scene integration remain required.')
    (ROOT / 'build/intro-later-origin.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print('PASS original-byte correspondence:', len(boss_cases), 'boss,', len(exit_cases), 'exit,', len(phase_cases), 'phase01, 256 animation,', len(title_cases), 'title')
    return rom, report


if __name__ == '__main__':
    recover()
