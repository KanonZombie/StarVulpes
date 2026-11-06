"""Decode SPC note events and playlist boundaries from local traces."""
import struct
from catalog import ROOT

OUT = ROOT / "build/audio-native"

# Soundtrack identity -> original helper context and SPC port-0 command.
# Extra command aliases remain in the complete bank tables below.
ORIGINS = [('intro',18),('title',18),('ops',18),('map',1),('10',16),('11',3),
 ('14',3),('23',3),('33',3),('35',3),('12',3),('13b',3),('26',3),('22',3),
 ('24',3),('16',3),('11',5),('14',5),('33',5),('35',5),('23',5),('12',5),
 ('13b',5),('36',5),('15',5),('36',6),('16',6),('16',19),('map',17),
 ('11',17),('gameover',12),('continue',10),('map',7),('11',7),('16',7),
 ('endseq',3),('endseq',18),('staff',18),('special',3),('special',5),('bhole',3),
 ('map',15),('training',3),('12',14),('12',8),('special',6),None,
 ('map',11),('map',13),('12',2),('13',9)]


def read_notes(row):
    data = (OUT/row['trace']).read_bytes(); assert len(data)%30==0
    regs = bytearray(128); notes=[]; active=[None]*8
    origin = row['orders'][0][0] if row['orders'] else 0
    for at in range(0,len(data),30):
        record=data[at:at+30]; clock=struct.unpack_from('<I',record)[0]
        reg,value=record[4:6]; regs[reg]=value
        # Original order-load latency is one music tick, not an authored
        # rest. Retain relative tick timing from the first playlist entry.
        frame=max(0,round((clock-origin)*60/1024000)-1)
        if reg==0x5c:
            for v in range(8):
                if value & (1<<v) and active[v] is not None:
                    active[v]['end']=max(active[v]['frame']+1,frame); active[v]=None
        elif reg==0x4c:
            for v in range(8):
                if not value&(1<<v): continue
                if active[v] is not None: active[v]['end']=max(active[v]['frame']+1,frame)
                p=v*16; pitch=regs[p+2]|(regs[p+3]&63)<<8
                if not pitch: continue
                volume=max(abs(x if x<128 else x-256) for x in regs[p:p+2])
                note=dict(frame=frame,end=frame+30,voice=v,pitch=record[6+v]+24,
                    fraction=record[14+v],instrument=record[22+v],src=regs[p+4],
                    volume=volume,spc_pitch=pitch,bends=[],volumes=[])
                notes.append(note); active[v]=note
        elif reg<0x80 and reg%16 in (2,3):
            v=reg>>4; note=active[v]
            if note:
                pitch=regs[v*16+2]|(regs[v*16+3]&63)<<8
                if pitch: note['bends'].append((frame,pitch))
        elif reg<0x80 and reg%16 in (0,1):
            v=reg>>4;note=active[v]
            if note:
                volume=max(abs(x if x<128 else x-256) for x in regs[v*16:v*16+2])
                note['volumes'].append((frame,volume))
    boundary=row['loop_end'] if row['loop_end']>=0 else row['song_end']
    if boundary<0: boundary=row['cycles']
    end=max(1,round((boundary-origin)*60/1024000)-1)
    for n in active:
        if n: n['end']=end
    loop=max(0,round((row['loop_start']-origin)*60/1024000)-1) if row['loop_start']>=0 else None
    return notes,end,loop
