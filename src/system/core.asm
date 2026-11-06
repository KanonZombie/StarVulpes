        include 'audio/macros.asm'
ROM_BYTES equ $400000 ;game + extracted PCM; SVP memory windows are excluded from the PCM allocator
; MegaSVP M0: own 68000/SVP ROM. asm68k 2.53 syntax.
; VDP startup/text layout informed by svpdev SVP_tests and its credited
; BigEvilCorporation examples. Font attribution in pixelfont.asm.

VDP_DATA        equ $c00000
VDP_CTRL        equ $c00004
XST             equ $a15000
XST_STATUS      equ $a15004
MAILBOX         equ $300000
ACK_SEQUENCE    equ MAILBOX+18 ; DSP writes last, then raises XST status bit 0
DIAG            equ $ff0000
RECORDS         equ DIAG+$10
TEST_COUNT      equ 4
TIMEOUT_POLLS   equ $100000

        org 0
        dc.l $ffff00,CPU_Start
        rept 26
        dc.l CPU_Exception
        endr
        dc.l M4VRHBlankIRQ,CPU_Exception
        dc.l M4IntroVBlankIRQ
        rept 33
        dc.l CPU_Exception
        endr
        dc.b 'SEGA MEGA DRIVE ' ; 16 bytes
        dc.b '(C) MEGASVP 2026' ; 16 bytes
        dc.b 'Virtua Racing / MEGASVP M1'
        dcb.b $150-*,$20
        dc.b 'Virtua Racing / MEGASVP M1'
        dcb.b $180-*,$20
        dc.b 'GM MK-1229 -00' ; compatibility identifier for SVP emulators
        dc.w 0                  ; build.ps1 fixes checksum
        dc.b 'J               '
        dc.l 0,ROM_BYTES-1,$ff0000,$ffffff
        dcb.b $1c8-*,0
        dc.b 'SV'               ; SVP hardware/boot signature
        dc.w 0,$2000,$0400      ; DSP entry word $0400
        dcb.b $1f0-*,$20
        dc.b 'JUE             '
        if def(M4_GRAPHICS117)
        include 'release/g117_probe.asm'
        endif
        dcb.b $800-*,0
        dc.w $4c00,SVP_Start/2   ; SSP1601 jump over cart-detection signature
        dcb.b $810-*,0
        dc.b 'OHMP'              ; legacy SVP emulator recognition, not code
        dcb.b $820-*,0
        include 'svp/svp_code.asm'
        if def(SVP_SPHERE_FAST)
; Legacy PCM is replaced by MDSDRV in the official integration. Keep its
; unused symbols stable; spend this window on exact sphere tables/code.
M4Sfx84 equ $16000
M4Sfx04 equ $1f100
        include '../build/agent-sphere/svp-sphere-fast.inc'
        if def(M4_STEXT)
; Scaled text of the level (msprint, cmd8 type 13): program window, reached
; by SVP_STextDispatch (tools/generate-svp-ending-text.py).
        include '../build/svp-ending-text.inc'
        endif
        else
        include '../build/sf-sfx-early.inc'
        endif
        include '../build/svp-guard-clip.inc'
SVP_GuardEnd:
        dcb.b $20000-*,0

CPU_Start:
        move.w #$2700,sr        ; polling only; no IRQ races during diagnostics
        move.w #0,$a11200       ; held until M0 checks complete; M4SoundInit loads the DAC driver
        move.b $a10001,d0
        andi.b #$f,d0
        beq.s CPU_NoTMSS
        move.l #'SEGA',$a14000
CPU_NoTMSS:
        move.w VDP_CTRL,d0
        lea DIAG,a0
        moveq #0,d0
        moveq #($50/4)-1,d1
CPU_ClearDiag:
        move.l d0,(a0)+
        dbra d1,CPU_ClearDiag
        move.l #'M0SV',DIAG
        jsr InitVideo
        moveq #1,d6
        jsr SetRow
        lea Title,a0
        jsr DrawText
        moveq #3,d6
        jsr SetRow
        lea Running,a0
        jsr DrawText
        move.w #$8144,VDP_CTRL  ; enable display after initialization

        lea TestVectors,a4
        lea RECORDS,a5
        moveq #0,d7
