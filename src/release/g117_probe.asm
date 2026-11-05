; graphics117, ROM $200: free-flight sampler hooked at M4LevelLoop (hw83/84,
; tools/hw-boot/make-round27.py, ROUND27.md). The continuous release enters
; it only to run the four displaced instructions and return; the sampler
; after G117PrbResume is unreachable here and kept byte-identical to the
; Nomad-measured 117 (its profile variant entered it).
G117_PROBE_STATE equ $ff0008    ; WORD 0 idle, 1 armed on map, 2 sampling
G117_SAMPLE equ M4_PROF+$50     ; LONG report rows, see G117PrbRows
G117_BASE equ M4_PROF+$70       ; WORD baselines, then LONG rows $78/$7c
G117_START equ M4_PROF+$80      ; 16 LONG accumulator copies
G117_DELTA equ M4_PROF+$c0      ; 16 LONG accumulator deltas
G117_PSG equ $c00011

        dcb.b $200-*,0
G117Probe:
        move.l d0,-(sp)          ; displaced from M4LevelLoop
        moveq #8,d0
        jsr M4ProfMark
        move.l (sp)+,d0
        jmp M4LevelLoopResume    ; continuous: was movem.l/move.w sr,-(sp)
        ori.w #$0700,sr
        cmpi.w #2,G117_PROBE_STATE
        beq G117PrbActive
        cmpi.b #3,M4_SC_VIEWTYPE
        bne G117PrbCheckFlight
        tst.b M4_SC_NOMAXBG
        beq G117PrbReturn
        move.w #1,G117_PROBE_STATE
        bra G117PrbReturn
G117PrbCheckFlight:
        cmpi.w #1,G117_PROBE_STATE
        bne G117PrbReturn
        tst.b M4_SC_VIEWTYPE
        bne G117PrbReturn
        lea M4_PROF,a0
        lea G117_START,a1
        moveq #15,d0
G117PrbBaseline:
        move.l (a0)+,(a1)+
        dbra d0,G117PrbBaseline
        move.w M4VR_PRESENT_COUNT,G117_BASE
        move.w M4_CLOCK,G117_BASE+2
        move.w M4_LV_GAMEFRAME,G117_BASE+4
        move.w M4_PROF_IMAGES,G117_BASE+6
        move.w #2,G117_PROBE_STATE
        bra G117PrbReturn
G117PrbActive:
        move.w M4VR_PRESENT_COUNT,d0
        sub.w G117_BASE,d0
        cmpi.w #64,d0
        blo G117PrbReturn
        move.l #1,G117_SAMPLE
        clr.l G117_SAMPLE+4
        bra G117PrbSnapshot
G117PrbReturn:
        move.w (sp)+,sr
        movem.l (sp)+,d0-d7/a0-a6
        jmp M4LevelLoopResume
G117PrbFatal:
        move.w #$2700,sr
        moveq #0,d1
        move.w d0,d1
        move.l d1,G117_SAMPLE+4
        move.l #2,G117_SAMPLE
        cmpi.w #2,G117_PROBE_STATE
        beq G117PrbSnapshot
        lea G117_BASE,a0
        moveq #19,d0
G117PrbClearBase:
        clr.l (a0)+
        dbra d0,G117PrbClearBase
G117PrbSnapshot:
        lea M4_PROF,a0
        lea G117_START,a1
        lea G117_DELTA,a2
        moveq #15,d0
G117PrbDifference:
        move.l (a0)+,d1
        sub.l (a1)+,d1
        move.l d1,(a2)+
        dbra d0,G117PrbDifference
        moveq #0,d0
        move.w M4VR_PRESENT_COUNT,d0
        sub.w G117_BASE,d0
        move.l d0,G117_SAMPLE+8
        moveq #0,d0
        move.w M4_CLOCK,d0
        sub.w G117_BASE+2,d0
        move.l d0,G117_SAMPLE+12
        moveq #0,d0
        move.w M4_LV_GAMEFRAME,d0
        sub.w G117_BASE+4,d0
        move.l d0,G117_SAMPLE+16
        moveq #0,d0
        move.w M4_PROF_IMAGES,d0
        sub.w G117_BASE+6,d0
        move.l d0,G117_SAMPLE+20
        move.l G117_SAMPLE+8,d0
        mulu.w #6000,d0
        move.w G117_SAMPLE+14,d1
        beq G117PrbNoRate
        divu.w d1,d0
        andi.l #$ffff,d0
        bra G117PrbRate
G117PrbNoRate:
        moveq #0,d0
