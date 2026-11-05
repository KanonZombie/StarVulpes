; Complete selected-ROM intro/title stream. This module owns map control only.
; a0 context: pointer.w, counter.w, lastZ.w, deltaZ.w, currentZ.w,
; bgFlags.w, currentBG.w, dmaList.w, fadeMode.b, fadeTimer.b, INIDISP.b,
; bank.b, eventOpcode.w, eventLength.w, embeddedKind.w, pending.w.
; Tick d0=new original player worldZ, once BEFORE object strategies.
; Next/Tick return d0: 0 blocked, 1 EVENT awaiting consumer, -1 invalid.
; a1 points at ORIGINAL bytes for an event; context retains its pointer.
; Consumer must apply original effects, then Commit. No silent skipped event.
; Clobbers d0/d1, a1/a2; persistent scene state belongs to the caller.
; Original advance 03:ED42: word subtraction/wrap, tests N (not signed <).
M4ScriptTick:
        tst.w 26(a0)
        bne M4ScriptInvalid
        move.w d0,8(a0)
        sub.w 4(a0),d0
        move.w d0,6(a0)
        move.w 8(a0),4(a0)
        move.w 2(a0),d1
        sub.w d0,d1
        bmi.s M4ScriptNext
        move.w d1,2(a0)
        moveq #0,d0
        rts

M4ScriptNext:
        tst.w 26(a0)
        bne M4ScriptInvalid ; previous event must have an explicit consumer
        ; context+28.l: program descriptor (0 = intro/title stream); the
        ; bank-0D map program goes to the bank-05 one when 19(a0) = 5.
        move.l 28(a0),d0
        bne.s M4ScriptHasProgram
        cmpi.b #13,19(a0)
        bne M4ScriptInvalid
        move.l #M4ScriptProgramIntro,d0
        bra.s M4ScriptProgram
M4ScriptHasProgram:
        cmpi.b #13,19(a0)
        beq.s M4ScriptProgram
        cmpi.b #5,19(a0)
        bne M4ScriptInvalid
        cmpi.l #M4ScriptProgramMap0D,d0
        bne M4ScriptInvalid
        move.l #M4ScriptProgramMap05,d0
M4ScriptProgram:
        movea.l d0,a1
        movea.l (a1),a2 ;boundary table
        tst.w 10(a1) ;entry count: sorted table, binary search
        beq.s M4ScriptFind
        move.l d2,-(sp)
        move.w (a0),d2
        moveq #6,d0
        move.w 10(a1),d1
        jsr M4BSearch
        move.l (sp)+,d2
        move.l a2,d0
        beq M4ScriptInvalid
        bra.s M4ScriptFound
M4ScriptFind:
        move.w (a2),d0
        cmpi.w #$ffff,d0
        beq M4ScriptInvalid
        cmp.w (a0),d0
        beq.s M4ScriptFound
        lea 6(a2),a2
        bra.s M4ScriptFind
M4ScriptFound:
        move.w 2(a2),22(a0)
        move.w 4(a2),24(a0)
        clr.w 26(a0)
        moveq #0,d0
        move.w (a0),d0
        sub.w 8(a1),d0 ;index base of the program bytes
        movea.l 4(a1),a1
        adda.l d0,a1
        moveq #0,d0
        move.b (a1),d0
        move.w d0,20(a0)
        cmpi.w #$50,d0
        beq M4ScriptDown
        cmpi.w #$44,d0
        beq M4ScriptSlowDown
        cmpi.w #$4e,d0
        beq M4ScriptUp
        cmpi.w #$42,d0
        beq M4ScriptSlowUp
        cmpi.w #$4c,d0
        beq M4ScriptFadeWait
        cmpi.w #$64,d0
        beq M4ScriptBGWait
        cmpi.w #$66,d0
        beq M4ScriptBGInfo
        cmpi.w #$10,d0
        beq M4ScriptBGRequest
        cmpi.w #$12,d0
        beq M4ScriptWaitWord
        cmpi.w #$8a,d0
        beq M4ScriptWaitByte
        cmpi.w #$2e,d0
        beq M4ScriptGoto
        ; Objects, their attributes and embedded code remain explicit events.
        ; The ROM-boundary table limits the accepted set, including opcode 78.
        move.w #1,26(a0)
        moveq #1,d0
        rts

M4ScriptDown:
        move.b #$fe,16(a0)
        bra M4ScriptAdvance
M4ScriptSlowDown: ;44 setfadedown 03:F21F
        move.b #$ff,16(a0)
        bra M4ScriptAdvance
M4ScriptUp:
        move.b #2,16(a0)
        bra M4ScriptAdvance
M4ScriptSlowUp: ;42 setfadeup 03:F213: fadedir 1
        move.b #1,16(a0)
        bra M4ScriptAdvance
M4ScriptFadeWait:
        tst.b 17(a0)
        bne.s M4ScriptFadeBlocked
        cmpi.b #$80,18(a0)
        beq M4ScriptAdvance
M4ScriptFadeBlocked:
        move.w #1,2(a0)
        bra M4ScriptBlocked
M4ScriptBGRequest:
        bsr M4ScriptOperand
        move.w d1,12(a0)
        ori.w #4,10(a0)
        ; Loading happens in the original consumer's order, not here.
        bra M4ScriptAdvance
