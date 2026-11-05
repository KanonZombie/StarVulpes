; Adapted from MegaTBS asm68k wrapper, SGDK 2.11 / XGM2, MIT.
; PCM and single-song API. See THIRD_PARTY.md and audio/music.asm.
; -----------------------------------------------------------------------------
; XGM2 68000 interface for asm68k
; Driver protocol pinned to SGDK 2.11 / XGM2Tool 1.05.
; -----------------------------------------------------------------------------

XGM2_Z80_RAM                   equ $00A00000
XGM2_Z80_BUSREQ                equ $00A11100
XGM2_Z80_RESET                 equ $00A11200
XGM2_YM2612                    equ $00A04000

XGM2_DRIVER_COMMAND            equ $00A00100
XGM2_DRIVER_STATUS             equ $00A00102
XGM2_DRIVER_PARAMS             equ $00A00104
XGM2_DRIVER_VARS               equ $00A00110

XGM2_PLAY_ARG_FM_ADDR          equ XGM2_DRIVER_PARAMS+$00
XGM2_PLAY_ARG_PSG_ADDR         equ XGM2_DRIVER_PARAMS+$02
XGM2_PLAY_ARG_LOOP             equ XGM2_DRIVER_PARAMS+$04
XGM2_PCM_ARG_BASE              equ XGM2_DRIVER_PARAMS+$05
XGM2_TEMPO_ARG_FRAC            equ XGM2_DRIVER_PARAMS+$0A
XGM2_TEMPO_ARG_INT             equ XGM2_DRIVER_PARAMS+$0B

XGM2_ACCESS                    equ XGM2_DRIVER_VARS+$50
XGM2_IN_DMA                    equ XGM2_DRIVER_VARS+$51
XGM2_FM_START                  equ XGM2_DRIVER_VARS+$5C
XGM2_PCM_PARAM_BASE            equ XGM2_DRIVER_VARS+$D0
XGM2_PCM_PARAM_LENGTH          equ 8
XGM2_PCM_PRIORITY_OFFSET       equ 5

XGM2_SID_TABLE                 equ XGM2_Z80_RAM+$1C00
XGM2_PCM_ADDR_ARG_BASE         equ XGM2_SID_TABLE+$1F4

XGM2_COMMAND_RESUME            equ $08
XGM2_COMMAND_PLAY              equ $10
XGM2_COMMAND_PAUSE             equ $20

XGM2_STATUS_PCM_MASK           equ $07
XGM2_STATUS_PLAYING            equ $10
XGM2_STATUS_READY              equ $80

XGM2_ACCESS_COMMAND            equ $01
XGM2_ACCESS_PCM                equ $02

XGM2_PCM_CHANNEL_AUTO          equ -1
XGM2_PCM_FLAG_HALF_RATE        equ $01
XGM2_PCM_FLAG_LOOP             equ $02

XGM2_DRIVER_SIZE               equ $2000
XGM2_READY_TIMEOUT             equ $7FFF
XGM2_ACCESS_TIMEOUT            equ $7FFF

; Returns D0.b = 1 when the driver reports READY, 0 on timeout.
XGM2_Init:
	MOVEM.l	D1-D7/A0-A2, -(A7)
	MOVE.w	SR, -(A7)
	ORI.w	#$0700, SR

	BSR.w	XGM2_RequestBus
	BSR.w	XGM2_ResetSoundChips

	; Clear all Z80 RAM before installing the complete 8 KiB driver image.
	LEA	XGM2_Z80_RAM, A0
	MOVEQ	#0, D0
	MOVE.w	#$1FFF, D1
XGM2_Init_ClearZ80:
	MOVE.b	D0, (A0)+
	DBF	D1, XGM2_Init_ClearZ80

	LEA	XGM2_Driver(PC), A0
	LEA	XGM2_Z80_RAM, A1
	MOVE.w	#$1FFF, D1
XGM2_Init_CopyDriver:
	MOVE.b	(A0)+, (A1)+
	DBF	D1, XGM2_Init_CopyDriver

	; Pulse reset after upload, matching SGDK's Z80_loadDriverInternal.
	MOVE.w	#$0000, XGM2_Z80_RESET
	BSR.w	XGM2_ReleaseBus
	MOVE.w	#$1000, D1