G117PrbRate:
        move.l d0,G117_SAMPLE+24
        moveq #0,d0
        move.w M4_PHASE_LAST+8,d0
        move.l d0,G117_SAMPLE+28
        moveq #0,d0
        move.b M4_BSP_SVP,d0
        move.l d0,G117_BASE+8
        moveq #0,d0
        move.b M4_CHAIN_ACTIVE,d0
        move.l d0,G117_BASE+12
        lea G117PrbTone(pc),a0
        moveq #6,d1
G117PrbToneLoop:
        move.b (a0)+,G117_PSG
        moveq #63,d0
G117PrbDelay:
        dbra d0,G117PrbDelay
        dbra d1,G117PrbToneLoop
        jmp G117Report           ; hw85: the report never returns
        moveq #0,d6
        jsr SetRow
        lea G117PrbHeading(pc),a0
        jsr DrawText
        moveq #1,d6
        lea G117PrbRows(pc),a2
        moveq #19,d7
G117PrbDrawRow:
        jsr SetRow
        movea.l (a2)+,a0
        jsr DrawText
        movea.l (a2)+,a0
        move.l (a0),d4
        bsr G117PrbDecimal
        addq.w #1,d6
        dbra d7,G117PrbDrawRow
        move.w #$8144,VDP_CTRL
G117PrbHalt:
        bra.s G117PrbHalt
; Ten decimal digits, full unsigned LONG, no hexadecimal glyph ambiguity.
G117PrbDecimal:
        lea G117PrbPowers(pc),a4
        moveq #9,d3
G117PrbDigit:
        move.l (a4)+,d2
        moveq #0,d1
G117PrbSubtract:
        cmp.l d2,d4
        blo G117PrbPrint
        sub.l d2,d4
        addq.w #1,d1
        bra.s G117PrbSubtract
G117PrbPrint:
        addi.w #27,d1
        move.w d1,VDP_DATA
        dbra d3,G117PrbDigit
        rts
G117PrbPowers: dc.l 1000000000,100000000,10000000,1000000,100000,10000,1000,100,10,1
G117PrbTone: dc.b $9f,$bf,$df,$ff,$8f,$07,$90
G117PrbHeading: dc.b '84 FLIGHT PROFILE - DECIMAL',0
        even
G117PrbRows:
        dc.l G117PrbLabel0,G117_SAMPLE
        dc.l G117PrbLabel1,G117_SAMPLE+4
        dc.l G117PrbLabel2,G117_SAMPLE+8
        dc.l G117PrbLabel3,G117_SAMPLE+12
        dc.l G117PrbLabel4,G117_SAMPLE+16
        dc.l G117PrbLabel5,G117_SAMPLE+20
        dc.l G117PrbLabel6,G117_SAMPLE+24
        dc.l G117PrbLabel7,G117_SAMPLE+28
        dc.l G117PrbLabel8,G117_DELTA
        dc.l G117PrbLabel9,G117_DELTA+4
        dc.l G117PrbLabel10,G117_DELTA+8
        dc.l G117PrbLabel11,G117_DELTA+12
        dc.l G117PrbLabel12,G117_DELTA+16
        dc.l G117PrbLabel13,G117_DELTA+20
        dc.l G117PrbLabel14,G117_DELTA+24
        dc.l G117PrbLabel15,G117_DELTA+28
        dc.l G117PrbLabel16,G117_DELTA+32
        dc.l G117PrbLabel17,G117_DELTA+36
        dc.l G117PrbLabel18,G117_BASE+8
        dc.l G117PrbLabel19,G117_BASE+12
G117PrbLabel0: dc.b 'RESULT ',0
G117PrbLabel1: dc.b 'ERROR ',0
G117PrbLabel2: dc.b 'IMAGES ',0
G117PrbLabel3: dc.b 'VBLANKS ',0
G117PrbLabel4: dc.b 'TICKS ',0
G117PrbLabel5: dc.b 'LOOPS ',0
G117PrbLabel6: dc.b 'FPS X100 ',0
G117PrbLabel7: dc.b 'LAST QUEUE VB ',0
G117PrbLabel8: dc.b 'LOGIC LINES ',0
G117PrbLabel9: dc.b 'DRAWLIST LINES ',0
G117PrbLabel10: dc.b 'GEO9 LINES ',0
G117PrbLabel11: dc.b 'VIS LINES ',0
G117PrbLabel12: dc.b 'COLOUR LINES ',0
G117PrbLabel13: dc.b 'FACE JOB LINES ',0
G117PrbLabel14: dc.b 'HUD MISC LINES ',0
G117PrbLabel15: dc.b 'SVP12/13 WAIT ',0
G117PrbLabel16: dc.b 'LOOP REST LINES ',0
G117PrbLabel17: dc.b 'RASTER SEAL ',0
G117PrbLabel18: dc.b 'BSP SVP ',0
G117PrbLabel19: dc.b 'CHAIN ACTIVE ',0
        even
G117ProbeEnd:
