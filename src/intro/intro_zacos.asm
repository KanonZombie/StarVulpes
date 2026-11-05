M4_ZACOS equ $ffce00 ;13 commercial actors: 8 zacointro, zaco2intro, 4 zacointro
M4_ZACO_COUNT equ $ffcfa0
M4IntroZacosInit:
        lea M4_ZACOS,a0
        moveq #103,d0
M4ZacosClear:
        clr.l (a0)+
        dbra d0,M4ZacosClear
        clr.w M4_ZACO_COUNT
        rts

; a1=original86 command; positions LE, worldZ from original camera cache.
M4IntroZacoCreate:
        move.w M4_ZACO_COUNT,d0
        cmpi.w #13,d0
        bhs M4ZacoCreateBad
        lsl.w #5,d0
        lea M4_ZACOS,a0
        adda.w d0,a0
        moveq #0,d2
        moveq #3,d3
M4ZacoCoordinates:
        move.b 1(a1,d3.w),d0
        lsl.w #8,d0
        move.b (a1,d3.w),d0
        move.w d0,(a0,d2.w)
        addq.w #2,d2
        addq.w #2,d3
        cmpi.w #6,d2
        bne.s M4ZacoCoordinates
        move.w INTRO_CAMERA+2,d0
        add.w d0,4(a0)
        move.b #14,21(a0)
        cmpi.b #$88,9(a1)
        beq.s M4ZacoKindReady
        move.b #15,21(a0)
M4ZacoKindReady:
        move.w #1,22(a0)
        clr.w 26(a0)
        cmpi.b #$91,11(a1)
        bne.s M4ZacoTypeReady
        move.w #1,26(a0) ;zaco2intro
M4ZacoTypeReady:
        move.w #1,30(a0) ;pending original initializer during traversal
        bsr M4IntroNativeAllocate
        tst.w d0
        beq.s M4ZacoCreateBad
        move.w d0,24(a0)
        move.w d0,M4_LAST_NATIVE
        move.l a0,M4_LAST_CONTEXT
        addq.w #1,M4_ZACO_COUNT
        moveq #0,d0
        rts
M4ZacoCreateBad:
        moveq #-1,d0
        rts

; showview atzremove (see M4IntroFlashesZRemove): every zaco strategy here
; has al_type 8. zmax E388=60, C22C=30 (header+14). Births are far ahead, so
; the first-frame exemption is never reached in this sequence.
M4IntroZacosZRemove:
        movem.l d0-d6/a0,-(sp)
        move.w M4_ZACO_COUNT,d6
        beq.s M4ZacosZDone
        subq.w #1,d6
        lea M4_ZACOS,a0
M4ZacosZNext:
        tst.w 22(a0)
        beq.s M4ZacosZSkip
        moveq #60,d1
        cmpi.b #14,21(a0)
        beq.s M4ZacosZMax
        moveq #30,d1
M4ZacosZMax:
        move.w 4(a0),d0
        sub.w INTRO_CAMERA+8,d0
        add.w d1,d0
        bpl.s M4ZacosZSkip
        move.w 24(a0),d0
        bsr M4IntroNativeRemove
        clr.w 22(a0)
M4ZacosZSkip:
        lea 32(a0),a0
        dbra d6,M4ZacosZNext
M4ZacosZDone:
        movem.l (sp)+,d0-d6/a0
        rts

M4IntroZacosStep:
        movem.l d1-d7/a0-a6,-(sp)
        move.w M4_ZACO_COUNT,d6
        beq.s M4ZacosStepDone
        subq.w #1,d6
M4ZacosStepActor:
        move.w d6,d0
        lsl.w #5,d0
        lea M4_ZACOS,a0
        adda.w d0,a0
        tst.w 22(a0)
        beq.s M4ZacosStepNext
        move.w INTRO_CAMERA+6,d1
        tst.w 26(a0)
        bne.s M4ZacosSecond
        tst.w 30(a0)
        beq.s M4ZacosExisting
        clr.w 30(a0)
        bsr M4IntroZacoInit
        bra.s M4ZacosTicked
M4ZacosExisting:
        bsr M4IntroZacoTick
        bra.s M4ZacosTicked
