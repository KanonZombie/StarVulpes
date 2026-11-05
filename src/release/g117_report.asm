; graphics117, ROM $159500: 64-image Nomad report, two pages of decimal rows
; and an error context page (hw85..90, tools/hw-boot/make-round28.py and
; make-round32.py; ROUND32.md). Entered from G117Probe and G117Fatal.
G117_TEXT equ $ff5d80           ; 16-byte row buffer
G117_FATAL equ $ff5f00          ; 20 LONG error-context rows
G117Report:
        jsr InitVideo
        move.w #$8c00,VDP_CTRL
        move.l #$40000000,VDP_CTRL
        lea VDP_DATA,a1
        bsr G117RepFontUpload
        moveq #0,d5
G117RepPage:
        move.w #$8104,VDP_CTRL
        lea G117RepTitle1(pc),a0
        lea G117RepRows1(pc),a2
        tst.w d5
        beq G117RepSelected
        lea G117RepTitle2(pc),a0
        lea G117RepRows2(pc),a2
G117RepSelected:
        cmpi.l #2,G117_SAMPLE
        bne G117RepNormal
        lea G117RepErrTitle1(pc),a0
        lea G117RepErrRows1(pc),a2
        tst.w d5
        beq G117RepNormal
        lea G117RepErrTitle2(pc),a0
        lea G117RepErrRows2(pc),a2
G117RepNormal:
        moveq #0,d6
        bsr G117RepText
        lea G117RepHint(pc),a0
        moveq #2,d6
        bsr G117RepText
        moveq #4,d6
        moveq #9,d7
G117RepRow:
        lea G117_TEXT,a1
        movea.l (a2)+,a0
        moveq #5,d0
G117RepLabel:
        move.b (a0)+,(a1)+
        dbra d0,G117RepLabel
        movea.l (a2)+,a0
        move.l (a0),d4
        lea G117RepPowers(pc),a4
        moveq #9,d3
        moveq #0,d2
G117RepDigit:
        move.l (a4)+,d0
        moveq #0,d1
G117RepSubtract:
        cmp.l d0,d4
        blo G117RepOutput
        sub.l d0,d4
        addq.w #1,d1
        bra G117RepSubtract
G117RepOutput:
        tst.w d1
        bne G117RepNonzero
        tst.w d2
        bne G117RepNonzero
        tst.w d3
        beq G117RepNonzero
        move.b #32,(a1)+
        bra G117RepNextDigit
G117RepNonzero:
        moveq #1,d2
        addi.b #48,d1
        move.b d1,(a1)+
G117RepNextDigit:
        dbra d3,G117RepDigit
        lea G117_TEXT,a0
        bsr G117RepText
        addq.w #2,d6
        dbra d7,G117RepRow
        move.w #$8144,VDP_CTRL
        move.w #479,d4
G117RepWaitFrame:
        btst #3,VDP_CTRL+1
        bne G117RepWaitFrame
G117RepWaitBlank:
        btst #3,VDP_CTRL+1
        beq G117RepWaitBlank
        dbra d4,G117RepWaitFrame
        eori.w #1,d5
        bra G117RepPage
; a0 = exactly 16 ASCII bytes, d6 = top tile row. Preserves row/page counters.
G117RepText:
        movea.l a0,a3
        moveq #0,d2
G117RepHalf:
        move.w d6,d0
        add.w d2,d0
        lsl.w #7,d0
        addi.w #$c000,d0
        andi.l #$3fff,d0
        swap d0
        ori.l #$40000003,d0
        move.l d0,VDP_CTRL
        movea.l a3,a0
        moveq #15,d3
G117RepCharacter:
        moveq #0,d0
        move.b (a0)+,d0
        subi.w #32,d0
        lsl.w #2,d0
        add.w d2,d0
        add.w d2,d0
        move.w d0,VDP_DATA
        addq.w #1,d0
        move.w d0,VDP_DATA
        dbra d3,G117RepCharacter
        addq.w #1,d2
        cmpi.w #2,d2
        blo G117RepHalf
        rts