CPU_TestLoop:
        move.w (a4)+,(a5)       ; sequence
        move.w (a4)+,2(a5)      ; operand A
        move.w (a4)+,4(a5)      ; operand B
        move.w (a4)+,6(a5)      ; expected independent literal
        jsr RunRequest
        addq.w #1,6+DIAG        ; completed count (includes failed request)
        cmpi.w #1,14(a5)
        bne.s CPU_Failed
        lea 16(a5),a5
        addq.w #1,d7
        cmpi.w #TEST_COUNT,d7
        bne.s CPU_TestLoop
        move.w #1,4+DIAG
        bra.s CPU_DrawResults
CPU_Failed:
        move.w #$ffff,4+DIAG
CPU_DrawResults:
        jsr DrawResults
        cmpi.w #1,4+DIAG
        bne CPU_Stop
        bsr M4LogicTest
        cmpi.w #1,$ff2004
        bne CPU_Stop
        cmpi.w #1,4+DIAG
        bne CPU_Stop
        bsr M4ScriptTest
        cmpi.w #1,$ff4404
        bne CPU_Stop
        bsr M4TextPathTest
        cmpi.w #1,$ff4444
        bne CPU_Stop
        jsr M4SoundInit
        bsr M4BackgroundStart
CPU_Stop:
        bra.s CPU_Stop

        include 'intro/intro_exit.asm'
        include 'intro/background.asm'
        include 'level/script.asm'
        include 'tests/script_test.asm'
        include 'intro/text_path.asm'
        include 'tests/text_path_test.asm'
        include 'render/text_video.asm'
        include 'render/bg_unpack.asm'
        include 'render/intro_dma.asm'
        include 'intro/text_objects.asm'
        include 'intro/text_trails.asm'
        include 'intro/text_draw_list.asm'
        include 'intro/text_project.asm'
        include 'tests/text_project_test.asm'
        include 'intro/camera.asm'
        include 'tests/camera_test.asm'
        include 'intro/intro_ships.asm'
        include 'tests/intro_ships_test.asm'
        include 'render/intro_matrix.asm'
        include 'tests/intro_poly_test.asm'
        include 'render/intro_mesh.asm'
        include 'render/intro_geometry.asm'
        include 'render/intro_chain.asm'
        include 'tests/intro_boss_geometry_test.asm'
        include 'tests/intro_particle_test.asm'
        include 'intro/intro_boss.asm'
        include 'intro/intro_native_pool.asm'
        include 'intro/intro_fire.asm'
        include 'intro/intro_weapons.asm'
        include 'intro/intro_effects.asm'
        include 'render/intro_timing.asm'
        include 'intro/intro_later.asm'
        include 'tests/intro_later_test.asm'
        include 'intro/intro_debris.asm'
        include 'intro/intro_zacos.asm'
        include 'render/intro_scene.asm'
        include 'intro/intro.asm'
        include 'screens/title.asm'
        include 'level/level.asm'
        include 'level/level_player.asm'
        include 'level/level_input.asm'
        include 'level/level_objects.asm'
        include 'level/level_view.asm'
        include 'level/level_stars.asm' ;space star field (68000 side; SVP side build/agent-stars/svp-stars.inc)
        include 'level/level_coll.asm'
        include 'level/level_enemies.asm'
        include 'level/level_paths.asm'
        include 'level/level_boss.asm'
        include 'level/level_scramble.asm'
        include 'level/level_radio.asm'
        include 'level/level_final.asm'
        include 'level/level_text.asm'
        include 'screens/controls.asm'
        include 'screens/gameover.asm'
        include 'screens/training.asm'
        include 'stages/level_training.asm'
        include 'level/level_space.asm'
        include 'level/level_space_bg.asm'
        include 'level/level_backgrounds.asm'
        include 'level/level_cockpit.asm'
        include 'level/level_warp.asm'
        include 'level/level_mapvars.asm'
        include 'stages/level_armada.asm'
        include 'stages/level_meteor.asm'
        include 'stages/level_venom.asm'
        include 'stages/level_corneria23.asm'
        include 'stages/level_titania.asm'
        include 'stages/level_macbeth.asm'
        include 'stages/level_sectors.asm'
        include 'stages/level_fortuna_boss.asm'
        include 'stages/level_spacemisc.asm'
        include 'stages/level_venom23.asm'
        include 'stages/level_ending.asm'
        include 'screens/routemap.asm'
        include 'screens/continue.asm'
        if def(M4_PROFILE)
        include 'level/level_profile.asm'
        endif
        include '../build/intro-colours.inc' ;original GSU colour descriptors
        include '../build/level-shapes.inc' ;level shape catalog data
        include 'level/level_video.asm' ;level BG/script data
        include '../build/packed-2d/level-backgrounds.inc' ;stage BG descriptors and programs
        include '../build/packed-2d/assets.inc'

