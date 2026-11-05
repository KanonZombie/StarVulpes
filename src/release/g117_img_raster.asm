; graphics117 IRAM image (raster): 968 WORDs, loaded at IRAM word $020 by
; its stage loader in g117_svp.asm; included by g117_rom.asm. Local labels
; are IRAM byte addresses (obj). Generated once from the Nomad-measured 117
; image; copied program ranges are checked by tools/check-g117-copies.py.
        obj $40
@IntroTriangle:
        dc.w $e003                   ; eor a,a
        dc.w $0644                   ; ld a,($044)
        dc.w $2642                   ; sub a,($042)
        dc.w $0ecd                   ; ld ($0cd),a
        dc.w $0645                   ; ld a,($045)
        dc.w $2641                   ; sub a,($041)
        dc.w $0ece                   ; ld ($0ce),a
        dc.w $18cd                   ; ld r0,#$cd
        dc.w $19ce                   ; ld r1,#$ce
        dc.w $0643                   ; ld a,($043)
        dc.w $2641                   ; sub a,($041)
        dc.w $0013                   ; ld x,a
        dc.w $0646                   ; ld a,($046)
        dc.w $2642                   ; sub a,($042)
        dc.w $0023                   ; ld y,a
        dc.w $0037                   ; ld a,p
        dc.w $0210                   ; ld x,(r0)
        dc.w $0221                   ; ld y,(r1)
        dc.w $2007                   ; sub a,p
        dc.w $4d70,SVP_IntroTriangleSlow/2 ; bra n=1,$0fa9
        dc.w $4d50,SVP_IntroTriangleSlow/2 ; bra z=1,$0fa9
        dc.w $0641                   ; ld a,($041)
        dc.w $0ea0                   ; ld ($0a0),a
        dc.w $0642                   ; ld a,($042)
        dc.w $0ea1                   ; ld ($0a1),a
        dc.w $0643                   ; ld a,($043)
        dc.w $0ea2                   ; ld ($0a2),a
        dc.w $0644                   ; ld a,($044)
        dc.w $0ea3                   ; ld ($0a3),a
        dc.w $0645                   ; ld a,($045)
        dc.w $0ea4                   ; ld ($0a4),a
        dc.w $0646                   ; ld a,($046)
        dc.w $0ea5                   ; ld ($0a5),a
        dc.w $e003                   ; eor a,a
        dc.w $9801                   ; addi a,#$01
        dc.w $0ec2                   ; ld ($0c2),a
        dc.w $e003                   ; eor a,a
        dc.w $06a3                   ; ld a,($0a3)
        dc.w $26a1                   ; sub a,($0a1)
        dc.w $4c70,@TriSorted1/2           ; bra n=0,$005a
        dc.w $06a0                   ; ld a,($0a0)
        dc.w $0013                   ; ld x,a
        dc.w $06a2                   ; ld a,($0a2)
        dc.w $0ea0                   ; ld ($0a0),a
        dc.w $0031                   ; ld a,x
        dc.w $0ea2                   ; ld ($0a2),a
        dc.w $06a1                   ; ld a,($0a1)
        dc.w $0013                   ; ld x,a
        dc.w $06a3                   ; ld a,($0a3)
        dc.w $0ea1                   ; ld ($0a1),a
        dc.w $0031                   ; ld a,x
        dc.w $0ea3                   ; ld ($0a3),a
        dc.w $06c2                   ; ld a,($0c2)
        dc.w $f801                   ; eori a,#$01
        dc.w $0ec2                   ; ld ($0c2),a
@TriSorted1:
        dc.w $e003                   ; eor a,a
        dc.w $06a5                   ; ld a,($0a5)
        dc.w $26a3                   ; sub a,($0a3)
        dc.w $4c70,@TriSorted2/2           ; bra n=0,$006e
        dc.w $06a2                   ; ld a,($0a2)
        dc.w $0013                   ; ld x,a
        dc.w $06a4                   ; ld a,($0a4)
        dc.w $0ea2                   ; ld ($0a2),a
        dc.w $0031                   ; ld a,x
        dc.w $0ea4                   ; ld ($0a4),a
        dc.w $06a3                   ; ld a,($0a3)
        dc.w $0013                   ; ld x,a
        dc.w $06a5                   ; ld a,($0a5)
        dc.w $0ea3                   ; ld ($0a3),a
        dc.w $0031                   ; ld a,x
        dc.w $0ea5                   ; ld ($0a5),a
        dc.w $06c2                   ; ld a,($0c2)
        dc.w $f801                   ; eori a,#$01
        dc.w $0ec2                   ; ld ($0c2),a
@TriSorted2:
        dc.w $e003                   ; eor a,a
        dc.w $06a3                   ; ld a,($0a3)
        dc.w $26a1                   ; sub a,($0a1)
        dc.w $4c70,@TriSorted3/2           ; bra n=0,$0082
        dc.w $06a0                   ; ld a,($0a0)
        dc.w $0013                   ; ld x,a
        dc.w $06a2                   ; ld a,($0a2)
        dc.w $0ea0                   ; ld ($0a0),a
        dc.w $0031                   ; ld a,x
        dc.w $0ea2                   ; ld ($0a2),a
        dc.w $06a1                   ; ld a,($0a1)
        dc.w $0013                   ; ld x,a
        dc.w $06a3                   ; ld a,($0a3)
        dc.w $0ea1                   ; ld ($0a1),a
        dc.w $0031                   ; ld a,x
        dc.w $0ea3                   ; ld ($0a3),a
        dc.w $06c2                   ; ld a,($0c2)
        dc.w $f801                   ; eori a,#$01
        dc.w $0ec2                   ; ld ($0c2),a
@TriSorted3:
        dc.w $e003                   ; eor a,a
        dc.w $06a5                   ; ld a,($0a5)
        dc.w $26a1                   ; sub a,($0a1)
        dc.w $0eac                   ; ld ($0ac),a
        dc.w $0ec9                   ; ld ($0c9),a
        dc.w $06a0                   ; ld a,($0a0)
        dc.w $0ea8                   ; ld ($0a8),a
        dc.w $e003                   ; eor a,a
        dc.w $06a4                   ; ld a,($0a4)
        dc.w $26a0                   ; sub a,($0a0)
        dc.w $0ecc                   ; ld ($0cc),a
        dc.w $9007                   ; mod7 cond$000
        dc.w $0ec8                   ; ld ($0c8),a
        dc.w $4800,@TriDiv/2               ; call always,$01fe
        dc.w $e003                   ; eor a,a
        dc.w $06cc                   ; ld a,($0cc)
        dc.w $7800                   ; cmpi a,#$00
        dc.w $4d70,@TriNeg4/2              ; bra n=1,$009c
        dc.w $06ca                   ; ld a,($0ca)
        dc.w $0eaa                   ; ld ($0aa),a
        dc.w $06cb                   ; ld a,($0cb)
        dc.w $0eab                   ; ld ($0ab),a
        dc.w $4c00,@TriStep6/2             ; bra always,$00b0
