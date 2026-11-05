; Selected ROM: RNG02:FC4E, global06:858E, medium06:EEEE,
; smoke06:8EA8/8F72/8FA7 and explosion06:EE38/F7AD.
; Bounded batch102..106; billboard texture/palette adaptation documented.
M4_RNG equ $ff9680 ; four BYTEs in original EF/F0/F1/F2 order
M4_EFFECTS equ $ffb400 ;22 contexts: polygon/sprite and original20 smoke births
M4_EFFECT_COUNT equ $ff9690
M4_EFFECT_MEDIUM equ $ff9692

; d0.byte=result; preserve other registers. Original CLC/SBC means the
; FIRST subtraction also borrows1. Propagate borrow, not CPU signed flags.
M4IntroRandom:
        movem.l d1-d3/a0,-(sp)
        lea M4_RNG,a0
        moveq #0,d0
        move.b (a0),d0
        moveq #1,d2
        moveq #1,d3
M4RandomByte:
        moveq #0,d1
        move.b (a0,d3.w),d1
        sub.w d1,d0
        sub.w d2,d0
        moveq #0,d2
        tst.w d0
        bpl.s M4RandomNoBorrow
        moveq #1,d2
M4RandomNoBorrow:
        andi.w #255,d0
        move.b d0,(a0,d3.w)
        addq.w #1,d3
        cmpi.w #4,d3
        blo.s M4RandomByte
        moveq #0,d1
        move.b (a0),d1
        sub.w d1,d0
        sub.w d2,d0
        andi.w #255,d0
        move.b d0,(a0)
        movem.l (sp)+,d1-d3/a0
        rts

M4IntroEffectsInit:
        lea M4_EFFECTS,a0
        move.w #175,d0
M4EffectsClear:
        clr.l (a0)+
        dbra d0,M4EffectsClear
        clr.l M4_EFFECT_COUNT
        move.l #$3aa7557f,M4_RNG ; actual selected-ROM boot physical01B819
        moveq #3,d7 ; entry gameframe4: four global init_strats calls
M4EffectsSeed:
        bsr M4IntroRandom
        dbra d7,M4EffectsSeed
        rts

; a0=third ship before movement; placeholder is allocated BEFORE smoke.
M4IntroEffectMedium:
        movem.l d0-d7/a0-a6,-(sp)
        lea M4_EFFECTS,a1
        move.l (a0),(a1)
        move.w 4(a0),4(a1)
        move.b #4,21(a1)
        move.w #1,22(a1)
        bsr M4IntroNativeAllocate
        move.w d0,24(a1)
        move.w M4_SCENE_TICK,26(a1)
        move.b #12,28(a1)
        move.w #1,M4_EFFECT_MEDIUM ; delay initializer still awaits traversal
        move.w #2,M4_EFFECT_COUNT ; reserve sprite own slot, not native block
        movem.l (sp)+,d0-d7/a0-a6
        rts

; a0=third ship previous pose. Native smoke allocation, three masked random
; offsets then initializer and the same tick's smoke strategy in EffectsStep.
M4IntroEffectSmoke:
        movem.l d0-d7/a0-a6,-(sp)
        move.w M4_EFFECT_COUNT,d0
        cmpi.w #22,d0
        bhs.s M4EffectSmokeBad
        lsl.w #5,d0
        lea M4_EFFECTS,a1
        adda.w d0,a1
        move.l (a0),(a1)
        move.w 4(a0),4(a1)
        move.w #40,6(a1)
        move.w #$0080,12(a1)
        move.b #6,21(a1)
        move.w #1,22(a1)
        bsr M4IntroNativeAllocate
        move.w d0,24(a1)
        move.w M4_SCENE_TICK,26(a1)
        move.b #20,29(a1)
        move.w #6,30(a1)
        moveq #0,d4
M4EffectSmokeOffset:
        bsr M4IntroRandom
        andi.w #127,d0
        subi.w #63,d0
        add.w d0,(a1,d4.w)
        addq.w #2,d4
        cmpi.w #6,d4
        bne.s M4EffectSmokeOffset
        addq.w #1,M4_EFFECT_COUNT
        bra.s M4EffectSmokeReturn
M4EffectSmokeBad:
        move.w #-1,M4_NATIVE_ERROR
M4EffectSmokeReturn:
        movem.l (sp)+,d0-d7/a0-a6
        rts

