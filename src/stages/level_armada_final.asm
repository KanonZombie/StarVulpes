; Space Armada unit (final): objects of the stage ending cl_ship1_3 05:DA3F
; (also the Sector Z ending 0D:E6D8). ROM USA rev0. Specification
; build/agent-armada/research/final/SPEC.md (dis-final.txt); oracle and notes
; build/agent-armada-boss/ (armada-final-oracle.py, INTEGRATION.md).
; Owner files: this file and level_armada_final_strats.asm (RAM: M4_AB,
; level_armada_boss.asm). Units: ship0cdown 06:E831/E84C, clshipSHIPa/b/c
; 06:C2BE/C30E/C35E (+ C2E5/C335/C381, common 06:C3AA..C4CD), clasteroid
; 0A:F8FA/F921. Reused: BIGparticleexplode 06:F89C (M4B1BigParticles), the
; boost flame 06:8671 (M4LevelBoostFlame), mother 04:F5B3 (M4StratMother).
; The player modes (ClearShip2 0B:9ACC/9AE1/9BFA) belong to
; level_armada_player.asm; contract: ClearShip2 sets bit 7 of X_AB_SF2 on the
; player (= +$1E |= $80 at 0B:9CB7) and keeps $C5 in M4_SC_VIEWPOS+4.
; Not ported: circleobj/circleanim 207 (laststage_circle, screen circle of
; 02:DD45) and sounds; deliberate (INTEGRATION.md section 4).

; viewposz $C5 as the strategies read it (fixed camera of ClearShip2:
; M4_SC_VIEWPOS; else the last getview position).
M4AfViewZ:
        move.w M4_LVW_POS+4,d0
        btst #1,M4_SC_VIEWTYPE
        beq.s M4AfViewZDone
        move.w M4_SC_VIEWPOS+4,d0
M4AfViewZDone:
        rts

; ship0cdown 06:E831: colldisable, sbyte1 60, count 115. 06:E84C: count - 1
; (0: removed, the tick goes on); rotx Achase8_5 toward $20; exploding
; (sflags2 $10): a huge explosion (06:EF0C); always a large one (06:EEDF),
; each + 06:EFA0, nopolyexp, z + 300; exploding: nothing more. Else sbyte1
; counts 60: then exploding (circle 207 and sound $1D not ported) and a
; nullshape BIGparticleexplode (06:F89C) at the ship; z + 55, y + 5.
M4AfShip0c:
        bset #SF_COLLDISABLE,49(a0)
        move.l #M4AfShip0cTick,32(a0)
        move.b #60,36(a0)
        move.b #115,19(a0)
M4AfShip0cTick:
        moveq #0,d7
        subq.b #1,19(a0)
        bne.s M4AfShip0cPitch
        moveq #1,d7
M4AfShip0cPitch:
        move.b 12(a0),d0
        moveq #$20,d1
        moveq #5,d2
        jsr M4EnChase8
        move.b d0,12(a0)
        btst #F2_SFLAG1,48(a0)
        beq.s M4AfShip0cLarge
        jsr M4FxHuge
        bsr M4AfBurst
M4AfShip0cLarge:
        jsr M4FxLarge
        bsr M4AfBurst
        btst #F2_SFLAG1,48(a0)
        bne.s M4AfShip0cDone
        subq.b #1,36(a0)
        bne.s M4AfShip0cMove
        bset #F2_SFLAG1,48(a0)
        move.w #$aca1,d0
        bsr M4AbCreate
        beq.s M4AfShip0cMove
        move.l #M4B1BigParticles,32(a2)
        move.l (a0),(a2)
        move.w 4(a0),4(a2)
M4AfShip0cMove:
        addi.w #55,4(a0)
        addq.w #5,2(a0)
M4AfShip0cDone:
        move.l d7,d0
        rts
; 06:EFA0 on the new explosion (or dummyobj), nopolyexp, z + 300.
M4AfBurst:
        cmpa.w #0,a2
        bsr M4AbRnd2xyz
        cmpa.w #0,a2
        beq.s M4AfBurstDone
        bset #F2_NOPOLYEXP,48(a2)
        addi.w #300,4(a2)
M4AfBurstDone:
        rts

; clshipSHIPa/b/c 06:C2BE/C30E/C35E: sflags2 |= $10, sbyte1 (departure delay)
; 10/20/30, sflags |= $08 (shadow), rotz $C0/$40/(kept), no zremove; the body
; runs on the creation tick.
M4AfShipA:
        move.b #10,36(a0)
        move.b #$c0,14(a0)
        move.l #M4AfShipABody,d1
        bra.s M4AfShipInit
