; graphics117: code and SSP overlay images between the SVP ROM data block and
; SVP_GeoRom0. Every reference is symbolic, so the blocks follow each
; other; the address after g117at is where the Nomad-measured 117 had it.
G117_AABB_RAM equ $ff4680       ; AABB test copied to RAM (115: was $ff5d80)
G117_EPOCH equ $fff9ac          ; WORD game frame of the last draw list
G117_ACTIVE equ $fff9aa         ; BYTE 114 early-raster chain armed
G117_READY equ M4_CHAIN_HDR+12  ; WORD $5254 ready, $ffff aborted
G117_MAGIC equ M4_CHAIN_HDR+14  ; WORD $4552 early-raster request
G117_LC_CACHE equ $ff4800       ; 64 x 8 bytes: Z, Z extent, descriptor
G117_SWEEP_RAM equ $ff4a00      ; sweep copy, G117SweepImage
G117_SWEEP_MAGIC equ $ff4ffc    ; 'RCV1' once the sweep copy is in RAM

g117at macro address
        even
        endm

        g117at $159500
        include 'release/g117_report.asm'
        g117at $15bc00
        include 'release/g117_diag.asm'
        g117at $15c000
G117ImgFaces:
        include 'release/g117_img_faces.asm'
G117ImgFacesEnd:
        g117at $15c800
        include 'release/g117_sweep.asm'
        g117at $15d000
G117ImgRaster:
        include 'release/g117_img_raster.asm'
G117ImgRasterEnd:
        g117at $15d800
        include 'release/g117_host.asm'
        g117at $15e000
G117ImgRaster2: ;same image for the startup loader
        include 'release/g117_img_raster.asm'
G117ImgRaster2End:
        g117at $15e800
G117ImgGeometry:
        include 'release/g117_img_geometry.asm'
G117ImgGeometryEnd:
        g117at $15f000
G117ImgBsp:
        include 'release/g117_img_bsp.asm'
G117ImgBspEnd:
; The following geometry include places its own page-aligned data after
; this block. $160000 was a historical address, not an overlap boundary.
