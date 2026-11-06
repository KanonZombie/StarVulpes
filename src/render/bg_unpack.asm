; ZX0 from the external MDSDRV mdssub.inc, extracted at build time.
; Emmanuel Marty, rewritten by ctr. See THIRD_PARTY.md.
        include '../build/packed-2d/zx0.inc'

; MDSDRV work ends at FF07EC in the official configuration. Temporary
; pattern/map decode ends before FF2000. The active scroll map owns FF2000
; through FF3FFF once in flight, after the startup diagnostics are consumed.
; Only foreground scene loaders decode. The IRQ consumes ready VRAM data.
M4_BG_SCRATCH equ $ff0800
M4_BG_MAP_RAM equ $ff2000

; a0 = uncompressed byte count.w followed by ZX0, a1 = destination.
; The extractor checks each complete stream and its size. Preserves registers.
M4BgDecode:
        movem.l d0-d1/a0-a1,-(sp)
        addq.l #2,a0
        mds_z80_unpack
        movem.l (sp)+,d0-d1/a0-a1
        rts

; Decode to temporary WRAM and return the raw pointer in a0.
M4BgDecodeScratch:
        move.l a1,-(sp)
        lea M4_BG_SCRATCH,a1
        bsr.w M4BgDecode
        movea.l a1,a0
        movea.l (sp)+,a1
        rts

; a0 = packed resource, d0.w = VRAM destination. Mask only for the upload.
M4BgUpload:
        movem.l d0-d2/a0,-(sp)
        move.w (a0),d1
        bsr.s M4BgDecodeScratch
        lsr.w #2,d1
        subq.w #1,d1
        move.w sr,-(sp)
        ori.w #$0700,sr
        jsr M4TextVideoWriteAddress
M4BgUploadLong:
        move.l (a0)+,VDP_DATA
        dbra d1,M4BgUploadLong
        move.w (sp)+,sr
        movem.l (sp)+,d0-d2/a0
        rts

; Stage changes may overlap retirement of the preceding image.
; Keep the original 16-byte VDP windows and leave decode interruptible.
M4BgUploadStage:
        movem.l d0-d3/a0,-(sp)
        move.w (a0),d3
        bsr.s M4BgDecodeScratch
        move.w d0,d1
        lsr.w #4,d3
        subq.w #1,d3
M4BgStageChunk:
        move.w sr,-(sp)
        ori.w #$0700,sr
        move.w d1,d0
        jsr M4TextVideoWriteAddress
        move.l (a0)+,VDP_DATA
        move.l (a0)+,VDP_DATA
        move.l (a0)+,VDP_DATA
        move.l (a0)+,VDP_DATA
        move.w (sp)+,sr
        addi.w #16,d1
        dbra d3,M4BgStageChunk
        movem.l (sp)+,d0-d3/a0
        rts
