; graphics117 IRAM image (faces): 968 WORDs, loaded at IRAM word $020 by
; its stage loader in g117_svp.asm; included by g117_rom.asm. Local labels
; are IRAM byte addresses (obj). Generated once from the Nomad-measured 117
; image; copied program ranges are checked by tools/check-g117-copies.py.
        obj $40
@L020:
        dc.w $e003                   ; eor a,a
        dc.w $0601                   ; ld a,($001)
        dc.w $00e3                   ; ld pmc,a
        dc.w $08e0,$0818             ; ld pmc,#$0818
        dc.w $000c                   ; ld -,pm4
        dc.w $1860                   ; ld r0,#$60
        dc.w $04c4                   ; ld (r0+!),pm4
        dc.w $04c4                   ; ld (r0+!),pm4
        dc.w $04c4                   ; ld (r0+!),pm4
        dc.w $04c4                   ; ld (r0+!),pm4
        dc.w $04c4                   ; ld (r0+!),pm4
        dc.w $04c4                   ; ld (r0+!),pm4
        dc.w $04c4                   ; ld (r0+!),pm4
        dc.w $04c4                   ; ld (r0+!),pm4
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
        dc.w $8800,$0010             ; add a,#$0010
        dc.w $0e01                   ; ld ($001),a
        dc.w $e003                   ; eor a,a
        dc.w $0663                   ; ld a,($063)
        dc.w $6800,$0009             ; cmp a,#$0009
        dc.w $4d50,G117S01e6a/2            ; bra z=1,$0f35
        dc.w $a800,$8000             ; and a,#$8000
        dc.w $4d50,@L07f/2                 ; bra z=1,$007f
        dc.w $e003                   ; eor a,a
        dc.w $0663                   ; ld a,($063)
        dc.w $6800,$801e             ; cmp a,#$801e
        dc.w $4d50,G117S01e2e/2            ; bra z=1,$0f17
        dc.w $e003                   ; eor a,a
        dc.w $0663                   ; ld a,($063)
        dc.w $6800,$801f             ; cmp a,#$801f
        dc.w $4d50,G117S01de4/2            ; bra z=1,$0ef2
        dc.w $e003                   ; eor a,a
        dc.w $0663                   ; ld a,($063)
        dc.w $6800,$8020             ; cmp a,#$8020
        dc.w $4d50,G117S01de4/2            ; bra z=1,$0ef2
        dc.w $e003                   ; eor a,a
        dc.w $0663                   ; ld a,($063)
        dc.w $6800,$8021             ; cmp a,#$8021
        dc.w $4d50,G117S01de4/2            ; bra z=1,$0ef2
        dc.w $e003                   ; eor a,a
        dc.w $0663                   ; ld a,($063)
        dc.w $6800,$8022             ; cmp a,#$8022
        dc.w $4d50,G117S01df6/2            ; bra z=1,$0efb
        dc.w $4c00,@L07f/2                 ; bra always,$007f
        dc.w $e003                   ; eor a,a
        dc.w $06f2                   ; ld a,($0f2)
        dc.w $6800,$0001             ; cmp a,#$0001
        dc.w $4d50,@L073/2                 ; bra z=1,$0073
        dc.w $e003                   ; eor a,a
        dc.w $0810,$0000             ; ld x,#$0000
        dc.w $0820,$0180             ; ld y,#$0180
        dc.w $4c00,SVP_IntroChecksumDirect/2; bra always,$15f3
@L073:
        dc.w $0810,$0000             ; ld x,#$0000
        dc.w $4c00,SVP_IntroChecksumDirect/2+40; bra always,$161b
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
@L07f:
        dc.w $e003                   ; eor a,a
        dc.w $0660                   ; ld a,($060)
        dc.w $0e08                   ; ld ($008),a
        dc.w $6800,$0002             ; cmp a,#$0002
        dc.w $4d70,SVP_GeoInvalid/2        ; bra n=1,$24f1
        dc.w $6800,$0009             ; cmp a,#$0009
        dc.w $4d70,@L08c/2                 ; bra n=1,$008c
        dc.w $4c00,SVP_GeoInvalid/2        ; bra always,$24f1
@L08c:
        dc.w $e003                   ; eor a,a
        dc.w $0830,$0000             ; ld a,#$0000
        dc.w $0e8a                   ; ld ($08a),a
        dc.w $e003                   ; eor a,a
        dc.w $0661                   ; ld a,($061)
        dc.w $6800,$0000             ; cmp a,#$0000
        dc.w $4c70,@L09f/2                 ; bra n=0,$009f
        dc.w $a800,$7fff             ; and a,#$7fff
        dc.w $8800,$0001             ; add a,#$0001
        dc.w $0e8a                   ; ld ($08a),a
        dc.w $e003                   ; eor a,a
        dc.w $0830,$0001             ; ld a,#$0001
        dc.w $0e61                   ; ld ($061),a