; One outstanding job. Host owns inputs until completion; DSP owns outputs.
; Read XST_STATUS once before sending to discard any old completion flag.
; Invalidate BOTH output fields. Only a NEW flag + matching XST + matching
; DRAM sequence + correct result can pass. Abort all further jobs on failure.
RunRequest:
        clr.w MAILBOX+8         ; command 0 = original M0 sum test
        move.w XST_STATUS,d0
        move.w 6(a5),d0
        not.w d0
        move.w d0,MAILBOX+4     ; poison differs from expected, including zero
        move.w d0,8(a5)
        move.w (a5),d0
        not.w d0
        move.w d0,MAILBOX+6     ; poison differs from current sequence
        move.w d0,10(a5)
        move.w 2(a5),MAILBOX
        move.w 4(a5),MAILBOX+2
        clr.w 12(a5)
        move.w (a5),d0
        not.w d0
        move.w d0,ACK_SEQUENCE
        move.w (a5),XST         ; publish request LAST
        move.l #TIMEOUT_POLLS,d0
CPU_Poll:
        move.w XST_STATUS,d1    ; consumes DSP completion bit 0
        btst #0,d1
        bne.s CPU_Completed
        subq.l #1,d0
        bne.s CPU_Poll
        move.w #2,14(a5)        ; FAIL TIMEOUT
        rts
CPU_Completed:
        move.w ACK_SEQUENCE,12(a5)
        move.w MAILBOX+4,8(a5)
        move.w MAILBOX+6,10(a5)
        move.w (a5),d0
        cmp.w 12(a5),d0
        bne.s CPU_BadSequence
        cmp.w 10(a5),d0
        bne.s CPU_BadSequence
        move.w 6(a5),d0
        cmp.w 8(a5),d0
        bne.s CPU_BadResult
        move.w #1,14(a5)        ; PASS
        rts
CPU_BadSequence:
        move.w #3,14(a5)
        rts
CPU_BadResult:
        move.w #4,14(a5)
        rts

InitVideo:
        lea VDPRegisters,a0
        move.w #$8000,d1
        moveq #23,d0
VDP_RegLoop:
        move.b (a0)+,d1
        move.w d1,VDP_CTRL
        addi.w #$100,d1
        dbra d0,VDP_RegLoop
        move.l #$40000000,VDP_CTRL
        move.w #$7fff,d0
VDP_ClearLoop:
        move.w #0,VDP_DATA
        dbra d0,VDP_ClearLoop
        move.l #$40000010,VDP_CTRL
        moveq #19,d0
VDP_ClearVScroll:
        move.l #0,VDP_DATA
        dbra d0,VDP_ClearVScroll
        move.l #$c0000000,VDP_CTRL
        moveq #31,d0
VDP_ClearPalette:
        move.l #0,VDP_DATA
        dbra d0,VDP_ClearPalette
        move.l #$c0040000,VDP_CTRL ; palette entry 2 = white (font color)
        move.w #$eee,VDP_DATA
        move.l #$40000000,VDP_CTRL
        lea PixelFont,a0
        move.w #(PixelFontEnd-PixelFont)/4-1,d0
