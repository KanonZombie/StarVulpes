"""Recover original Nintendo/Presents trail creation, update and draw order.

The byte executor is the original 65816 trail strategy. Pool indices and the
32-byte layout are destination storage; original list insertion/removal rules
determine which objects run and appear, including the newly-created trail.
"""
from starfox_rom import rom_hex
import hashlib
import json
from pathlib import Path
import runpy
import sys

ROOT = Path(__file__).resolve().parents[1]
TEXT = runpy.run_path(str(ROOT/'tools/recover-intro-text.py'))
CAMERA = runpy.run_path(str(ROOT/'tools/recover-intro-camera.py'))


def word(state, offset):
    return int.from_bytes(state[offset:offset+2], 'big')


def put(state, offset, value):
    state[offset:offset+2] = (value & 65535).to_bytes(2, 'big')


def original_trail(rom, z, life, depth, velocity, initialize=False):
    """Run selected original 04:A2F1(initializer) /04:A30A(strategy) bytes."""
    x = 0x336
    ram = {x+0x22: life, x+0x1cdf: depth}
    for address, value in [(x+0x10, z), (0x14f6, velocity)]:
        ram[address] = value & 255
        ram[address+1] = value >> 8
    pc = 0x222f1 if initialize else 0x2230a
    a = 0
    width = 8
    zero = carry = False
    alive = True
    calls = []

    def get(address, size):
        return sum(ram.get(address+i, 0) << (8*i) for i in range(size))

    def write(address, value, size):
        for i in range(size):
            ram[address+i] = (value >> (8*i)) & 255

    for _ in range(70):
        op = rom[pc]
        pc += 1
        size = width//8
        mask = (1 << width)-1
        if op in (0xc2, 0xe2):
            assert rom[pc] == 0x20
            pc += 1
            width = 16 if op == 0xc2 else 8
        elif op in (0xa9, 0x29, 0xc9):
            value = int.from_bytes(rom[pc:pc+size], 'little')
            pc += size
            if op == 0xa9:
                a = value
                zero = not a
            elif op == 0x29:
                a &= value
                zero = not a
            else:
                zero = a == value
        elif op in (0x95, 0xb5, 0xbd, 0xde, 0xd6, 0x6d):
            length = 2 if op in (0xbd, 0xde, 0x6d) else 1
            address = int.from_bytes(rom[pc:pc+length], 'little')
            pc += length
            if op != 0x6d:
                address += x
            if op == 0x95:
                write(address, a, size)
            elif op in (0xde, 0xd6):
                value = (get(address, size)-1) & mask
                write(address, value, size)
                zero = not value
            elif op == 0x6d:
                value = a+get(address, size)+carry
                carry = value > mask
                a = value & mask
                zero = not a
            else:
                a = get(address, size)
                zero = not a
        elif op == 0xd0:
            delta = int.from_bytes(rom[pc:pc+1], 'little', signed=True)
            pc += 1
            if not zero:
                pc += delta
        elif op == 0x18:
            carry = False
        elif op in (0x5c, 0x4c, 0x22):
            length = 2 if op == 0x4c else 3
            target = int.from_bytes(rom[pc:pc+length], 'little')
            pc += length
            if op == 0x4c:
                target |= 0x040000
            if op == 0x22 and target == 0x1fd501:
                alive = False  # actual remover marks current node for traversal unlink
                continue
            if op == 0x22:
                assert target == 0x1fdc69
                calls.append(pc)
            pc = (target >> 16)*32768+(target & 32767)
        elif op == 0x6b:
            if calls:
                pc = calls.pop()
            else:
                return dict(z=get(x+0x10, 2), life=ram[x+0x22], depth=ram[x+0x1cdf], alive=alive)
        else:
            raise AssertionError((hex(pc-1), hex(op)))
    raise AssertionError('Original trail did not return within bound')