@L09f:
        dc.w $e003                   ; eor a,a
        dc.w $0661                   ; ld a,($061)
        dc.w $0e09                   ; ld ($009),a
        dc.w $6800,$0001             ; cmp a,#$0001
        dc.w $4d70,SVP_GeoInvalid/2        ; bra n=1,$24f1
        dc.w $6800,$0100             ; cmp a,#$0100
        dc.w $4d70,@L0ac/2                 ; bra n=1,$00ac
        dc.w $4c00,SVP_GeoInvalid/2        ; bra always,$24f1
@L0ac:
        dc.w $e003                   ; eor a,a
        dc.w $0830,$0000             ; ld a,#$0000
        dc.w $0e0e                   ; ld ($00e),a
        dc.w $e003                   ; eor a,a
        dc.w $0830,$0030             ; ld a,#$0030
        dc.w $0e0f                   ; ld ($00f),a
        dc.w $0e47                   ; ld ($047),a
        dc.w $0e48                   ; ld ($048),a
        dc.w $0e49                   ; ld ($049),a
        dc.w $e003                   ; eor a,a
        dc.w $0830,$0000             ; ld a,#$0000
        dc.w $0e47                   ; ld ($047),a
        dc.w $0e48                   ; ld ($048),a
        dc.w $0e49                   ; ld ($049),a
        dc.w $e003                   ; eor a,a
        dc.w $0830,$0001             ; ld a,#$0001
        dc.w $0e4a                   ; ld ($04a),a
        dc.w $0e4c                   ; ld ($04c),a
        dc.w $e003                   ; eor a,a
        dc.w $0663                   ; ld a,($063)
        dc.w $6800,$0002             ; cmp a,#$0002
        dc.w $4d50,G117S017ee/2            ; bra z=1,$0bf7
        dc.w $6800,$000a             ; cmp a,#$000a
        dc.w $4c50,@L0ce/2                 ; bra z=0,$00ce
        dc.w $4c00,G117S017ee/2            ; bra always,$0bf7
@L0ce:
        dc.w $1868                   ; ld r0,#$68
        dc.w $1c00                   ; ld r4,#$00
        dc.w $1d90                   ; ld r5,#$90
        dc.w $e003                   ; eor a,a
        dc.w $0608                   ; ld a,($008)
        dc.w $0e4d                   ; ld ($04d),a
@L0d4:
        dc.w $e003                   ; eor a,a
        dc.w $0234                   ; ld a,(r0+!)
        dc.w $8800,SVP_GeoIndexOffsets/2   ; add a,#$2f15 (table base)
        dc.w $4a30                   ; ld a,((a))
        dc.w $8662                   ; add a,($062)
        dc.w $8800,$0010             ; add a,#$0010
        dc.w $00e3                   ; ld pmc,a
        dc.w $08e0,$0818             ; ld pmc,#$0818
        dc.w $000c                   ; ld -,pm4
        dc.w $e003                   ; eor a,a
        dc.w $003c                   ; ld a,pm4
        dc.w $8647                   ; add a,($047)
        dc.w $0534                   ; ld (r4+!),a
        dc.w $e003                   ; eor a,a
        dc.w $003c                   ; ld a,pm4
        dc.w $8648                   ; add a,($048)
        dc.w $0534                   ; ld (r4+!),a
        dc.w $e003                   ; eor a,a
        dc.w $003c                   ; ld a,pm4
        dc.w $8649                   ; add a,($049)
        dc.w $0534                   ; ld (r4+!),a
        dc.w $0e72                   ; ld ($072),a
        dc.w $6800,$0201             ; z>=513: projection range is safe
        dc.w $4d70,@L0f3/2                 ; bra n=1,$00f3
        dc.w $4c00,@L0f7/2                 ; bra always,$00f7
@L0f3:
        dc.w $4800,SVP_FaceCacheGuard/2
        dc.w $4c00,@L0fd/2
@L0f7:
        dc.w $05c5,$05c5             ; stream cached sx,sy directly
        dc.w $4c00,@L0fd/2
        dc.w $0000,$0000
@L0fd:
        dc.w $e003                   ; eor a,a
        dc.w $0672                   ; ld a,($072)
        dc.w $0535                   ; ld (r5+!),a
        dc.w $e003                   ; eor a,a
        dc.w $064d                   ; ld a,($04d)
        dc.w $2800,$0001             ; sub a,#$0001
        dc.w $0e4d                   ; ld ($04d),a
        dc.w $4c50,@L0d4/2                 ; bra z=0,$00d4
        dc.w $e003                   ; eor a,a
        dc.w $068a                   ; ld a,($08a)
        dc.w $6800,$0000             ; cmp a,#$0000
        dc.w $4c50,G117S01be8/2            ; bra z=0,$0df4
        dc.w $e003                   ; eor a,a
        dc.w $064a                   ; ld a,($04a)
        dc.w $a64c                   ; and a,($04c)
        dc.w $4d50,G117S01b30/2            ; bra z=1,$0d98
        dc.w $e003                   ; eor a,a
        dc.w $0830,$0090             ; ld a,#$0090
        dc.w $0e0e                   ; ld ($00e),a
        dc.w $4c00,@L123/2                 ; bra always,$0123
        dc.w $e003                   ; eor a,a
        dc.w $0830,$0000             ; ld a,#$0000
        dc.w $0e4d                   ; ld ($04d),a
        dc.w $0e4e                   ; ld ($04e),a
        dc.w $e003                   ; eor a,a
        dc.w $0830,$0090             ; ld a,#$0090
        dc.w $0e4f                   ; ld ($04f),a
        dc.w $4c00,SVP_TriNeg9/2           ; bra always,$0ccd
