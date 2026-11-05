"""Complete polygon dependencies of the existing route-1 strategy units.

Headers and creator addresses remain in tools/stages/<unit>.py. Keep this
closure outside that directory: legacy modules scan each other's literals
to avoid duplicate geometry, including literals in comments.
"""
import runpy
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
UNITS = ('armada_tunnel', 'venom_orbital', 'venom_planet', 'venom_escape')
NON_POLYGONS = {0xae29: 'smoke billboard (separate sprite path)',
                0xae99: 'invisible map mother; header has no point/face pointers',
                0xb8f7: 'iris child reservation; replaced before drawing'}


def additions(shapes):
    known = {h for _, h in shapes}
    out = []
    for unit in UNITS:
        module = runpy.run_path(str(ROOT/'tools/stages'/(unit+'.py')))
        for name, header, svp in module.get('EFFECTS', []):
            if svp == -1 and header not in NON_POLYGONS and header not in known:
                out.append((name.lower(), header))
                known.add(header)
    return out