@TriNeg4:
        dc.w $e003                   ; eor a,a
        dc.w $06cb                   ; ld a,($0cb)
        dc.w $7800                   ; cmpi a,#$00
        dc.w $4d50,@TriZero5/2             ; bra z=1,$00aa
        dc.w $06ca                   ; ld a,($0ca)
        dc.w $9006                   ; mod6 cond$000
        dc.w $3801                   ; subi a,#$01
        dc.w $0eaa                   ; ld ($0aa),a
        dc.w $06ac                   ; ld a,($0ac)
        dc.w $26cb                   ; sub a,($0cb)
        dc.w $0eab                   ; ld ($0ab),a
        dc.w $4c00,@TriStep6/2             ; bra always,$00b0
@TriZero5:
        dc.w $e003                   ; eor a,a
        dc.w $06ca                   ; ld a,($0ca)
        dc.w $9006                   ; mod6 cond$000
        dc.w $0eaa                   ; ld ($0aa),a
        dc.w $e003                   ; eor a,a
        dc.w $0eab                   ; ld ($0ab),a
@TriStep6:
        dc.w $e003                   ; eor a,a
        dc.w $06c2                   ; ld a,($0c2)
        dc.w $7801                   ; cmpi a,#$01
        dc.w $4d50,@TriCeil7/2             ; bra z=1,$00bb
        dc.w $e003                   ; eor a,a
        dc.w $06ac                   ; ld a,($0ac)
        dc.w $9006                   ; mod6 cond$000
        dc.w $0ea9                   ; ld ($0a9),a
        dc.w $4c00,@TriReady8/2            ; bra always,$00bf
@TriCeil7:
        dc.w $e003                   ; eor a,a
        dc.w $0830,$ffff             ; ld a,#$ffff
        dc.w $0ea9                   ; ld ($0a9),a
@TriReady8:
        dc.w $e003                   ; eor a,a
        dc.w $06a3                   ; ld a,($0a3)
        dc.w $26a5                   ; sub a,($0a5)
        dc.w $4d50,@TriOnePhase/2          ; bra z=1,$00e1
        dc.w $e003                   ; eor a,a
        dc.w $06a3                   ; ld a,($0a3)
        dc.w $26a1                   ; sub a,($0a1)
        dc.w $4d50,@TriFlatTop/2           ; bra z=1,$00f6
        dc.w $e003                   ; eor a,a
        dc.w $06a3                   ; ld a,($0a3)
        dc.w $26a1                   ; sub a,($0a1)
        dc.w $0eb4                   ; ld ($0b4),a
        dc.w $0ec9                   ; ld ($0c9),a
        dc.w $06a0                   ; ld a,($0a0)
        dc.w $0eb0                   ; ld ($0b0),a
        dc.w $e003                   ; eor a,a
        dc.w $06a2                   ; ld a,($0a2)
        dc.w $26a0                   ; sub a,($0a0)
        dc.w $0ecc                   ; ld ($0cc),a
        dc.w $9007                   ; mod7 cond$000
        dc.w $0ec8                   ; ld ($0c8),a
        dc.w $4800,@TriShortSetup/2        ; call always,$0223
        dc.w $e003                   ; eor a,a
        dc.w $06a3                   ; ld a,($0a3)
        dc.w $3801                   ; subi a,#$01
        dc.w $0ec1                   ; ld ($0c1),a
        dc.w $0830,$0001             ; ld a,#$0001
        dc.w $0ecf                   ; ld ($0cf),a
        dc.w $4c00,@TriStart/2             ; bra always,$0109
@TriOnePhase:
        dc.w $e003                   ; eor a,a
        dc.w $06a3                   ; ld a,($0a3)
        dc.w $26a1                   ; sub a,($0a1)
        dc.w $0eb4                   ; ld ($0b4),a
        dc.w $0ec9                   ; ld ($0c9),a
        dc.w $06a0                   ; ld a,($0a0)
        dc.w $0eb0                   ; ld ($0b0),a
        dc.w $e003                   ; eor a,a
        dc.w $06a2                   ; ld a,($0a2)
        dc.w $26a0                   ; sub a,($0a0)
        dc.w $0ecc                   ; ld ($0cc),a
        dc.w $9007                   ; mod7 cond$000
        dc.w $0ec8                   ; ld ($0c8),a
        dc.w $4800,@TriShortSetup/2        ; call always,$0223
        dc.w $06a5                   ; ld a,($0a5)
        dc.w $0ec1                   ; ld ($0c1),a
        dc.w $e003                   ; eor a,a
        dc.w $0ecf                   ; ld ($0cf),a
        dc.w $4c00,@TriStart/2             ; bra always,$0109
@TriFlatTop:
        dc.w $e003                   ; eor a,a
        dc.w $06a5                   ; ld a,($0a5)
        dc.w $26a3                   ; sub a,($0a3)
        dc.w $0eb4                   ; ld ($0b4),a
        dc.w $0ec9                   ; ld ($0c9),a
        dc.w $06a2                   ; ld a,($0a2)
        dc.w $0eb0                   ; ld ($0b0),a
        dc.w $e003                   ; eor a,a
        dc.w $06a4                   ; ld a,($0a4)
        dc.w $26a2                   ; sub a,($0a2)
        dc.w $0ecc                   ; ld ($0cc),a
        dc.w $9007                   ; mod7 cond$000
        dc.w $0ec8                   ; ld ($0c8),a
        dc.w $4800,@TriShortSetup/2        ; call always,$0223
        dc.w $06a5                   ; ld a,($0a5)
        dc.w $0ec1                   ; ld ($0c1),a
        dc.w $e003                   ; eor a,a
        dc.w $0ecf                   ; ld ($0cf),a