XGM2_Init_ResetDelay:
	DBF	D1, XGM2_Init_ResetDelay
	MOVE.w	#$0100, XGM2_Z80_RESET

	MOVE.w	#XGM2_READY_TIMEOUT, D2
XGM2_Init_WaitReady:
	BSR.w	XGM2_RequestBus
	MOVE.b	XGM2_DRIVER_STATUS, D0
	BSR.w	XGM2_ReleaseBus
	BTST	#7, D0
	BNE.s	XGM2_Init_Ready
	MOVEQ	#31, D1
XGM2_Init_ReadyDelay:
	DBF	D1, XGM2_Init_ReadyDelay
	DBF	D2, XGM2_Init_WaitReady
	MOVEQ	#0, D0
	BRA.s	XGM2_Init_Exit

XGM2_Init_Ready:
	; Infinite loop and a neutral 1.0 tempo until a song is selected.
	MOVEQ	#XGM2_ACCESS_COMMAND, D7
	BSR.w	XGM2_RequestAccess
	TST.b	D0
	BEQ.s	XGM2_Init_Exit
	MOVE.b	#$FF, XGM2_PLAY_ARG_LOOP
	MOVE.b	#$00, XGM2_TEMPO_ARG_FRAC
	MOVE.b	#$01, XGM2_TEMPO_ARG_INT
	BSR.w	XGM2_ReleaseBus
	MOVEQ	#1, D0

XGM2_Init_Exit:
	MOVE.w	(A7)+, SR
	MOVEM.l	(A7)+, D1-D7/A0-A2
	RTS

; A0 = compiled, single-track XGM2 blob. Returns D0.b success.
XGM2_Play:
	MOVEM.l	D1-D7/A0-A3, -(A7)
	MOVE.w	SR, -(A7)
	ORI.w	#$0700, SR
	MOVEA.l	A0, A3
	MOVEQ	#0, D0
	MOVE.l	A3, D4
	TST.b	D4
	BNE.w	XGM2_Play_Exit
	CMPI.b	#$10, (A3)
	BNE.w	XGM2_Play_Exit
	BTST	#1, 1(A3)
	BNE.w	XGM2_Play_Exit
	MOVEQ	#XGM2_ACCESS_COMMAND, D7
	BSR.w	XGM2_RequestAccess
	TST.b	D0
	BEQ.w	XGM2_Play_Exit

	; Translate the relative music SID table to absolute 24-bit ROM addresses.
	LEA	8(A3), A1
	LEA	$100(A3), A2
	LEA	XGM2_SID_TABLE, A0
	MOVEQ	#123, D5
XGM2_Play_LoadSid:
	MOVEQ	#0, D0
	MOVE.b	1(A1), D0
	LSL.w	#8, D0
	MOVE.b	(A1), D0
	ADDQ.l	#2, A1
	CMPI.w	#$FFFF, D0
	BEQ.s	XGM2_Play_EmptySid
	LSL.l	#8, D0
	MOVE.l	A2, D1
	ADD.l	D1, D0
	MOVE.l	D0, D1
	LSR.l	#8, D1
	MOVE.b	D1, (A0)+
	LSR.l	#8, D1
	MOVE.b	D1, (A0)+
	BRA.s	XGM2_Play_NextSid
XGM2_Play_EmptySid:
	MOVE.b	#$FF, (A0)+
	MOVE.b	#$FF, (A0)+