M4ZacosSecond:
        ; Player strategy runs first in the original list: its Z already
        ; advanced by this tick's objectVZ when zaco2intro aims/exits.
        move.w INTRO_CAMERA,d2
        add.w INTRO_CAMERA+12,d2
        tst.w 30(a0)
        beq.s M4ZacosSecondTick
        clr.w 30(a0)
        bsr M4IntroZaco2Init
        bra.s M4ZacosTicked
M4ZacosSecondTick:
        bsr M4IntroZaco2Tick
M4ZacosTicked:
        tst.w d0
        beq.s M4ZacosStepNext
        move.w 24(a0),d0
        bsr M4IntroNativeRemove
M4ZacosStepNext:
        dbra d6,M4ZacosStepActor
M4ZacosStepDone:
        movem.l (sp)+,d1-d7/a0-a6
        rts

M4IntroZacosSort:
        movem.l d7/a0,-(sp)
        move.w M4_ZACO_COUNT,d7
        beq.s M4ZacosSortDone
        subq.w #1,d7
M4ZacosSortActor:
        move.w d7,d0
        lsl.w #5,d0
        lea M4_ZACOS,a0
        adda.w d0,a0
        tst.w 22(a0)
        beq.s M4ZacosSortNext
        bsr M4IntroSceneSortObject
M4ZacosSortNext:
        dbra d7,M4ZacosSortActor
M4ZacosSortDone:
        movem.l (sp)+,d7/a0
        rts

; Selected-ROM07:8EC5..8F90; source helpers RNG,chase,speedto,n3Dvecs.
; Context: xyz0..4,vel6..10,angles12..14,speed15,anim16,counter18,
; life19,kind21,alive22. d1=pviewVelZ. d0=0 tick/1 source removal.
; Removal is reported to the scene allocator; no replacement explosion.
M4IntroZacoInit:
        movem.l d1-d7/a0-a1,-(sp)
        move.w d1,d7
        bsr M4IntroRandom
        andi.b #15,d0
        addi.b #57,d0
        move.b d0,12(a0)
        bsr M4IntroRandom
        move.b d0,13(a0)
        bsr M4IntroRandom
        move.b d0,14(a0)
        move.b #10,18(a0)
        move.b #60,15(a0)
        move.b #60,19(a0)
        move.b #128,16(a0)
        move.w d7,d1
        bsr M4IntroZacoTick ;initializer falls through to first tick
        movem.l (sp)+,d1-d7/a0-a1
        rts

M4IntroZacoTick:
        movem.l d1-d7/a0-a1,-(sp)
        move.w d1,d7
        moveq #0,d0
        move.b 16(a0),d0
        bsr M4IntroZacoAnimation
        move.b d0,16(a0)
        subq.b #1,19(a0)
        beq M4ZacoRemoved
        subq.b #1,18(a0)
        bne.s M4ZacoRolling
        move.b #1,18(a0)
        moveq #0,d0
        move.b 13(a0),d0
        moveq #0,d1
        moveq #3,d2
        bsr M4IntroShipChase
        move.b d0,13(a0)
        moveq #0,d0
        move.b 12(a0),d0
        moveq #0,d1
        moveq #3,d2
        bsr M4IntroShipChase
        move.b d0,12(a0)
        moveq #0,d0
        move.b 14(a0),d0
        moveq #0,d1
        moveq #4,d2
        bsr M4IntroShipChase
        move.b d0,14(a0)
        cmpi.b #120,15(a0)
        beq.s M4ZacoVectors
        addq.b #2,15(a0)
        cmpi.b #120,15(a0)
        bls.s M4ZacoVectors
        move.b #120,15(a0)
        bra.s M4ZacoVectors
M4ZacoRolling:
        addq.b #6,14(a0)
M4ZacoVectors:
        move.w 16(a0),-(sp)
        move.b 13(a0),16(a0)
        move.b 12(a0),17(a0)
        moveq #0,d0
        move.b 15(a0),d0
        bsr M4IntroActorVectors
        move.w (sp)+,16(a0)
        move.w 6(a0),d0
        add.w d0,(a0)
        move.w 8(a0),d0
        add.w d0,2(a0)
        move.w 10(a0),d0
        add.w d0,4(a0)
        add.w d7,4(a0)
        moveq #0,d0
        bra.s M4ZacoTickReturn