@L123:
        dc.w $e003                   ; eor a,a
        dc.w $0830,$0000             ; ld a,#$0000
        dc.w $0e82                   ; ld ($082),a
        dc.w $e003                   ; eor a,a
        dc.w $0830,$000f             ; ld a,#$000f
        dc.w $0e83                   ; ld ($083),a
        dc.w $e003                   ; eor a,a
        dc.w $060e                   ; ld a,($00e)
        dc.w $0e4e                   ; ld ($04e),a
        dc.w $e003                   ; eor a,a
        dc.w $0608                   ; ld a,($008)
        dc.w $0e4d                   ; ld ($04d),a
@L131:
        dc.w $e003                   ; eor a,a
        dc.w $0830,$0000             ; ld a,#$0000
        dc.w $0e80                   ; ld ($080),a
        dc.w $e003                   ; eor a,a
        dc.w $064e                   ; ld a,($04e)
        dc.w $8800,$0000             ; add a,#$0000
        dc.w $1530                   ; ld r4,a
        dc.w $e003                   ; eor a,a
        dc.w $0334                   ; ld a,(r4+!)
        dc.w $6800,$0000             ; cmp a,#$0000
        dc.w $4d70,@L14b/2                 ; bra n=1,$014b
        dc.w $6800,$0100             ; cmp a,#$0100
        dc.w $4d70,@L150/2                 ; bra n=1,$0150
        dc.w $e003                   ; eor a,a
        dc.w $0680                   ; ld a,($080)
        dc.w $c800,$0002             ; or a,#$0002
        dc.w $0e80                   ; ld ($080),a
        dc.w $4c00,@L150/2                 ; bra always,$0150
@L14b:
        dc.w $e003                   ; eor a,a
        dc.w $0680                   ; ld a,($080)
        dc.w $c800,$0001             ; or a,#$0001
        dc.w $0e80                   ; ld ($080),a
@L150:
        dc.w $e003                   ; eor a,a
        dc.w $0334                   ; ld a,(r4+!)
        dc.w $4c00,@L157/2                 ; bra always,$0157
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
@L157:
        dc.w $6800,$0000             ; cmp a,#$0000
        dc.w $4d70,@L166/2                 ; bra n=1,$0166
        dc.w $6800,$00e0             ; cmp a,#$00e0
        dc.w $4d70,@L16b/2                 ; bra n=1,$016b
        dc.w $e003                   ; eor a,a
        dc.w $0680                   ; ld a,($080)
        dc.w $c800,$0008             ; or a,#$0008
        dc.w $0e80                   ; ld ($080),a
        dc.w $4c00,@L16b/2                 ; bra always,$016b
@L166:
        dc.w $e003                   ; eor a,a
        dc.w $0680                   ; ld a,($080)
        dc.w $c800,$0004             ; or a,#$0004
        dc.w $0e80                   ; ld ($080),a
