; Original1F:DAB8: angleBYTE -> trotx, troty64, tmpz35 -> n3Dvecs.
; These are original game velocities, not geometry preparation for the renderer.
M4_FAST_ACTORS equ $ffbc00 ;particle,fragment1,fragment2,sprite; four32B contexts
M4_FAST_CREATED equ $ffbc80
M4_FAST_SPRITES equ $ffcc00 ;secondary sprites of fragment1/fragment2
M4IntroFastInit:
        lea M4_FAST_ACTORS,a0
        moveq #32,d0
M4FastClear:
        clr.l (a0)+
        dbra d0,M4FastClear
        lea M4_FAST_SPRITES,a0
        moveq #15,d0
M4FastClearSprites:
        clr.l (a0)+
        dbra d0,M4FastClearSprites
        rts

; Selected037157 factory for the original old_type/debris header00660C.
; Same four native allocations and RNG order; no captured poses are inputs.
M4IntroFastDebrisCreate:
        movem.l d1-d7/a0-a6,-(sp)
        tst.w M4_FAST_CREATED
        bne M4FastCreateBad
        movea.l a0,a6
        moveq #0,d5
M4FastCreateObject:
        move.w d5,d0
        lsl.w #5,d0
        lea M4_FAST_ACTORS,a1
        adda.w d0,a1
        move.l (a6),(a1)
        move.w 4(a6),4(a1)
        move.w #1,22(a1)
        move.w M4_SCENE_TICK,26(a1)
        move.b #10,21(a1)
        tst.w d5
        bne.s M4FastCreateNotParticle
        move.b #11,21(a1)
        move.b #7,18(a1)
        bra.s M4FastCreateAllocate
M4FastCreateNotParticle:
        cmpi.w #3,d5
        beq.s M4FastCreateSprite
        move.w 12(a6),12(a1)
        move.b 14(a6),14(a1)
        bra.s M4FastCreateAllocate
M4FastCreateSprite:
        move.l 6(a6),6(a1)
        move.w 10(a6),10(a1)
        move.w #$0080,12(a1)
        move.b #13,21(a1)
        move.b #8,28(a1)
M4FastCreateAllocate:
        bsr M4IntroNativeAllocate
        tst.w d0
        beq M4FastCreateBad
        move.w d0,24(a1)
        addq.w #1,d5
        cmpi.w #4,d5
        blo M4FastCreateObject
        bsr M4IntroRandom
        addi.b #16,d0
        move.w d0,d4
        lea M4_FAST_ACTORS+32,a0
        moveq #35,d1 ;source header size188 selects35
        bsr M4IntroDebrisVectors
        move.w d4,d0
        addi.b #85,d0
        lea M4_FAST_ACTORS+64,a0
        moveq #35,d1
        bsr M4IntroDebrisVectors
        bsr M4IntroRandom
        move.b d0,12(a6)
        bsr M4IntroRandom
        move.b d0,13(a6)
        move.b #12,21(a6) ;original BE20 explosion body
        clr.b 18(a6)
        clr.b 19(a6)
        move.b #12,28(a6)
        clr.w 24(a6)
        clr.w 26(a6)
        move.w #1,M4_FAST_CREATED
        moveq #0,d0
        bra.s M4FastCreateReturn
M4FastCreateBad:
        moveq #-1,d0
M4FastCreateReturn:
        movem.l (sp)+,d1-d7/a0-a6
        rts

M4IntroFastParentTick:
        tst.w 22(a0)
        beq.s M4FastParentDone
        addq.b #1,18(a0)
        andi.b #7,18(a0)
        addq.b #1,19(a0)
        bsr M4FastAddVelocity
        move.b 19(a0),d0
        cmp.b 28(a0),d0
        blo.s M4FastParentDone
        clr.w 22(a0)
        move.w #5,24(a0) ;scene owns the original parent native identity
        move.w M4_NATIVE_SHIPS+4,d0
        clr.w M4_NATIVE_SHIPS+4
        bsr M4IntroNativeRemove ;released before the next child's allocation
M4FastParentDone:
        moveq #0,d0
        rts

M4FastAddVelocity:
        move.w 6(a0),d0
        add.w d0,(a0)
        move.w 8(a0),d0
        add.w d0,2(a0)
        move.w 10(a0),d0
        add.w d0,4(a0)
        rts