M4ZacoRemoved:
        clr.w 22(a0)
        moveq #1,d0
M4ZacoTickReturn:
        movem.l (sp)+,d1-d7/a0-a1
        rts

; Selected-ROM zaco2intro 07:8F91..9193. Context as zacointro plus
; counter18=sbyte1, 19=sbyte2, state20, type26=1. d1=pviewVelZ,
; d2=player worldZ already advanced this tick (player strategy runs first).
; The weapon factory call happens mid-tick, before aim and movement.
M4_EXIT_INTRO equ $ff9c80 ;original exitintro BYTE
M4_ZACO2_TEST equ $ff9c82 ;nonzero: record fire request instead of firing
M4_ZACO2_FIRED equ $ff9c8a ;count.w, pitch, yaw of the last request (not ff9c86 brightness)
M4IntroZaco2Init:
        move.b #45,15(a0)
        move.b #64,12(a0)
        move.b #30,18(a0)
        move.b #6,19(a0)
        move.b #128,16(a0)
M4IntroZaco2Tick:
        movem.l d1-d7/a0-a1,-(sp)
        move.w d1,d7
        move.w d2,d6
        moveq #0,d0
        move.b 16(a0),d0
        bsr M4IntroZacoAnimation
        move.b d0,16(a0)
        bsr M4IntroZacoPhases01
        cmpi.b #2,20(a0)
        bne M4Zaco2Vectors
        addq.b #6,14(a0)
        bsr M4Zaco2PlayerDistance
        subi.w #50,d0
        bmi.s M4Zaco2AimCheck
        addi.w #50-1000,d0
        bpl.s M4Zaco2AimCheck
        move.w M4_SCENE_TICK,d0
        andi.w #3,d0
        bne M4Zaco2Vectors ;not this frame: skips the aim as well
        bsr M4IntroRandom
        andi.b #7,d0
        subq.b #3,d0
        move.b d0,d4 ;$152E: pitch offset
        bsr M4IntroRandom
        andi.b #7,d0
        subq.b #3,d0
        move.b d0,d5 ;$152F: yaw offset
        addq.w #1,M4_ZACO2_FIRED
        move.b d4,M4_ZACO2_FIRED+2
        move.b d5,M4_ZACO2_FIRED+3
        tst.w M4_ZACO2_TEST
        bne.s M4Zaco2AimCheck
        move.w d6,d2
        bsr M4IntroZaco2Fire
M4Zaco2AimCheck:
        bsr M4Zaco2PlayerDistance
        subi.w #500,d0
        bmi M4Zaco2Vectors
        ; Pitch: 1F:D03E, D0AB distance, atan(dy,distance) high BYTE.
        moveq #0,d0
        sub.w (a0),d0 ;player X is zero
        bpl.s M4Zaco2AbsX
        neg.w d0
M4Zaco2AbsX:
        asr.w #1,d0
        move.w d6,d1
        sub.w 4(a0),d1
        bpl.s M4Zaco2AbsZ
        neg.w d1
M4Zaco2AbsZ:
        asr.w #1,d1
        move.w d1,d2
        add.w d0,d2
        add.w d2,d2 ;$1252
        move.w d1,d3
        sub.w d0,d3
        bpl.s M4Zaco2Larger
        move.w d0,d1
M4Zaco2Larger:
        add.w d2,d1 ;$02
        move.w d1,d2
        lsl.w #2,d2
        asr.w #1,d1
        add.w d2,d1
        asr.w #3,d1 ;distance
        moveq #0,d0
        sub.w 2(a0),d0 ;player Y is zero
        bsr M4IntroWeaponAtan
        lsr.w #8,d0
        move.b 12(a0),d1
        bsr M4Zaco2Chase
        move.b d0,12(a0)
        ; Yaw: 1F:D021, -(atan(dx,dz) high BYTE).
        moveq #0,d0
        sub.w (a0),d0
        move.w d6,d1
        sub.w 4(a0),d1
        bsr M4IntroWeaponAtan
        lsr.w #8,d0
        neg.b d0
        move.b 13(a0),d1
        bsr M4Zaco2Chase
        move.b d0,13(a0)