XGM2_Play_NextSid:
	DBF	D5, XGM2_Play_LoadSid

	; Locate the FM and PSG streams in the compiled single-track layout.
	MOVEQ	#0, D4
	MOVE.b	2(A3), D4
	LSL.l	#8, D4
	MOVEQ	#0, D1
	MOVE.b	3(A3), D1
	SWAP	D1
	OR.l	D1, D4
	MOVE.l	A3, D1
	ADDI.l	#$100, D1
	ADD.l	D4, D1

	MOVEQ	#0, D4
	MOVE.b	4(A3), D4
	LSL.l	#8, D4
	MOVEQ	#0, D2
	MOVE.b	5(A3), D2
	SWAP	D2
	OR.l	D2, D4
	MOVE.l	D1, D2
	ADD.l	D4, D2

	MOVE.l	D1, D4
	LSR.l	#8, D4
	MOVE.b	D4, XGM2_PLAY_ARG_FM_ADDR
	LSR.l	#8, D4
	MOVE.b	D4, XGM2_PLAY_ARG_FM_ADDR+1
	MOVE.l	D2, D4
	LSR.l	#8, D4
	MOVE.b	D4, XGM2_PLAY_ARG_PSG_ADDR
	LSR.l	#8, D4
	MOVE.b	D4, XGM2_PLAY_ARG_PSG_ADDR+1

	; Preserve source tempo on either PAL or NTSC hardware.
	MOVE.w	VDP_CTRL, D0
	BTST	#0, D0
	BNE.s	XGM2_Play_HardwarePal
	BTST	#0, 1(A3)
	BNE.s	XGM2_Play_PalOnNtsc
	MOVE.b	#$00, XGM2_TEMPO_ARG_FRAC
	MOVE.b	#$01, XGM2_TEMPO_ARG_INT
	BRA.s	XGM2_Play_SetCommand
XGM2_Play_PalOnNtsc:
	MOVE.b	#$D5, XGM2_TEMPO_ARG_FRAC
	MOVE.b	#$00, XGM2_TEMPO_ARG_INT
	BRA.s	XGM2_Play_SetCommand
XGM2_Play_HardwarePal:
	BTST	#0, 1(A3)
	BNE.s	XGM2_Play_NativePal
	MOVE.b	#$33, XGM2_TEMPO_ARG_FRAC
	MOVE.b	#$01, XGM2_TEMPO_ARG_INT
	BRA.s	XGM2_Play_SetCommand
XGM2_Play_NativePal:
	MOVE.b	#$00, XGM2_TEMPO_ARG_FRAC
	MOVE.b	#$01, XGM2_TEMPO_ARG_INT

XGM2_Play_SetCommand:
	MOVE.b	XGM2_DRIVER_COMMAND, D0
	ANDI.b	#$D7, D0
	ORI.b	#XGM2_COMMAND_PLAY, D0
	MOVE.b	D0, XGM2_DRIVER_COMMAND
	BSR.w	XGM2_ReleaseBus
	MOVEQ	#1, D0

XGM2_Play_Exit:
	MOVE.w	(A7)+, SR
	MOVEM.l	(A7)+, D1-D7/A0-A3
	RTS

XGM2_Stop:
	MOVEM.l	D1-D7, -(A7)
	MOVE.w	SR, -(A7)
	ORI.w	#$0700, SR
	MOVEQ	#XGM2_ACCESS_COMMAND, D7
	BSR.w	XGM2_RequestAccess
	TST.b	D0
	BEQ.s	XGM2_Stop_Exit
	CLR.b	XGM2_PLAY_ARG_FM_ADDR
	CLR.b	XGM2_PLAY_ARG_FM_ADDR+1
	CLR.b	XGM2_PLAY_ARG_PSG_ADDR
	CLR.b	XGM2_PLAY_ARG_PSG_ADDR+1
	MOVE.b	XGM2_DRIVER_COMMAND, D0
	ANDI.b	#$D7, D0
	ORI.b	#XGM2_COMMAND_PLAY, D0
	MOVE.b	D0, XGM2_DRIVER_COMMAND
	BSR.w	XGM2_ReleaseBus
	MOVEQ	#1, D0
XGM2_Stop_Exit:
	MOVE.w	(A7)+, SR
	MOVEM.l	(A7)+, D1-D7
	RTS