G117RepPowers: dc.l 1000000000,100000000,10000000,1000000,100000,10000,1000,100,10,1
G117RepTitle1: dc.b '117NOMAD 1/2    '
G117RepTitle2: dc.b '117NOMAD 2/2    '
G117RepHint: dc.b   'DECIMAL  AUTO 8S'
        even
G117RepRows1:
        dc.l G117RepLabel0,G117_SAMPLE
        dc.l G117RepLabel1,G117_SAMPLE+4
        dc.l G117RepLabel2,G117_SAMPLE+8
        dc.l G117RepLabel3,G117_SAMPLE+12
        dc.l G117RepLabel4,G117_SAMPLE+16
        dc.l G117RepLabel5,G117_SAMPLE+20
        dc.l G117RepLabel6,G117_SAMPLE+24
        dc.l G117RepLabel7,G117_SAMPLE+28
        dc.l G117RepLabel8,G117_BASE+8
        dc.l G117RepLabel9,G117_BASE+12
G117RepRows2:
        dc.l G117RepLabel10,G117_DELTA
        dc.l G117RepLabel11,G117_DELTA+4
        dc.l G117RepLabel12,G117_DELTA+8
        dc.l G117RepLabel13,G117_DELTA+12
        dc.l G117RepLabel14,G117_DELTA+16
        dc.l G117RepLabel15,G117_DELTA+20
        dc.l G117RepLabel16,G117_DELTA+24
        dc.l G117RepLabel17,G117_DELTA+28
        dc.l G117RepLabel18,G117_DELTA+32
        dc.l G117RepLabel19,G117_DELTA+36
G117RepLabel0: dc.b 'RESULT'
G117RepLabel1: dc.b 'ERROR '
G117RepLabel2: dc.b 'FRAME '
G117RepLabel3: dc.b 'VB    '
G117RepLabel4: dc.b 'TICKS '
G117RepLabel5: dc.b 'LOOPS '
G117RepLabel6: dc.b 'FX100 '
G117RepLabel7: dc.b 'QUEUE '
G117RepLabel8: dc.b 'BSP   '
G117RepLabel9: dc.b 'CHAIN '
G117RepLabel10: dc.b 'LOGIC '
G117RepLabel11: dc.b 'DRAW  '
G117RepLabel12: dc.b 'GEO9  '
G117RepLabel13: dc.b 'POLL  '
G117RepLabel14: dc.b 'COLOR '
G117RepLabel15: dc.b 'FACE  '
G117RepLabel16: dc.b 'HUD   '
G117RepLabel17: dc.b 'WAIT  '
G117RepLabel18: dc.b 'REST  '
G117RepLabel19: dc.b 'SEAL  '
        even
G117RepErrTitle1: dc.b '117ERROR 1/2    '
G117RepErrTitle2: dc.b '117ERROR 2/2    '
        even
G117RepErrRows1:
        dc.l G117RepErrLabel0,G117_FATAL
        dc.l G117RepErrLabel1,G117_FATAL+4
        dc.l G117RepErrLabel2,G117_FATAL+8
        dc.l G117RepErrLabel3,G117_FATAL+12
        dc.l G117RepErrLabel4,G117_FATAL+16
        dc.l G117RepErrLabel5,G117_FATAL+20
        dc.l G117RepErrLabel6,G117_FATAL+24
        dc.l G117RepErrLabel7,G117_FATAL+28
        dc.l G117RepErrLabel8,G117_FATAL+32
        dc.l G117RepErrLabel9,G117_FATAL+36
G117RepErrRows2:
        dc.l G117RepErrLabel10,G117_FATAL+40
        dc.l G117RepErrLabel11,G117_FATAL+44
        dc.l G117RepErrLabel12,G117_FATAL+48
        dc.l G117RepErrLabel13,G117_FATAL+52
        dc.l G117RepErrLabel14,G117_FATAL+56
        dc.l G117RepErrLabel15,G117_FATAL+60
        dc.l G117RepErrLabel16,G117_FATAL+64
        dc.l G117RepErrLabel17,G117_FATAL+68
        dc.l G117RepErrLabel18,G117_FATAL+72
        dc.l G117RepErrLabel19,G117_FATAL+76
