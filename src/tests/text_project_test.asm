; Actual 68000 descriptors versus expected values from original GSU execution.
; Header FF4490: 'M4TP', status.w (1 pass/FFFF fail), passed.w, return.w.
; 84 records at FFD000, each the seven descriptor words; stringptr/len=FFFF.
; Uses disposable FFA0A0 context/FFA0C0 descriptor before the BG map is loaded.
M4TextProjectTest:
        movem.l d0-d7/a0-a6,-(sp)
        move.l #'M4TP',$ff4490
        clr.l $ff4494
        clr.w $ff4498
        lea $ffa0a0,a0
        movea.l a0,a1
        moveq #7,d0
M4TextProjectTestClear:
        clr.l (a1)+
        dbra d0,M4TextProjectTestClear
        move.b #14,10(a0)
        move.w #1,16(a0)
        lea M4TextProjectVectors,a2
        lea $ffd000,a3
        lea $ffa0c0,a1
        move.w #M4_TEXT_PROJECT_CASES-1,d7
M4TextProjectTestNext:
        move.w (a2)+,(a0)
        move.w (a2)+,2(a0)
        move.w (a2)+,d4
        move.w (a2)+,d1
        move.b d1,20(a0)
        move.l #-1,(a1)
        move.l #-1,4(a1)
        move.l #-1,8(a1)
        move.w #-1,12(a1)
        move.w d4,d0
        bsr M4TextProject
        move.w d0,$ff4498
        movea.l a1,a4
        moveq #6,d1
M4TextProjectTestRecord:
        move.w (a4)+,(a3)+
        dbra d1,M4TextProjectTestRecord
        tst.w d0
        bne.s M4TextProjectTestBad
        move.w (a2)+,d1
        cmp.w (a1),d1
        bne.s M4TextProjectTestBad
        move.w (a2)+,d1
        cmp.w 2(a1),d1
        bne.s M4TextProjectTestBad
        move.w (a2)+,d1
        cmp.w 4(a1),d1
        bne.s M4TextProjectTestBad
        move.w (a2)+,d1
        cmp.w 12(a1),d1
        bne.s M4TextProjectTestBad
        cmpi.w #14,6(a1)
        bne.s M4TextProjectTestBad
        addq.w #1,$ff4496
        dbra d7,M4TextProjectTestNext
        move.w #1,$ff4494
        bra.s M4TextProjectTestDone
M4TextProjectTestBad:
        move.w #-1,$ff4494
M4TextProjectTestDone:
        movem.l (sp)+,d0-d7/a0-a6
        rts

M4TextProjectVectors:
        include '../build/intro-text-project.inc'
