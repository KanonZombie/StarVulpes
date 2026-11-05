; Radio messages: send_message_l 03:E993 and friends_messages_l 03:E9EA.
; Research: build/research/radio-messages.md; data and SVP drawing from
; tools/generate-level-radio.py; correspondence in src/m4/LEVEL_ORIGIN.md.
; No queue: a valid send replaces the active message at once; a person whose
; shield is 0 is ignored. Counts are logical ticks: 5 opening, 50 text,
; 5 closing. The 68000 lays out the lines once per message (mgetlinelen
; 01:B604 + print loop 01:B599); the SVP draws the box after the polygons
; (cmd8 types 6..8). Original facesounds at the end of opening, $64 on close.
M4_RD equ $fff2c0
M4_RD_WHICH equ M4_RD+0 ;.b $189C whichfriend (person, bit7 = 3-line text)
M4_RD_COUNT1 equ M4_RD+1 ;.b $189F text ticks left
M4_RD_COUNT2 equ M4_RD+2 ;.b $18A0 opening/closing phase 0..5
M4_RD_SOUND equ M4_RD+3 ;.b $1FFC
M4_RD_FRAME equ M4_RD+4 ;.b face frame drawn this tick ($FF none)
M4_RD_TEXT equ M4_RD+5 ;.b text drawn this tick
M4_RD_METERV equ M4_RD+6 ;.b meter value drawn this tick
M4_RD_COLOUR equ M4_RD+7 ;.b text colour (message byte 2)
M4_RD_GLYPHS equ M4_RD+8 ;.w laid-out glyphs
M4_RD_SIZE equ 16
M4_RD_LAYOUT equ $ff5600 ;(x.w, y.w, t.w) per glyph, text position
M4_RD_MAXGLYPHS equ 80
RD_X1 equ 82+16 ;mfprintstr x (GSU 82) in the bitmap (+16)
RD_Y1 equ 169 ;first line; 153 with meter, 3-line flag or andross
RD_CLIP equ 174-82 ;line width limit (174 - x1)

M4RadioInit: ;initgame_l 02:E330: msg_count1/2 = 0
        lea M4_RD,a0
        moveq #M4_RD_SIZE/4-1,d0
M4RadioInitClear:
        clr.l (a0)+
        dbra d0,M4RadioInitClear
        st M4_RD_FRAME
        rts

; d0 = person 0..5 -> d1 = friends_hp-1 ($18A1+p); fox (in the port table),
; pepper and andross keep 40 (never written after initialise_l).
M4RadioPersonHp:
        moveq #40,d1
        cmpi.b #4,d0
        bhs.s M4RadioPersonHpDone
        movem.l d0/a0,-(sp)
        ext.w d0
        lea M4_PV_FRIENDHP,a0
        move.b (a0,d0.w),d1
        movem.l (sp)+,d0/a0
M4RadioPersonHpDone:
        rts

; send_message_l 03:E993: d0.b = message id (0 = nothing). Keeps registers.
M4RadioSend:
        movem.l d0-d7/a0-a5,-(sp)
        andi.w #$ff,d0
        beq M4RadioSendDone
        cmpi.w #M4_RADIO_MESSAGES,d0
        bhi M4RadioSendDone
        subq.w #1,d0
        add.w d0,d0
        lea M4RadioMsgPtr,a0
        move.w (a0,d0.w),d0
        lea M4RadioMsgData,a2
        adda.w d0,a2 ;person, sound, colour, text, 0
        move.b (a2),d0
        andi.b #$7f,d0
        bsr M4RadioPersonHp
        tst.b d1
        beq M4RadioSendDone ;person shot down: message discarded
        cmpi.b #$ff,M4_PV_METER
        bne.s M4RadioNoMeter
        ori.b #$80,d1
        move.b d1,M4_PV_METER
        bra.s M4RadioSendSet
M4RadioNoMeter:
        clr.b M4_PV_METER
M4RadioSendSet:
        move.b (a2)+,M4_RD_WHICH
        move.b (a2)+,M4_RD_SOUND
        move.b (a2)+,M4_RD_COLOUR
        move.b #50,M4_RD_COUNT1
        clr.b M4_RD_COUNT2
        ; layout: line y 169, 16 higher with bit7, andross or a meter
        move.w #RD_Y1,d6
        move.b M4_RD_WHICH,d0
        bmi.s M4RadioUp
        cmpi.b #5,d0
        beq.s M4RadioUp
        tst.b M4_PV_METER
        beq.s M4RadioLayout
M4RadioUp:
        subi.w #16,d6
M4RadioLayout:
        lea M4RadioTrn-32,a0
        lea M4RadioWidth,a1
        lea M4_RD_LAYOUT,a3
        moveq #0,d7 ;glyphs