def initial_parents(rom, player_z):
    """Read actual two map74 records and attributes; mapdo adds player worldZ."""
    parents = []
    for index in (0x78ae, 0x78c4):
        address = 0x68000+index
        data = rom[address:address+22]
        assert data[0] == 0x74 and data[9] == 0xe4
        assert data[10:13] == bytes.fromhex(rom_hex(0x6f8b8, 3))
        assert data[15:18] == bytes.fromhex(rom_hex(0x6f8bd, 3))
        assert data[18:22] == bytes.fromhex(rom_hex(0x6f8c0, 4))
        state = bytearray(32)
        for at, source in [(0, 3), (2, 5), (4, 7)]:
            value = int.from_bytes(data[source:source+2], 'little')
            put(state, at, value+(player_z if at == 4 else 0))
        put(state, 6, int.from_bytes(data[16:18], 'little'))
        state[10] = data[21]
        put(state, 16, 1)
        put(state, 18, int.from_bytes(data[13:15], 'little'))
        if index == 0x78c4:
            assert rom[address+22:address+26] == bytes.fromhex(rom_hex(0x6f8da, 4))
            state[20] = rom[address+25]
        put(state, 30, 65535)
        parents.append(state)
    return parents


def step_pool(rom, parent, pool, velocity):
    """Destination pool representation of original insert-after-parent walk."""
    if word(parent, 22):
        free = next((i for i, s in enumerate(pool) if not word(s, 16)), None)
        assert free is not None, 'Pool too small for original transient objects'
        s = bytearray(32)
        s[:6] = parent[24:30]
        put(s, 6, word(parent, 30))
        s[8] = 5
        s[10] = word(parent, 22) & 255
        put(s, 16, 1)
        s[18:21] = parent[18:21]
        put(parent, 30, free)
        pool[free] = s
    # A pointer to the predecessor's link permits deletion while walking.
    previous = parent
    link = 30
    seen = set()
    while (index := word(previous, link)) != 65535:
        assert index < len(pool) and index not in seen
        seen.add(index)
        s = pool[index]
        assert word(s, 16)
        result = original_trail(rom, word(s, 4), s[8], s[10], velocity)
        put(s, 4, result['z'])
        s[8] = result['life']
        s[10] = result['depth']
        if not result['alive']:
            put(previous, link, word(s, 6))
            put(s, 16, 0)
        else:
            previous = s
            link = 6


def objects_in_list(parents, pool):
    """Original visible list order: Presents before Nintendo, each own trails."""
    objects = []
    for owner in (1, 0):
        p = parents[owner]
        if word(p, 16):
            objects.append(dict(text=word(p, 18), xyz=[word(p, a) for a in (0, 2, 4)],
                                depth=p[10], size=p[20], trail=False))
        index = word(p, 30)
        seen = set()
        while index != 65535:
            assert index < len(pool) and index not in seen
            seen.add(index)
            s = pool[index]
            assert word(s, 16)
            objects.append(dict(text=word(s, 18), xyz=[word(s, a) for a in (0, 2, 4)],
                                depth=s[10], size=s[20], trail=True, life=s[8]))
            index = word(s, 6)
    return objects


def draw_order(objects, view_z):
    """Original00:B2C5 insertion: compare(existingZ-1, incomingZ) using N.

    Nullshape.sortZ and object ground bias are both0 for these text objects.
    Coordinates have zero rotation in this recovered intro interval.
    """
    ordered = []
    for i, obj in enumerate(objects):
        z = (obj['xyz'][2]-view_z) & 65535
        at = 0
        while at < len(ordered):
            existing_z = (objects[ordered[at]]['xyz'][2]-view_z) & 65535
            if (existing_z-1-z) & 32768:
                break
            at += 1
        ordered.insert(at, i)
    return ordered


def sequence(rom, count=48, slots=16):
    cameras = {s['frame']: s for s in CAMERA['trajectory'](rom, max(72, count+4))}
    parents = initial_parents(rom, cameras[4]['world_z'])
    pool = [bytearray(32) for _ in range(slots)]
    states = []
    for frame in range(5, 5+count):
        previous = cameras[frame-1]
        camera = cameras[frame]
        for owner in (1, 0):
            parents[owner] = bytearray(TEXT['tick'](rom, parents[owner], previous['view_z'], camera['velocity']))
            step_pool(rom, parents[owner], pool, camera['velocity'])
        objects = objects_in_list(parents, pool)
        states.append(dict(frame=frame, parents=[bytes(s).hex() for s in parents],
                           pool=[bytes(s).hex() for s in pool], objects=objects,
                           draw_order=draw_order(objects, camera['view_z']), view_z=camera['view_z']))
    return states


def check_observations(rom, states):
    observed = json.loads((ROOT/'evidence/starfox-intro-text.json').read_text())
    assert observed['rom_sha256'] == hashlib.sha256(rom).hexdigest()
    expected = {s['frame']: s for s in states}
    matched = []
    partial = []
    for sample in observed['samples']:
        if sample['frame'] not in expected:
            continue
        # Do not infer traversal completion from gameframe or parent symmetry.
        # Require the entire ordered set including EVERY live trail's position.
        actual = [dict(text=o['text'], xyz=o['xyz'], depth=o['depth'], size=o['size'],
                       trail=o['strategy'] == 0x04a30a) for o in sample['objects']]
        wanted = [{k: v for k, v in o.items() if k != 'life'} for o in expected[sample['frame']]['objects']]
        (matched if actual == wanted else partial).append(sample['frame'])
    # These existing snapshots prove creation + immediate tick at several
    # early poses, and the later stable interval. The original sampler did
    # not mark completion of traversal: do not invent a 20-frame pass quota
    # or declare every unmatched snapshot a timing artefact.
    assert {5, 6, 7, 10, 29, 42}.issubset(matched), (matched, partial)
    return dict(matched_complete_object_frames=matched, incomplete_or_different_samples=partial,
                limitation='Only the listed complete object sets correspond. Unmatched observations are retained, not attributed automatically to partial traversal. Original probe did not record life; life is checked by original instruction oracle and target records.')


def recover():
    rom, authority = runpy.run_path(str(ROOT/'tools/extract-intro.py'))['recover']()
    fragments = {
        'trail_creation_before_triggers': (0x22247, rom_hex(0x22247, 100)),
        'trail_initializer_and_strategy': (0x222f1, rom_hex(0x222f1, 89)),
        'add_player_z_uses_camera_velocity': (0xfdc69, rom_hex(0xfdc69, 13)),
        'map_initial_z': (0x1f860, rom_hex(0x1f7ad, 15)),
        'list_insert_after_current': (0xfd3a9, rom_hex(0xfd3a9, 53)),
        'traverse_new_next_after_strategy': (0x15b01, rom_hex(0x15b01, 32)),
        'draw_sort_compare': (0xb2c5, rom_hex(0x0b2c5, 40)),
    }
    for name, (offset, code) in fragments.items():
        data = bytes.fromhex(code)
        assert rom[offset:offset+len(data)] == data, name
    assert rom[0x264b:0x264d] == bytes.fromhex(rom_hex(0x0264b, 2))
    assert rom[0x2ca6:0x2ca8] == b'\0\0'
    # Check all byte life/depth combinations against actual original opcodes;
    # retain digest instead of a 65536-entry generated fixture.
    digest = hashlib.sha256()
    for life in range(256):
        for depth in range(256):
            s = original_trail(rom, 65520, life, depth, 63)
            digest.update(s['z'].to_bytes(2, 'big')+bytes([s['life'], s['depth'], s['alive']]))
    samples = sequence(rom)
    manifest = dict(rom=authority, source='UltraStarFox SF/PATH/PATHS.ASM .move/trail_istrat; WORLD.ASM mapdobjdo; MARIO/MDRAWLIS.MC mallrotzsort',
                    fragments={name: dict(offset=offset, bytes=code) for name,(offset,code) in fragments.items()},
                    velocity_source=0x14f6, original_initializer=0x04a2f1, original_strategy=0x04a30a,
                    original_life_depth_exhaustive_sha256=digest.hexdigest(), source_life_depth_cases=65536,
                    frame_count=len(samples), pool_slots=16, peak_visible_trails=max(sum(o['trail'] for o in s['objects']) for s in samples),
                    states=samples, limitations='Zero-angle Nintendo/Presents segment. No unrelated object allocator/collisions or full intro playback.')
    (ROOT/'build/intro-trails-origin.json').write_text(json.dumps(manifest, indent=2)+'\n', encoding='utf-8')
    return rom, manifest


if __name__ == '__main__':
    rom, manifest = recover()
    report = dict(source_cases=manifest['source_life_depth_cases'], frames=manifest['frame_count'], peak_trails=manifest['peak_visible_trails'])
    if '--check-observed' in sys.argv:
        report.update(check_observations(rom, manifest['states']))
        report['rom_sha256'] = hashlib.sha256(rom).hexdigest()
        (ROOT/'evidence/starfox-intro-trails-observations.json').write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
    print(json.dumps(report))
