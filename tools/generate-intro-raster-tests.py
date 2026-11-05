"""Independent scalar pixels -> compressed exact onboard SVP test bitmaps."""
import hashlib
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
HEIGHT = 224 if '--height=224' in sys.argv else 192
TOP = (224-HEIGHT)//2
VR_LAYOUT = '--vr-layout' in sys.argv


def plot(pixels, x, y, color):
    # VR build: colour is the original GSU dither byte HL; (x^y)&1=0 uses L.
    # A zero nibble leaves the pixel untouched (CMODE transparency).
    if VR_LAYOUT:
        color = color & 15 if not ((x ^ y) & 1) else color >> 4
        if not color:
            return
    pixels[y*256+x] = color


def raster(pixels, primitive):
    kind,x0,y0,x1,y1,x2,y2,color = primitive
    if kind == 3:
        area = (x1-x0)*(y2-y0)-(y1-y0)*(x2-x0)
        assert area > 0
        for y in range(min(y0,y1,y2),max(y0,y1,y2)+1):
            for x in range(min(x0,x1,x2),max(x0,x1,x2)+1):
                if all((x-ax)*(ay-by)+(y-ay)*(bx-ax) >= 0 for ax,ay,bx,by in
                       ((x1,y1,x2,y2),(x2,y2,x0,y0),(x0,y0,x1,y1))):
                    plot(pixels,x,y,color)
    else:
        assert kind == 2
        dx,dy=abs(x1-x0),abs(y1-y0)
        sx,sy=1 if x0<x1 else -1,1 if y0<y1 else -1
        err=dx-dy
        while True:
            plot(pixels,x0,y0,color)
            if x0==x1 and y0==y1: break
            e2=err*2
            if e2>=-dy: err-=dy; x0+=sx
            if e2<=dx: err+=dx; y0+=sy


def packed(pixels):
    data=bytearray(HEIGHT*128)
    for y in range(HEIGHT):
        for x in range(256):
            tile=(y//16)*64+(x//8)*2+((y//8)&1) if VR_LAYOUT else (y//8)*32+x//8
            at=tile*32+(y&7)*4+(x&7)//2
            data[at]|=pixels[(y+TOP)*256+x] << (0 if x&1 else 4)
    return bytes(data)


def rle(data):
    words=[int.from_bytes(data[i:i+2],'big') for i in range(0,len(data),2)]
    result=[]
    at=0
    while at<len(words):
        zero=words[at]==0
        end=at+1
        while end<len(words) and (words[end]==0)==zero: end+=1
        result.append(-(end-at) if zero else end-at)
        if not zero: result.extend(words[at:end])
        at=end
    result.append(0)
    return result


def main():
    cases=[dict(name='empty',append=0,primitives=[]),
           dict(name='triangle',append=0,primitives=[[3,30,20,210,45,80,170,12]]),
           dict(name='wide_edges_overlap',append=0,primitives=[[3,0,0,255,0,0,223,10],[3,20,10,210,55,135,180,14]]),
           dict(name='append_lines',append=1,primitives=[[2,255,0,0,223,0,0,8],[2,21,170,180,21,0,0,6],[2,255,223,0,223,0,0,4]]),
           dict(name='axes_points',append=0,primitives=[[2,0,0,255,0,0,0,7],[2,255,223,255,0,0,0,3],[2,128,112,128,112,0,0,12],[2,20,221,21,0,0,0,13]]),
           dict(name='fresh_empty',append=0,primitives=[])]
    if VR_LAYOUT:  # original two-index dither, both parities, triangle and line
        cases.insert(-1,dict(name='dither',append=0,primitives=[[3,7,9,240,30,60,200,0x5a],[2,3,180,250,40,0,0,0xc3]]))
    lines=[f'M4_POLY_TEST_CASES equ {len(cases)}','M4IntroPolyCases:']
    pixels=bytearray(256*224)
    for index,case in enumerate(cases):
        if not case['append']: pixels=bytearray(256*224)
        for primitive in case['primitives']: raster(pixels,primitive)
        data=packed(pixels)
        checksum=sum(int.from_bytes(data[i:i+2],'big') for i in range(0,len(data),2))&65535
        case.update(checksum=checksum,bitmap_sha256=hashlib.sha256(data).hexdigest())
        lines += [f'        dc.w {len(case["primitives"])},{case["append"]},{checksum}',
                  f'        dc.l M4IntroPolyInput{index},M4IntroPolyExpected{index}']
    for index,case in enumerate(cases):
        lines += [f'M4IntroPolyInput{index}:']
        for primitive in case['primitives']: lines+=['        dc.w '+','.join(map(str,primitive))]
        if not case['primitives']: lines+=['        dc.w 0']
        if not case['append']: pixels=bytearray(256*224)
        for primitive in case['primitives']: raster(pixels,primitive)
        encoded=rle(packed(pixels))
        lines += [f'M4IntroPolyExpected{index}:']
        for at in range(0,len(encoded),16): lines+=['        dc.w '+','.join(f'${v&65535:04x}' for v in encoded[at:at+16])]
    (ROOT/'build/intro-poly-cases.inc').write_text('\n'.join(lines)+'\n',encoding='ascii')
    (ROOT/'build/intro-poly-cases.json').write_text(json.dumps(cases,indent=2)+'\n')
    print('Generated six exact SVP bitmap tests, including >32767 area and append/clear')


if __name__=='__main__': main()