@L16b:
        dc.w $e003                   ; eor a,a
        dc.w $0682                   ; ld a,($082)
        dc.w $c680                   ; or a,($080)
        dc.w $0e82                   ; ld ($082),a
        dc.w $e003                   ; eor a,a
        dc.w $0683                   ; ld a,($083)
        dc.w $a680                   ; and a,($080)
        dc.w $0e83                   ; ld ($083),a
        dc.w $e003                   ; eor a,a
        dc.w $064e                   ; ld a,($04e)
        dc.w $8800,$0003             ; add a,#$0003
        dc.w $0e4e                   ; ld ($04e),a
        dc.w $e003                   ; eor a,a
        dc.w $064d                   ; ld a,($04d)
        dc.w $2800,$0001             ; sub a,#$0001
        dc.w $0e4d                   ; ld ($04d),a
        dc.w $4c50,@L131/2                 ; bra z=0,$0131
        dc.w $e003                   ; eor a,a
        dc.w $0683                   ; ld a,($083)
        dc.w $6800,$0000             ; cmp a,#$0000
        dc.w $4c50,@L2ca/2                 ; bra z=0,$02ca
        dc.w $e003                   ; eor a,a
        dc.w $0682                   ; ld a,($082)
        dc.w $6800,$0000             ; cmp a,#$0000
        dc.w $4d50,@L1db/2                 ; bra z=1,$01db
        dc.w $e003                   ; eor a,a
        dc.w $0830,$0000             ; ld a,#$0000
        dc.w $0e0b                   ; ld ($00b),a
        dc.w $e003                   ; eor a,a
        dc.w $0830,$0000             ; ld a,#$0000
        dc.w $0e0c                   ; ld ($00c),a
        dc.w $e003                   ; eor a,a
        dc.w $0830,$0001             ; ld a,#$0001
        dc.w $0e0d                   ; ld ($00d),a
        dc.w $4800,SVP_FaceClip/2          ; call always,$2df9
        dc.w $e003                   ; eor a,a
        dc.w $0608                   ; ld a,($008)
        dc.w $6800,$0000             ; cmp a,#$0000
        dc.w $4d50,@L2ca/2                 ; bra z=1,$02ca
        dc.w $e003                   ; eor a,a
        dc.w $0830,$0000             ; ld a,#$0000
        dc.w $0e0b                   ; ld ($00b),a
        dc.w $e003                   ; eor a,a
        dc.w $0830,$00ff             ; ld a,#$00ff
        dc.w $0e0c                   ; ld ($00c),a
        dc.w $e003                   ; eor a,a
        dc.w $0830,$0000             ; ld a,#$0000
        dc.w $0e0d                   ; ld ($00d),a
        dc.w $4800,SVP_FaceClip/2          ; call always,$2df9
        dc.w $e003                   ; eor a,a
        dc.w $0608                   ; ld a,($008)
        dc.w $6800,$0000             ; cmp a,#$0000
        dc.w $4d50,@L2ca/2                 ; bra z=1,$02ca
        dc.w $e003                   ; eor a,a
        dc.w $0830,$0001             ; ld a,#$0001
        dc.w $0e0b                   ; ld ($00b),a
        dc.w $e003                   ; eor a,a
        dc.w $0830,$0000             ; ld a,#$0000
        dc.w $0e0c                   ; ld ($00c),a
        dc.w $e003                   ; eor a,a
        dc.w $0830,$0001             ; ld a,#$0001
        dc.w $0e0d                   ; ld ($00d),a
        dc.w $4800,SVP_FaceClip/2          ; call always,$2df9
        dc.w $e003                   ; eor a,a
        dc.w $0608                   ; ld a,($008)
        dc.w $6800,$0000             ; cmp a,#$0000
        dc.w $4d50,@L2ca/2                 ; bra z=1,$02ca
        dc.w $e003                   ; eor a,a
        dc.w $0830,$0001             ; ld a,#$0001
        dc.w $0e0b                   ; ld ($00b),a
        dc.w $e003                   ; eor a,a
        dc.w $0830,$00df             ; ld a,#$00df
        dc.w $0e0c                   ; ld ($00c),a
        dc.w $e003                   ; eor a,a
        dc.w $0830,$0000             ; ld a,#$0000
        dc.w $0e0d                   ; ld ($00d),a
        dc.w $4800,SVP_FaceClip/2          ; call always,$2df9
        dc.w $e003                   ; eor a,a
        dc.w $0608                   ; ld a,($008)
        dc.w $6800,$0000             ; cmp a,#$0000
        dc.w $4d50,@L2ca/2                 ; bra z=1,$02ca
@L1db:
        dc.w $e003                   ; eor a,a
        dc.w $0608                   ; ld a,($008)
        dc.w $6800,$0002             ; cmp a,#$0002
        dc.w $4d70,@L2ca/2                 ; bra n=1,$02ca
        dc.w $e003                   ; eor a,a
        dc.w $0660                   ; ld a,($060)
        dc.w $6800,$0002             ; cmp a,#$0002
        dc.w $4d50,@L275/2                 ; bra z=1,$0275
        dc.w $e003                   ; eor a,a
        dc.w $0608                   ; ld a,($008)
        dc.w $6800,$0003             ; cmp a,#$0003
        dc.w $4d70,@L2ca/2                 ; bra n=1,$02ca
        dc.w $e003                   ; eor a,a
        dc.w $0830,$0001             ; ld a,#$0001
        dc.w $0e4d                   ; ld ($04d),a
