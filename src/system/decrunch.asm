; Semantic MDECRU translation for bounded original intro resources.
; a4 compressed begin, a0 end, a2 destination. Byte accesses: ROM data is odd.
; d0=0 success / 1 malformed. Original 32-bit sentinel, 16-bit getbits/result,
; reverse literal/match order, overlapping backwards copy, early final stop.
; SNES VRAM tile relocation is applied by the destination visual layer.
M4Decrunch:
        move.l sp,BG_DECODE_SP
        moveq #0,d6
        move.b -2(a0),d6
        lsl.w #8,d6
        move.b -1(a0),d6
        tst.w d6
        beq M4DecrunchBad
        cmpi.w #8192,d6
        bhi M4DecrunchBad
        movea.l a0,a1
        subq.l #4,a1
        movea.l a2,a3
        adda.l d6,a3
        movea.l a3,a5
        bsr M4PreviousLong
        tst.l d2
        beq M4DecrunchBad
M4DecrunchToken:
        moveq #3,d1
        bsr M4GetBits
        move.w d0,d3
        cmpi.w #7,d3
        bne.s M4DecrunchRawReady
        moveq #1,d1
        bsr M4GetBits
        tst.w d0
        bne.s M4DecrunchLongRaw
        moveq #4,d1
        bsr M4GetBits
        addq.w #7,d0
        bra.s M4DecrunchRawSet
M4DecrunchLongRaw:
        moveq #10,d1
        bsr M4GetBits
        tst.w d0
        bne.s M4DecrunchRawSet
        moveq #18,d1
        bsr M4GetBits
M4DecrunchRawSet:
        move.w d0,d3
M4DecrunchRawReady:
        tst.w d3
        beq.s M4DecrunchMatch
        cmp.w d6,d3
        bhi M4DecrunchBad
M4DecrunchLiteral:
        moveq #8,d1
        bsr M4GetBits
        move.b d0,-(a3)
        subq.w #1,d6
        beq M4DecrunchDone
        subq.w #1,d3
        bne.s M4DecrunchLiteral
M4DecrunchMatch:
        moveq #2,d1
        bsr M4GetBits
        moveq #2,d3
        moveq #8,d4
        tst.w d0
        beq.s M4DecrunchOffset
        moveq #3,d3
        cmpi.w #1,d0
        bne.s M4DecrunchLongMatch
        moveq #1,d1
        bsr M4GetBits
        tst.w d0
        bne.s M4DecrunchOffset
        moveq #14,d4
        bra.s M4DecrunchOffset
M4DecrunchLongMatch:
        moveq #4,d3
        cmpi.w #2,d0
        beq.s M4DecrunchVariableOffset
        moveq #2,d1
        bsr M4GetBits
        cmpi.w #2,d0
        bhs.s M4DecrunchMatchExtra
        addq.w #5,d0
        bra.s M4DecrunchMatchSet
M4DecrunchMatchExtra:
        beq.s M4DecrunchMatchSeven
        moveq #8,d1
        bsr M4GetBits
        tst.w d0
        bne.s M4DecrunchMatchSet
        moveq #1,d0          ; original signed copy loop enters once at run=0
        bra.s M4DecrunchMatchSet
M4DecrunchMatchSeven:
        moveq #2,d1
        bsr M4GetBits
        addq.w #7,d0
M4DecrunchMatchSet:
        move.w d0,d3
M4DecrunchVariableOffset:
        moveq #16,d4
        moveq #1,d1
        bsr M4GetBits
        tst.w d0
        beq.s M4DecrunchOffset
        moveq #8,d4
        moveq #1,d1
        bsr M4GetBits
        tst.w d0
        bne.s M4DecrunchOffset
        moveq #12,d4
M4DecrunchOffset:
        move.w d4,d1
        bsr M4GetBits
        tst.w d0
        beq.s M4DecrunchBad
        move.l d0,d5
        cmp.w d6,d3
        bhi.s M4DecrunchBad
        subq.w #1,d3
M4DecrunchCopy:
        movea.l a3,a6
        adda.l d5,a6
        cmpa.l a5,a6
        bhi.s M4DecrunchBad
        move.b -1(a6),-(a3)
        subq.w #1,d6
        beq.s M4DecrunchDone
        subq.w #1,d3
        bpl.s M4DecrunchCopy
        bra M4DecrunchToken
M4DecrunchDone:
        moveq #0,d0
        rts
M4DecrunchBad:
        move.l a1,$ff4204
        move.l a3,$ff4208
        move.w d6,$ff420c
        move.w d3,$ff420e
        move.l d2,$ff4210
        move.l a4,$ff4214
        move.l a5,$ff4218
        move.l d5,$ff421c
        move.l #'M4DC',$ff4200
        moveq #1,d0
        rts

M4GetBits:
        moveq #0,d0
        subq.w #1,d1
M4GetBit:
        lsr.l #1,d2
        tst.l d2            ; X preserves data bit; zero means sentinel only
        bne.s M4GotBit
        bsr M4PreviousLong
        lsr.l #1,d2
        ori.l #$80000000,d2 ; X preserves first new bit, force next sentinel
M4GotBit:
        roxl.w #1,d0
        dbra d1,M4GetBit
        rts
M4PreviousLong:
        movea.l a1,a6
        subq.l #4,a6
        cmpa.l a4,a6
        blo.s M4DecrunchTruncated
        moveq #0,d2
        move.b -(a1),d2
        moveq #0,d7
        move.b -(a1),d7
        lsl.l #8,d7
        or.l d7,d2
        moveq #0,d7
        move.b -(a1),d7
        lsl.l #8,d7
        lsl.l #8,d7
        or.l d7,d2
        moveq #0,d7
        move.b -(a1),d7
        lsl.l #8,d7
        lsl.l #8,d7
        lsl.l #8,d7
        or.l d7,d2
        rts
M4DecrunchTruncated:
        ; Unwind helper nesting via saved entry SP; malformed resources must
        ; never continue rendering stale decoded memory.
        movea.l BG_DECODE_SP,sp
        bra M4DecrunchBad