VDP_FontLoop:
        move.l (a0)+,VDP_DATA
        dbra d0,VDP_FontLoop
        rts

; d6=row, column 2, plane A at $c000, width 64 tiles. Clobbers d0-d2.
SetRow:
        move.w d6,d0
        lsl.w #7,d0
        addi.w #$c004,d0
        moveq #0,d1
        move.w d0,d1
        andi.w #$3fff,d1
        swap d1
        move.w d0,d2
        lsr.w #8,d2
        lsr.w #6,d2
        or.w d2,d1
        ori.l #$40000000,d1
        move.l d1,VDP_CTRL
        rts

; a0=uppercase ASCII string. Clobbers d0-d1,a0-a1.
DrawText:
        lea ASCIIMap,a1
        moveq #0,d0
        moveq #0,d1
Text_Loop:
        move.b (a0)+,d0
        beq.s Text_End
        subi.w #$20,d0
        move.b (a1,d0.w),d1
        move.w d1,VDP_DATA
        bra.s Text_Loop
Text_End:
        rts

; d4=unsigned word, print four hex digits and space. Clobbers d0-d3,d5.
DrawHex:
        moveq #12,d5
Hex_Loop:
        move.w d4,d0
        lsr.w d5,d0
        andi.w #15,d0
        cmpi.w #10,d0
        blo.s Hex_Digit
        subi.w #9,d0           ; A-F map to font tiles 1-6
        bra.s Hex_Write
Hex_Digit:
        addi.w #27,d0
Hex_Write:
        move.w d0,VDP_DATA
        subq.w #4,d5
        bpl.s Hex_Loop
        move.w #0,VDP_DATA
        rts

DrawResults:
        moveq #3,d6
        jsr SetRow
        lea PassTitle,a0
        cmpi.w #1,4+DIAG
        beq.s Results_Title
        lea FailTitle,a0
Results_Title:
        jsr DrawText
        moveq #5,d6
        jsr SetRow
        lea Columns,a0
        jsr DrawText
        lea RECORDS,a5
        moveq #7,d6
        moveq #TEST_COUNT-1,d7
Results_Loop:
        jsr SetRow
        move.w (a5),d4
        bsr DrawHex
        move.w 2(a5),d4
        bsr DrawHex
        move.w 4(a5),d4
        bsr DrawHex
        move.w 6(a5),d4
        bsr DrawHex
        move.w 8(a5),d4
        bsr DrawHex
        lea NotRun,a0
        move.w 14(a5),d0
        beq.s Results_Status
        lea Pass,a0
        cmpi.w #1,d0
        beq.s Results_Status
        lea Timeout,a0
        cmpi.w #2,d0
        beq.s Results_Status
        lea BadSeq,a0
        cmpi.w #3,d0
        beq.s Results_Status
        lea BadResult,a0
Results_Status:
        jsr DrawText
        addq.w #1,d6
        jsr SetRow
        lea AckLabel,a0
        jsr DrawText
        move.w 12(a5),d4
        bsr DrawHex
        lea EchoLabel,a0
        jsr DrawText
        move.w 10(a5),d4
        bsr DrawHex
        addq.w #2,d6
        lea 16(a5),a5
        dbra d7,Results_Loop
        moveq #22,d6
        jsr SetRow
        lea Contract,a0
        jsr DrawText
        rts

CPU_Exception:
        move.w #$2700,sr
        move.w #$eeee,4+DIAG
        moveq #3,d6
        jsr SetRow
        lea Exception,a0
        jsr DrawText
        jmp CPU_Stop

; Inputs and independently stated expectations. Case 3 exercises wrap to 0;
; case 4 repeats case 1 inputs but MUST produce a fresh completion/sequence.
TestVectors:
        dc.w $1101,$1234,$0102,$1336
        dc.w $2202,$abcd,$0021,$abee
        dc.w $3303,$ffff,$0001,$0000
        dc.w $4404,$1234,$0102,$1336