; A0=sample, D0.l=len, D1.b=channel (-1 auto), D2.b=priority,
; D3.b bit0=half rate, bit1=loop. Returns D0.b success,
; D0 high byte = selected channel + 1 (MegaSVP addition).
XGM2_PlayPCM:
	MOVEM.l	D1-D7/A0-A2, -(A7)
	MOVE.w	SR, -(A7)
	ORI.w	#$0700, SR
	MOVE.l	D0, D4
	MOVEQ	#0, D5
	MOVE.b	D1, D5
	MOVEQ	#0, D6
	MOVE.b	D2, D6
	ANDI.b	#$0F, D6
	TST.l	D4
	BEQ.w	XGM2_PlayPCM_Fail
	MOVE.l	A0, D0
	TST.b	D0
	BNE.w	XGM2_PlayPCM_Fail
	TST.b	D4
	BNE.w	XGM2_PlayPCM_Fail

	MOVEQ	#XGM2_ACCESS_COMMAND+XGM2_ACCESS_PCM, D7
	BSR.w	XGM2_RequestAccess
	TST.b	D0
	BEQ.w	XGM2_PlayPCM_Exit
	MOVE.b	XGM2_DRIVER_STATUS, D0
	OR.b	XGM2_DRIVER_COMMAND, D0 ;pending starts already own their channels
	ANDI.b	#XGM2_STATUS_PCM_MASK, D0
	CMPI.b	#$FF, D5
	BNE.s	XGM2_PlayPCM_ManualChannel

	; Auto selection: prefer channel 3, then 2, then compare priorities.
	BTST	#2, D0
	BEQ.s	XGM2_PlayPCM_UseChannel3
	BTST	#1, D0
	BEQ.s	XGM2_PlayPCM_UseChannel2
	TST.w	M4_MUSIC_ACTIVE
	BNE.s	XGM2_PlayPCM_CompareSfx
	BTST	#0, D0
	BEQ.s	XGM2_PlayPCM_UseChannel1
XGM2_PlayPCM_CompareSfx:
	MOVEQ	#2, D5
	BSR.w	XGM2_PCM_Priority
	CMP.b	D6, D1
	BLS.s	XGM2_PlayPCM_UseChannel3
	MOVEQ	#1, D5
	BSR.w	XGM2_PCM_Priority
	CMP.b	D6, D1
	BLS.s	XGM2_PlayPCM_UseChannel2
	TST.w	M4_MUSIC_ACTIVE
	BNE.w	XGM2_PlayPCM_FailRelease
	MOVEQ	#0, D5
	BSR.w	XGM2_PCM_Priority
	CMP.b	D6, D1
	BLS.s	XGM2_PlayPCM_UseChannel1
	BRA.w	XGM2_PlayPCM_FailRelease

XGM2_PlayPCM_UseChannel3:
	MOVEQ	#2, D5
	BRA.s	XGM2_PlayPCM_Write
XGM2_PlayPCM_UseChannel2:
	MOVEQ	#1, D5
	BRA.s	XGM2_PlayPCM_Write
XGM2_PlayPCM_UseChannel1:
	MOVEQ	#0, D5
	BRA.s	XGM2_PlayPCM_Write

XGM2_PlayPCM_ManualChannel:
	CMPI.b	#2, D5
	BHI.w	XGM2_PlayPCM_FailRelease
	TST.b	D5
	BNE.s	XGM2_PlayPCM_ManualAllowed
	TST.w	M4_MUSIC_ACTIVE
	BNE.w	XGM2_PlayPCM_FailRelease
XGM2_PlayPCM_ManualAllowed:
	MOVEQ	#1, D1
	LSL.b	D5, D1
	AND.b	D0, D1
	BEQ.s	XGM2_PlayPCM_Write
	BSR.w	XGM2_PCM_Priority
	CMP.b	D6, D1
	BHI.w	XGM2_PlayPCM_FailRelease

XGM2_PlayPCM_Write:
	LEA	XGM2_PCM_ADDR_ARG_BASE, A1
	MOVE.w	D5, D2
	LSL.w	#2, D2
	ADDA.w	D2, A1
	MOVE.l	A0, D0
	LSR.l	#8, D0
	MOVE.b	D0, (A1)+
	LSR.l	#8, D0
	MOVE.b	D0, (A1)+
	MOVE.l	D4, D0
	BTST	#0, D3
	BEQ.s	XGM2_PlayPCM_FullRateLength
	LSR.l	#5, D0
	BRA.s	XGM2_PlayPCM_StoreLength
XGM2_PlayPCM_FullRateLength:
	LSR.l	#6, D0
