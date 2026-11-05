; Original USA ROM: 07:8A90 / 8B3B / 88EA; GISTRATS playerdown[2/3]intro.
; Own 32-byte context: xyz.w[3], velocity.w[3], pitch/yaw/roll/speed.b,
; smoothedYaw/ smoothedPitch/count/life/state/kind.b, alive.w,event.w,
; pending.w,timer.b,spare.b,flags.w (own bit0 collision disabled,bit1 keepbehind).
; kind0=down2,kind1=down3,kind2=down. Angles wrap byte, xyz wrap word.
; Events: 1 sound id1(initialization),2 medium explosion,5 removal.
; Third ship exposes the medium event to the scene consumer, then resumes
; source state2 with smoke/RNG; FASTdebris remains a pending consumer.
;
; Init a0=context,d0=kind,d1=playerworldZ at original map spawn.
; Clobbers d0-d5/a1. Does NOT run first strategy tick: caller must do so in
; the same original object traversal, as the initializer falls through.
M4IntroShipInit:
        cmpi.w #2,d0
        bhi M4IntroShipUnsupported
        move.w d0,d4
        move.w d1,d5
        movea.l a0,a1
        moveq #7,d0
M4IntroShipInitClear:
        clr.l (a1)+
        dbra d0,M4IntroShipInitClear
        move.w #50,(a0)
        move.w #-400,2(a0)
        subi.w #700,d5
        move.w d5,4(a0)
        move.b #16,12(a0)
        move.b #120,15(a0)
        move.b #16,17(a0)
        move.b #30,18(a0)
        move.b #70,19(a0)
        move.b d4,21(a0)
        move.w #1,22(a0)
        move.w #1,24(a0)
        move.w #3,30(a0)
        cmpi.w #2,d4
        bne.s M4IntroShipReturn
        move.b #33,18(a0)
        clr.b 19(a0)
        move.b #16,28(a0)
M4IntroShipReturn:
        moveq #0,d0
        rts

; Tick a0=context,d0=gameframe.byte,d1=player velocityZ at RAM14F6.
; Returns d0=0 completed,1 external effect pending,-1 badkind.
; Clobbers d0-d7/a1; same-tick nextstate tail dispatch is intentional.
M4IntroShipTick:
        cmpi.b #2,21(a0)
        bhi M4IntroShipUnsupported
        tst.w 22(a0)
        beq.s M4IntroShipReturn
        tst.w 26(a0)
        bne M4IntroShipPending
        move.w d0,d6
        move.w d1,d7
        clr.w 24(a0)
M4IntroShipStrategy:
        cmpi.b #2,21(a0)
        beq.s M4IntroShipState0
        subq.b #1,19(a0)
        beq M4IntroShipRemove
M4IntroShipState0:
        tst.b 20(a0)
        bne.s M4IntroShipState1
        tst.b 18(a0)
        bne.s M4IntroShipCountdown
        addq.b #1,20(a0)
        bra.s M4IntroShipStrategy ; 1F:DB66 -> DC25 -> strategy, NOT return
M4IntroShipCountdown:
        subq.b #1,18(a0)
        cmpi.b #2,21(a0)
        bne.s M4IntroShipDelay
        addq.b #1,14(a0)
M4IntroShipDelay:
        move.w d6,d0
        andi.w #3,d0
        bne M4IntroShipMove
        subq.b #1,12(a0)
        tst.b 21(a0)
        bne.s M4IntroShipOtherYaw
        addq.b #1,13(a0)
        bra M4IntroShipMove
M4IntroShipOtherYaw:
        cmpi.b #1,21(a0)
        bne M4IntroShipMove
        subq.b #1,13(a0)
        bra M4IntroShipMove
M4IntroShipState1:
        cmpi.b #2,20(a0)
        beq.s M4IntroShipState2
        cmpi.b #2,21(a0)
        bne.s M4IntroShipTurn
        move.b #20,28(a0)
        move.w #2,24(a0)
        move.w #2,26(a0)
M4IntroShipPending:
        moveq #1,d0
        rts
M4IntroShipResume:
        move.w M4_SCENE_TICK,d6
        move.w INTRO_CAMERA+6,d7
        clr.w 26(a0)
        move.b #2,20(a0)
        ori.w #4,30(a0) ; native hitflash
M4IntroShipState2:
        tst.b 28(a0)
        beq.s M4IntroShipDebrisPending
        subq.b #1,28(a0)
        movem.l d6-d7,-(sp)
        bsr M4IntroEffectSmoke
        movem.l (sp)+,d6-d7
        bra.s M4IntroShipTurn