G117RepErrLabel0: dc.b 'D0    '
G117RepErrLabel1: dc.b 'D1    '
G117RepErrLabel2: dc.b 'SR    '
G117RepErrLabel3: dc.b 'ROOT  '
G117RepErrLabel4: dc.b 'ISTAT '
G117RepErrLabel5: dc.b 'ITICK '
G117RepErrLabel6: dc.b 'VIDEO '
G117RepErrLabel7: dc.b 'GEO   '
G117RepErrLabel8: dc.b 'PROJ  '
G117RepErrLabel9: dc.b 'CAM   '
G117RepErrLabel10: dc.b 'SHIP  '
G117RepErrLabel11: dc.b 'MAT   '
G117RepErrLabel12: dc.b 'FIRE  '
G117RepErrLabel13: dc.b 'WEAP  '
G117RepErrLabel14: dc.b 'FX    '
G117RepErrLabel15: dc.b 'POLY  '
G117RepErrLabel16: dc.b 'BOSS  '
G117RepErrLabel17: dc.b 'PART  '
G117RepErrLabel18: dc.b 'LATER '
G117RepErrLabel19: dc.b 'NATIVE'
        even
; Report font: ASCII 32..90 as 5x7 glyphs (font_bytes() of
; tools/hw-boot/make-round28.py), sent as 16x16 cells of four 8x8 tiles in
; the order (0,0) (8,0) (0,8) (8,8): every glyph pixel doubled to 2x2 of
; colour 2 at (3 + 2x, 1 + 2y). The same 7552 VRAM bytes as the 117 table.
; a1 = data port.
G117RepFontUpload:
        lea G117RepGlyphs(pc),a0
        moveq #58,d7
G117RepFontGlyph:
        moveq #0,d6 ;tile: bit0 right half, bit1 lower half
G117RepFontTile:
        moveq #0,d5 ;row in the tile
G117RepFontRow:
        moveq #0,d1 ;16-pixel row, bit 15 = x 0
        move.w d6,d0
        andi.w #2,d0
        lsl.w #2,d0
        add.w d5,d0 ;y
        subq.w #1,d0
        bmi.s G117RepFontPixels
        lsr.w #1,d0 ;glyph row
        cmpi.w #7,d0
        bhs.s G117RepFontPixels
        move.b (a0,d0.w),d2
        moveq #4,d3 ;bit 4 = left column
        move.w #$1800,d4 ;x 3 and 4
G117RepFontBit:
        btst d3,d2
        beq.s G117RepFontClear
        or.w d4,d1
G117RepFontClear:
        lsr.w #2,d4
        dbra d3,G117RepFontBit
G117RepFontPixels:
        btst #0,d6
        beq.s G117RepFontLeft
        lsl.w #8,d1
G117RepFontLeft:
        moveq #0,d2
        moveq #7,d3
G117RepFontNibble:
        lsl.l #4,d2
        add.w d1,d1
        bcc.s G117RepFontZero
        addq.l #2,d2
G117RepFontZero:
        dbra d3,G117RepFontNibble
        move.l d2,(a1)
        addq.w #1,d5
        cmpi.w #8,d5
        blo.s G117RepFontRow
        addq.w #1,d6
        cmpi.w #4,d6
        blo.s G117RepFontTile
        addq.l #7,a0
        dbra d7,G117RepFontGlyph
        rts
