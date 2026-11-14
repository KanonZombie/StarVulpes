; Corneria video: setbg 27 (bg_1_1c 03:910B) converted by
; tools/extract-corneria-background.py; gamepal 1 on line2 until bg_1_1c
; selects blue. Pipeline idle, IRQ4 masked during uploads.
M4_LEVEL_BG_TILES equ $9a40 ;110 tiles, ids $4D2..$53F
M4_LEVEL_HUD_TILES equ $f420 ;HUD tile bank, sized by the extracted parameters
M4_LEVEL_HUD equ $ffd848 ;1: level HUD sprites chained after the footer mask
        include '../build/level-hud.inc'
M4LevelVideoInit:
        move.w #M4_LEVEL_BG_TILES,d0
        lea M4LevelBgTiles,a0
        jsr M4BgUpload
        move.w #$e000,d0
        lea M4LevelBgPlaneB,a0
        jsr M4BgUpload
        move.w #$8731,VDP_CTRL ;backdrop: palette3 colour1, reserved black
        lea M4LevelBgCram,a0
        lea M4_BASE_CRAM,a1
        moveq #63,d1
M4LvVideoCram:
        move.w (a0)+,(a1)+
        dbra d1,M4LvVideoCram
        lea M4LevelGamepals+32,a0 ;gamepal 1 until bg_1_1c sets blue
        lea M4_BASE_CRAM+64,a1
        moveq #15,d1
M4LvVideoScene:
        move.w (a0)+,(a1)+
        dbra d1,M4LvVideoScene
        clr.w M4_BASE_CRAM+98 ;line3 colour1 black (margin tiles)
        move.w #$eee,M4_BASE_CRAM+100 ;line3 colour2 FPS HUD
        clr.w M4_TITLE_SPRITE
        move.w #LV_HUD_RED,M4_BASE_CRAM+96+4*2
        move.w #LV_HUD_BOOST,M4_BASE_CRAM+96+7*2
        move.w #LV_HUD_OUTLINE,M4_BASE_CRAM+96+13*2
        move.w #LV_HUD_BOSSEDGE,M4_BASE_CRAM+96+14*2
        move.w #LV_HUD_BOSSFILL,M4_BASE_CRAM+96+5*2
        move.w #M4_LEVEL_HUD_TILES,d0
        lea M4LevelHudTiles,a0
        jsr M4BgUpload
        move.w #M4_LEVEL_MSG_TILES,d0 ;OBJ texts SCRAMBLE / STAGE
        lea M4LvMsgTiles,a0
        jsr M4BgUpload
        lea M4LvMsgColours,a0
M4LvVideoMsgColour:
        move.w (a0)+,d0 ;CRAM byte offset
        bmi.s M4LvVideoMsgDone
        lea M4_BASE_CRAM,a1
        move.w (a0)+,(a1,d0.w)
        bra.s M4LvVideoMsgColour
M4LvVideoMsgDone:
        clr.l M4_LV_SATREADY
        move.w sr,-(sp) ;until the first upload: sprite 13 off screen, end of list
        ori.w #$0700,sr
        move.w #$d800+13*8,d0
        jsr M4TextVideoWriteAddress
        move.l #0,VDP_DATA
        move.l #0,VDP_DATA
        move.w (sp)+,sr
        move.w #1,M4_LEVEL_HUD
        ; BG2 tilt (bg-tilt.md section 6): VSCROLL per 2-cell column, HSCROLL
        ; per line; plane A keeps HSCROLL 0 on every line. M4_NO_TILT: A/B
        ; measurement build without it.
        if ~def(M4_NO_TILT)
        move.w sr,-(sp)
        ori.w #$0700,sr
        move.w #$8f02,VDP_CTRL
        move.l #$50000003,VDP_CTRL ;VRAM D000/D400: page tables, 256 lines x (A, B)
        move.w #511,d1
M4LvVideoHScroll:
        move.l #0,VDP_DATA
        dbra d1,M4LvVideoHScroll
        move.w #$8b07,VDP_CTRL
        move.w (sp)+,sr
        move.w #1,M4_LEVEL_TILT
        endif
        move.w #248,M4_BOSS_SCROLL ;see M4LevelBgScroll
        move.w #248,M4_BOSS_SCROLL_PRESENT
        rts

        even
M4LevelBgCram:
        incbin '../build/corneria-bg-cram.md.bin'
M4LevelScenePalette:
        incbin '../build/level-scene-palette.md.bin'
M4Map0DBytes: ;0D:8000..FFFF (map scripts of every stage and screen)
        incbin '../build/map0d.bin'
M4Map05Bytes: ;05:8000..FFFF (map subroutines reached with mapjsr/mapgoto)
        incbin '../build/map05.bin'
        include '../build/map0d.inc'
        include '../build/level-sprites.inc'
        include '../build/level-tilt.inc'

; do_sprites_l 03:DB5A: the HUD block (bars, boss bar) only with stayblack
; $FF and m_meters set; then the OBJ texts (level_scramble.asm). Bars:
; do_shield 03:DC20 / calcmeters 02:DD04 (drawn by the GSU in the original,
; MD sprites here): outline + fill width min(value,36), shield fill red,
; boost colour 7, palette line 3. Entries are built in RAM from sprite 13
; (after the footer mask), the last one ends the list (link 0).
M4_LV_SATBUF equ $ff5400 ;two buffers of up to 51 entries (intro background
M4_LV_SATBUF2 equ $ff5a00 ;decode area); the IRQ4 second run DMAs the
M4_LV_SATREADY equ $fff2f0 ;.l published buffer (0 = none) to SAT sprite 13
M4_LV_SATWORDS equ $fff2f4 ;.w its WORD count
M4_LV_SATBASE equ $fff2f6 ;.l buffer being built
M4LevelHudSprites:
        movem.l d0-d7/a0-a1,-(sp)
        lea M4_LV_SATBUF,a1 ;build in the buffer that is not published
        cmpa.l M4_LV_SATREADY,a1
        bne.s M4LvHudBase
        lea M4_LV_SATBUF2,a1
M4LvHudBase:
        move.l a1,M4_LV_SATBASE
        moveq #13,d7 ;sprite number of the next entry
        tst.b M4_SC_MMETERS
        beq.s M4LvHudTexts
        cmpi.b #$ff,M4_SC_STAYBLACK
        bne.s M4LvHudTexts
        bsr M4LvHudObj
        moveq #0,d4
        move.b M4_LP_BODYHP,d4
        bpl.s M4LvHudShield
        moveq #0,d4 ;m_damage = (pBody.HP & $80) ? 0 : HP
M4LvHudShield:
        move.w #24+128,d5 ;screen x of the shield bar
        moveq #0,d6 ;tile base shield
        bsr M4LvHudBar
        moveq #0,d4
        move.b M4_LP_BOOSTMETER,d4
        move.w #192+128,d5
        moveq #LV_HUD_BOOST_BASE,d6
        bsr M4LvHudBar
        jsr M4SpCrosshairObj ;do_crosshair 03:E0B5 (the boss bar: M4BossBarDraw, SVP)
M4LvHudTexts:
        jsr M4ScTextSprites
        cmpi.b #1,M4_SCREEN
        bne.s M4LvHudNoCtl
        jsr M4CtlSprites ;controls screen box (controls.asm)
M4LvHudNoCtl:
        cmpi.b #3,M4_SCREEN
        bne.s M4LvHudNoMap
        jsr M4RmSprites ;route map OBJ (routemap.asm)
M4LvHudNoMap:
        cmpi.b #4,M4_SCREEN
        bne.s M4LvHudNoCont
        jsr M4CnSprites ;continue screen OBJ (continue.asm)
M4LvHudNoCont:
        cmpa.l M4_LV_SATBASE,a1
        bne.s M4LvHudEnd
        clr.l (a1)+ ;nothing drawn: one sprite above the screen, link 0
        clr.l (a1)+
        bra.s M4LvHudCopy
M4LvHudEnd:
        clr.b -5(a1) ;last entry ends the list