@L1f1:
        dc.w $e003                   ; eor a,a
        dc.w $060e                   ; ld a,($00e)
        dc.w $8800,$0000             ; add a,#$0000
        dc.w $1530                   ; ld r4,a
        dc.w $e003                   ; eor a,a
        dc.w $0330                   ; ld a,(r4)
        dc.w $0e70                   ; ld ($070),a
        dc.w $e003                   ; eor a,a
        dc.w $060e                   ; ld a,($00e)
        dc.w $8800,$0001             ; add a,#$0001
        dc.w $1530                   ; ld r4,a
        dc.w $e003                   ; eor a,a
        dc.w $0330                   ; ld a,(r4)
        dc.w $0e71                   ; ld ($071),a
        dc.w $e003                   ; eor a,a
        dc.w $064d                   ; ld a,($04d)
        dc.w $0e4e                   ; ld ($04e),a
        dc.w $9003                   ; mod3 cond$000
        dc.w $864e                   ; add a,($04e)
        dc.w $860e                   ; add a,($00e)
        dc.w $0e4e                   ; ld ($04e),a
        dc.w $e003                   ; eor a,a
        dc.w $064e                   ; ld a,($04e)
        dc.w $8800,$0000             ; add a,#$0000
        dc.w $1530                   ; ld r4,a
        dc.w $e003                   ; eor a,a
        dc.w $0330                   ; ld a,(r4)
        dc.w $0e72                   ; ld ($072),a
        dc.w $e003                   ; eor a,a
        dc.w $064e                   ; ld a,($04e)
        dc.w $8800,$0003             ; add a,#$0003
        dc.w $1530                   ; ld r4,a
        dc.w $e003                   ; eor a,a
        dc.w $0330                   ; ld a,(r4)
        dc.w $0e74                   ; ld ($074),a
        dc.w $e003                   ; eor a,a
        dc.w $064e                   ; ld a,($04e)
        dc.w $8800,$0001             ; add a,#$0001
        dc.w $1530                   ; ld r4,a
        dc.w $e003                   ; eor a,a
        dc.w $0330                   ; ld a,(r4)
        dc.w $0e73                   ; ld ($073),a
        dc.w $e003                   ; eor a,a
        dc.w $064e                   ; ld a,($04e)
        dc.w $8800,$0004             ; add a,#$0004
        dc.w $1530                   ; ld r4,a
        dc.w $e003                   ; eor a,a
        dc.w $0330                   ; ld a,(r4)
        dc.w $0e75                   ; ld ($075),a
        dc.w $e003                   ; eor a,a
        dc.w $0672                   ; ld a,($072)
        dc.w $2670                   ; sub a,($070)
        dc.w $0e7a                   ; ld ($07a),a
        dc.w $e003                   ; eor a,a
        dc.w $0675                   ; ld a,($075)
        dc.w $2671                   ; sub a,($071)
        dc.w $0e7b                   ; ld ($07b),a
        dc.w $e003                   ; eor a,a
        dc.w $067a                   ; ld a,($07a)
        dc.w $0013                   ; ld x,a
        dc.w $e003                   ; eor a,a
        dc.w $067b                   ; ld a,($07b)
        dc.w $0023                   ; ld y,a
        dc.w $0037                   ; ld a,p
        dc.w $0e52                   ; ld ($052),a
        dc.w $003f                   ; ld a,al
        dc.w $0e53                   ; ld ($053),a
        dc.w $e003                   ; eor a,a
        dc.w $0673                   ; ld a,($073)
        dc.w $2671                   ; sub a,($071)
        dc.w $0013                   ; ld x,a
        dc.w $e003                   ; eor a,a
        dc.w $0674                   ; ld a,($074)
        dc.w $2670                   ; sub a,($070)
        dc.w $0023                   ; ld y,a
        dc.w $e003                   ; eor a,a
        dc.w $0653                   ; ld a,($053)
        dc.w $00f3                   ; ld al,a
        dc.w $0652                   ; ld a,($052)
        dc.w $2007                   ; sub a,p
        dc.w $6800,$0000             ; cmp a,#$0000
        dc.w $4d50,@L267/2                 ; bra z=1,$0267
        dc.w $4d70,@L24f/2                 ; bra n=1,$024f
        dc.w $4c00,@L261/2                 ; bra always,$0261
@L24f:
        dc.w $e003                   ; eor a,a
        dc.w $0672                   ; ld a,($072)
        dc.w $0e80                   ; ld ($080),a
        dc.w $e003                   ; eor a,a
        dc.w $0674                   ; ld a,($074)
        dc.w $0e72                   ; ld ($072),a
        dc.w $e003                   ; eor a,a
        dc.w $0680                   ; ld a,($080)
        dc.w $0e74                   ; ld ($074),a
        dc.w $e003                   ; eor a,a
        dc.w $0673                   ; ld a,($073)
        dc.w $0e80                   ; ld ($080),a
        dc.w $e003                   ; eor a,a
        dc.w $0675                   ; ld a,($075)
        dc.w $0e73                   ; ld ($073),a
        dc.w $e003                   ; eor a,a
        dc.w $0680                   ; ld a,($080)
        dc.w $0e75                   ; ld ($075),a
@L261:
        dc.w $e003                   ; eor a,a
        dc.w $0830,$0003             ; ld a,#$0003
        dc.w $0e81                   ; ld ($081),a
        dc.w $4800,@L2e0/2                 ; call always,$02e0
@L267:
        dc.w $e003                   ; eor a,a
        dc.w $064d                   ; ld a,($04d)
        dc.w $8800,$0001             ; add a,#$0001
        dc.w $0e4d                   ; ld ($04d),a
        dc.w $e003                   ; eor a,a
        dc.w $0608                   ; ld a,($008)
        dc.w $2800,$0001             ; sub a,#$0001
        dc.w $264d                   ; sub a,($04d)
        dc.w $4c50,@L1f1/2                 ; bra z=0,$01f1
        dc.w $4c00,@L2ca/2                 ; bra always,$02ca
@L275:
        dc.w $e003                   ; eor a,a
        dc.w $060e                   ; ld a,($00e)
        dc.w $8800,$0000             ; add a,#$0000
        dc.w $1530                   ; ld r4,a
        dc.w $e003                   ; eor a,a
        dc.w $0330                   ; ld a,(r4)
        dc.w $0e70                   ; ld ($070),a
        dc.w $e003                   ; eor a,a
        dc.w $060e                   ; ld a,($00e)
        dc.w $8800,$0001             ; add a,#$0001
        dc.w $1530                   ; ld r4,a
        dc.w $e003                   ; eor a,a
        dc.w $0330                   ; ld a,(r4)
        dc.w $0e71                   ; ld ($071),a
        dc.w $e003                   ; eor a,a
        dc.w $060e                   ; ld a,($00e)
        dc.w $8800,$0003             ; add a,#$0003
        dc.w $0e4e                   ; ld ($04e),a
        dc.w $e003                   ; eor a,a
        dc.w $0608                   ; ld a,($008)
        dc.w $2800,$0001             ; sub a,#$0001
        dc.w $0e4d                   ; ld ($04d),a