VDPRegisters:
        dc.b $04,$04,$30,$00,$07,$78,$00,$00
        dc.b $00,$00,$00,$00,$81,$3f,$00,$02
; R23=$80 matches VR's startup table ($0200BF). On Nomad + ED Pro,
; $00 blocks the next VDP command; $80 restores pre-DSP text (probes 44/46).
; This is initial state only; actual DMA setup writes its own source/mode.
        dc.b $01,$00,$00,$00,$00,$00,$00,$80
Title:      dc.b 'MEGASVP M1 - SVP TO VDP',0
Running:    dc.b 'RUNNING - WAITING FOR DSP',0
PassTitle:  dc.b 'PASS - ALL 4 FRESH REQUESTS',0
FailTitle:  dc.b 'FAIL - REQUEST ABORTED    ',0
Columns:    dc.b 'SEQ  A    B    EXP  GOT  STATUS',0
Pass:       dc.b 'PASS',0
NotRun:     dc.b 'SKIP',0
Timeout:    dc.b 'FAIL TIME',0
BadSeq:     dc.b 'FAIL SEQ',0
BadResult:  dc.b 'FAIL SUM',0
AckLabel:   dc.b 'ACK ',0
EchoLabel:  dc.b 'ECHO ',0
Contract:   dc.b 'U16 SUM MOD 65536 / SINGLE JOB',0
Exception:  dc.b 'FAIL EXCEPTION',0
        even
        include 'system/charmap.asm'
        even
        include 'system/pixelfont.asm'
        include 'system/graphics.asm'
        include '../build/intro-ships-cases.inc'
        include '../build/intro-matrix-cases.inc'
        include '../build/intro-poly-cases.inc'
        include '../build/intro-model.inc'
        include '../build/intro-fire-cases.inc'
        include '../build/intro-weapons.inc'
        include '../build/intro-effects.inc'
        include '../build/intro-later-cases.inc'
        include '../build/intro-boss-geometry-cases.inc'
        include '../build/intro-boss-models.inc'
        include '../build/intro-particle-cases.inc'
        include '../build/intro-debris-vector-cases.inc'
        include '../build/intro-zaco-cases.inc'
        even
        include 'audio/sfx.asm'
CPU_CodeEnd:
; SVP ROM data block, read by the SVP through PM4 outside its 64K-word program
; window (projection reciprocals, ztab). A table must not cross a 64K-word
; page: start on the next 128 KiB boundary when the block could cross one.
; The bound is the block's own size limit (it was $AF00 on 23/10/2026), not
; a whole page: a page-sized bound padded it past SVP_GeoRom0 for nothing.
SVP_ROMDATA_MAX equ $b000
        if ((*+SVP_ROMDATA_MAX-1)>>17)<>(*>>17)
        dcb.b ((*+$1ffff)&$fe0000)-*,0
        endif
SVP_RomData:
        include '../build/svp-rom-particles.inc'
        include '../build/svp-rom-geometry.inc'
SVP_RomDataEnd:
        if (SVP_RomDataEnd-SVP_RomData)>SVP_ROMDATA_MAX
        inform 3,"SVP ROM data larger than SVP_ROMDATA_MAX"
        endif
        if def(M4_GRAPHICS117)
        include 'release/g117_rom.asm'
        endif
        if def(M4_STEXT)
        include '../build/svp-ending-text-rom.inc' ;msprint glyphs/strings, read by SVP_SText through PM4
        endif
        include '../build/svp-geo-rom.inc' ;level/intro models (generate-intro-geometry.py), own page guard
        include '../build/agent-sphere/svp-sphere-rom.inc' ;own page guard
        include '../build/agent-texpoly/svp-texpoly-rom.inc' ;atlas + materials (own page guard)
        include '../build/svp-bsp-rom.inc' ;colour pool, one WORD per byte (generate-svp-bsp.py, own page guard)
        include '../build/sf-sfx-data.inc'
        dcb.b ROM_BYTES-*,0
ROM_End:
