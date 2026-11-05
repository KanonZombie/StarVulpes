"""Recover polygon models from the selected USA ROM.

The ROM supplies every vertex, visibility triple, BSP branch, face and
material. SHAPES5/SHMACS name and explain these bytes; they are not input data.
The generated representation changes pointers/endianness, not geometry.
"""
from starfox_rom import rom_hex
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SHA = '3857b5294ea8f7468849437bb2d8271564e8a0ff30774622e9c872bcbd53a84d'


def signed(v):
    return v - 256 if v & 128 else v


def point_frames(rom, start, end, shift):
    """Selected shape opcodes; Frames masks6 bits and selects modulo count.

    SHMACS relative WORDs point from their second byte, as msh_jump reads.
    The bound is this model's point stream, not arbitrary ROM traversal.
    """
    def decode(frame):
        p=start;vertices=[];count=1
        for _ in range(64):
            assert start<=p<end,(hex(p),hex(start),hex(end))
            op=rom[p]
            if op==12:
                return vertices,count
            if op in (4,56):
                n=rom[p+1];p+=2
                assert p+n*3<=end
                for _ in range(n):
                    x,y,z=map(signed,rom[p:p+3]);p+=3
                    vertices.append([x<<shift,y<<shift,z<<shift])
                    if op==56:vertices.append([-x<<shift,y<<shift,z<<shift])
            elif op in (8,52):
                # pointsw / pointsxw: signed WORD triples, optionally mirrored.
                # Only shift-zero WORD models are currently admitted.
                assert shift==0,(hex(p),shift)
                n=rom[p+1];p+=2
                assert p+n*6<=end
                for _ in range(n):
                    x,y,z=(int.from_bytes(rom[p+2*k:p+2*k+2],'little',signed=True) for k in range(3));p+=6
                    vertices.append([x,y,z])
                    if op==52:vertices.append([-x,y,z])
            elif op==28:
                count=rom[p+1];assert 1<=count<=63
                field=p+2+((frame&63)%count)*2
                p=field+1+int.from_bytes(rom[field:field+2],'little',signed=True)
            elif op==32:
                p=p+2+int.from_bytes(rom[p+1:p+3],'little',signed=True)
            else:raise AssertionError(('Point opcode',hex(p),op))
        raise AssertionError('Point stream exceeded bound')
    first,count=decode(0)
    frames=[decode(frame)[0] for frame in range(count)]
    assert frames[0]==first and len({len(v) for v in frames})==1
    return frames