@L28f:
        dc.w $e003                   ; eor a,a
        dc.w $064e                   ; ld a,($04e)
        dc.w $8800,$0000             ; add a,#$0000
        dc.w $1530                   ; ld r4,a
        dc.w $e003                   ; eor a,a
        dc.w $0330                   ; ld a,(r4)
        dc.w $0e72                   ; ld ($072),a
        dc.w $2670                   ; sub a,($070)
        dc.w $4c50,@L2b3/2                 ; bra z=0,$02b3
        dc.w $e003                   ; eor a,a
        dc.w $064e                   ; ld a,($04e)
        dc.w $8800,$0001             ; add a,#$0001
        dc.w $1530                   ; ld r4,a
        dc.w $e003                   ; eor a,a
        dc.w $0330                   ; ld a,(r4)
        dc.w $0e73                   ; ld ($073),a
        dc.w $2671                   ; sub a,($071)
        dc.w $4c50,@L2b3/2                 ; bra z=0,$02b3
        dc.w $e003                   ; eor a,a
        dc.w $064e                   ; ld a,($04e)
        dc.w $8800,$0003             ; add a,#$0003
        dc.w $0e4e                   ; ld ($04e),a
        dc.w $e003                   ; eor a,a
        dc.w $064d                   ; ld a,($04d)
        dc.w $2800,$0001             ; sub a,#$0001
        dc.w $0e4d                   ; ld ($04d),a
        dc.w $4c50,@L28f/2                 ; bra z=0,$028f
        dc.w $4c00,@L2ca/2                 ; bra always,$02ca
@L2b3:
        dc.w $e003                   ; eor a,a
        dc.w $064e                   ; ld a,($04e)
        dc.w $8800,$0001             ; add a,#$0001
        dc.w $1530                   ; ld r4,a
        dc.w $e003                   ; eor a,a
        dc.w $0330                   ; ld a,(r4)
        dc.w $0e73                   ; ld ($073),a
        dc.w $e003                   ; eor a,a
        dc.w $0830,$0000             ; ld a,#$0000
        dc.w $0e74                   ; ld ($074),a
        dc.w $0e75                   ; ld ($075),a
        dc.w $e003                   ; eor a,a
        dc.w $0830,$0002             ; ld a,#$0002
        dc.w $0e81                   ; ld ($081),a
        dc.w $4800,@L2e0/2                 ; call always,$02e0
        dc.w $4c00,@L2ca/2                 ; bra always,$02ca
        dc.w $4c00,G117S01be8/2            ; bra always,$0df4
@L2ca:
        dc.w $e003                   ; eor a,a
        dc.w $0602                   ; ld a,($002)
        dc.w $2800,$0001             ; sub a,#$0001
        dc.w $0e02                   ; ld ($002),a
        dc.w $4c50,@L020/2                 ; bra z=0,$0020
        dc.w $08e0,$000a             ; ld pmc,#$000a
        dc.w $08e0,$0018             ; ld pmc,#$0018
        dc.w $00c0                   ; ld pm4,-
        dc.w $e003                   ; eor a,a
        dc.w $0606                   ; ld a,($006)
        dc.w $00c3                   ; ld pm4,a
        dc.w $e003                   ; eor a,a
        dc.w $0600                   ; ld a,($000)
        dc.w $0023                   ; ld y,a
        dc.w $e003                   ; eor a,a
        dc.w $0603                   ; ld a,($003)
        dc.w $4c00,SVP_PublishResult/2     ; bra always,$0453
@L2e0:
        dc.w $e003                   ; eor a,a
        dc.w $0606                   ; ld a,($006)
        dc.w $6800,$0100             ; cmp a,#$0100
        dc.w $4d70,@L2e7/2                 ; bra n=1,$02e7
        dc.w $0065                   ; ld pc,stack
