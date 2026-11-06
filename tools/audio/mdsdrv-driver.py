"""Build a marked workspace copy of MDSDRV with a cooperative DMA gate."""
from pathlib import Path
import re


def patch(work, root):
    path68=work/'src/mdsdrv.68k';code=path68.read_text()
    # Song offsets are unsigned words. A word index sign-extends offsets
    # above $7fff and reads the preceding song instead of the current track.
    begin=code.index('\nmds_update_seq\n')
    end=code.index('\nmds_update_mtab\n',begin)
    sequence=code[begin:end]
    position='\tmove.w\tt_position(twork),@trackpos'
    assert sequence.count(position)==1 and sequence.count(',@trackpos)')==33
    sequence=sequence.replace(position,
        '; ALTERED for MegaSVP: zero-extend the sequence offset.\n\tmoveq\t#0,@trackpos\n'+position)
    sequence=sequence.replace(',@trackpos)',',@trackpos.l)')
    code=code[:begin]+sequence+code[end:]
    marker='\tadd.w\td1,d0\t\t\t\t\t\t\t; d0=porta_target'
    assert code.count(marker)==1
    code=code.replace(marker,marker+'''
; ALTERED for MegaSVP: original warp key shift on destination BGM melody.
; PCM and finite SFX stay untransposed. Host byte is reset on each song.
    cmpi.b #6,t_request_id(twork)
    bne.s @host_warp_done
    cmpi.b #9,t_channel_id(twork)
    bcc.s @host_warp_done
    move.b $ff0151,d1
    ext.w d1
    lsl.w #8,d1
    add.w d1,d0
@host_warp_done
''')
    # MML exports set pcmmode for each request, including lower-priority
    # continuous sounds. Resetting an unchanged mode disables active Z80
    # channels without retriggering their current notes. Preserve them.
    marker='\nmds_set_pcm_mode\n';assert code.count(marker)==1
    code=code.replace(marker,marker+'''
; ALTERED for MegaSVP: unchanged mixing mode must preserve active voices.
    move.b w_pcm_mode(work),d1
    andi.b #$0f,d1
    cmp.b d1,d0
    bne.s @host_mode_changed
    mds_z80_wait_req
    rts
@host_mode_changed
''')
    path68.write_text(code)
    # Background music shares L with higher-priority world/radio effects.
    # Resume at its next authored PCM onset, never replay a stale sample
    # from its beginning when an effect releases the channel mid-group.
    marker='\tbtst\t#cf_drum_mode,t_channel_flag(twork)'
    assert code.count(marker)==1
    code=code.replace(marker,'''    cmpi.b #6,t_request_id(twork)
    bne.s @host_pcm_restore_done
    cmpi.b #11,t_channel_id(twork)
    beq.s @always_mask
@host_pcm_restore_done
'''+marker)
    path68.write_text(code)
    path=work/'src/mdssub.z80';text=path.read_text()
    # Fixed mode3 and a buffer covering the pre-arm plus the actual DMA.
    text=re.sub(r'(PCM_DEFAULT_BUFFER\s+equ\s+)40',r'\g<1>192',text)
    text=re.sub(r'(DEFAULT_MODE\s+equ\s+)2',r'\g<1>3',text)
    text='; ALTERED for MegaSVP: cooperative HBlank DMA gate, see mdsdrv-dmagate.z80\n'+text
    # Poll once per complete refill batch, not once per sample.
    for label,call in (('m3_loop','host_gate'),('m2_loop','host_gate'),('idle_loop','host_idle_gate')):
        marker='\n'+label+'\n';assert text.count(marker)==1
        text=text.replace(marker,marker+'\tld a,($0e07)\n\tor a\n\tcall nz,'+call+'\n')
    # Keep the real Z80 interrupt vector disabled. The software gate enters
    # the stock drain path at a known main-register boundary instead.
    # All three timed drain paths release on request==0. No new DAC loop.
    for begin,end in (('vbl_loop','vbl_ack_done'),('m2_vbl','m2_pcm1_disabled'),('m3_vbl','m3_pcm3_disabled')):
        a=text.index('\n'+begin+'\n');b=text.index('\n'+end,a)
        part=text[a:b]
        part=part.replace('ld\t\ta,(z_vbl_ack)','ld\t\ta,($0e07)')
        part=re.sub(r'(jp\s+)nz,(vbl_ack_done)',r'\1z,\2',part)
        part=re.sub(r'(jr\s+)z,(vbl_wait_ack|\.blah)',r'\1nz,\2',part)
        text=text[:a]+part+text[b:]
    marker='\nvbl_ack_done\n';assert text.count(marker)==1
    text=text.replace(marker,marker+'\txor a\n\tld ($0e20),a\n')
    # Place the extension before the stock aligned lookup tables, preserving
    # the tables' alignment constraints rather than appending into z_busy.
    marker='\n\talign\t64,0';assert text.count(marker)==1
    text=text.replace(marker,'\n'+(root/'src/audio/mdsdrv-dmagate.z80').read_text()+marker)
    path.write_text(text)