M4LvHudCopy: ;publish: no VDP access here (the IRQ4 second run uploads it)
        move.l a1,d1
        sub.l M4_LV_SATBASE,d1
        lsr.w #1,d1
        move.w sr,-(sp)
        ori.w #$0700,sr ;pointer and size change together
        move.w d1,M4_LV_SATWORDS
        move.l M4_LV_SATBASE,M4_LV_SATREADY
        move.w (sp)+,sr
        movem.l (sp)+,d0-d7/a0-a1
        rts
; HUD OBJ of do_sprites_l (sprites.md section 8.2): lives 03:DBDD (icon,
; "x", digit max(lives,1)-1), SHIELD 03:DC20, ENEMY 03:E148 (only with a boss
; bar; x = 200 - w + 8k, w = max halved from 128), nova bombs 03:E04E
; (225 - 9i): while specflash $1FCA runs (30 after a pickup) the last bomb
; is drawn only when specflash (decremented) != 0 and gameframe & 7 >= 3.
M4LvHudObj:
        move.w #M4_LVHUD_Y_LIVES,d0
        moveq #0,d1
        move.w #M4_LVHUD_ICON,d2
        move.w #16+128,d3
        bsr.w M4LvHudSpr
        move.w #M4_LVHUD_TIMES,d2
        move.w #24+128,d3
        bsr.w M4LvHudSpr
        moveq #0,d2
        move.b M4_LP_LIVES,d2
        bne.s M4LvHudLives
        moveq #1,d2
M4LvHudLives:
        subq.w #1,d2
        addi.w #M4_LVHUD_DIGITS,d2
        move.w #32+128,d3
        bsr.s M4LvHudSpr
        move.w #M4_LVHUD_Y_SHIELD,d0
        move.w #$0c00,d1 ;4 cells wide
        move.w #M4_LVHUD_SHIELD,d2
        move.w #24+128,d3
        bsr.s M4LvHudSpr
        moveq #0,d3
        move.b M4_BOSS_MAXHP,d3
        beq.s M4LvHudBombs
        cmpi.w #128,d3
        blo.s M4LvHudEnemyW
        lsr.w #1,d3
M4LvHudEnemyW:
        neg.w d3
        addi.w #200+128,d3
        move.w #M4_LVHUD_Y_ENEMY,d0
        move.w #M4_LVHUD_ENEMY,d2
        bsr.s M4LvHudSpr
M4LvHudBombs:
        move.w M4_LP_SPECWEP,d4
        beq.s M4LvHudObjDone
        tst.b M4_LP_SPECFLASH
        beq.s M4LvHudBombN
        subq.b #1,M4_LP_SPECFLASH
        beq.s M4LvHudBombHide
        moveq #7,d0
        and.w M4_LV_GAMEFRAME,d0
        cmpi.w #3,d0
        bhs.s M4LvHudBombN
M4LvHudBombHide:
        subq.w #1,d4
        beq.s M4LvHudObjDone
M4LvHudBombN:
        move.w #225+128,d3
        moveq #0,d1
        move.w #M4_LVHUD_BOMB,d2
        move.w #M4_LVHUD_Y_BOMB,d0
M4LvHudBomb:
        bsr.s M4LvHudSpr
        subi.w #9,d3
        subq.w #1,d4
        bne.s M4LvHudBomb
M4LvHudObjDone:
        rts
; d0 y, d1 size (cells) << 8, d2 tile word, d3 x: entry linked to the next.
M4LvHudSpr:
        move.w d0,(a1)+
        move.w d7,d5
        addq.w #1,d5
        or.w d1,d5
        move.w d5,(a1)+
        move.w d2,(a1)+
        move.w d3,(a1)+
        addq.w #1,d7
        rts
; d4 value, d5 x, d6 tile base, d7 sprite number, a1 entries.
M4LvHudBar:
        cmpi.w #LV_HUD_LIMIT,d4
        bls.s M4LvHudClamp
        moveq #LV_HUD_LIMIT,d4
M4LvHudClamp:
        moveq #0,d3 ;k