@L2e7:
        dc.w $e003                   ; eor a,a
        dc.w $0605                   ; ld a,($005)
        dc.w $00e3                   ; ld pmc,a
        dc.w $08e0,$0818             ; ld pmc,#$0818
        dc.w $00c0                   ; ld pm4,-
        dc.w $e003                   ; eor a,a
        dc.w $0681                   ; ld a,($081)
        dc.w $00c3                   ; ld pm4,a
        dc.w $1870                   ; ld r0,#$70
        dc.w $02c4                   ; ld pm4,(r0+!)
        dc.w $02c4                   ; ld pm4,(r0+!)
        dc.w $02c4                   ; ld pm4,(r0+!)
        dc.w $02c4                   ; ld pm4,(r0+!)
        dc.w $02c4                   ; ld pm4,(r0+!)
        dc.w $02c4                   ; ld pm4,(r0+!)
        dc.w $4c00,@L302/2                 ; bra always,$0302
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
@L302:
        dc.w $e003                   ; eor a,a
        dc.w $0609                   ; ld a,($009)
        dc.w $00c3                   ; ld pm4,a
        dc.w $e003                   ; eor a,a
        dc.w $0605                   ; ld a,($005)
        dc.w $8800,$0008             ; add a,#$0008
        dc.w $0e05                   ; ld ($005),a
        dc.w $e003                   ; eor a,a
        dc.w $0606                   ; ld a,($006)
        dc.w $8800,$0001             ; add a,#$0001
        dc.w $0e06                   ; ld ($006),a
        dc.w $0065                   ; ld pc,stack
        dc.w $4c00,SVP_FaceClip/2          ; bra always,$2df9
        dc.w $e003                   ; eor a,a
        dc.w $0631                   ; ld a,($031)
        dc.w $00f3                   ; ld al,a
        dc.w $0630                   ; ld a,($030)
        dc.w $9007                   ; mod7 cond$000
        dc.w $4d70,SVP_GeoInvalid/2        ; bra n=1,$24f1
        dc.w $0e34                   ; ld ($034),a
        dc.w $003f                   ; ld a,al
        dc.w $0e35                   ; ld ($035),a
        dc.w $a800,$0001             ; and a,#$0001
        dc.w $0e36                   ; ld ($036),a
        dc.w $e003                   ; eor a,a
        dc.w $0632                   ; ld a,($032)
        dc.w $9007                   ; mod7 cond$000
        dc.w $4d50,SVP_GeoInvalid/2        ; bra z=1,$24f1
        dc.w $0e37                   ; ld ($037),a
        dc.w $4d70,@L32b/2                 ; bra n=1,$032b
        dc.w $0634                   ; ld a,($034)
        dc.w $2637                   ; sub a,($037)
        dc.w $4c70,SVP_GeoInvalid/2        ; bra n=0,$24f1
@L32b:
        dc.w $e003                   ; eor a,a
        dc.w $0635                   ; ld a,($035)
        dc.w $a800,$fffe             ; and a,#$fffe
        dc.w $00f3                   ; ld al,a
        dc.w $0634                   ; ld a,($034)
        dc.w $0810,$0001             ; ld x,#$0001
        dc.w $0820,$0001             ; ld y,#$0001
        dc.w $9003                   ; mod3 cond$000
        dc.w $6637                   ; cmp a,($037)
        dc.w $4d70,@L33b/2                 ; bra n=1,$033b
        dc.w $2637                   ; sub a,($037)
        dc.w $8007                   ; add a,p
@L33b:
        dc.w $9003                   ; mod3 cond$000
        dc.w $6637                   ; cmp a,($037)
        dc.w $4d70,@L341/2                 ; bra n=1,$0341
        dc.w $2637                   ; sub a,($037)
        dc.w $8007                   ; add a,p
@L341:
        dc.w $9003                   ; mod3 cond$000
        dc.w $6637                   ; cmp a,($037)
        dc.w $4d70,@L347/2                 ; bra n=1,$0347
        dc.w $2637                   ; sub a,($037)
        dc.w $8007                   ; add a,p
@L347:
        dc.w $9003                   ; mod3 cond$000
        dc.w $6637                   ; cmp a,($037)
        dc.w $4d70,@L34d/2                 ; bra n=1,$034d
        dc.w $2637                   ; sub a,($037)
        dc.w $8007                   ; add a,p
@L34d:
        dc.w $9003                   ; mod3 cond$000
        dc.w $6637                   ; cmp a,($037)
        dc.w $4d70,@L353/2                 ; bra n=1,$0353
        dc.w $2637                   ; sub a,($037)
        dc.w $8007                   ; add a,p
@L353:
        dc.w $9003                   ; mod3 cond$000
        dc.w $6637                   ; cmp a,($037)
        dc.w $4d70,@L359/2                 ; bra n=1,$0359
        dc.w $2637                   ; sub a,($037)
        dc.w $8007                   ; add a,p
@L359:
        dc.w $9003                   ; mod3 cond$000
        dc.w $6637                   ; cmp a,($037)
        dc.w $4d70,@L35f/2                 ; bra n=1,$035f
        dc.w $2637                   ; sub a,($037)
        dc.w $8007                   ; add a,p
@L35f:
        dc.w $9003                   ; mod3 cond$000
        dc.w $6637                   ; cmp a,($037)
        dc.w $4d70,@L365/2                 ; bra n=1,$0365
        dc.w $2637                   ; sub a,($037)
        dc.w $8007                   ; add a,p
@L365:
        dc.w $9003                   ; mod3 cond$000
        dc.w $6637                   ; cmp a,($037)
        dc.w $4d70,@L36b/2                 ; bra n=1,$036b
        dc.w $2637                   ; sub a,($037)
        dc.w $8007                   ; add a,p
@L36b:
        dc.w $9003                   ; mod3 cond$000
        dc.w $6637                   ; cmp a,($037)
        dc.w $4d70,@L371/2                 ; bra n=1,$0371
        dc.w $2637                   ; sub a,($037)
        dc.w $8007                   ; add a,p
