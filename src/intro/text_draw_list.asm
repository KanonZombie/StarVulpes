; Original nullshape text list / mallrotzsort (ROM physical00B2C5).
; Pool/list addresses are destination storage. Original traversal is Presents,
; newest..oldest trails, Nintendo, newest..oldest trails. Insert before equal
; Z using the original WORD N flag of existingZ-1-incomingZ.
; Zero camera rotation and both sort biases0 in this intro interval.
INTRO_TRAILS equ $ff8500
INTRO_TRAIL_SLOTS equ 16
INTRO_DRAW_LIST equ $ff8800 ; 18 records: drawable address.l, relativeZ.w
INTRO_DRAW_COUNT equ $ff8272

M4IntroTextList:
        clr.w INTRO_DRAW_COUNT
        lea TEXT_OBJECTS+32,a0
        moveq #1,d7
M4IntroTextListParent:
        bsr M4IntroTextInsert
        move.w #INTRO_TRAIL_SLOTS,d5
        move.w 30(a0),d4
M4IntroTextListTrail:
        cmpi.w #$ffff,d4
        beq.s M4IntroTextListNextParent
        cmpi.w #INTRO_TRAIL_SLOTS,d4
        bhs M4IntroTextListBad
        subq.w #1,d5
        bmi M4IntroTextListBad
        move.w d4,d0
        lsl.w #5,d0
        lea INTRO_TRAILS,a0
        adda.w d0,a0
        tst.w 16(a0)
        beq M4IntroTextListBad
        move.w 6(a0),d4
        bsr M4IntroTextInsert
        bra.s M4IntroTextListTrail
M4IntroTextListNextParent:
        lea TEXT_OBJECTS,a0
        dbra d7,M4IntroTextListParent
        moveq #0,d0
        rts
M4IntroTextListBad:
        moveq #-1,d0
        rts

; Preserves a0,d4-d7. Incoming alive drawable is inserted once.
M4IntroTextInsert:
        tst.w 16(a0)
        beq.s M4IntroTextInsertDone
        move.w 4(a0),d3
        sub.w INTRO_CAMERA+8,d3
        lea INTRO_DRAW_LIST,a2
        move.w INTRO_DRAW_COUNT,d2
        move.w d2,d1
        mulu.w #6,d1
        lea (a2,d1.w),a3
M4IntroTextFindPosition:
        tst.w d2
        beq.s M4IntroTextPosition
        move.w 4(a2),d0
        subq.w #1,d0
        sub.w d3,d0
        bmi.s M4IntroTextPosition
        lea 6(a2),a2
        subq.w #1,d2
        bra.s M4IntroTextFindPosition
M4IntroTextPosition:
        cmpi.w #18,INTRO_DRAW_COUNT
        bhs.s M4IntroTextListBad
        tst.w d2
        beq.s M4IntroTextStore
M4IntroTextShift:
        move.w -2(a3),4(a3)
        move.l -6(a3),(a3)
        subq.l #6,a3
        subq.w #1,d2
        bne.s M4IntroTextShift
M4IntroTextStore:
        move.l a0,(a2)
        move.w d3,4(a2)
        addq.w #1,INTRO_DRAW_COUNT
M4IntroTextInsertDone:
        rts