@TriStart:
        dc.w $06a1                   ; ld a,($0a1)
        dc.w $0ec0                   ; ld ($0c0),a
        dc.w $4800,@TriOrient/2            ; call always,$0258
        dc.w $4c00,@TriRow0/2              ; bra always,$010f
@TriRow0:
        dc.w $e003                   ; eor a,a
        dc.w $06c0                   ; ld a,($0c0)
        dc.w $6800,$00d0             ; cmp a,#$00d0
        dc.w $4c70,@TriClippedDone/2       ; bra n=0,$0254
        dc.w $6800,$0010             ; cmp a,#$0010
        dc.w $4d70,@TriSkip0/2             ; bra n=1,$01a4
        dc.w $06a8                   ; ld a,($0a8)
        dc.w $26b0                   ; sub a,($0b0)
        dc.w $4d70,@TriSkip0/2             ; bra n=1,$01a4
        dc.w $e003                   ; eor a,a
        dc.w $06b0                   ; ld a,($0b0)
        dc.w $8800,SVP_TriCol/2            ; add a,#$180f (table base)
        dc.w $4a20                   ; ld y,((a))
        dc.w $06c0                   ; ld a,($0c0)
        dc.w $8800,SVP_TriRowBase/2        ; add a,#$164f (table base)
        dc.w $4a30                   ; ld a,((a))
        dc.w $86f6                   ; add a,($0f6)
        dc.w $8002                   ; add a,y
        dc.w $00e3                   ; ld pmc,a
        dc.w $08e0,$4418             ; ld pmc,#$4418
        dc.w $00c0                   ; ld pm4,-
        dc.w $e003                   ; eor a,a
        dc.w $06c0                   ; ld a,($0c0)
        dc.w $b801                   ; andi a,#$01
        dc.w $4c50,@TriOddRow9/2           ; bra z=0,$0134
        dc.w $06d2                   ; ld a,($0d2)
        dc.w $4c00,@TriRowColour10/2       ; bra always,$0135
@TriOddRow9:
        dc.w $06d3                   ; ld a,($0d3)
@TriRowColour10:
        dc.w $0e13                   ; ld ($013),a
        dc.w $e003                   ; eor a,a
        dc.w $06b0                   ; ld a,($0b0)
        dc.w $b803                   ; andi a,#$03
        dc.w $8800,@PackedLeftMasks/2      ; add a,#$03dd (IRAM base)
        dc.w $4a10                   ; ld x,((a))
        dc.w $0613                   ; ld a,($013)
        dc.w $a001                   ; and a,x
        dc.w $0013                   ; ld x,a
        dc.w $06b0                   ; ld a,($0b0)
        dc.w $9002                   ; mod2 cond$000
        dc.w $9002                   ; mod2 cond$000
        dc.w $0023                   ; ld y,a
        dc.w $06a8                   ; ld a,($0a8)
        dc.w $9002                   ; mod2 cond$000
        dc.w $9002                   ; mod2 cond$000
        dc.w $a800,$ffff             ; and a,#$ffff
        dc.w $2002                   ; sub a,y
        dc.w $4d50,@TriSingle0/2           ; bra z=1,$019d
        dc.w $00c1                   ; ld pm4,x
        dc.w $9006                   ; mod6 cond$000
        dc.w $8800,@TriFillEnd0/2+1        ; add a,#$019b (IRAM base)
        dc.w $0ed0                   ; ld ($0d0),a
        dc.w $06a8                   ; ld a,($0a8)
        dc.w $b803                   ; andi a,#$03
        dc.w $8800,@PackedRightMasks/2     ; add a,#$03e1 (IRAM base)
        dc.w $4a10                   ; ld x,((a))
        dc.w $0613                   ; ld a,($013)
        dc.w $a001                   ; and a,x
        dc.w $0013                   ; ld x,a
        dc.w $0613                   ; ld a,($013)
        dc.w $0023                   ; ld y,a
        dc.w $06d0                   ; ld a,($0d0)
        dc.w $0063                   ; ld pc,a
        dc.w $00c2                   ; ld pm4,y
        dc.w $00c2                   ; ld pm4,y
        dc.w $00c2                   ; ld pm4,y
        dc.w $00c2                   ; ld pm4,y
        dc.w $00c2                   ; ld pm4,y
        dc.w $00c2                   ; ld pm4,y
        dc.w $00c2                   ; ld pm4,y
        dc.w $00c2                   ; ld pm4,y
        dc.w $00c2                   ; ld pm4,y
        dc.w $00c2                   ; ld pm4,y
        dc.w $00c2                   ; ld pm4,y
        dc.w $00c2                   ; ld pm4,y
        dc.w $00c2                   ; ld pm4,y
        dc.w $00c2                   ; ld pm4,y
        dc.w $00c2                   ; ld pm4,y
        dc.w $00c2                   ; ld pm4,y
        dc.w $00c2                   ; ld pm4,y
        dc.w $00c2                   ; ld pm4,y
        dc.w $00c2                   ; ld pm4,y
        dc.w $00c2                   ; ld pm4,y
        dc.w $00c2                   ; ld pm4,y
        dc.w $00c2                   ; ld pm4,y
        dc.w $00c2                   ; ld pm4,y
        dc.w $00c2                   ; ld pm4,y
        dc.w $00c2                   ; ld pm4,y
        dc.w $00c2                   ; ld pm4,y
        dc.w $00c2                   ; ld pm4,y
        dc.w $00c2                   ; ld pm4,y
        dc.w $00c2                   ; ld pm4,y
        dc.w $00c2                   ; ld pm4,y
        dc.w $00c2                   ; ld pm4,y
        dc.w $00c2                   ; ld pm4,y
        dc.w $00c2                   ; ld pm4,y
        dc.w $00c2                   ; ld pm4,y
        dc.w $00c2                   ; ld pm4,y
        dc.w $00c2                   ; ld pm4,y
        dc.w $00c2                   ; ld pm4,y
        dc.w $00c2                   ; ld pm4,y
        dc.w $00c2                   ; ld pm4,y
        dc.w $00c2                   ; ld pm4,y
        dc.w $00c2                   ; ld pm4,y
        dc.w $00c2                   ; ld pm4,y
        dc.w $00c2                   ; ld pm4,y
        dc.w $00c2                   ; ld pm4,y
        dc.w $00c2                   ; ld pm4,y
        dc.w $00c2                   ; ld pm4,y
        dc.w $00c2                   ; ld pm4,y
        dc.w $00c2                   ; ld pm4,y
        dc.w $00c2                   ; ld pm4,y
        dc.w $00c2                   ; ld pm4,y
        dc.w $00c2                   ; ld pm4,y
        dc.w $00c2                   ; ld pm4,y
        dc.w $00c2                   ; ld pm4,y
        dc.w $00c2                   ; ld pm4,y
        dc.w $00c2                   ; ld pm4,y
        dc.w $00c2                   ; ld pm4,y
        dc.w $00c2                   ; ld pm4,y
        dc.w $00c2                   ; ld pm4,y
        dc.w $00c2                   ; ld pm4,y
        dc.w $00c2                   ; ld pm4,y
        dc.w $00c2                   ; ld pm4,y
        dc.w $00c2                   ; ld pm4,y
