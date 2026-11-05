; Official integration: direct sphere reads and fractional visual zoom.
SVP_SPHERE_FAST equ 1
; build-release.py installs the active audio bank after assembly. Retired
; late PCM samples must not reserve fixed addresses over live graphics.
M4_EXTERNAL_AUDIO equ 1
; Hardware-measured graphics lots 83..117 (src/release/, tools/hw-boot/).
; build.ps1 also assembles this file with /e M4_NO_GRAPHICS117=1 as the base
; that tools/check-g117-copies.py compares the release SSP code with.
        if ~def(M4_NO_GRAPHICS117)
M4_GRAPHICS117 equ 1
        endif
; Scaled text of the level (ending scores, credits): msprint on the SVP.
M4_STEXT equ 1
        include 'main_level_profile.asm'
