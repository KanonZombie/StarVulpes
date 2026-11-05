; Profiling build only (M4_PROFILE): elapsed time between marks, in lines
; (VBlank count * 262 + lines since the VBlank IRQ from the VDP V counter;
; the repeated NTSC values $E5..$EA give at most 6 lines of error), added to
; the slot of the mark. tools/measure-level-profile.py reads M4_PROF.
M4_PROF equ $ff5c00 ;16 LONG accumulators, LONG last time, WORD images
M4_PROF_LAST equ M4_PROF+64
M4_PROF_IMAGES equ M4_PROF+68
M4ProfTime: ;-> d0.l
        move.l d1,-(sp)
        move.w sr,-(sp)
        ori.w #$0700,sr
        moveq #0,d1
        move.b $c00008,d1 ;V counter
        moveq #0,d0
        move.w M4_CLOCK,d0
        move.w (sp)+,sr
        cmpi.w #$e0,d1
        bhs.s M4ProfBlank
        addi.w #262-224,d1
        bra.s M4ProfLines
M4ProfBlank:
        subi.w #$e0,d1
M4ProfLines:
        mulu.w #262,d0
        add.l d1,d0
        move.l (sp)+,d1
        rts
; d0 = slot 0..15: M4_PROF[slot] += now - last; last = now.
M4ProfMark:
        if def(M4_GRAPHICS117)
        rts                      ;release: no runtime line profiler
        dc.w $e080               ;unreachable register mask of the movem
        else
        movem.l d0-d2/a0,-(sp)
        endif
        move.w d0,d2
        bsr.s M4ProfTime
        move.l d0,d1
        sub.l M4_PROF_LAST,d0
        move.l d1,M4_PROF_LAST
        lea M4_PROF,a0
        lsl.w #2,d2
        add.l d0,(a0,d2.w)
        movem.l (sp)+,d0-d2/a0
        rts