M4AfShipB:
        move.b #20,36(a0)
        move.b #$40,14(a0)
        move.l #M4AfShipBBody,d1
        bra.s M4AfShipInit
M4AfShipC:
        move.b #30,36(a0)
        move.l #M4AfShipCBody,d1
M4AfShipInit:
        bset #F2_SFLAG1,48(a0)
        bset #F2_SHADOW,48(a0)
        move.l d1,32(a0)
        bclr #3,45(a0)
        movea.l d1,a2
        jmp (a2)
; Bodies 06:C2E5/C335/C381: x Achase16_4 toward -50/+50/0; dz ($151F)
; 100/200/300, dy ($1521) 20/40/50.
M4AfShipABody:
        moveq #-50,d1
        move.w #100,d5
        moveq #20,d6
        bra.s M4AfShipBody
M4AfShipBBody:
        moveq #50,d1
        move.w #200,d5
        moveq #40,d6
        bra.s M4AfShipBody
M4AfShipCBody:
        moveq #0,d1
        move.w #300,d5
        moveq #50,d6
; 06:C3AA: |z - viewposz| >= 4000 (abs16, N) -> removed (the tick goes on).
; Leaving (own sflags2 $10 and player sflags2 $80): sbyte1 counts, then
; every tick z + 100, y - 10, and once sflags2 |= $20 with the boost flame
; (boostobj = this ship; sound $32 not ported). Else formation: z/y
; Achase16_4 toward player z - dz / y + dy, rotz Achase8_4 toward the
; player's on even gameframes, rotx Achase8_5 every 4th. Then addplayerZ.
M4AfShipBody:
        move.w (a0),d0
        moveq #4,d2
        jsr M4LpAchase
        move.w d0,(a0)
        moveq #0,d7
        bsr M4AfViewZ
        move.w 4(a0),d1
        sub.w d0,d1
        bpl.s M4AfShipAbs
        neg.w d1
M4AfShipAbs:
        subi.w #4000,d1
        bmi.s M4AfShipNear
        moveq #1,d7
M4AfShipNear:
        btst #F2_SFLAG1,48(a0)
        beq.s M4AfShipForm
        btst #7,X_AB_SF2(a1)
        beq.s M4AfShipForm
        subq.b #1,36(a0)
        bne M4AfShipEnd
        move.b #1,36(a0)
        addi.w #100,4(a0)
        subi.w #10,2(a0)
        bset #F2_SFLAG2,48(a0)
        bne M4AfShipEnd
        jsr M4LevelBoostFlame
        bra M4AfShipEnd
M4AfShipForm:
        move.w 4(a1),d1
        sub.w d5,d1
        move.w 4(a0),d0
        moveq #4,d2
        jsr M4LpAchase
        move.w d0,4(a0)
        move.w 2(a1),d1
        add.w d6,d1
        move.w 2(a0),d0
        jsr M4LpAchase
        move.w d0,2(a0)
        btst #0,M4_LV_GAMEFRAME+1
        bne.s M4AfShipPitch
        move.b 14(a0),d0
        move.b 14(a1),d1
        moveq #4,d2
        jsr M4EnChase8
        move.b d0,14(a0)
M4AfShipPitch:
        move.w M4_LV_GAMEFRAME,d0
        andi.w #3,d0
        bne M4AfShipEnd
        move.b 12(a0),d0
        move.b 12(a1),d1
        moveq #5,d2
        jsr M4EnChase8
        move.b d0,12(a0)
M4AfShipEnd:
        jsr M4EnAddPZ
        move.l d7,d0
        rts

; clasteroid 0A:F8FA (children of the mother 05:D835, motherrnd): ssprite,
; $1CDF = $1CF4 = 0, colldisable, count 70. 0A:F921: count - 1 -> removed at
; 0 (no movement, no addplayerZ).
M4AfAsteroid:
        bset #F2_SPRITE,48(a0)
        clr.b X_TX(a0)
        bset #SF_COLLDISABLE,49(a0)
        move.l #M4AfAsteroidTick,32(a0)
        move.b #70,19(a0)
M4AfAsteroidTick:
        subq.b #1,19(a0)
        beq M4AbRemove
        moveq #0,d0
        rts