M4IntroShipDebrisPending:
        move.w #3,26(a0)
        bra M4IntroShipPending
M4IntroShipTurn:
        moveq #0,d0
        move.b 13(a0),d0
        moveq #64,d1
        cmpi.b #1,21(a0)
        bne.s M4IntroShipTurnYaw
        move.w #192,d1
M4IntroShipTurnYaw:
        moveq #4,d2
        bsr M4IntroShipChase
        move.b d0,13(a0)
        moveq #0,d0
        move.b 12(a0),d0
        moveq #0,d1
        moveq #4,d2
        bsr M4IntroShipChase
        move.b d0,12(a0)
        moveq #0,d0
        move.b 14(a0),d0
        moveq #32,d1
        cmpi.b #1,21(a0)
        bne.s M4IntroShipTurnRoll
        move.w #224,d1
M4IntroShipTurnRoll:
        moveq #3,d2
        bsr M4IntroShipChase
        move.b d0,14(a0)
M4IntroShipMove:
        moveq #0,d0
        move.b 16(a0),d0
        moveq #0,d1
        move.b 13(a0),d1
        moveq #5,d2
        bsr M4IntroShipChase
        move.b d0,16(a0)
        moveq #0,d0
        move.b 17(a0),d0
        moveq #0,d1
        move.b 12(a0),d1
        moveq #5,d2
        bsr M4IntroShipChase
        move.b d0,17(a0)
        bsr M4IntroShipVectors
        move.w 6(a0),d0
        add.w d0,(a0)
        move.w 8(a0),d0
        add.w d0,2(a0)
        move.w 10(a0),d0
        add.w d0,4(a0)
        add.w d7,4(a0)
        bra M4IntroShipReturn
M4IntroShipRemove:
        clr.w 22(a0)
        move.w #5,24(a0)
        bra M4IntroShipReturn
M4IntroShipUnsupported:
        moveq #-1,d0
        rts

; Original 1F:D8BD/D8F7/D938: signed BYTE angular difference; minimum
; magnitude 2^shift before repeated signed halves toward zero.
; d0=current,d1=target,d2=shift3/4/5 => d0=byte result. Clobbers d1/d3.
M4IntroShipChase:
        sub.b d0,d1
        beq.s M4IntroShipChaseReturn
        ext.w d1
        move.w d1,d3
        bpl.s M4IntroShipChaseMagnitude
        neg.w d1
M4IntroShipChaseMagnitude:
        lsr.w d2,d1
        bne.s M4IntroShipChaseStep
        moveq #1,d1
M4IntroShipChaseStep:
        tst.w d3
        bpl.s M4IntroShipChaseAdd
        neg.w d1
M4IntroShipChaseAdd:
        add.b d1,d0
M4IntroShipChaseReturn:
        andi.w #$ff,d0
        rts

; Original 1F:C41E uses signed ROM 00:98A5 sine /98E5 cosine and the
; SNES multiplier: truncate(a*b/128) toward zero AT EACH multiplication.
; These angles/speed120 never hit the multiplier's doubling overflow.
M4IntroShipVectors:
        moveq #120,d0
; d0=speedBYTE, angles are yaw16/pitch17; original1F:C41E semantics.
M4IntroActorVectors:
        move.l d6,-(sp)
        move.w d0,d6
        lea M4IntroShipSine,a1
        moveq #0,d0
        move.b 17(a0),d0
        move.b 64(a1,d0.w),d4
        ext.w d4
        move.b (a1,d0.w),d5
        ext.w d5
        moveq #0,d2
        move.b 16(a0),d2
        neg.b d2
        move.b (a1,d2.w),d1
        ext.w d1
        move.w d6,d0
        bsr.s M4IntroShipMul
        move.w d4,d1
        bsr.s M4IntroShipMul
        move.w d0,6(a0)
        move.b 64(a1,d2.w),d1
        ext.w d1
        move.w d6,d0
        bsr.s M4IntroShipMul
        move.w d4,d1
        bsr.s M4IntroShipMul
        move.w d0,10(a0)
        move.w d6,d0
        move.w d5,d1
        bsr.s M4IntroShipMul
        move.w d0,8(a0)
        move.l (sp)+,d6
        rts
M4IntroShipMul:
        muls.w d1,d0
        tst.l d0
        bpl.s M4IntroShipMulShift
        addi.l #127,d0
M4IntroShipMulShift:
        asr.l #7,d0
        rts

M4IntroShipSine:
        incbin '../build/intro-ships-sine.bin'
        even
