; GSU screen texts drawn over the 3D view (mprintstr 01:B54B/B55A, mprtperc
; 01:B6C8, mprt2zeros 01:B75A, mshowpercgraph 01:B674, mshowteammate
; 01:B799, mcopyface 01:D15B) as SVP face records of the radio primitives
; (glyph kind 32, rectangle kind 33, face kind 31; generate-level-radio.py).
; Coordinates are GSU bitmap ones; the port bitmap adds 16 to x.
; M4_TX_HOOK: routine run after the radio box while the image is built
; (pause and results), 0 = none.

M4_TX_HOOK equ $fff820 ;.l
M4_TX_X equ $fff824 ;.w text cursor ($70:0062)

; mprintstr with clip 224 (01:B54B): one line, colour from the string's
; first byte, no shadow. a0 string, d2 x, d3 y; returns M4_TX_X after it.
M4TxString:
        movem.l d0-d7/a0-a2,-(sp)
        moveq #0,d5
        move.b (a0)+,d5 ;colour
        move.w d2,M4_TX_X
M4TxStrChar:
        moveq #0,d0
        move.b (a0)+,d0
        beq.s M4TxStrDone
        lea M4RadioTrn-32,a1
        move.b (a1,d0.w),d0 ;glyph
        lea M4RadioWidth,a1
        moveq #0,d7
        move.b (a1,d0.w),d7
        move.w M4_TX_X,d2
        bsr.s M4TxGlyph
        add.w d7,M4_TX_X
        bra.s M4TxStrChar
M4TxStrDone:
        movem.l (sp)+,d0-d7/a0-a2
        rts
; d0 glyph, d2 x, d3 y, d5 colour, d7 pixel count.
M4TxGlyph:
        movem.l d0-d2/a2,-(sp)
        mulu.w #12,d0
        addi.w #SVP_RadioGlyphs/2,d0
        move.w d0,-(sp)
        move.w #32,d1
        addi.w #16,d2
        jsr M4RadioRecord
        move.w (sp)+,12(a2)
        move.w d7,14(a2)
        move.w d5,16(a2)
        movem.l (sp)+,d0-d2/a2
        rts

; mprtperc 01:B6C8: d0 value, d2 x, d3 y. v >= 100: x - 8; v <= 9: x + 8;
; hundreds and tens only when not leading zeros; 8 pixels per digit, colour
; 14. M4_TX_X ends after the last digit.
M4TxNumber:
        movem.l d0-d7,-(sp)
        moveq #14,d5
        moveq #15,d7
        cmpi.w #100,d0
        blo.s M4TxNumSmall
        subq.w #8,d2
        bra.s M4TxNumDigits
M4TxNumSmall:
        cmpi.w #9,d0
        bhi.s M4TxNumDigits
        addq.w #8,d2
M4TxNumDigits:
        move.w d2,M4_TX_X
        moveq #0,d6 ;digit printed
        ext.l d0
        divu.w #100,d0
        tst.w d0
        beq.s M4TxNumTens
        bsr.s M4TxDigit
        st d6
M4TxNumTens:
        clr.w d0
        swap d0
        divu.w #10,d0
        tst.w d0
        bne.s M4TxNumTen
        tst.b d6
        beq.s M4TxNumOnes
M4TxNumTen:
        bsr.s M4TxDigit
M4TxNumOnes:
        swap d0
        bsr.s M4TxDigit
        movem.l (sp)+,d0-d7
        rts
M4TxDigit: ;d0.w digit (glyph = value) at M4_TX_X, advance 8, colour 14
        movem.l d0/d2/d5/d7,-(sp)
        moveq #14,d5
        moveq #15,d7
        andi.w #$ff,d0
        move.w M4_TX_X,d2
        bsr M4TxGlyph
        addq.w #8,M4_TX_X
        movem.l (sp)+,d0/d2/d5/d7
        rts

; Boxes (GSU 01:B06C outline, 01:B053 solid). d2 x, d3 y, d4 w, d5 h, d6
; colour.
M4TxBox:
        movem.l d0-d3/a2,-(sp)
        move.w #33,d1
        addi.w #16,d2
        jsr M4RadioRecord
        move.w d4,12(a2)
        move.w d5,14(a2)
        move.w d6,16(a2)
        movem.l (sp)+,d0-d3/a2
        rts