XGM2_PlayPCM_StoreLength:
	MOVE.b	D0, (A1)+
	LSR.w	#8, D0
	MOVE.b	D0, (A1)

	MOVE.b	D6, D0
	ORI.b	#$10, D0
	BTST	#0, D3
	BEQ.s	XGM2_PlayPCM_NoHalfRate
	ORI.b	#$40, D0
XGM2_PlayPCM_NoHalfRate:
	BTST	#1, D3
	BEQ.s	XGM2_PlayPCM_NoLoop
	ORI.b	#$80, D0
XGM2_PlayPCM_NoLoop:
	LEA	XGM2_PCM_ARG_BASE, A1
	MOVE.b	D0, (A1,D5.w)
	MOVEQ	#1, D1
	LSL.b	D5, D1
	OR.b	D1, XGM2_DRIVER_COMMAND
	BSR.w	XGM2_ReleaseBus
	MOVE.w	D5, D0
	ADDQ.w	#1, D0
	LSL.w	#8, D0
	MOVE.b	#1, D0
	BRA.s	XGM2_PlayPCM_Exit

XGM2_PlayPCM_FailRelease:
	BSR.w	XGM2_ReleaseBus
XGM2_PlayPCM_Fail:
	MOVEQ	#0, D0
XGM2_PlayPCM_Exit:
	MOVE.w	(A7)+, SR
	MOVEM.l	(A7)+, D1-D7/A0-A2
	RTS

; D5=channel -> D1=priority. Pending command parameters supersede the
; running voice, which the Z80 will replace at its next VBlank interrupt.
XGM2_PCM_Priority:
	BTST	D5, XGM2_DRIVER_COMMAND
	BNE.s	XGM2_PCM_PriorityPending
	LEA	XGM2_PCM_PARAM_BASE, A1
	MOVE.w	D5, D2
	LSL.w	#3, D2
	MOVE.b	XGM2_PCM_PRIORITY_OFFSET(A1,D2.w), D1
	BRA.s	XGM2_PCM_PriorityMask
XGM2_PCM_PriorityPending:
	LEA	XGM2_PCM_ARG_BASE, A1
	MOVE.b	(A1,D5.w), D1
XGM2_PCM_PriorityMask:
	ANDI.b	#$0F, D1
	RTS

; D0.b = channel 0..2. Returns D0.b success.
XGM2_StopPCM:
	MOVEM.l	D1-D7/A0, -(A7)
	MOVE.w	SR, -(A7)
	ORI.w	#$0700, SR
	MOVEQ	#0, D5
	MOVE.b	D0, D5
	CMPI.b	#2, D5
	BHI.s	XGM2_StopPCM_Fail
	MOVEQ	#XGM2_ACCESS_COMMAND+XGM2_ACCESS_PCM, D7
	BSR.w	XGM2_RequestAccess
	TST.b	D0
	BEQ.s	XGM2_StopPCM_Exit
	LEA	XGM2_PCM_ADDR_ARG_BASE, A0
	MOVE.w	D5, D2
	LSL.w	#2, D2
	ADDA.w	D2, A0
	CLR.b	(A0)+
	CLR.b	(A0)+
	CLR.b	(A0)+
	CLR.b	(A0)
	LEA	XGM2_PCM_ARG_BASE, A0
	MOVE.b	#$1F, (A0,D5.w)
	MOVEQ	#1, D1
	LSL.b	D5, D1
	OR.b	D1, XGM2_DRIVER_COMMAND
	BSR.w	XGM2_ReleaseBus
	MOVEQ	#1, D0
	BRA.s	XGM2_StopPCM_Exit
XGM2_StopPCM_Fail:
	MOVEQ	#0, D0
XGM2_StopPCM_Exit:
	MOVE.w	(A7)+, SR
	MOVEM.l	(A7)+, D1-D7/A0
	RTS

; D0.b = requested channel mask. Returns the active subset in D0.b.
XGM2_IsPlayingPCM:
	MOVEM.l	D1-D7, -(A7)
	MOVE.w	SR, -(A7)
	ORI.w	#$0700, SR
	MOVE.b	D0, D6
	MOVEQ	#XGM2_ACCESS_COMMAND, D7
	BSR.w	XGM2_RequestAccess
	TST.b	D0
	BEQ.s	XGM2_IsPlayingPCM_Exit
	MOVE.b	XGM2_DRIVER_STATUS, D4
	AND.b	D6, D4
	ANDI.b	#XGM2_STATUS_PCM_MASK, D4
	BSR.w	XGM2_ReleaseBus
	MOVE.b	D4, D0
