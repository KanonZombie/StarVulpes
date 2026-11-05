"""Compare incremental boundaries with exact integer half-plane division."""
import json
from pathlib import Path
import random

ROOT=Path(__file__).resolve().parents[1]
rng=random.Random(0x535650)
rows=moves=0
for _ in range(2048):
    vertices=[(rng.randrange(256),rng.randrange(224)) for _ in range(3)]
    xmin,xmax=min(x for x,y in vertices),max(x for x,y in vertices)
    ymin,ymax=min(y for x,y in vertices),max(y for x,y in vertices)
    width=xmax-xmin+1
    for (ax,ay),(bx,by) in zip(vertices,vertices[1:]+vertices[:1]):
        a,b=ay-by,bx-ax
        e0=2*(a*(xmin-ax)+b*(ymin-ay))
        e=e0;q=0;edge_moves=0
        for y in range(ymin,ymax+1):
            if a:
                while q<width and (e<0 if a>0 else e>=0):
                    q+=1;e+=2*a;edge_moves+=1
                while q>0 and (e-2*a>=0 if a>0 else e-2*a<0):
                    q-=1;e-=2*a;edge_moves+=1
                # Independent closed form, without incremental state.
                exact=-(e0//(2*a)) if a>0 else e0//(-2*a)+1
                exact=max(0,min(width,exact))
                assert q==exact,(vertices,y,a,b,q,exact,e,e0)
                assert e==e0+2*a*q
            e+=2*b;e0+=2*b;rows+=1
        assert edge_moves<=2*width
        moves+=edge_moves
report=dict(check='PASS',seed=0x535650,triangles=2048,edge_rows=rows,
            boundary_moves=moves,contract='Inclusive E>=0; clamped lower ceil(-E/2a), upper floor(E/-2a)+1. Signed32 doubled edges. At most2*width boundary moves/edge across all rows. Destination coverage only; no source game logic changed.')
(ROOT/'evidence/m4-span-walk-arithmetic.json').write_text(json.dumps(report,indent=2)+'\n')
print('PASS exact incremental edge boundaries:',rows,'edge rows')
