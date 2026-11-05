; Original text trails, ROM04:A247..A2AB and 04:A2F1..A349.
; Same drawable fields as text_path's32-byte parent: xyz0/2/4,depth10.b,
; alive16.w,text18.w,size20.b. Trail-only: next6.w,life8.b.
; Parent30.w is the head slot index; FFFF terminates each list.
; Pool storage is32 bytes/entry. Slots are representation, not SNES pointers.
; a0 parent, a1 pool, d0 original pviewvelZ, d1 capacity. Call AFTER its
; M4TextPathTick, BEFORE the next parent. New trail is traversed this tick.
; Parents must be visited Presents then Nintendo, as original insertion order.
; M4IntroTrailsStep returns d0=0 orFFFF invalid list/full pool; full allocation
; still updates the prior list. No original game logic chooses a render clock.
; Clobbers d0-d4/a2-a3. Preserves a0/a1/d5-d7/a4-a6.

; a0 points to the two contiguous32-byte parents, a1 to pool, d1 capacity.
M4IntroTrailsInit:
        move.w #-1,30(a0)
        move.w #-1,62(a0)
        movea.l a1,a2
        moveq #0,d0
        move.w d1,d2
        beq.s M4IntroTrailsInitDone
        subq.w #1,d2
M4IntroTrailsInitSlot:
        moveq #7,d3
M4IntroTrailsInitWord:
        move.l d0,(a2)+
        dbra d3,M4IntroTrailsInitWord
        dbra d2,M4IntroTrailsInitSlot
M4IntroTrailsInitDone:
        rts

M4IntroTrailsStep:
        move.w d0,-(sp)         ; velocity survives allocation and list traversal
        clr.w -(sp)            ; status
        tst.w 22(a0)            ; emitted before the keep4000 trigger
        beq M4IntroTrailsWalk
        moveq #0,d2
        movea.l a1,a3
M4IntroTrailsFindFree:
        cmp.w d1,d2
        bcc.s M4IntroTrailsFull
        tst.w 16(a3)
        beq.s M4IntroTrailsAllocate
        addq.w #1,d2
        lea 32(a3),a3
        bra.s M4IntroTrailsFindFree
M4IntroTrailsFull:
        move.w #-1,(sp)
        bra.s M4IntroTrailsWalk
M4IntroTrailsAllocate:
        bsr M4IntroNativeTrailAllocate
        movea.l a3,a2
        moveq #0,d0
        moveq #7,d3
M4IntroTrailsClearSlot:
        move.l d0,(a2)+
        dbra d3,M4IntroTrailsClearSlot
        move.l 24(a0),(a3)      ; copy pre-trigger X/Y/Z, original1F:DAD9
        move.w 28(a0),4(a3)
        move.w 30(a0),6(a3)
        move.w d2,30(a0)        ; insert immediately AFTER its parent
        move.b #5,8(a3)         ; original trail_istrat, run immediately
        move.w 22(a0),d0
        move.b d0,10(a3)
        move.w #1,16(a3)
        move.w 18(a0),18(a3)
        move.b 20(a0),20(a3)
M4IntroTrailsWalk:
        lea 30(a0),a2           ; pointer to previous->next, initially parent
        move.w d1,d4            ; bound catches cycles/corrupt links
M4IntroTrailsNext:
        moveq #0,d2
        move.w (a2),d2
        cmpi.w #$ffff,d2
        beq M4IntroTrailsDone
        cmp.w d1,d2
        bcc M4IntroTrailsBadList
        subq.w #1,d4
        bmi M4IntroTrailsBadList
        lsl.l #5,d2
        movea.l a1,a3
        adda.l d2,a3
        tst.w 16(a3)
        beq M4IntroTrailsBadList
        btst #0,8(a3)
        bne.s M4IntroTrailsMove
        cmpi.b #1,10(a3)
        beq.s M4IntroTrailsMove
        cmpi.b #5,10(a3)
        beq.s M4IntroTrailsMove
        cmpi.b #9,10(a3)
        beq.s M4IntroTrailsMove
        subq.b #1,10(a3)
M4IntroTrailsMove:
        move.w 2(sp),d0
        add.w d0,4(a3)          ; ORIGINAL pviewvelZ, not lastZchange
        tst.b 8(a3)             ; test BEFORE decrement; life0 stays visible
        beq.s M4IntroTrailsRemove
        subq.b #1,8(a3)
        lea 6(a3),a2
        bra M4IntroTrailsNext
M4IntroTrailsRemove:
        bsr M4IntroNativeTrailRemove
        move.w 6(a3),(a2)
        clr.w 16(a3)
        bra M4IntroTrailsNext
M4IntroTrailsBadList:
        move.w #-1,(sp)
M4IntroTrailsDone:
        move.w (sp)+,d0
        addq.l #2,sp
        rts