@L371:
        dc.w $9003                   ; mod3 cond$000
        dc.w $6637                   ; cmp a,($037)
        dc.w $4d70,@L377/2                 ; bra n=1,$0377
        dc.w $2637                   ; sub a,($037)
        dc.w $8007                   ; add a,p
@L377:
        dc.w $9003                   ; mod3 cond$000
        dc.w $6637                   ; cmp a,($037)
        dc.w $4d70,@L37d/2                 ; bra n=1,$037d
        dc.w $2637                   ; sub a,($037)
        dc.w $8007                   ; add a,p
@L37d:
        dc.w $9003                   ; mod3 cond$000
        dc.w $6637                   ; cmp a,($037)
        dc.w $4d70,@L383/2                 ; bra n=1,$0383
        dc.w $2637                   ; sub a,($037)
        dc.w $8007                   ; add a,p
@L383:
        dc.w $9003                   ; mod3 cond$000
        dc.w $6637                   ; cmp a,($037)
        dc.w $4d70,@L389/2                 ; bra n=1,$0389
        dc.w $2637                   ; sub a,($037)
        dc.w $8007                   ; add a,p
@L389:
        dc.w $9003                   ; mod3 cond$000
        dc.w $6637                   ; cmp a,($037)
        dc.w $4d70,@L38f/2                 ; bra n=1,$038f
        dc.w $2637                   ; sub a,($037)
        dc.w $8007                   ; add a,p
@L38f:
        dc.w $0e34                   ; ld ($034),a
        dc.w $003f                   ; ld a,al
        dc.w $0e35                   ; ld ($035),a
        dc.w $e003                   ; eor a,a
        dc.w $0634                   ; ld a,($034)
        dc.w $9003                   ; mod3 cond$000
        dc.w $8636                   ; add a,($036)
        dc.w $6637                   ; cmp a,($037)
        dc.w $4d70,@L39d/2                 ; bra n=1,$039d
        dc.w $0635                   ; ld a,($035)
        dc.w $8800,$0001             ; add a,#$0001
        dc.w $0e35                   ; ld ($035),a
@L39d:
        dc.w $e003                   ; eor a,a
        dc.w $0635                   ; ld a,($035)
        dc.w $6800,$0000             ; cmp a,#$0000
        dc.w $4c70,@L3ac/2                 ; bra n=0,$03ac
        dc.w $6800,$8000             ; cmp a,#$8000
        dc.w $4c50,SVP_GeoInvalid/2        ; bra z=0,$24f1
        dc.w $e003                   ; eor a,a
        dc.w $0630                   ; ld a,($030)
        dc.w $e632                   ; eor a,($032)
        dc.w $4c70,SVP_GeoInvalid/2        ; bra n=0,$24f1
@L3ac:
        dc.w $e003                   ; eor a,a
        dc.w $0630                   ; ld a,($030)
        dc.w $e632                   ; eor a,($032)
        dc.w $4d70,@L3b4/2                 ; bra n=1,$03b4
        dc.w $e003                   ; eor a,a
        dc.w $0635                   ; ld a,($035)
        dc.w $0065                   ; ld pc,stack
@L3b4:
        dc.w $e003                   ; eor a,a
        dc.w $0635                   ; ld a,($035)
        dc.w $9006                   ; mod6 cond$000
        dc.w $0065                   ; ld pc,stack
        dc.w $e003                   ; eor a,a
        dc.w $0678                   ; ld a,($078)
        dc.w $6800,$0010             ; cmp a,#$0010
        dc.w $4d70,@L3c0/2                 ; bra n=1,$03c0
        dc.w $4c00,SVP_GeoInvalid/2        ; bra always,$24f1
@L3c0:
        dc.w $e003                   ; eor a,a
        dc.w $0679                   ; ld a,($079)
        dc.w $8800,$0000             ; add a,#$0000
        dc.w $1530                   ; ld r4,a
        dc.w $e003                   ; eor a,a
        dc.w $0680                   ; ld a,($080)
        dc.w $0530                   ; ld (r4),a
        dc.w $e003                   ; eor a,a
        dc.w $0679                   ; ld a,($079)
        dc.w $8800,$0001             ; add a,#$0001
        dc.w $1530                   ; ld r4,a
        dc.w $e003                   ; eor a,a
        dc.w $0681                   ; ld a,($081)
        dc.w $0530                   ; ld (r4),a
        dc.w $e003                   ; eor a,a
        dc.w $0679                   ; ld a,($079)
        dc.w $8800,$0002             ; add a,#$0002
        dc.w $1530                   ; ld r4,a
        dc.w $e003                   ; eor a,a
        dc.w $0682                   ; ld a,($082)
        dc.w $0530                   ; ld (r4),a
        dc.w $e003                   ; eor a,a
        dc.w $0679                   ; ld a,($079)
        dc.w $8800,$0003             ; add a,#$0003
        dc.w $0e79                   ; ld ($079),a
        dc.w $e003                   ; eor a,a
        dc.w $0678                   ; ld a,($078)
        dc.w $8800,$0001             ; add a,#$0001
        dc.w $0e78                   ; ld ($078),a
        dc.w $0065                   ; ld pc,stack
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        dc.w $0000                   ; nop
        objend