; a2 = start of the line. mgetlinelen: accumulate widths; before reading a
; character (but the final 0), wrap at the last space when width > clip.
M4RadioLine:
        movea.l a2,a4 ;cursor
        movea.l a2,a5 ;lastspace (character after it)
        moveq #0,d2 ;linelen
        moveq #0,d3 ;chars
        moveq #0,d4 ;lastnum
        moveq #-1,d5 ;wrap pointer flag
M4RadioScan:
        moveq #0,d0
        move.b (a4)+,d0
        beq.s M4RadioPlace
        cmpi.w #RD_CLIP,d2
        bls.s M4RadioFits
        movea.l a5,a4 ;continue after the last space
        move.w d4,d3
        moveq #0,d5
        bra.s M4RadioPlace
M4RadioFits:
        cmpi.b #32,d0
        bne.s M4RadioCount
        movea.l a4,a5
        move.w d3,d4
M4RadioCount:
        moveq #0,d1
        move.b (a0,d0.w),d1
        move.b (a1,d1.w),d1
        add.w d1,d2
        addq.w #1,d3
        bra.s M4RadioScan
M4RadioPlace: ;d3 characters from a2 at x1, line y d6
        move.w #RD_X1,d2
        subq.w #1,d3
        bmi.s M4RadioPlaced
M4RadioPlaceChar:
        moveq #0,d0
        move.b (a2)+,d0
        moveq #0,d1
        move.b (a0,d0.w),d1
        bne.s M4RadioGlyph
        addq.w #5,d2 ;translation 0: +5, nothing drawn
        bra.s M4RadioPlaceNext
M4RadioGlyph:
        cmpi.w #M4_RD_MAXGLYPHS,d7
        bhs.s M4RadioPlaceAdvance
        move.w d2,(a3)+
        move.w d6,(a3)+
        move.w d1,(a3)+
        addq.w #1,d7
M4RadioPlaceAdvance:
        moveq #0,d0
        move.b (a1,d1.w),d0
        add.w d0,d2
M4RadioPlaceNext:
        dbra d3,M4RadioPlaceChar
M4RadioPlaced:
        tst.w d5
        bmi.s M4RadioLaidOut
        movea.l a4,a2 ;next line starts after the space
        addi.w #13,d6
        bra M4RadioLine
M4RadioLaidOut:
        move.w d7,M4_RD_GLYPHS
M4RadioSendDone:
        movem.l (sp)+,d0-d7/a0-a5
        rts

; friends_messages_l 03:E9EA after the tick: face frame, text and meter of
; this tick's image; one random_l per tick while the text is shown.
M4RadioTick:
        movem.l d0-d2/a0,-(sp)
        st M4_RD_FRAME
        clr.b M4_RD_TEXT
        tst.b M4_LP_DEADCNT ;gameflags dying/dead: frozen, not drawn
        bne M4RadioTickDone
        tst.b M4_RD_COUNT1
        bne.s M4RadioOpen
        move.b M4_RD_COUNT2,d0 ;closing
        subq.b #1,d0
        bmi M4RadioTickDone
        move.b d0,M4_RD_COUNT2
        move.b d0,M4_RD_FRAME
        bra M4RadioTickDone
M4RadioOpen:
        move.b M4_RD_COUNT2,d0
        cmpi.b #5,d0
        bhs.s M4RadioTalk
        move.b d0,M4_RD_FRAME
        addq.b #1,M4_RD_COUNT2
        cmpi.b #5,M4_RD_COUNT2
        blo M4RadioTickDone
        moveq #0,d0
        move.b M4_RD_WHICH,d0
        andi.w #$7f,d0
        lsl.w #2,d0
        moveq #0,d1
        move.b M4_RD_SOUND,d1
        add.w d1,d0
        lea M4RadioFaceSounds,a0
        move.b (a0,d0.w),d0
        jsr M4Sfx
        bra M4RadioTickDone
M4RadioTalk:
        jsr M4IntroRandom
        moveq #4,d1
        move.b d0,d2
        andi.b #31,d2
        beq.s M4RadioFace ;1/32: static
        moveq #1,d1
        and.b d0,d1 ;mouth
        cmpi.b #30,M4_RD_COUNT1
        bhs.s M4RadioMouth
        moveq #0,d1
M4RadioMouth:
        move.b M4_RD_WHICH,d0
        andi.w #$7f,d0
        add.w d0,d0
        addq.w #5,d0
        add.w d0,d1
M4RadioFace:
        move.b d1,M4_RD_FRAME
        subq.b #1,M4_RD_COUNT1
        bne.s M4RadioNoCloseSound
        M4PlaySfx $64
M4RadioNoCloseSound:
        move.b #1,M4_RD_TEXT
        move.b M4_PV_METER,d0
        beq M4RadioTickDone
        andi.b #$7f,d0
        move.b d0,M4_RD_METERV ;value drawn: before the adjustment
        move.b d0,d2
        move.b M4_RD_WHICH,d0
        andi.b #$7f,d0
        bsr M4RadioPersonHp
        cmp.b d2,d1
        beq M4RadioTickDone
        subq.b #1,d2 ;shown value drops 1 per tick
        ori.b #$80,d2
        move.b d2,M4_PV_METER
