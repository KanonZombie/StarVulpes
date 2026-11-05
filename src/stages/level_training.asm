; Training objects (build/research/training.md section 3).

; groundpilon_Istrat 0A:F7A6 (shape pilon 00:DD30): strategy 0A:F7C3,
; set_normcollptrs (hitflash / explode_Istrat), HP 16, AP 1, sbyte1 = HP,
; then the strategy in the same call.
M4StratPilon:
        move.l #M4StratPilonTick,32(a0)
        move.l #M4LcHitFlash,X_COLL(a0)
        move.l #M4LevelExplode,X_EXP(a0)
        move.b #16,38(a0)
        move.b #1,39(a0)
        move.b #16,36(a0)
; 0A:F7C3: a hit (HP != sbyte1) throws it up: vx = (random & 15) - 7 (second
; random_l discarded), vy = -60, vz = +80; addvecs; ground at y >= -35
; (bit N), else in the air (sflags $08 = F2_SHADOW) and, while falling,
; it rests 70 above another pilon within distXZ 70 and |dy| 70 (find_obj
; 1F:C7D5 over allst, skipping itself); in the air vy += 5 and, moving in
; z, rotx += 10 / roty += 5. Landing: rotx 0, zero_vecs, sound $86 (not
; modelled) when it was in the air.
M4StratPilonTick:
        move.b 38(a0),d0
        cmp.b 36(a0),d0
        beq.s M4PilonMove
        move.b d0,36(a0) ;trigse $14 (sound, not modelled)
        jsr M4IntroRandom
        andi.w #15,d0
        subq.w #7,d0
        move.w d0,6(a0)
        jsr M4IntroRandom
        move.w #-60,8(a0)
        move.w #80,10(a0)
M4PilonMove:
        jsr M4EnMove ;addvecs 1F:C7BB
        move.w 2(a0),d0
        addi.w #35,d0
        bpl.s M4PilonGround
        bclr #F2_SHADOW,48(a0)
        tst.w 8(a0)
        bmi.s M4PilonAir
        move.w M4_LV_HEAD,d1
M4PilonFind:
        tst.w d1
        beq.s M4PilonAir
        movea.w d1,a2
        move.w X_NEXT(a2),d1
        cmpa.l a0,a2
        beq.s M4PilonFind
        cmpi.w #M4_SH_PILON,46(a2)
        bne.s M4PilonFind
        jsr M4EnDistXZ
        subi.w #70,d0
        bpl.s M4PilonFind
        move.w 2(a2),d2
        sub.w 2(a0),d2
        move.w d2,d0
        bpl.s M4PilonAbsDy
        neg.w d0
M4PilonAbsDy:
        subi.w #70,d0
        bpl.s M4PilonFind
        tst.w d2
        bmi.s M4PilonFind
        move.w 2(a2),d0
        subi.w #70,d0
        move.w d0,2(a0)
        bra.s M4PilonFound
M4PilonAir:
        bset #F2_SHADOW,48(a0)
        addq.w #5,8(a0)
        tst.w 10(a0)
        beq.s M4PilonDone
        addi.b #10,12(a0)
        addq.b #5,13(a0)
        bra.s M4PilonDone
M4PilonGround:
        clr.w 2(a0)
M4PilonFound:
        clr.b 12(a0)
        clr.l 6(a0) ;zero_vecs 1F:DB45: v and vel
        clr.w 10(a0)
        clr.b 15(a0)
        bclr #F2_SHADOW,48(a0) ;landing: trigse $86 (not modelled)
M4PilonDone:
        moveq #0,d0
        rts