XGM2_IsPlayingPCM_Exit:
	MOVE.w	(A7)+, SR
	MOVEM.l	(A7)+, D1-D7
	RTS

; D7.b = access mask. Returns D0.b success and leaves the Z80 bus held.
XGM2_RequestAccess:
	MOVEM.l	D5-D6, -(A7)
	MOVE.w	#XGM2_ACCESS_TIMEOUT, D5
XGM2_RequestAccess_Retry:
	BSR.w	XGM2_RequestBus
	MOVE.b	XGM2_ACCESS, D6
	AND.b	D7, D6
	BEQ.s	XGM2_RequestAccess_Granted
	BSR.w	XGM2_ReleaseBus
	MOVEQ	#31, D6
XGM2_RequestAccess_Delay:
	DBF	D6, XGM2_RequestAccess_Delay
	DBF	D5, XGM2_RequestAccess_Retry
	MOVEQ	#0, D0
	MOVEM.l	(A7)+, D5-D6
	RTS
XGM2_RequestAccess_Granted:
	MOVEQ	#1, D0
	MOVEM.l	(A7)+, D5-D6
	RTS

XGM2_RequestBus:
	MOVE.w	#$0100, XGM2_Z80_BUSREQ
	MOVE.w	#$0100, XGM2_Z80_RESET
XGM2_RequestBus_Wait:
	BTST.b	#0, XGM2_Z80_BUSREQ
	BNE.s	XGM2_RequestBus_Wait
	RTS

XGM2_ReleaseBus:
	MOVE.w	#$0000, XGM2_Z80_BUSREQ
	RTS

XGM2_ResetSoundChips:
	; Minimal deterministic YM reset before the XGM2 driver initializes it.
	MOVEQ	#0, D0
	MOVEQ	#$22, D1
	BSR.s	XGM2_WriteYm
	MOVEQ	#1, D0
	MOVEQ	#0, D1
	BSR.s	XGM2_WriteYm
	MOVEQ	#0, D0
	MOVEQ	#$27, D1
	BSR.s	XGM2_WriteYm
	MOVEQ	#1, D0
	MOVEQ	#0, D1
	BSR.s	XGM2_WriteYm
	MOVEQ	#0, D0
	MOVEQ	#$2B, D1
	BSR.s	XGM2_WriteYm
	MOVEQ	#1, D0
	MOVEQ	#0, D1
	BSR.s	XGM2_WriteYm
	MOVEQ	#0, D0
	MOVEQ	#$28, D1
	BSR.s	XGM2_WriteYm
	MOVEQ	#1, D0
	MOVEQ	#0, D1
XGM2_ResetSoundChips_KeyOff:
	BSR.s	XGM2_WriteYm
	ADDQ.b	#1, D1
	CMPI.b	#3, D1
	BNE.s	XGM2_ResetSoundChips_KeyOff
	MOVEQ	#4, D1
XGM2_ResetSoundChips_KeyOffPort1:
	BSR.s	XGM2_WriteYm
	ADDQ.b	#1, D1
	CMPI.b	#7, D1
	BNE.s	XGM2_ResetSoundChips_KeyOffPort1
	MOVE.b	#$9F, $c00011
	MOVE.b	#$BF, $c00011
	MOVE.b	#$DF, $c00011
	MOVE.b	#$FF, $c00011
	RTS

; D0.w = YM port (0..3), D1.b = value.
XGM2_WriteYm:
	LEA	XGM2_YM2612, A2
XGM2_WriteYm_Wait:
	TST.b	(A2)
	BMI.s	XGM2_WriteYm_Wait
	MOVE.b	D1, (A2,D0.w)
	NOP
	NOP
	NOP
	NOP
	NOP
	RTS


        even
XGM2_Driver:
        incbin "audio/drv_xgm2.bin"
XGM2_Driver_End:
        if (XGM2_Driver_End-XGM2_Driver)<>$2000
        inform 3,"XGM2 driver must be 8192 bytes"
        endif