G117RepGlyphs:
        dc.b $00,$00,$00,$00,$00,$00,$00 ; ' '
        dc.b $00,$00,$00,$00,$00,$00,$00 ; '!'
        dc.b $00,$00,$00,$00,$00,$00,$00 ; '"'
        dc.b $00,$00,$00,$00,$00,$00,$00 ; '#'
        dc.b $00,$00,$00,$00,$00,$00,$00 ; '$'
        dc.b $00,$00,$00,$00,$00,$00,$00 ; '%'
        dc.b $00,$00,$00,$00,$00,$00,$00 ; '&'
        dc.b $00,$00,$00,$00,$00,$00,$00 ; '''
        dc.b $00,$00,$00,$00,$00,$00,$00 ; '('
        dc.b $00,$00,$00,$00,$00,$00,$00 ; ')'
        dc.b $00,$00,$00,$00,$00,$00,$00 ; '*'
        dc.b $00,$00,$00,$00,$00,$00,$00 ; '+'
        dc.b $00,$00,$00,$00,$00,$00,$00 ; ','
        dc.b $00,$00,$00,$00,$00,$00,$00 ; '-'
        dc.b $00,$00,$00,$00,$00,$00,$00 ; '.'
        dc.b $01,$01,$02,$04,$08,$10,$10 ; '/'
        dc.b $0e,$11,$11,$11,$11,$11,$0e ; '0'
        dc.b $04,$0c,$04,$04,$04,$04,$0e ; '1'
        dc.b $0e,$11,$01,$02,$04,$08,$1f ; '2'
        dc.b $1e,$01,$01,$0e,$01,$01,$1e ; '3'
        dc.b $02,$06,$0a,$12,$1f,$02,$02 ; '4'
        dc.b $1f,$10,$10,$1e,$01,$01,$1e ; '5'
        dc.b $0e,$10,$10,$1e,$11,$11,$0e ; '6'
        dc.b $1f,$01,$02,$04,$08,$08,$08 ; '7'
        dc.b $0e,$11,$11,$0e,$11,$11,$0e ; '8'
        dc.b $0e,$11,$11,$0f,$01,$01,$0e ; '9'
        dc.b $00,$00,$00,$00,$00,$00,$00 ; ':'
        dc.b $00,$00,$00,$00,$00,$00,$00 ; ';'
        dc.b $00,$00,$00,$00,$00,$00,$00 ; '<'
        dc.b $00,$00,$00,$00,$00,$00,$00 ; '='
        dc.b $00,$00,$00,$00,$00,$00,$00 ; '>'
        dc.b $00,$00,$00,$00,$00,$00,$00 ; '?'
        dc.b $00,$00,$00,$00,$00,$00,$00 ; '@'
        dc.b $0e,$11,$11,$1f,$11,$11,$11 ; 'A'
        dc.b $1e,$11,$11,$1e,$11,$11,$1e ; 'B'
        dc.b $0f,$10,$10,$10,$10,$10,$0f ; 'C'
        dc.b $1e,$11,$11,$11,$11,$11,$1e ; 'D'
        dc.b $1f,$10,$10,$1e,$10,$10,$1f ; 'E'
        dc.b $1f,$10,$10,$1e,$10,$10,$10 ; 'F'
        dc.b $0f,$10,$10,$17,$11,$11,$0f ; 'G'
        dc.b $11,$11,$11,$1f,$11,$11,$11 ; 'H'
        dc.b $0e,$04,$04,$04,$04,$04,$0e ; 'I'
        dc.b $07,$02,$02,$02,$12,$12,$0c ; 'J'
        dc.b $11,$12,$14,$18,$14,$12,$11 ; 'K'
        dc.b $10,$10,$10,$10,$10,$10,$1f ; 'L'
        dc.b $11,$1b,$15,$15,$11,$11,$11 ; 'M'
        dc.b $11,$19,$15,$13,$11,$11,$11 ; 'N'
        dc.b $0e,$11,$11,$11,$11,$11,$0e ; 'O'
        dc.b $1e,$11,$11,$1e,$10,$10,$10 ; 'P'
        dc.b $0e,$11,$11,$11,$15,$12,$0d ; 'Q'
        dc.b $1e,$11,$11,$1e,$14,$12,$11 ; 'R'
        dc.b $0f,$10,$10,$0e,$01,$01,$1e ; 'S'
        dc.b $1f,$04,$04,$04,$04,$04,$04 ; 'T'
        dc.b $11,$11,$11,$11,$11,$11,$0e ; 'U'
        dc.b $11,$11,$11,$11,$11,$0a,$04 ; 'V'
        dc.b $11,$11,$11,$15,$15,$15,$0a ; 'W'
        dc.b $11,$11,$0a,$04,$0a,$11,$11 ; 'X'
        dc.b $11,$11,$0a,$04,$04,$04,$04 ; 'Y'
        dc.b $1f,$01,$02,$04,$08,$10,$1f ; 'Z'
        even