M4Zaco2Vectors:
        move.w 16(a0),-(sp)
        move.b 13(a0),16(a0)
        move.b 12(a0),17(a0)
        moveq #0,d0
        move.b 15(a0),d0
        bsr M4IntroActorVectors
        move.w (sp)+,16(a0)
        move.w 6(a0),d0
        add.w d0,(a0)
        move.w 8(a0),d0
        add.w d0,2(a0)
        move.w 10(a0),d0
        add.w d0,4(a0)
        add.w d7,4(a0)
        move.w 4(a0),d0
        sub.w d6,d0
        bpl.s M4Zaco2InFront
        move.b #1,M4_EXIT_INTRO
M4Zaco2InFront:
        moveq #0,d0
        movem.l (sp)+,d1-d7/a0-a1
        rts

; d0=|playerZ-Z| with 65816 EOR/INC wrap (8000 stays 8000). d6 playerZ.
M4Zaco2PlayerDistance:
        move.w d6,d0
        sub.w 4(a0),d0
        bpl.s M4Zaco2DistanceDone
        neg.w d0
M4Zaco2DistanceDone:
        rts

; 07:90FD..912A. d0 target BYTE, d1 current BYTE -> d0 new BYTE.
; Minimum step magnitude4, then two ROR halvings rounded toward zero.
M4Zaco2Chase:
        cmp.b d1,d0
        beq.s M4Zaco2ChaseDone
        sub.b d1,d0
        bmi.s M4Zaco2ChaseNegative
        cmpi.b #4,d0
        bge.s M4Zaco2ChaseHalve
        moveq #4,d0
        bra.s M4Zaco2ChaseHalve
M4Zaco2ChaseNegative:
        cmpi.b #-4,d0
        blt.s M4Zaco2ChaseHalve
        moveq #-4,d0
M4Zaco2ChaseHalve:
        asr.b #1,d0
        bpl.s M4Zaco2ChaseHalf1
        bcc.s M4Zaco2ChaseHalf1
        addq.b #1,d0
M4Zaco2ChaseHalf1:
        asr.b #1,d0
        bpl.s M4Zaco2ChaseHalf2
        bcc.s M4Zaco2ChaseHalf2
        addq.b #1,d0
M4Zaco2ChaseHalf2:
        add.b d1,d0
M4Zaco2ChaseDone:
        rts

; FF45E0:M4ZA,status,count. All expected states are executed ROM goldens.
M4IntroZacoTest:
        movem.l d1-d7/a0-a6,-(sp)
        move.l M4_RNG,-(sp)
        move.l #'M4ZA',$ff45e0
        clr.l $ff45e4
        lea M4ZacoCases,a4
        move.w #M4_ZACO_CASES-1,d7
M4ZacoCase:
        lea $ffbd00,a0
        movea.l a0,a1
        moveq #7,d6
M4ZacoInput:
        move.l (a4)+,(a1)+
        dbra d6,M4ZacoInput
        move.w (a4)+,d1
        move.l (a4)+,M4_RNG
        move.w (a4)+,d0
        tst.w d0
        bne.s M4ZacoCaseTick
        bsr M4IntroZacoInit
        bra.s M4ZacoCaseCompare
M4ZacoCaseTick:
        bsr M4IntroZacoTick
M4ZacoCaseCompare:
        cmp.w 36(a4),d0
        bne.s M4ZacoCaseBad
        lea $ffbd00,a1
        moveq #7,d6
M4ZacoExpected:
        move.l (a4)+,d0
        cmp.l (a1)+,d0
        bne.s M4ZacoCaseBad
        dbra d6,M4ZacoExpected
        move.l (a4)+,d0
        cmp.l M4_RNG,d0
        bne.s M4ZacoCaseBad
        addq.l #2,a4
        addq.w #1,$ff45e6
        dbra d7,M4ZacoCase
        move.w #1,$ff45e4
        moveq #0,d0
        bra.s M4ZacoTestReturn
M4ZacoCaseBad:
        move.w #-1,$ff45e4
        moveq #-1,d0
M4ZacoTestReturn:
        move.l (sp)+,M4_RNG
        movem.l (sp)+,d1-d7/a0-a6
        rts