@TriFillEnd0:
        dc.w $00c1                   ; ld pm4,x
        dc.w $4c00,@TriSkip0/2             ; bra always,$01a4
@TriSingle0:
        dc.w $06a8                   ; ld a,($0a8)
        dc.w $b803                   ; andi a,#$03
        dc.w $8800,@PackedRightMasks/2     ; add a,#$03e1 (IRAM base)
        dc.w $4a30                   ; ld a,((a))
        dc.w $a001                   ; and a,x
        dc.w $00c3                   ; ld pm4,a
@TriSkip0:
        dc.w $e003                   ; eor a,a
        dc.w $06c0                   ; ld a,($0c0)
        dc.w $26c1                   ; sub a,($0c1)
        dc.w $4d50,@TriPhaseEnd/2          ; bra z=1,$01cc
        dc.w $06c0                   ; ld a,($0c0)
        dc.w $9801                   ; addi a,#$01
        dc.w $0ec0                   ; ld ($0c0),a
        dc.w $06b1                   ; ld a,($0b1)
        dc.w $86b3                   ; add a,($0b3)
        dc.w $4d70,@TriCarry11/2           ; bra n=1,$01b7
        dc.w $26b4                   ; sub a,($0b4)
        dc.w $0eb1                   ; ld ($0b1),a
        dc.w $06b0                   ; ld a,($0b0)
        dc.w $86b2                   ; add a,($0b2)
        dc.w $9801                   ; addi a,#$01
        dc.w $4c00,@TriStepped12/2         ; bra always,$01ba
@TriCarry11:
        dc.w $0eb1                   ; ld ($0b1),a
        dc.w $06b0                   ; ld a,($0b0)
        dc.w $86b2                   ; add a,($0b2)
@TriStepped12:
        dc.w $0eb0                   ; ld ($0b0),a
        dc.w $06a9                   ; ld a,($0a9)
        dc.w $86ab                   ; add a,($0ab)
        dc.w $4d70,@TriCarry13/2           ; bra n=1,$01c6
        dc.w $26ac                   ; sub a,($0ac)
        dc.w $0ea9                   ; ld ($0a9),a
        dc.w $06a8                   ; ld a,($0a8)
        dc.w $86aa                   ; add a,($0aa)
        dc.w $9801                   ; addi a,#$01
        dc.w $4c00,@TriStepped14/2         ; bra always,$01c9
@TriCarry13:
        dc.w $0ea9                   ; ld ($0a9),a
        dc.w $06a8                   ; ld a,($0a8)
        dc.w $86aa                   ; add a,($0aa)
@TriStepped14:
        dc.w $0ea8                   ; ld ($0a8),a
        dc.w $4c00,@TriRow0/2              ; bra always,$010f
@TriPhaseEnd:
        dc.w $4800,@TriOrient/2            ; call always,$0258
        dc.w $e003                   ; eor a,a
        dc.w $06cf                   ; ld a,($0cf)
        dc.w $7800                   ; cmpi a,#$00
        dc.w $4d50,@TriDone/2              ; bra z=1,$01fc
        dc.w $e003                   ; eor a,a
        dc.w $0ecf                   ; ld ($0cf),a
        dc.w $06a5                   ; ld a,($0a5)
        dc.w $0ec1                   ; ld ($0c1),a
        dc.w $06c0                   ; ld a,($0c0)
        dc.w $9801                   ; addi a,#$01
        dc.w $0ec0                   ; ld ($0c0),a
        dc.w $06a9                   ; ld a,($0a9)
        dc.w $86ab                   ; add a,($0ab)
        dc.w $4d70,@TriCarry15/2           ; bra n=1,$01e5
        dc.w $26ac                   ; sub a,($0ac)
        dc.w $0ea9                   ; ld ($0a9),a
        dc.w $06a8                   ; ld a,($0a8)
        dc.w $86aa                   ; add a,($0aa)
        dc.w $9801                   ; addi a,#$01
        dc.w $4c00,@TriStepped16/2         ; bra always,$01e8
@TriCarry15:
        dc.w $0ea9                   ; ld ($0a9),a
        dc.w $06a8                   ; ld a,($0a8)
        dc.w $86aa                   ; add a,($0aa)
@TriStepped16:
        dc.w $0ea8                   ; ld ($0a8),a
        dc.w $e003                   ; eor a,a
        dc.w $06a5                   ; ld a,($0a5)
        dc.w $26a3                   ; sub a,($0a3)
        dc.w $0eb4                   ; ld ($0b4),a
        dc.w $0ec9                   ; ld ($0c9),a
        dc.w $06a2                   ; ld a,($0a2)
        dc.w $0eb0                   ; ld ($0b0),a
        dc.w $e003                   ; eor a,a
        dc.w $06a4                   ; ld a,($0a4)
        dc.w $26a2                   ; sub a,($0a2)
        dc.w $0ecc                   ; ld ($0cc),a
        dc.w $9007                   ; mod7 cond$000
        dc.w $0ec8                   ; ld ($0c8),a
        dc.w $4800,@TriShortSetup/2        ; call always,$0223
        dc.w $4800,@TriOrient/2            ; call always,$0258
        dc.w $4c00,@TriRow0/2              ; bra always,$010f
@TriDone:
        dc.w $4c00,SVP_IntroNextPrimitive/2; bra always,$1446