M4LvHudCell:
        move.w #191+128,(a1)+
        move.w d7,d0
        addq.w #1,d0
        move.w d0,(a1)+ ;size 1x1 + link to the next entry
        ; fill pixels in this cell
        move.w d4,d0
        addq.w #LV_HUD_SHIELD_INSET,d0
        move.w d3,d1
        lsl.w #3,d1
        sub.w d1,d0 ;filled pixels relative to this tile
        tst.w d3
        bne.s M4LvHudNotFirst
        move.w d4,d0
        cmpi.w #LV_HUD_SHIELD_FIRST,d0
        bls.s M4LvHudId
        moveq #LV_HUD_SHIELD_FIRST,d0
        bra.s M4LvHudId
M4LvHudNotFirst:
        cmpi.w #LV_HUD_CELLS-1,d3
        bne.s M4LvHudMid
        tst.w d0
        bpl.s M4LvHudLastPos
        moveq #0,d0
M4LvHudLastPos:
        cmpi.w #LV_HUD_SHIELD_LAST,d0
        bls.s M4LvHudLastId
        moveq #LV_HUD_SHIELD_LAST,d0
M4LvHudLastId:
        addi.w #LV_HUD_SHIELD_LAST_INDEX,d0
        bra.s M4LvHudId
M4LvHudMid:
        tst.w d0
        bpl.s M4LvHudMidPos
        moveq #0,d0
M4LvHudMidPos:
        cmpi.w #8,d0
        bls.s M4LvHudMidId
        moveq #8,d0
M4LvHudMidId:
        addq.w #LV_HUD_SHIELD_MID_INDEX,d0
M4LvHudId:
        add.w d6,d0
        addi.w #$e000|(M4_LEVEL_HUD_TILES/32),d0
        move.w d0,(a1)+
        move.w d3,d0
        lsl.w #3,d0
        add.w d5,d0
        move.w d0,(a1)+
        addq.w #1,d7
        addq.w #1,d3
        cmpi.w #LV_HUD_CELLS,d3
        bne M4LvHudCell
        rts
; Boss bar (mdrawbossHP 01:AFEB): 10 sprites at window (146, 2) = MD
; (162, 17), outline 76 wide (max 72 + 4), fill = m_bossHP from column 2.
; Drawn only for the route-1 maximum 72 (the tiles assume that width).
M4LvHudBoss:
        moveq #0,d4
        move.b M4_BOSS_HUDHP,d4
        moveq #0,d3
M4LvHudBossCell:
        move.w #17+128,(a1)+
        move.w d7,d0
        addq.w #1,d0
        move.w d0,(a1)+
        move.w d4,d0
        addq.w #LV_HUD_BOSS_INSET,d0
        move.w d3,d1
        lsl.w #3,d1
        sub.w d1,d0 ;filled pixels relative to this tile
        bpl.s M4LvHudBossPos
        moveq #0,d0
M4LvHudBossPos:
        tst.w d3
        bne.s M4LvHudBossNotFirst
        move.w d4,d0
        cmpi.w #LV_HUD_BOSS_FIRST,d0
        bls.s M4LvHudBossId
        moveq #LV_HUD_BOSS_FIRST,d0
        bra.s M4LvHudBossId
M4LvHudBossNotFirst:
        cmpi.w #9,d3
        bne.s M4LvHudBossMid
        cmpi.w #LV_HUD_BOSS_LAST,d0
        bls.s M4LvHudBossLast
        moveq #LV_HUD_BOSS_LAST,d0
M4LvHudBossLast:
        addi.w #LV_HUD_BOSS_LAST_INDEX,d0
        bra.s M4LvHudBossId
M4LvHudBossMid:
        cmpi.w #8,d0
        bls.s M4LvHudBossMidId
        moveq #8,d0
M4LvHudBossMidId:
        addq.w #LV_HUD_BOSS_MID_INDEX,d0
M4LvHudBossId:
        addi.w #LV_HUD_BOSS_BASE+($e000|(M4_LEVEL_HUD_TILES/32)),d0
        move.w d0,(a1)+
        move.w d3,d0
        lsl.w #3,d0
        addi.w #162+128,d0
        move.w d0,(a1)+
        addq.w #1,d7
        addq.w #1,d3
        cmpi.w #10,d3
        bne M4LvHudBossCell
        rts
