; Game over gameover_l 02:E4C2 (build/research/screens-and-flow.md 8.2):
; gameoverinit_l 06:BBDA (initgame with the waiting map 0D:FA71, playercred,
; GAME B235 at x -270 and OVER B251 at x +270, y +120, z +3400, path istrat
; 04:8022 with path $474D, HP $FF, AP 0; palette rows 0..6 black and
; gameoverpal 02:F8B1 on row 7; m_meters 0), bg_gameover_1 03:A963 (Andross,
; bg2vofsreq 32), fadedir 1; 50 ticks with the BG colour window subtracting
; 31 (02:F0A5), then 02:F061 lowers it 1 per tick to 0 (BG2/BG3/backdrop only:
; the 3D words are seen from the start), then up to 1200 ticks or Start held
; ($1202 & $10); fadedir $FF until black; defaulttrain = contexit = 1;
; foxy_continue_l 03:E3C7: no credits -> restart 1F:BDEE (controls screen,
; GAME preselected); with credits the CONTINUE screen (continue.asm). Not
; modelled: music.
; Colour subtraction: the VDP has no colour math; the port subtracts from the
; plane B CRAM lines (MD component ~ SNES >> 2: (4*md + 2 - v) >> 2, floor 0)
; and keeps line 2 (the GSU colours) as is: a deliberate adaptation.

M4_GO equ $fff850
M4_GO_PHASE equ M4_GO+0 ;.b 0 black BG (50), 1 BG fades in, 2 wait, 3 fade out
M4_GO_SUB equ M4_GO+1 ;.b colour window subtraction (0..31)
M4_GO_COUNT equ M4_GO+2 ;.w ticks left in the phase
M4_GO_SHOWNSUB equ M4_GO+4 ;.b subtraction applied to M4_BASE_CRAM
M4_GO_CRAM equ $ff5d00 ;64 WORDs: BG lines before the subtraction

M4GameOverStart:
        jsr M4SoundStopLoops
        move.b #2,M4_SCREEN
        clr.l M4_GEO_VP
        jsr M4LevelInit ;initgame_l (M4GoVideoInit for M4_SCREEN 2)
        jsr M4PlayerStartInit ;06:BBEF gameoverinit_l
        move.b #8,M4_AR_GF2 ;initgame_strats 06:8004: gameflags2 = gf2_ingame
        move.l #$3aa7557f,M4_RNG ;02:E2C6 -> 03:B819 seed (the waiting map 0D:FA71 creates nothing)
        lea LV_PLAYER,a0
        move.l #M4PmCredI,32(a0) ;0B:B551 set_playercred_l
        andi.b #$fd,M4_LP_GAMEFLAGS
        clr.b M4_SC_MMETERS
        move.l a0,M4_LV_CREATOR ;06:BC09: created behind the player
        move.w #$fef2,d1 ;GAME at x -270
        move.w #M4_SH_GAMESH,d0
        bsr M4GoWord
        move.w #$010e,d1 ;OVER at x +270
        move.w #M4_SH_OVERSH,d0
        bsr M4GoWord
        clr.l M4_LV_CREATOR
        lea M4_FADE,a0
        move.b #1,(a0) ;fadedir 1
        clr.b 1(a0)
        move.l #$80808000,4(a0)
        lea TEXT_MAP_CONTEXT,a0
        move.w #$7a71,(a0)
        clr.w 4(a0)
        move.l #M4ScriptProgramMap0D,28(a0)
        clr.b M4_GO_PHASE
        move.b #31,M4_GO_SUB ;02:F0A5
        move.w #50,M4_GO_COUNT
        st M4_GO_SHOWNSUB
        move.w #6,INTRO_DIAG+4
M4GoLoop:
        if def(M4_LOGIC_OVERLAP)
        bclr #0,M4_OVL_STATE ;tick and M4GoPreDraw ran during the previous cmd10
        beq.s M4GoTick
        tst.w M4_LV_STATUS
        bpl.s M4GoTicked
        jmp M4IntroFailed
M4GoTick:
        endif
        jsr M4LevelTick
        tst.w M4_LV_STATUS
        bpl.s M4GoOk1
        jmp M4IntroFailed
M4GoOk1:
        bsr M4GoPreDraw
M4GoTicked:
        if def(M4_LOGIC_OVERLAP)
        move.b #3,M4_OVL_LOOP ;M4OvlWindow: M4GoTail, then tick + M4GoPreDraw of k+1
        endif
        jsr M4LevelDraw
        move.w d0,INTRO_DIAG+8
        tst.w d0
        beq.s M4GoOk2
        jmp M4IntroFailed
M4GoOk2:
        moveq #0,d1
        jsr M4IntroPhaseEnd
        moveq #0,d0
        jsr M4TextVideoDraw
        move.w d0,INTRO_DIAG+10
        tst.w d0
        beq.s M4GoOk3
        jmp M4IntroFailed