; Original traversal after parent: sprite,fragment2,fragment1,particle.
M4IntroFastActorsTick:
        movem.l d1-d7/a0-a6,-(sp)
        tst.w M4_FAST_CREATED
        beq M4FastActorsDone
        moveq #3,d7
M4FastActor:
        move.w d7,d0
        lsl.w #5,d0
        lea M4_FAST_ACTORS,a0
        adda.w d0,a0
        tst.w 22(a0)
        beq M4FastActorNext
        tst.w d7
        beq.s M4FastParticleTick
        cmpi.w #3,d7
        beq.s M4FastSpriteTick
        cmpi.b #12,21(a0)
        beq M4FastSecondaryBodyTick
        move.w M4_SCENE_TICK,d0
        cmp.w 26(a0),d0
        bne.s M4FastPieceTick
        bsr M4IntroRandom
        andi.w #7,d0
        addi.w #10,d0
        move.b d0,19(a0)
        bsr M4FastAddVelocity ;initializer falls through, then strategy adds again
M4FastPieceTick:
        tst.b 19(a0)
        beq M4FastSecondaryBirth ;original exp strategy is next tick
        addq.b #8,12(a0)
        addq.b #4,14(a0)
        subq.b #1,19(a0)
        bsr M4FastAddVelocity
        bra.s M4FastActorNext
M4FastParticleTick:
        move.w M4_SCENE_TICK,d0
        cmp.w 26(a0),d0
        beq.s M4FastActorNext
        clr.b 18(a0) ;source subsequent particle_data0,0,0
        move.w 4(a0),d0
        sub.w INTRO_CAMERA+8,d0
        addi.w #144,d0 ;commercial nullshape sh_zmax144, default removebehind
        bpl.s M4FastActorNext
        move.w 24(a0),d0
        bsr M4IntroNativeRemove
        clr.w 22(a0)
        bra.s M4FastActorNext
M4FastSpriteTick:
        addq.b #1,18(a0)
        andi.b #7,18(a0)
        addq.b #1,19(a0)
        bsr M4FastAddVelocity
        move.b 19(a0),d0
        cmp.b 28(a0),d0
        blo.s M4FastActorNext
        move.w 24(a0),d0
        bsr M4IntroNativeRemove
        clr.w 22(a0)
M4FastActorNext:
        dbra d7,M4FastActor
        moveq #1,d7
M4FastSecondarySpriteNext:
        move.w d7,d0
        lsl.w #5,d0
        lea M4_FAST_SPRITES,a0
        adda.w d0,a0
        tst.w 22(a0)
        beq.s M4FastSecondarySpriteSkipped
        move.w M4_SCENE_TICK,d0
        cmp.w 26(a0),d0
        beq.s M4FastSecondarySpriteSkipped ;birth was ticked during its parent
        bsr M4FastStandaloneExplosionTick
M4FastSecondarySpriteSkipped:
        dbra d7,M4FastSecondarySpriteNext
M4FastActorsDone:
        moveq #0,d0
        bra.s M4FastActorsReturn
M4FastSecondaryBodyTick:
        bsr M4FastStandaloneExplosionTick
        bra M4FastActorNext
M4FastSecondaryBirth:
        bsr M4IntroFastSecondaryCreate
        tst.w d0
        bne.s M4FastActorsReturn
        bra M4FastActorNext
M4FastActorsReturn:
        movem.l (sp)+,d1-d7/a0-a6
        rts

; 0373F5 -> explode_Icont. Both commercial E60C/E5F0 headers have size188.
; Source copies vectors/position to one B139 sprite and chooses BE20/12 ticks.
M4IntroFastSecondaryCreate:
        movem.l d1-d7/a0-a6,-(sp)
        movea.l a0,a6
        move.w d7,d0
        subq.w #1,d0
        lsl.w #5,d0
        lea M4_FAST_SPRITES,a1
        adda.w d0,a1
        tst.w 22(a1)
        bne.s M4FastSecondaryBad
        move.l (a6),(a1)
        move.w 4(a6),4(a1)
        move.l 6(a6),6(a1)
        move.w 10(a6),10(a1)
        move.w #$0080,12(a1)
        clr.b 14(a1)
        clr.b 18(a1)
        clr.b 19(a1)
        move.b #13,21(a1)
        move.w #1,22(a1)
        move.w M4_SCENE_TICK,26(a1)
        move.b #8,28(a1)
        bsr M4IntroNativeAllocate
        tst.w d0
        beq.s M4FastSecondaryBad
        move.w d0,24(a1)
        bsr M4IntroRandom
        move.b d0,12(a6)
        bsr M4IntroRandom
        move.b d0,13(a6)
        move.b #12,21(a6)
        clr.b 18(a6)
        clr.b 19(a6)
        move.b #12,28(a6)
        movea.l a1,a0
        bsr M4FastStandaloneExplosionTick
        moveq #0,d0
        bra.s M4FastSecondaryReturn