M4TxOutline: ;d2 x, d3 y, d4 w, d5 h, colour 14 (as the radio meter)
        movem.l d2-d6,-(sp)
        moveq #14,d6
        move.w d5,-(sp)
        moveq #1,d5
        bsr.s M4TxBox ;top
        add.w (sp),d3
        subq.w #1,d3
        bsr.s M4TxBox ;bottom
        sub.w (sp),d3
        addq.w #2,d3
        move.w (sp)+,d5
        subq.w #2,d5
        move.w d4,-(sp)
        moveq #1,d4
        bsr.s M4TxBox ;left
        add.w (sp)+,d2
        subq.w #1,d2
        bsr.s M4TxBox ;right
        movem.l (sp)+,d2-d6
        rts
; Bar: outline w x 12 and a fill of width d0 and colour d6 at (+2, +2), 8 high.
M4TxBar:
        movem.l d2-d5,-(sp)
        moveq #12,d5
        bsr.s M4TxOutline
        tst.w d0
        beq.s M4TxBarDone
        addq.w #2,d2
        addq.w #2,d3
        move.w d0,d4
        moveq #8,d5
        bsr.s M4TxBox
M4TxBarDone:
        movem.l (sp)+,d2-d5
        rts
; mcopyface 01:D15B: d0 face index of the radio face table, d2 x, d3 y.
M4TxFace:
        movem.l d0-d3/a2,-(sp)
        andi.l #$ff,d0
        mulu.w #320,d0
        addi.l #M4RadioFaces/2,d0 ;ROM WORD address (20 bits)
        move.w #31,d1
        addi.w #16,d2
        jsr M4RadioRecord
        move.w d0,12(a2)
        swap d0
        ori.w #$0800,d0
        move.w d0,14(a2)
        movem.l (sp)+,d0-d3/a2
        rts

; Draw hook of the scene (after the radio box).
M4TxDraw:
        move.l M4_TX_HOOK,d0
        beq.s M4TxDrawNone
        movem.l d0-d7/a0-a2,-(sp)
        movea.l d0,a0
        jsr (a0)
        movem.l (sp)+,d0-d7/a0-a2
M4TxDrawNone:
        rts

; printpause 02:F009: "PAUSED" at (90, 90).
M4TxPaused:
        lea M4GsuStrPaused,a0
        moveq #90,d2
        moveq #90,d3
        bra M4TxString

; printspeclp 02:EC42 texts of end_level_seq (one image per tick).
M4TxResults:
        lea M4GsuStrTotalScore,a0
        moveq #16,d2
        moveq #44,d3
        bsr M4TxString
        move.w M4_GM_TOTAL,d0
        move.w #176,d2
        moveq #39,d3
        bsr M4TxNumber
        moveq #0,d0 ;mprt2zeros 01:B75A
        bsr M4TxDigit
        bsr M4TxDigit
        cmpi.w #1,M4_GM_CLB1
        bne.s M4TxResScore
        lea M4GsuStrBonus,a0
        moveq #16,d2
        moveq #24,d3
        bsr M4TxString
        bra.s M4TxResTeam
M4TxResScore:
        lea M4GsuStrScore,a0
        moveq #16,d2
        moveq #24,d3
        bsr M4TxString
        move.w M4_GM_CLA1,d0 ;mshowpercgraph (60,24): outline 104, fill colour 7
        moveq #60,d2
        move.w #104,d4
        moveq #7,d6
        bsr M4TxBar
        move.w #176,d2
        bsr M4TxNumber
        move.w M4_TX_X,d2
        addq.w #4,d2
        lea M4GsuStrPercent,a0
        bsr M4TxString
M4TxResTeam:
        lea M4GsuStrShield,a0
        moveq #48,d2
        moveq #69,d3
        bsr M4TxString
        moveq #0,d7 ;Peppy $18A2, Falco $18A3, Slippy $18A4
M4TxResFriend:
        lea M4_PV_FRIENDHP+1,a1
        moveq #0,d0
        move.b (a1,d7.w),d0
        move.w d7,d2 ;mshowteammate (11 + 80i, 136): outline 44, fill colour 2
        mulu.w #80,d2
        addi.w #11,d2
        move.w #136,d3
        tst.w d0
        beq.s M4TxResDown
        moveq #44,d4
        moveq #2,d6
        bsr M4TxBar
        move.w d7,d1
        add.w d1,d1
        lea M4ResNamePos,a1
        move.w (a1,d1.w),d2
        move.w #150,d3
        add.w d1,d1
        lea M4ResNames,a1
        movea.l (a1,d1.w),a0
        bsr M4TxString
        lea M4TxAliveFaces,a1
        move.b (a1,d7.w),d0
        bra.s M4TxResFace