; Called at the third ship's original traversal position. Newly inserted
; smoke runs before older smoke, medium placeholder and its new sprite.
M4IntroEffectsStep:
        movem.l d0-d7/a0-a6,-(sp)
        move.w M4_EFFECT_COUNT,d7
        cmpi.w #2,d7
        bls.s M4EffectsPolygon
        subq.w #1,d7
M4EffectsSmokeNext:
        move.w d7,d0
        lsl.w #5,d0
        lea M4_EFFECTS,a0
        adda.w d0,a0
        bsr M4IntroSmokeTick
        subq.w #1,d7
        cmpi.w #2,d7
        bhs.s M4EffectsSmokeNext
M4EffectsPolygon:
        tst.w M4_EFFECT_MEDIUM
        beq.s M4EffectsEnd
        lea M4_EFFECTS,a0
        cmpi.w #1,M4_EFFECT_MEDIUM
        bne.s M4EffectsPolygonTick
        ; Selected-ROM explosion initializer: after smoke's three RNG calls.
        moveq #$21,d0
        jsr M4SoundIntroAt
        bsr M4IntroRandom
        move.b d0,12(a0)
        bsr M4IntroRandom
        move.b d0,13(a0)
        lea M4_EFFECTS+32,a1
        move.l (a0),(a1)
        move.w 4(a0),4(a1)
        move.w #$0080,12(a1)
        move.b #5,21(a1)
        move.w #1,22(a1)
        bsr M4IntroNativeAllocate
        move.w d0,24(a1)
        move.w M4_SCENE_TICK,26(a1)
        move.b #6,28(a1)
        move.w #2,M4_EFFECT_MEDIUM
        bra.s M4EffectsSprite
M4EffectsPolygonTick:
        bsr M4IntroExplosionTick
M4EffectsSprite:
        lea M4_EFFECTS+32,a0
        bsr M4IntroExplosionTick
M4EffectsEnd:
        movem.l (sp)+,d0-d7/a0-a6
        rts

; Original smoke0: colanim[0..7], remove at0; decrement20 timer, X-1,
; Y-growth, then add vectors. Smoke is absolute: no player-Z addition.
M4IntroSmokeTick:
        tst.w 22(a0)
        beq.s M4EffectTickReturn
        addq.b #1,18(a0)
        andi.b #7,18(a0)
        beq.s M4EffectRemove
        subq.w #1,(a0)
        move.w 30(a0),d0
        sub.w d0,2(a0)
        subq.b #1,29(a0)
        bne.s M4EffectVectors
        move.b #20,29(a0)
        subq.w #1,30(a0)
        beq.s M4EffectRemove
M4EffectVectors:
        move.w 6(a0),d0
        add.w d0,(a0)
        move.w 8(a0),d0
        add.w d0,2(a0)
        move.w 10(a0),d0
        add.w d0,4(a0)
M4EffectTickReturn:
        rts

; Original count/life is al_count BYTE at+10. Rel-explosion moves by pviewZ.
M4IntroExplosionTick:
        tst.w 22(a0)
        beq.s M4EffectTickReturn
        addq.b #1,18(a0)
        andi.b #7,18(a0)
        addq.b #1,19(a0)
        move.w INTRO_CAMERA+6,d0
        add.w d0,4(a0)
        bsr.s M4EffectVectors
        move.b 19(a0),d0
        cmp.b 28(a0),d0
        bhs.s M4EffectRemove
        rts
M4EffectRemove:
        move.w 24(a0),d0
        bsr M4IntroNativeRemove
        clr.w 22(a0)
        rts

; Assert actual68000 borrow propagation against selected-ROM byte execution.
M4IntroEffectsTest:
        movem.l d0-d7/a0-a6,-(sp)
        move.l #'M4EF',$ff4540
        clr.l $ff4544
        lea M4EffectRandomCases,a4
        move.w #M4_EFFECT_RNG_CASES-1,d7
M4EffectRandomTest:
        move.l (a4)+,M4_RNG
        bsr M4IntroRandom
        move.l M4_RNG,d0
        cmp.l (a4)+,d0
        bne.s M4EffectTestBad
        addq.w #1,$ff4546
        dbra d7,M4EffectRandomTest
        move.w #1,$ff4544
        bra.s M4EffectTestEnd
M4EffectTestBad:
        move.w #-1,$ff4544
M4EffectTestEnd:
        movem.l (sp)+,d0-d7/a0-a6
        rts