M4FastSecondaryBad:
        moveq #-1,d0
M4FastSecondaryReturn:
        movem.l (sp)+,d1-d7/a0-a6
        rts

M4FastStandaloneExplosionTick:
        addq.b #1,18(a0)
        andi.b #7,18(a0)
        addq.b #1,19(a0)
        bsr M4FastAddVelocity
        move.b 19(a0),d0
        cmp.b 28(a0),d0
        blo.s M4FastStandaloneDone
        move.w 24(a0),d0
        bsr M4IntroNativeRemove
        clr.w 22(a0)
M4FastStandaloneDone:
        rts

M4IntroFastActorsSort:
        movem.l d7/a0,-(sp)
        tst.w M4_FAST_CREATED
        beq.s M4FastSortDone
        moveq #3,d7
M4FastSortActor:
        move.w d7,d0
        lsl.w #5,d0
        lea M4_FAST_ACTORS,a0
        adda.w d0,a0
        tst.w 22(a0)
        beq.s M4FastSortNext
        bsr M4IntroSceneSortObject
        cmpi.w #1,d7
        blo.s M4FastSortNext
        cmpi.w #2,d7
        bhi.s M4FastSortNext
        move.w d7,d0
        subq.w #1,d0
        lsl.w #5,d0
        lea M4_FAST_SPRITES,a0
        adda.w d0,a0
        tst.w 22(a0)
        beq.s M4FastSortNext
        bsr M4IntroSceneSortObject
M4FastSortNext:
        dbra d7,M4FastSortActor
M4FastSortDone:
        movem.l (sp)+,d7/a0
        rts

; a0=context,d0=angleBYTE,d1=speedBYTE (required factory uses35).
M4IntroDebrisVectors:
        movem.l d1-d7/a1,-(sp)
        move.w d0,d4
        andi.w #255,d4
        move.w d1,d5
        andi.w #255,d5
        move.w d5,d0
        move.w #-127,d1 ; original sin(-64)
        bsr M4IntroShipMul
        lea M4IntroShipSine,a1
        move.b 64(a1,d4.w),d1
        ext.w d1
        bsr M4IntroShipMul
        move.w d0,6(a0)
        move.b (a1,d4.w),d1
        ext.w d1
        move.w d5,d0
        bsr M4IntroShipMul
        move.w d0,8(a0)
        clr.w 10(a0)
        movem.l (sp)+,d1-d7/a1
        rts

; FF45C0:M4DV,status,passed. Isolated native68000 original-vector cases.
M4IntroDebrisVectorTest:
        movem.l d1-d7/a0-a6,-(sp)
        move.l #'M4DV',$ff45c0
        clr.l $ff45c4
        lea M4DebrisVectorCases,a4
        move.w #M4_DEBRIS_VECTOR_CASES-1,d7
M4DebrisVectorCase:
        lea $ffbd00,a0
        move.w (a4)+,d0
        move.w (a4)+,d1
        move.l #$deaddead,6(a0)
        move.w #$dead,10(a0)
        bsr M4IntroDebrisVectors
        lea 6(a0),a1
        moveq #2,d6
M4DebrisVectorCompare:
        move.w (a4)+,d0
        cmp.w (a1)+,d0
        bne.s M4DebrisVectorBad
        dbra d6,M4DebrisVectorCompare
        addq.w #1,$ff45c6
        dbra d7,M4DebrisVectorCase
        move.w #1,$ff45c4
        moveq #0,d0
        bra.s M4DebrisVectorReturn
M4DebrisVectorBad:
        move.w #-1,$ff45c4
        moveq #-1,d0
M4DebrisVectorReturn:
        movem.l (sp)+,d1-d7/a0-a6
        rts