@TriDiv:
        dc.w $e003                   ; eor a,a
        dc.w $06c9                   ; ld a,($0c9)
        dc.w $7801                   ; cmpi a,#$01
        dc.w $4d50,@TriDivOne/2            ; bra z=1,$021e
        dc.w $8800,SVP_TriDivM/2           ; add a,#$1c0f (table base)
        dc.w $4a20                   ; ld y,((a))
        dc.w $06c8                   ; ld a,($0c8)
        dc.w $0013                   ; ld x,a
        dc.w $0037                   ; ld a,p
        dc.w $0eca                   ; ld ($0ca),a
        dc.w $0013                   ; ld x,a
        dc.w $06c9                   ; ld a,($0c9)
        dc.w $0023                   ; ld y,a
        dc.w $0037                   ; ld a,p
        dc.w $003f                   ; ld a,al
        dc.w $9002                   ; mod2 cond$000
        dc.w $0ecb                   ; ld ($0cb),a
        dc.w $e003                   ; eor a,a
        dc.w $06c8                   ; ld a,($0c8)
        dc.w $26cb                   ; sub a,($0cb)
        dc.w $4d70,@TriDivFix/2            ; bra n=1,$0218
        dc.w $0ecb                   ; ld ($0cb),a
        dc.w $0065                   ; ld pc,stack
@TriDivFix:
        dc.w $86c9                   ; add a,($0c9)
        dc.w $0ecb                   ; ld ($0cb),a
        dc.w $06ca                   ; ld a,($0ca)
        dc.w $3801                   ; subi a,#$01
        dc.w $0eca                   ; ld ($0ca),a
        dc.w $0065                   ; ld pc,stack
@TriDivOne:
        dc.w $06c8                   ; ld a,($0c8)
        dc.w $0eca                   ; ld ($0ca),a
        dc.w $e003                   ; eor a,a
        dc.w $0ecb                   ; ld ($0cb),a
        dc.w $0065                   ; ld pc,stack
@TriShortSetup:
        dc.w $4800,@TriDiv/2               ; call always,$01fe
        dc.w $e003                   ; eor a,a
        dc.w $06cc                   ; ld a,($0cc)
        dc.w $7800                   ; cmpi a,#$00
        dc.w $4d70,@TriNeg17/2             ; bra n=1,$0230
        dc.w $06ca                   ; ld a,($0ca)
        dc.w $0eb2                   ; ld ($0b2),a
        dc.w $06cb                   ; ld a,($0cb)
        dc.w $0eb3                   ; ld ($0b3),a
        dc.w $4c00,@TriStep19/2            ; bra always,$0244
@TriNeg17:
        dc.w $e003                   ; eor a,a
        dc.w $06cb                   ; ld a,($0cb)
        dc.w $7800                   ; cmpi a,#$00
        dc.w $4d50,@TriZero18/2            ; bra z=1,$023e
        dc.w $06ca                   ; ld a,($0ca)
        dc.w $9006                   ; mod6 cond$000
        dc.w $3801                   ; subi a,#$01
        dc.w $0eb2                   ; ld ($0b2),a
        dc.w $06b4                   ; ld a,($0b4)
        dc.w $26cb                   ; sub a,($0cb)
        dc.w $0eb3                   ; ld ($0b3),a
        dc.w $4c00,@TriStep19/2            ; bra always,$0244
@TriZero18:
        dc.w $e003                   ; eor a,a
        dc.w $06ca                   ; ld a,($0ca)
        dc.w $9006                   ; mod6 cond$000
        dc.w $0eb2                   ; ld ($0b2),a
        dc.w $e003                   ; eor a,a
        dc.w $0eb3                   ; ld ($0b3),a
@TriStep19:
        dc.w $e003                   ; eor a,a
        dc.w $06c2                   ; ld a,($0c2)
        dc.w $7800                   ; cmpi a,#$00
        dc.w $4d50,@TriCeil20/2            ; bra z=1,$024f
        dc.w $e003                   ; eor a,a
        dc.w $06b4                   ; ld a,($0b4)
        dc.w $9006                   ; mod6 cond$000
        dc.w $0eb1                   ; ld ($0b1),a
        dc.w $4c00,@TriReady21/2           ; bra always,$0253
@TriCeil20:
        dc.w $e003                   ; eor a,a
        dc.w $0830,$ffff             ; ld a,#$ffff
        dc.w $0eb1                   ; ld ($0b1),a
@TriReady21:
        dc.w $0065                   ; ld pc,stack
@TriClippedDone:
        dc.w $4800,@TriOrient/2            ; call always,$0258
        dc.w $4c00,@TriDone/2              ; bra always,$01fc
@TriOrient:
        dc.w $e003                   ; eor a,a
        dc.w $06c2                   ; ld a,($0c2)
        dc.w $7800                   ; cmpi a,#$00
        dc.w $4d50,@TriOrientEnd/2         ; bra z=1,$027b
        dc.w $06a8                   ; ld a,($0a8)
        dc.w $0013                   ; ld x,a
        dc.w $06b0                   ; ld a,($0b0)
        dc.w $0ea8                   ; ld ($0a8),a
        dc.w $0031                   ; ld a,x
        dc.w $0eb0                   ; ld ($0b0),a
        dc.w $06a9                   ; ld a,($0a9)
        dc.w $0013                   ; ld x,a
        dc.w $06b1                   ; ld a,($0b1)
        dc.w $0ea9                   ; ld ($0a9),a
        dc.w $0031                   ; ld a,x
        dc.w $0eb1                   ; ld ($0b1),a
        dc.w $06aa                   ; ld a,($0aa)
        dc.w $0013                   ; ld x,a
        dc.w $06b2                   ; ld a,($0b2)
        dc.w $0eaa                   ; ld ($0aa),a
        dc.w $0031                   ; ld a,x
        dc.w $0eb2                   ; ld ($0b2),a
        dc.w $06ab                   ; ld a,($0ab)
        dc.w $0013                   ; ld x,a
        dc.w $06b3                   ; ld a,($0b3)
        dc.w $0eab                   ; ld ($0ab),a
        dc.w $0031                   ; ld a,x
        dc.w $0eb3                   ; ld ($0b3),a
        dc.w $06ac                   ; ld a,($0ac)
        dc.w $0013                   ; ld x,a
        dc.w $06b4                   ; ld a,($0b4)
        dc.w $0eac                   ; ld ($0ac),a
        dc.w $0031                   ; ld a,x
        dc.w $0eb4                   ; ld ($0b4),a