M4RadioTickDone:
        movem.l (sp)+,d0-d2/a0
        rts

M4RadioFaceSounds:
        incbin '../build/M4RadioFaceSounds.bin'

; Face records (kinds 31..33 -> cmd8 types 6..8) after the sorted objects:
; face at (48,152)+16, shadow (83,170) colour 9 then text (82,169) in the
; message colour, meter outline in colour 14 and bar in colour 2.
; Meter geometry from 03:EAB4 / 01:B7DC, x + 16 in the bitmap.
M4RadioDraw:
        movem.l d0-d4/a0-a2,-(sp)
        moveq #0,d0
        move.b M4_RD_FRAME,d0
        cmpi.b #$ff,d0
        beq M4RadioDrawDone
        mulu.w #320,d0
        addi.l #M4RadioFaces/2,d0 ;ROM WORD address (20 bits)
        move.w #31,d1
        move.w #48+16,d2
        move.w #152,d3
        bsr M4RadioRecord
        move.w d0,12(a2) ;low WORD
        swap d0
        ori.w #$0800,d0 ;PM ROM mode, increment 1
        move.w d0,14(a2)
        tst.b M4_RD_TEXT
        beq M4RadioDrawDone
        moveq #1,d4 ;shadow: +1,+1, colour 9
        moveq #9,d0
        bsr M4RadioText
        moveq #0,d4
        moveq #0,d0
        move.b M4_RD_COLOUR,d0
        bsr M4RadioText
        tst.b M4_PV_METER
        beq M4RadioDrawDone
        lea M4RadioMeterBox,a0
        moveq #3,d4
M4RadioBox:
        move.w #33,d1
        move.w (a0)+,d2
        move.w (a0)+,d3
        bsr M4RadioRecord
        move.l (a0)+,12(a2) ;w, h
        move.w #14,16(a2)
        dbra d4,M4RadioBox
        moveq #0,d0
        move.b M4_RD_METERV,d0
        beq.s M4RadioDrawDone
        move.w #33,d1
        move.w #M4RadioMeterFillX,d2
        move.w #M4RadioMeterFillY,d3
        bsr M4RadioRecord
        move.w d0,12(a2)
        move.w #M4RadioMeterFillH,14(a2)
        move.w #2,16(a2)
M4RadioDrawDone:
        movem.l (sp)+,d0-d4/a0-a2
        rts
; Glyph records of the laid-out text: d0 colour, d4 offset (shadow 1).
M4RadioText:
        movem.l d0-d7/a0,-(sp)
        move.w d0,d5
        lea M4_RD_LAYOUT,a0
        move.w M4_RD_GLYPHS,d6
        subq.w #1,d6
        bmi.s M4RadioTextDone
M4RadioTextGlyph:
        move.w #32,d1
        move.w (a0)+,d2
        add.w d4,d2
        move.w (a0)+,d3
        add.w d4,d3
        bsr M4RadioRecord
        move.w (a0)+,d0
        lea M4RadioWidth,a1
        moveq #0,d7
        move.b (a1,d0.w),d7
        mulu.w #12,d0
        addi.w #SVP_RadioGlyphs/2,d0
        move.w d0,12(a2)
        move.w d7,14(a2)
        move.w d5,16(a2)
        dbra d6,M4RadioTextGlyph
M4RadioTextDone:
        movem.l (sp)+,d0-d7/a0
        rts
; New face record: d1 kind, d2 x, d3 y -> a2 (x at 8, y at 10, params at
; 12..19; 0 when the face buffer is full: record not written).
M4RadioRecord:
        if def(M4_GRAPHICS117)
        jmp G117H106Radio
        nop
        else
        move.l d0,-(sp)
        move.w M4_FACE_COUNT,d0
        endif
        cmpi.w #512,d0
        bhs.s M4RadioRecordFull
        jsr M4FaceSlot
        clr.l (a2)
        clr.w 4(a2)
        move.w d1,6(a2)
        ori.w #$8000,6(a2) ;special packet kind (31..34 | $8000): not a model kind
        move.w d2,8(a2)
        move.w d3,10(a2)
        clr.l 12(a2)
        clr.l 16(a2)
        clr.l 20(a2)
        clr.l 24(a2)
        clr.l 28(a2)
        addq.w #1,M4_FACE_COUNT
        move.l (sp)+,d0
        rts
M4RadioRecordFull: ;face buffer full: the record is dropped (counted)
        lea M4_RD_SCRATCH,a2
        addq.w #1,INTRO_DIAG+14
        move.l (sp)+,d0
        rts
M4_RD_SCRATCH equ $ff5580
M4RadioMeterBox: ;x, y, w, h
        include '../build/m4-radio-meter-box.inc'
        include '../build/level-radio.inc'