M4GoOk3:
        addq.w #1,INTRO_DIAG+6
        jsr M4IntroTimingPublish
        if def(M4_LOGIC_OVERLAP)
        bclr #2,M4_OVL_STATE ;M4GoTail ran during cmd10: its decision
        beq.s M4GoTailNow
        jsr M4OvlSatPublish ;its HUD buffer, at the serial point
        move.b M4_OVL_EXIT,d0
        bra.s M4GoTailDone
M4GoTailNow:
        endif
        bsr M4GoTail
M4GoTailDone:
        tst.b d0
        bne.s M4GoExit
M4GoCapture:
        if def(M4_LOGIC_OVERLAP)
        btst #0,M4_OVL_STATE ;the gate came up after the logic of k+1 ran: hold one
        bne M4GoLoop ;image later, after a serial iteration (consistent state)
        endif
        cmpi.w #2,INTRO_CAPTURE
        bne.s M4GoCaptureWait
        move.w #1,INTRO_CAPTURE
        bra M4GoLoop
M4GoCaptureWait:
        tst.w INTRO_CAPTURE
        bne.s M4GoCapture
        bra M4GoLoop
; Between the logic and the draw of a tick (also run by M4OvlWindow).
M4GoPreDraw:
        bsr M4GoPhase
        jmp M4GoSubtract
; Tail of the image after TextVideoDraw (also run by M4OvlWindow during cmd10);
; d0.b = 2 at phase 4 (leave), else 0.
M4GoTail:
        jsr M4LevelFade
        jsr M4LevelHudSprites
        move.w M4_LV_GAMEFRAME,M4_LV_DIAG+4
        moveq #0,d0
        cmpi.b #4,M4_GO_PHASE
        bne.s M4GoTailRet
        moveq #2,d0
M4GoTailRet:
        rts
M4GoExit: ;defaulttrain = contexit = 1, foxy_continue_l -> restart
        jsr M4PipeFlush
        beq.s M4GoOk4
        jmp M4IntroFailed
M4GoOk4:
        move.b #1,M4_CTL_DEFTRAIN
        move.b #1,M4_CTL_EXIT
        clr.b M4_SCREEN
        lea $ffff00,sp
        jmp M4ContinueStart ;foxy_continue_l 03:E3C7 (credits 0: controls)

; One object of gameoverinit_l: d0 descriptor, d1 x. Path istrat 04:8022 with
; path $474D, HP $FF, AP 0, position = player + (x, +120, +3400).
M4GoWord:
        movem.l d0-d1/a0-a2,-(sp)
        lea LV_PLAYER,a2
        jsr M4LevelAlloc
        move.l a0,d2
        beq.s M4GoWordDone
        jsr M4LevelSetShape
        move.l #M4PathIstrat,32(a0)
        move.w #$474d,42(a0)
        move.b #$ff,38(a0)
        clr.b 39(a0)
        move.w d1,(a0)
        move.w 2(a2),d0
        addi.w #120,d0
        move.w d0,2(a0)
        move.w 4(a2),d0
        addi.w #$0d48,d0
        move.w d0,4(a0)
M4GoWordDone:
        movem.l (sp)+,d0-d1/a0-a2
        rts

; gameover_l loop phases (after the tick, as the original calls F0A5/F061
; before setblack_l + transfer_l of the next pass).
M4GoPhase:
        move.b M4_GO_PHASE,d0
        bne.s M4GoPhase1
        subq.w #1,M4_GO_COUNT ;50 x (F0A5, setblack, transfer)
        bne.s M4GoPhaseDone
        move.b #1,M4_GO_PHASE
        move.w #1200,M4_GO_COUNT
        rts
M4GoPhase1:
        cmpi.b #1,d0
        bne.s M4GoPhase2
        tst.b M4_GO_SUB ;F061: v-- while v != 0
        beq.s M4GoSubDone
        subq.b #1,M4_GO_SUB
        rts
M4GoSubDone:
        move.b #2,M4_GO_PHASE ;02:E529: the same pass goes on to the wait
        moveq #2,d0
M4GoPhase2:
        cmpi.b #2,d0
        bne.s M4GoPhase3
        btst #J_START,M4_LP_JOY ;$1202 & $10: held
        bne.s M4GoFadeOut
        subq.w #1,M4_GO_COUNT
        bne.s M4GoPhaseDone
M4GoFadeOut:
        move.b #3,M4_GO_PHASE
        move.b #$ff,M4_FADE
        rts
M4GoPhase3:
        move.b #$ff,M4_FADE ;fadedir $FF each pass until 0
        tst.b M4_FADE+1
        bne.s M4GoPhaseDone
        move.b #4,M4_GO_PHASE