M4TxResDown:
        move.w d7,d1
        add.w d1,d1
        lea M4ResNamePos,a1
        move.w (a1,d1.w),d2
        move.w #137,d3
        add.w d1,d1
        lea M4ResNames,a1
        movea.l (a1,d1.w),a0
        bsr M4TxString
        move.w d7,d1
        add.w d1,d1
        lea M4ResDeadPos,a1
        move.w (a1,d1.w),d2
        move.w #151,d3
        lea M4GsuStrIsDown,a0
        bsr M4TxString
        moveq #M4ResDeadFrameEven,d0
        btst #0,M4_LV_GAMEFRAME+1
        beq.s M4TxResFace
        moveq #M4ResDeadFrameOdd,d0
M4TxResFace:
        move.w d7,d1
        add.w d1,d1
        lea M4ResFacePos,a1
        moveq #0,d2
        move.b (a1,d1.w),d2
        lsl.w #3,d2
        moveq #0,d3
        move.b 1(a1,d1.w),d3
        bsr M4TxFace
        addq.w #1,d7
        cmpi.w #3,d7
        bne M4TxResFriend
        rts
M4TxAliveFaces: ;mcopyface sources relative to 17:B9C0
        include '../build/level-result-faces.inc'
        even
        include '../build/level-texts.inc'

; ---------------------------------------------------------------------
; Pause. gameloop2 calls dopause 02:EF97 with Start in the last read and no
; singlestep, psf_noctrl, boss dying or pstf_notdie; dopause leaves at once
; with doingwipe or stayblack != $FF. Otherwise two more ticks (transfer_l,
; printpause, transfer_l: PAUSED drawn over the second image), then Start
; released, pressed and released (once per VBlank), the pad copies cleared.
; Run after each published level tick.
M4_TX_PAUSE equ $fff828 ;.b 0 off, 1 first pause tick done next, 2 PAUSED image
M4LevelPause:
        move.b M4_TX_PAUSE,d0
        bne.s M4PauseStep
        tst.b M4_GM_RESULTS
        bne.s M4PauseNone
        tst.b M4_END_ON ;end_game_seq / credits: no dopause (02:E3EC is gameloop2 only)
        bne.s M4PauseNone
        btst #J_START,M4_LP_JOY
        beq.s M4PauseNone
        btst #5,M4_LP_PSF ;psf_noctrl
        bne.s M4PauseNone
        tst.b M4_BOSS_DYING
        bne.s M4PauseNone
        btst #5,M4_BOSS_PSTRATF ;pstf_notdie
        bne.s M4PauseNone
        tst.b M4_SC_WIPE
        bne.s M4PauseNone
        cmpi.b #$ff,M4_SC_STAYBLACK
        bne.s M4PauseNone
        move.b #1,M4_TX_PAUSE ;next tick: first transfer_l
        M4PlaySfx $02
M4PauseNone:
        rts
M4PauseStep:
        cmpi.b #1,d0
        bne.s M4PauseWait
        move.b #2,M4_TX_PAUSE ;next tick: printpause + transfer_l
        move.l #M4TxPaused,M4_TX_HOOK
        rts
M4PauseWait:
        clr.l M4_TX_HOOK
        clr.b M4_TX_PAUSE
        movem.l d0-d1,-(sp)
        moveq #0,d1 ;wait: release, press, release
M4PauseVBlank:
        move.w M4_CLOCK,d0
M4PauseSame:
        cmp.w M4_CLOCK,d0
        beq.s M4PauseSame
        jsr M4LevelReadPad
        btst #J_START,M4_LP_JOY
        sne d0
        andi.b #1,d0
        cmpi.b #1,d1
        beq.s M4PauseWantPress
        tst.b d0 ;phases 0 and 2: wait for the release
        bne.s M4PauseVBlank
        addq.b #1,d1
        cmpi.b #3,d1
        bne.s M4PauseVBlank
        bra.s M4PauseResume
M4PauseWantPress:
        tst.b d0
        beq.s M4PauseVBlank
        addq.b #1,d1
        bra.s M4PauseVBlank
M4PauseResume:
        M4PlaySfx $01
        clr.l M4_LP_JOY ;cont0/contl0/cont0l/contl0l = 0 (JOY, LASTJOY)
        movem.l (sp)+,d0-d1
        rts