M4ScriptBGWait:
        moveq #0,d1
        move.w 14(a0),d1
        cmpi.w #508,d1
        bhi M4ScriptInvalid
        lea M4BGLists,a2
        ; Original reads words at index and index+1 and ORs them: all THREE
        ; bytes must be zero. Big endian assembly can test each byte directly.
        move.b (a2,d1.w),d0
        or.b 1(a2,d1.w),d0
        or.b 2(a2,d1.w),d0
        bne M4ScriptBlocked
        bra M4ScriptAdvance
M4ScriptBGInfo:
        ori.w #8,10(a0)
        bra M4ScriptAdvance
M4ScriptWaitWord:
        bsr M4ScriptOperand
        tst.w d1
        beq M4ScriptAdvance ; zero does not write counter and keeps parsing
        move.w d1,2(a0)
        bsr M4ScriptMovePointer
        bra M4ScriptBlocked
M4ScriptWaitByte:
        moveq #0,d1
        move.b 1(a1),d1
        lsl.w #4,d1
        move.w d1,2(a0)
        bsr M4ScriptMovePointer ; zero ALSO returns; differs from word wait
        bra M4ScriptBlocked
M4ScriptGoto:
        bsr M4ScriptOperand
        move.w d1,(a0)
        move.b 3(a1),19(a0)
        bra M4ScriptNext
M4ScriptAdvance:
        bsr M4ScriptMovePointer
        bra M4ScriptNext
M4ScriptMovePointer:
        move.w 22(a0),d1
        add.w d1,(a0)
        rts
M4ScriptOperand:
        moveq #0,d1
        move.b 2(a1),d1
        lsl.w #8,d1
        move.b 1(a1),d1
        rts
M4ScriptCommit:
        cmpi.w #1,26(a0)
        bne.s M4ScriptInvalid
        clr.w 26(a0)
        ; Object commands set mapcnt and return only when nonzero. Actual
        ; allocator/strategy consumer supplies its result in the context.
        move.w 20(a0),d0
        cmpi.w #$74,d0
        beq.s M4ScriptObjectCommit
        cmpi.w #$76,d0
        beq.s M4ScriptObjectCommit
        cmpi.w #$86,d0
        beq.s M4ScriptObjectCommit
        cmpi.w #$00,d0 ;mapobj 03:F75F (level scripts)
        beq.s M4ScriptObjectCommit
        cmpi.w #$70,d0 ;mapqobj 03:F560 (level scripts)
        beq.s M4ScriptObjectCommit
        cmpi.w #$0a,d0 ;mapmother 03:FA6E: mapcnt = wait (03:FAF4)
        beq.s M4ScriptObjectCommit
        cmpi.w #$26,d0 ;mapobjzrot 03:F8C6: mapcnt = wait
        beq.s M4ScriptObjectCommit
        bra M4ScriptAdvance
M4ScriptObjectCommit:
        bsr M4ScriptMovePointer
        tst.w 2(a0)
        beq M4ScriptNext
M4ScriptBlocked:
        moveq #0,d0
        rts
M4ScriptInvalid:
        moveq #-1,d0
        rts
        even
        include '../build/m4-script-boundaries.inc'
; Program descriptor: boundaries.l, bytes.l, index base.w, entries.w (0 =
; linear search up to $FFFF, else a sorted table of that many entries).
M4ScriptProgramIntro:
        dc.l M4ScriptBoundaries,M4ScriptBytes
        dc.w $7870,0
; Bank-0D / bank-05 map programs (tools/generate-map-programs.py, map0d.inc):
; every map script of the ROM (stages, training, credits, screens).
M4ScriptProgramMap0D:
        dc.l M4Map0DBoundaries,M4Map0DBytes
        dc.w 0,M4_MAP0D_COMMANDS
M4ScriptProgramMap05:
        dc.l M4Map05Boundaries,M4Map05Bytes
        dc.w 0,M4_MAP05_COMMANDS

; Binary search of a table sorted by its first WORD (unsigned).
; a2 table, d0.w entry size, d1.w entry count, d2.w key -> a2 entry or 0.
M4BSearch:
        movem.l d0-d1/d3-d5,-(sp)
        moveq #0,d3 ;lo
        move.w d1,d4 ;hi (exclusive)
M4BsLoop:
        cmp.w d4,d3
        bhs.s M4BsMiss
        move.w d3,d5
        add.w d4,d5
        lsr.w #1,d5 ;mid
        moveq #0,d1
        move.w d5,d1
        mulu.w d0,d1
        cmp.w (a2,d1.l),d2
        beq.s M4BsHit
        bhi.s M4BsUp
        move.w d5,d4
        bra.s M4BsLoop
M4BsUp:
        addq.w #1,d5
        move.w d5,d3
        bra.s M4BsLoop
M4BsHit:
        adda.l d1,a2
        movem.l (sp)+,d0-d1/d3-d5
        rts
M4BsMiss:
        suba.l a2,a2
        movem.l (sp)+,d0-d1/d3-d5
        rts

M4ScriptBytes:
        incbin '../build/m4-intro-script.bin'
        incbin '../build/m4-title-script.bin'
M4BGLists:
        incbin '../build/m4-bg-lists.bin'
        even