def recover(rom, header_offset=0x65f0):
    assert hashlib.sha256(rom).hexdigest() == SHA
    units = {0x65f0: ('old_type', 32, 40, rom_hex(0x065f0, 28)),
             0x6644: ('boss7intro', 64, 40, rom_hex(0x06644, 28)),
             0x6628: ('boss_child1', 28, 15, rom_hex(0x06628, 28)),
             0x48a0: ('boss_child2', 35, 20, rom_hex(0x048a0, 28)),
             0x660c: ('old_typP',21,18,rom_hex(0x0660c, 28)),
             0x6388: ('intro_zaco_E388',22,27,rom_hex(0x06388, 28)),
             0x422c: ('intro_zaco_C22C',18,28,rom_hex(0x0422c, 28)),
             # Title: script 0x6FA18 ctrlmapqobj2 -> istrat $F1 -> shape $E1 -> 00:BCD0.
             0x3cd0: ('my_demo',36,48,rom_hex(0x03cd0, 28))}
    header = rom[header_offset:header_offset+28]
    shift = header[7]
    points_start = (header[2] & 127)*32768 + (int.from_bytes(header[:2], 'little') & 32767)
    faces_start = (header[2] & 127)*32768 + (int.from_bytes(header[3:5], 'little') & 32767)
    # EndPoints terminates the stream, not the location of the face list.
    # Several original headers share faces or place their points after them.
    points_bound = faces_start if faces_start > points_start else ((points_start//0x8000)+1)*0x8000
    frames=point_frames(rom,points_start,points_bound,shift)
    if header_offset in units:
        name, vertex_count, visibility_count, expected_header = units[header_offset]
        assert header.hex() == expected_header
    else:
        # Level shapes: counts come from the selected ROM streams themselves.
        name, vertex_count, visibility_count = f'shape_{header_offset+0x8000:04X}', len(frames[0]), rom[faces_start+1]
    vertices=frames[0];p=faces_start
    assert len(vertices)==vertex_count
    assert rom[p:p+2] == bytes((48, visibility_count))
    visibility = [list(rom[p+2+i*3:p+5+i*3]) for i in range(visibility_count)]
    p += 2+visibility_count*3
    has_bsp = rom[p] == 60
    assert has_bsp or rom[p] == 20
    if has_bsp: p += 1
    bsp_start = p
    # A direct Faces group has implicit original order, no BSP bytecode.
    nodes = [] if has_bsp else [dict(offset=p, op=68, group=p, implicit=True)]
    # This bounded tree terminates immediately before its first Faces group.
    while rom[p] != 20:
        op = rom[p]
        if op == 40:
            face = p + 3 + int.from_bytes(rom[p+2:p+4], 'little', signed=True)
            right = p + 4 + rom[p+4] if rom[p+4] else None
            nodes.append(dict(offset=p, op=op, visibility=rom[p+1], group=face,
                              left=p+5, right=right))
            p += 5
        elif op == 68:
            face = p + 2 + int.from_bytes(rom[p+1:p+3], 'little', signed=True)
            nodes.append(dict(offset=p, op=op, group=face))
            p += 3
        else:
            assert op == 64, (hex(p), op)
            nodes.append(dict(offset=p, op=op))
            p += 1
    groups = []
    while rom[p] == 20:
        start = p
        p += 1
        faces = []
        while rom[p] not in (254, 255):
            n, vis, material = rom[p:p+3]
            assert 2 <= n <= 8 and (vis < visibility_count or n == 2 and vis == 255), (name, hex(p), n, vis, visibility_count, rom[p:p+16].hex())
            indices = list(rom[p+6:p+6+n])
            assert all(i < vertex_count for i in indices)
            faces.append(dict(offset=p, count=n, visibility=vis, material=material,
                              normal=list(map(signed, rom[p+3:p+6])), vertices=indices))
            p += 6+n
        terminator = rom[p]
        p += 1
        groups.append(dict(offset=start, faces=faces, terminator=terminator))
    assert rom[p] == 0
    groups_by_address = {g['offset']: i for i, g in enumerate(groups)}
    nodes_by_address = {n['offset']: i for i, n in enumerate(nodes)}
    for node in nodes:
        for field in ('left', 'right'):
            if field in node:
                node[field] = nodes_by_address[node[field]] if node[field] else -1
        if 'group' in node:
            node['group'] = groups_by_address[node['group']]
    faces = [f for g in groups for f in g['faces']]
    if header_offset == 0x65f0:
        assert len(faces) == 44 and sum(f['count'] == 2 for f in faces) == 4
    material_start = 0x10000 + int.from_bytes(header[18:20], 'little')
    material_count = max(44, 1+max(f['material'] for f in faces))
    materials = [int.from_bytes(rom[material_start+i*2:material_start+i*2+2], 'little') for i in range(material_count)]
    if header_offset == 0x65f0:
        assert materials[:10] == [i*257 for i in range(10)]
        assert materials[10:42] == [0x3e00+i for i in range(32)]
    return dict(rom_sha256=SHA, model=name, header_offset=header_offset,
                header_hex=header.hex(), points_offset=points_start, end_offset=p+1,
                shape_shift=shift, vertices=vertices, visibility=visibility,
                **(dict(frames=frames) if len(frames)>1 else {}),
                bsp_offset=bsp_start if has_bsp else None, bsp=nodes, groups=groups, materials_offset=material_start,
                materials=materials,
                # The old contiguous slice is not a source span when points
                # follow shared faces. Do not report the hash of empty bytes.
                geometry_sha256=(hashlib.sha256(rom[points_start:p+1]).hexdigest()
                                 if points_start < faces_start else None),
                decoded_geometry_sha256=hashlib.sha256(json.dumps(
                    [frames, visibility, nodes, groups], sort_keys=True).encode()).hexdigest(),
                interpretation_sources=['SF/SHAPES/SHAPES5.ASM old_type',
                    'SF/INC/SHMACS.INC PointsXb/Vizis/BSP/Face2/Face3/Face4',
                    'SF/MARIO/MOBJ.MC msh_bsp/msh_bspout/mdo_vis'],
                notes='Selected-ROM geometry/shift/BSP topology; counts and addresses remain model-specific. geometry_sha256 covers the contiguous source slice only; decoded_geometry_sha256 also covers shared/reordered streams.')


def main():
    rom = (ROOT / 'ref/Star Fox (USA).sfc').read_bytes()
    model = recover(rom)
    build = ROOT / 'build'
    (build / 'intro-model.json').write_text(json.dumps(model, indent=2)+'\n')
    lines = ['; Generated directly from selected USA ROM old_type, header00:E5F0.',
             'M4IntroModelVertices:']
    lines += ['        dc.w '+','.join(map(str, v)) for v in model['vertices']]
    lines += ['M4IntroModelVisibility:']
    lines += ['        dc.w '+','.join(str(i*6) for i in v) for v in model['visibility']]
    lines += ['M4IntroModelBSP:']
    # Fixed ten-byte records: opcode,vis,group,left,right. Indices, not pointers.
    for n in model['bsp']:
        lines += ['        dc.w '+','.join(str(n.get(k, -1)) for k in
                    ('op', 'visibility', 'group', 'left', 'right'))]
    lines += ['M4IntroModelGroups:']
    lines += [f'        dc.l M4IntroModelGroup{i}' for i in range(len(model['groups']))]
    for i, group in enumerate(model['groups']):
        lines += [f'M4IntroModelGroup{i}:', f'        dc.w {len(group["faces"])}']
        for f in group['faces']:
            # Stride20: original face normal bytes (signed, as stored in ROM)
            # follow the indices; the GSU lit colour path dots them with L.
            values = [f['count'], f['visibility'], f['material'],
                      *(v*6 for v in f['vertices']), *([0]*(4-f['count'])), *f['normal']]
            lines += ['        dc.w '+','.join(map(str, values))]
    lines += ['M4IntroModelMaterials:', '        dc.w '+','.join(f'${v:04x}' for v in model['materials'])]
    # MD visual adaptation: retain every active text/trail palette index;
    # unused indices1..4/8 provide opaque black, blue, cyan and jet orange.
    colours = {0:10,10:1,11:10,12:10,14:11,16:12,18:13,20:14,
               28:2,30:3,32:8,34:3,43:4}
    used = {f['material'] for g in model['groups'] for f in g['faces']}
    assert used <= colours.keys(), used-colours.keys()
    lines += ['M4IntroMaterialColours:', '        dc.b '+','.join(str(colours.get(i,0)) for i in range(44)), '        even']
    # Polygons, text and particles share the original GSU row (03:8ACA row1,
    # CGRAM $70..$7F); no MD substitutes. Colours are dither pairs of it.
    palette = bytearray((build/'intro-text-palette.md.bin').read_bytes())
    (build/'intro-scene-palette.md.bin').write_bytes(palette)
    (build / 'intro-model.inc').write_text('\n'.join(lines)+'\n', encoding='ascii')
    print(f'Original old_type: 32 vertices, 40 polygons, 4 lines, {len(model["bsp"])} BSP nodes; exact ROM geometry')


if __name__ == '__main__':
    main()