@TriOrientEnd:
        dc.w $0065                   ; ld pc,stack
@RadioPackedSpan:
        dc.w $4800,@RadioPackedAddress/2   ; call always,$0284
        dc.w $00e3                   ; ld pmc,a
        dc.w $08e0,$4418             ; ld pmc,#$4418
        dc.w $00c0                   ; ld pm4,-
        dc.w $4c00,@RadioPackedBegin/2     ; bra always,$02a6
@RadioPackedAddress:
        dc.w $e003                   ; eor a,a
        dc.w $07d1                   ; ld a,($1d1)
        dc.w $a800,$fff0             ; and a,#$fff0
        dc.w $9003                   ; mod3 cond$000
        dc.w $9003                   ; mod3 cond$000
        dc.w $9003                   ; mod3 cond$000
        dc.w $9003                   ; mod3 cond$000
        dc.w $9003                   ; mod3 cond$000
        dc.w $9003                   ; mod3 cond$000
        dc.w $0fd3                   ; ld ($1d3),a
        dc.w $e003                   ; eor a,a
        dc.w $07d1                   ; ld a,($1d1)
        dc.w $b80f                   ; andi a,#$0f
        dc.w $9003                   ; mod3 cond$000
        dc.w $87d3                   ; add a,($1d3)
        dc.w $0fd3                   ; ld ($1d3),a
        dc.w $e003                   ; eor a,a
        dc.w $07d0                   ; ld a,($1d0)
        dc.w $a800,$fff8             ; and a,#$fff8
        dc.w $9003                   ; mod3 cond$000
        dc.w $9003                   ; mod3 cond$000
        dc.w $87d3                   ; add a,($1d3)
        dc.w $0fd3                   ; ld ($1d3),a
        dc.w $e003                   ; eor a,a
        dc.w $07d0                   ; ld a,($1d0)
        dc.w $b804                   ; andi a,#$04
        dc.w $9002                   ; mod2 cond$000
        dc.w $9002                   ; mod2 cond$000
        dc.w $87d3                   ; add a,($1d3)
        dc.w $86f6                   ; add a,($0f6)
        dc.w $0fd3                   ; ld ($1d3),a
        dc.w $0065                   ; ld pc,stack
@RadioPackedBegin:
        dc.w $e003                   ; eor a,a
        dc.w $07d9                   ; ld a,($1d9)
        dc.w $8800,G117RadioWidthMasks/2   ; add a,#$ae0b (table base)
        dc.w $4a30                   ; ld a,((a))
        dc.w $a7d8                   ; and a,($1d8)
        dc.w $0fd8                   ; ld ($1d8),a
        dc.w $e003                   ; eor a,a
        dc.w $07d2                   ; ld a,($1d2)
        dc.w $9003                   ; mod3 cond$000
        dc.w $9003                   ; mod3 cond$000
        dc.w $9003                   ; mod3 cond$000
        dc.w $9003                   ; mod3 cond$000
        dc.w $0fd6                   ; ld ($1d6),a
        dc.w $e003                   ; eor a,a
        dc.w $07d0                   ; ld a,($1d0)
        dc.w $b803                   ; andi a,#$03
        dc.w $0fd4                   ; ld ($1d4),a
        dc.w $7800                   ; cmpi a,#$00
        dc.w $4d50,@RadioPackedLoop/2      ; bra z=1,$02fd
        dc.w $7801                   ; cmpi a,#$01
        dc.w $4d50,@RadioPackedFirst1/2    ; bra z=1,$02c3
        dc.w $7802                   ; cmpi a,#$02
        dc.w $4d50,@RadioPackedFirst2/2    ; bra z=1,$02d4
        dc.w $4c00,@RadioPackedFirst3/2    ; bra always,$02e7
@RadioPackedFirst1:
        dc.w $4800,@RadioPackedDecode/2    ; call always,$030b
        dc.w $9002                   ; mod2 cond$000
        dc.w $9002                   ; mod2 cond$000
        dc.w $9002                   ; mod2 cond$000
        dc.w $9002                   ; mod2 cond$000
        dc.w $a800,$0fff             ; and a,#$0fff
        dc.w $00c3                   ; ld pm4,a
        dc.w $e003                   ; eor a,a
        dc.w $07d8                   ; ld a,($1d8)
        dc.w $9003                   ; mod3 cond$000
        dc.w $9003                   ; mod3 cond$000
        dc.w $9003                   ; mod3 cond$000
        dc.w $0fd8                   ; ld ($1d8),a
        dc.w $4c00,@RadioPackedTest/2      ; bra always,$0307
@RadioPackedFirst2:
        dc.w $4800,@RadioPackedDecode/2    ; call always,$030b
        dc.w $9002                   ; mod2 cond$000
        dc.w $9002                   ; mod2 cond$000
        dc.w $9002                   ; mod2 cond$000
        dc.w $9002                   ; mod2 cond$000
        dc.w $9002                   ; mod2 cond$000
        dc.w $9002                   ; mod2 cond$000
        dc.w $9002                   ; mod2 cond$000
        dc.w $9002                   ; mod2 cond$000
        dc.w $b8ff                   ; andi a,#$ff
        dc.w $00c3                   ; ld pm4,a
        dc.w $e003                   ; eor a,a
        dc.w $07d8                   ; ld a,($1d8)
        dc.w $9003                   ; mod3 cond$000
        dc.w $9003                   ; mod3 cond$000
        dc.w $0fd8                   ; ld ($1d8),a
        dc.w $4c00,@RadioPackedTest/2      ; bra always,$0307
@RadioPackedFirst3:
        dc.w $4800,@RadioPackedDecode/2    ; call always,$030b
        dc.w $9002                   ; mod2 cond$000
        dc.w $9002                   ; mod2 cond$000
        dc.w $9002                   ; mod2 cond$000
        dc.w $9002                   ; mod2 cond$000
        dc.w $9002                   ; mod2 cond$000
        dc.w $9002                   ; mod2 cond$000
        dc.w $9002                   ; mod2 cond$000
        dc.w $9002                   ; mod2 cond$000
        dc.w $9002                   ; mod2 cond$000
        dc.w $9002                   ; mod2 cond$000
        dc.w $9002                   ; mod2 cond$000
        dc.w $9002                   ; mod2 cond$000
        dc.w $b80f                   ; andi a,#$0f
        dc.w $00c3                   ; ld pm4,a
        dc.w $e003                   ; eor a,a
        dc.w $07d8                   ; ld a,($1d8)
        dc.w $9003                   ; mod3 cond$000
        dc.w $0fd8                   ; ld ($1d8),a
        dc.w $4c00,@RadioPackedTest/2      ; bra always,$0307