M4GoPhaseDone:
        rts

; Plane B lines 0, 1, 3 = M4_GO_CRAM minus the window subtraction (line 2,
; the GSU colours, is not subtracted).
M4GoSubtract:
        move.b M4_GO_SUB,d0
        cmp.b M4_GO_SHOWNSUB,d0
        beq.s M4GoSubReturn
        move.b d0,M4_GO_SHOWNSUB
        movem.l d0-d5/a0-a1,-(sp)
        moveq #0,d5
        move.b d0,d5
        lea M4_GO_CRAM,a0
        lea M4_BASE_CRAM,a1
        moveq #0,d4
M4GoSubColour:
        move.w (a0)+,d0
        cmpi.w #32,d4 ;line 2 = entries 32..47
        blo.s M4GoSubDo
        cmpi.w #48,d4
        bhs.s M4GoSubDo
        move.w d0,(a1)+
        bra.s M4GoSubNext
M4GoSubDo:
        bsr.s M4GoSubOne
        move.w d3,(a1)+
M4GoSubNext:
        addq.w #1,d4
        cmpi.w #64,d4
        blo.s M4GoSubColour
        movem.l (sp)+,d0-d5/a0-a1
        eori.b #$40,M4_SC_PALVER ;force the CRAM upload with the image
M4GoSubReturn:
        rts
; d0 MD colour, d5 subtraction -> d3 MD colour.
M4GoSubOne:
        moveq #0,d3
        moveq #1,d2 ;bit position of the component
M4GoSubOneComp:
        move.w d0,d1
        lsr.w d2,d1
        andi.w #7,d1
        lsl.w #2,d1
        addq.w #2,d1
        sub.w d5,d1
        bpl.s M4GoSubPos
        moveq #0,d1
M4GoSubPos:
        lsr.w #2,d1
        lsl.w d2,d1
        or.w d1,d3
        addq.w #4,d2
        cmpi.w #13,d2
        blo.s M4GoSubOneComp
        rts

; Video (instead of M4LevelVideoInit): Andross on plane B (vscroll 33 =
; bg2vofsreq 32 + 1, rows 0..1 repeated at 32..33 for the SNES 32-row wrap),
; gameoverpal on line 2, no tilt.
M4GoVideoInit:
        move.w #M4_SCR_GAMEOVER_VRAM,d0
        lea M4ScrGameoverTiles,a0
        jsr M4BgUpload
        lea M4ScrGameoverMap0,a0
        jsr M4BgDecodeScratch
        move.w sr,-(sp)
        ori.w #$0700,sr
        move.w #$e000,d0
        jsr M4TextVideoWriteAddress
        move.w #32*32/2-1,d1
M4GoMap:
        move.l (a0)+,VDP_DATA
        dbra d1,M4GoMap
        lea M4_BG_SCRATCH,a0
        moveq #32*2/2-1,d1
M4GoMapWrap:
        move.l (a0)+,VDP_DATA
        dbra d1,M4GoMapWrap
        move.w #$8731,VDP_CTRL
        move.w #$8b00,VDP_CTRL
        move.w (sp)+,sr
        clr.w M4_LEVEL_TILT
        move.w #M4_SCR_GAMEOVER_BLANK,d0
        jsr M4CtlPlaneA ;BG2 over the whole screen
        lea M4_BASE_CRAM,a1
        moveq #31,d1
M4GoCramClear:
        clr.l (a1)+
        dbra d1,M4GoCramClear
        lea M4ScrGameoverCram,a0
        jsr M4CtlCram
        lea M4GoPalette,a0
        lea M4_BASE_CRAM+64,a1
        moveq #15,d1
M4GoScene:
        move.w (a0)+,(a1)+
        dbra d1,M4GoScene
        clr.w M4_BASE_CRAM+98
        move.w #$eee,M4_BASE_CRAM+100
        lea M4_BASE_CRAM,a0
        lea M4_GO_CRAM,a1
        moveq #63,d1
M4GoCramSave:
        move.w (a0)+,(a1)+
        dbra d1,M4GoCramSave
        clr.w M4_TITLE_SPRITE
        clr.l M4_LV_SATREADY
        move.w sr,-(sp)
        ori.w #$0700,sr
        move.w #$d800+13*8,d0
        jsr M4TextVideoWriteAddress
        move.l #0,VDP_DATA
        move.l #0,VDP_DATA
        move.w (sp)+,sr
        move.w #1,M4_LEVEL_HUD
        move.w #33,M4_BOSS_SCROLL
        move.w #33,M4_BOSS_SCROLL_PRESENT
        clr.w M4_BG_HSCROLL
        rts

; Waiting map 0D:FA71 runs from M4ScriptProgramMap0D.
        include '../build/gameover-data.inc'
        include '../build/packed-2d/screen-gameover.inc'
