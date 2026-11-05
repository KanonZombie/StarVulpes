"""Verified Star Fox USA input and operands shared by extraction tools."""
import hashlib
from functools import cache
from pathlib import Path


@cache
def read_rom():
    path = Path(__file__).resolve().parents[1] / 'ref/Star Fox (USA).sfc'
    rom = path.read_bytes()
    expected = '3857b5294ea8f7468849437bb2d8271564e8a0ff30774622e9c872bcbd53a84d'
    if hashlib.sha256(rom).hexdigest() != expected:
        raise ValueError(f'Unexpected Star Fox ROM: {path}')
    return rom


def rom_hex(offset, size):
    data = read_rom()[offset:offset + size]
    if len(data) != size:
        raise ValueError(f'Invalid ROM span: {offset:#x}, {size}')
    return data.hex()


def rom_pattern(offset, size, fields):
    """Return a map decoder pattern with the named operands left variable."""
    data = bytes.fromhex(rom_hex(offset, size))
    parts = []
    start = 0
    for position, name, width in fields:
        parts.extend((data[start:position].hex(), f'{{{name}:{width}}}'))
        start = position + width
    parts.append(data[start:].hex())
    return ''.join(parts)


def title_demo():
    """Read the 0D:FA18 command and its relative spawn per handler 03:F560."""
    command = read_rom()[0x6fa18:0x6fa1e]
    assert command[0] == 0x76
    x, y = (int.from_bytes(bytes([value]), 'little', signed=True) * 4 for value in command[2:4])
    return command, (x, y, command[4] * 16)


def title_rotation():
    """Read the LDA immediate / STA indexed pairs in tit_istrat at 1F:F600."""
    rom = read_rom()
    angles = []
    for i, field in enumerate((0x12, 0x13, 0x14)):
        at = 0xff600 + 4 * i
        load, angle, store, destination = rom[at:at + 4]
        assert (load, store, destination) == (0xa9, 0x95, field)
        angles.append(angle)
    return angles


def route_write(address):
    """Decode a bank 03 LDA immediate / STA to routes[] at $16D0."""
    at = 0x18000 + (address & 0x7fff)
    load, low, high, store, destination, page = read_rom()[at:at + 6]
    assert (load, store, page) == (0xa9, 0x8d, 0x16) and destination in range(0xd0, 0xd8, 2)
    return (destination - 0xd0) // 2, low | high << 8


def route_defaults():
    writes = dict(route_write(0xbda8 + 6 * i) for i in range(4))
    return [writes[i] for i in range(4)]


def macbeth_petals():
    """Read the three model headers selected by the petal strategy at 08:9793."""
    rom = read_rom()
    return [int.from_bytes(rom[at:at + 2], 'little') for at in range(0x41793, 0x41799, 2)]


def radio_meter():
    """Read the outline and fill geometry at 03:EAB4 and 01:B7DC."""
    rom = read_rom()
    for at, field in ((0x1eab4, 0x62), (0x1eabb, 0x2c)):
        assert rom[at] == 0xa9 and rom[at + 3:at + 7] == bytes([0x8f, field, 0x00, 0x70])
    assert (rom[0xb7dc], rom[0xb7df], rom[0xb7fb]) == (0xf3, 0xf4, 0xf4)
    x, y, width, height, fill_height = (
        int.from_bytes(rom[at:at + 2], 'little') for at in (0x1eab5, 0x1eabc, 0xb7dd, 0xb7e0, 0xb7fc))
    dx = rom[0xb7ea:0xb7ec].count(0xd1)  # INC R1 after reloading the X origin.
    dy = rom[0xb7ef:0xb7f1].count(0xd2)  # INC R2 after reloading the Y origin.
    return (x, y, width, height), (x + dx, y + dy, fill_height)