@RadioPackedLoop:
        dc.w $4800,@RadioPackedDecode/2    ; call always,$030b
        dc.w $00c3                   ; ld pm4,a
        dc.w $e003                   ; eor a,a
        dc.w $07d8                   ; ld a,($1d8)
        dc.w $9003                   ; mod3 cond$000
        dc.w $9003                   ; mod3 cond$000
        dc.w $9003                   ; mod3 cond$000
        dc.w $9003                   ; mod3 cond$000
        dc.w $0fd8                   ; ld ($1d8),a
@RadioPackedTest:
        dc.w $7800                   ; cmpi a,#$00
        dc.w $4c50,@RadioPackedLoop/2      ; bra z=0,$02fd
        dc.w $0065                   ; ld pc,stack
@RadioPackedDecode:
        dc.w $e003                   ; eor a,a
        dc.w $07d8                   ; ld a,($1d8)
        dc.w $0013                   ; ld x,a
        dc.w $0820,$0008             ; ld y,#$0008
        dc.w $0037                   ; ld a,p
        dc.w $b80f                   ; andi a,#$0f
        dc.w $87d6                   ; add a,($1d6)
        dc.w $8800,G117RadioPackedLUT/2    ; add a,#$ad0b (table base)
        dc.w $4a30                   ; ld a,((a))
        dc.w $0065                   ; ld pc,stack
@RadioPackedFace:
        dc.w $e003                   ; eor a,a
        dc.w $0830,$0000             ; ld a,#$0000
        dc.w $0fd7                   ; ld ($1d7),a
        dc.w $e003                   ; eor a,a
        dc.w $0643                   ; ld a,($043)
        dc.w $00e3                   ; ld pmc,a
        dc.w $e003                   ; eor a,a
        dc.w $0644                   ; ld a,($044)
        dc.w $00e3                   ; ld pmc,a
        dc.w $000c                   ; ld -,pm4
        dc.w $e003                   ; eor a,a
        dc.w $0641                   ; ld a,($041)
        dc.w $0fd0                   ; ld ($1d0),a
@RadioPackedFaceRow:
        dc.w $e003                   ; eor a,a
        dc.w $0642                   ; ld a,($042)
        dc.w $87d7                   ; add a,($1d7)
        dc.w $0fd1                   ; ld ($1d1),a
        dc.w $4800,@RadioPackedAddress/2   ; call always,$0284
        dc.w $00e3                   ; ld pmc,a
        dc.w $08e0,$4018             ; ld pmc,#$4018
        dc.w $00c0                   ; ld pm4,-
        dc.w $003c                   ; ld a,pm4
        dc.w $00c3                   ; ld pm4,a
        dc.w $003c                   ; ld a,pm4
        dc.w $00c3                   ; ld pm4,a
        dc.w $003c                   ; ld a,pm4
        dc.w $00c3                   ; ld pm4,a
        dc.w $003c                   ; ld a,pm4
        dc.w $00c3                   ; ld pm4,a
        dc.w $003c                   ; ld a,pm4
        dc.w $00c3                   ; ld pm4,a
        dc.w $003c                   ; ld a,pm4
        dc.w $00c3                   ; ld pm4,a
        dc.w $003c                   ; ld a,pm4
        dc.w $00c3                   ; ld pm4,a
        dc.w $003c                   ; ld a,pm4
        dc.w $00c3                   ; ld pm4,a
        dc.w $e003                   ; eor a,a
        dc.w $07d7                   ; ld a,($1d7)
        dc.w $9801                   ; addi a,#$01
        dc.w $0fd7                   ; ld ($1d7),a
        dc.w $7828                   ; cmpi a,#$28
        dc.w $4c50,@RadioPackedFaceRow/2   ; bra z=0,$0325
        dc.w $0065                   ; ld pc,stack
@RasterPrimitive:
        dc.w $e003                   ; eor a,a
        dc.w $0601                   ; ld a,($001)
        dc.w $00e3                   ; ld pmc,a
        dc.w $08e0,$0818             ; ld pmc,#$0818
        dc.w $000c                   ; ld -,pm4
        dc.w $1840                   ; ld r0,#$40
        dc.w $04c4                   ; ld (r0+!),pm4
        dc.w $04c4                   ; ld (r0+!),pm4
        dc.w $04c4                   ; ld (r0+!),pm4
        dc.w $04c4                   ; ld (r0+!),pm4
        dc.w $04c4                   ; ld (r0+!),pm4
        dc.w $04c4                   ; ld (r0+!),pm4
        dc.w $04c4                   ; ld (r0+!),pm4
        dc.w $04c4                   ; ld (r0+!),pm4
        dc.w $e003                   ; eor a,a
        dc.w $0601                   ; ld a,($001)
        dc.w $9808                   ; addi a,#$08
        dc.w $0e01                   ; ld ($001),a
        dc.w $e003                   ; eor a,a
        dc.w $0640                   ; ld a,($040)
        dc.w $7802                   ; cmpi a,#$02
        dc.w $4d50,@RasterOrdinary/2       ; bra z=1,$0364
        dc.w $7803                   ; cmpi a,#$03
        dc.w $4d50,@RasterOrdinary/2       ; bra z=1,$0364
        dc.w $4c00,SVP_IntroPrimitive/2+35 ; bra always,$0b52
@RasterOrdinary:
        dc.w $0641                   ; ld a,($041)
        dc.w $a800,$ff00             ; and a,#$ff00
        dc.w $4c50,SVP_IntroInvalid/2      ; bra z=0,$162b
        dc.w $0642                   ; ld a,($042)
        dc.w $a800,$ff00             ; and a,#$ff00
        dc.w $4c50,SVP_IntroInvalid/2      ; bra z=0,$162b
        dc.w $e003                   ; eor a,a
        dc.w $0642                   ; ld a,($042)
        dc.w $78e0                   ; cmpi a,#$e0
        dc.w $4c70,SVP_IntroInvalid/2      ; bra n=0,$162b
        dc.w $0643                   ; ld a,($043)
        dc.w $a800,$ff00             ; and a,#$ff00
        dc.w $4c50,SVP_IntroInvalid/2      ; bra z=0,$162b
        dc.w $0644                   ; ld a,($044)
        dc.w $a800,$ff00             ; and a,#$ff00
        dc.w $4c50,SVP_IntroInvalid/2      ; bra z=0,$162b
        dc.w $e003                   ; eor a,a
        dc.w $0644                   ; ld a,($044)
        dc.w $78e0                   ; cmpi a,#$e0
        dc.w $4c70,SVP_IntroInvalid/2      ; bra n=0,$162b
        dc.w $0645                   ; ld a,($045)
        dc.w $a800,$ff00             ; and a,#$ff00
        dc.w $4c50,SVP_IntroInvalid/2      ; bra z=0,$162b
        dc.w $0646                   ; ld a,($046)
        dc.w $a800,$ff00             ; and a,#$ff00
        dc.w $4c50,SVP_IntroInvalid/2      ; bra z=0,$162b
        dc.w $e003                   ; eor a,a
        dc.w $0646                   ; ld a,($046)
        dc.w $78e0                   ; cmpi a,#$e0
        dc.w $4c70,SVP_IntroInvalid/2      ; bra n=0,$162b
        dc.w $0647                   ; ld a,($047)
        dc.w $a800,$ff00             ; and a,#$ff00
        dc.w $4c50,SVP_IntroInvalid/2      ; bra z=0,$162b
        dc.w $e003                   ; eor a,a
        dc.w $0647                   ; ld a,($047)
        dc.w $7800                   ; cmpi a,#$00
        dc.w $4d50,SVP_IntroInvalid/2      ; bra z=1,$162b
        dc.w $e003                   ; eor a,a
        dc.w $0647                   ; ld a,($047)
        dc.w $8800,SVP_DitherEven/2        ; add a,#$1a0f (table base)
        dc.w $4a30                   ; ld a,((a))
        dc.w $0ed2                   ; ld ($0d2),a
        dc.w $0e13                   ; ld ($013),a
        dc.w $e003                   ; eor a,a
        dc.w $0647                   ; ld a,($047)
        dc.w $8800,SVP_DitherOdd/2         ; add a,#$1b0f (table base)
        dc.w $4a30                   ; ld a,((a))
        dc.w $0ed3                   ; ld ($0d3),a
        dc.w $e003                   ; eor a,a
        dc.w $0640                   ; ld a,($040)
        dc.w $7802                   ; cmpi a,#$02
        dc.w $4d50,SVP_IntroLine/2         ; bra z=1,$135e
        dc.w $4c00,@IntroTriangle/2        ; bra always,$0020
@GlyphPC35569:
        dc.w $e003                   ; eor a,a
@GlyphPC35570:
        dc.w $0645                   ; ld a,($045)
@GlyphPC35571:
        dc.w $0fd2                   ; ld ($1d2),a
@GlyphPC35572:
        dc.w $e003                   ; eor a,a
@GlyphPC35573:
        dc.w $0830,$0000             ; ld a,#$0000
@GlyphPC35575:
        dc.w $0fd7                   ; ld ($1d7),a
@GlyphPC35576:
        dc.w $e003                   ; eor a,a
@GlyphPC35577:
        dc.w $0642                   ; ld a,($042)
@GlyphPC35578:
        dc.w $87d7                   ; add a,($1d7)
@GlyphPC35579:
        dc.w $0fd1                   ; ld ($1d1),a
@GlyphPC35580:
        dc.w $e003                   ; eor a,a
@GlyphPC35581:
        dc.w $0830,$00bf             ; ld a,#$00bf
@GlyphPC35583:
        dc.w $27d1                   ; sub a,($1d1)
@GlyphPC35584:
        dc.w $4d70,@GlyphPC35618/2         ; bra n=1,$03dc
@GlyphPC35586:
        dc.w $e003                   ; eor a,a
@GlyphPC35587:
        dc.w $0643                   ; ld a,($043)
@GlyphPC35588:
        dc.w $87d7                   ; add a,($1d7)
@GlyphPC35589:
        dc.w $4a10                   ; ld x,((a))
@GlyphPC35590:
        dc.w $e003                   ; eor a,a
@GlyphPC35591:
        dc.w $0031                   ; ld a,x
@GlyphPC35592:
        dc.w $0fd8                   ; ld ($1d8),a
@GlyphPC35593:
        dc.w $7800                   ; cmpi a,#$00
@GlyphPC35595:
        dc.w $4d50,@GlyphPC35609/2         ; bra z=1,$03d5
@GlyphPC35597:
        dc.w $e003                   ; eor a,a
@GlyphPC35598:
        dc.w $0641                   ; ld a,($041)
@GlyphPC35599:
        dc.w $0fd0                   ; ld ($1d0),a
@GlyphPC35600:
        dc.w $e003                   ; eor a,a
@GlyphPC35601:
        dc.w $0644                   ; ld a,($044)
@GlyphPC35602:
        dc.w $0fd9                   ; ld ($1d9),a
@GlyphPC35603:
        dc.w $7800                   ; cmpi a,#$00
@GlyphPC35605:
        dc.w $4d50,@GlyphPC35609/2         ; bra z=1,$03d5
@GlyphPC35607:
        dc.w $4800,@RadioPackedSpan/2      ; call always,$027c
@GlyphPC35609:
        dc.w $e003                   ; eor a,a
@GlyphPC35610:
        dc.w $07d7                   ; ld a,($1d7)
@GlyphPC35611:
        dc.w $9801                   ; addi a,#$01
@GlyphPC35613:
        dc.w $0fd7                   ; ld ($1d7),a
@GlyphPC35614:
        dc.w $780c                   ; cmpi a,#$0c
@GlyphPC35616:
        dc.w $4c50,@GlyphPC35576/2         ; bra z=0,$03b6
@GlyphPC35618:
        dc.w $0065                   ; ld pc,stack
@PackedLeftMasks:
        dc.w $ffff                   ; ?ffff
        dc.w $0fff                   ; ld ($1ff),a
        dc.w $00ff                   ; ld al,al
        dc.w $000f                   ; ld -,al
@PackedRightMasks:
        dc.w $f000                   ; ?f000
        dc.w $ff00                   ; ?ff00
        dc.w $fff0                   ; ?fff0
        dc.w $ffff                   ; ?ffff
@RasterImageEnd:
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        objend
