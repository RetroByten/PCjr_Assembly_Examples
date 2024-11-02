TITLE CART Template Program
PAGE 66,80 ; 66 lines per page, 80 characters/line

;; Template for a DOS program that can either
; Run from cartridge or run from DOS

; NOTE1: CRC needs to be calculated externally
; NOTE2: Does not add JRC header for emulators

CODESEG SEGMENT
	assume CS:CODESEG, DS:CODESEG, SS:CODESEG
	
ROM EQU 0 ; Set to 0 if COM, Set to 1 if ROM
		
IF ROM 	;; Cartride Header
	ORG 0
	PROGRAM:
	CARTSIG		dw 0AA55h					; Cartridge Signature
	CARTSIZ		db (ENDLOC - PROGRAM) / 512 ; Cartride size in 512 byte chunks
	jmp			INIT						; Cartridge BIOS Init Entry Point
	DOSCMD1L	db DOSCMD1E - DOSCMD1S		; Length of DOS Command1 name
	DOSCMD1S	db "MAIN"					; DOS Command1 name string
	DOSCMD1E:								; End of Command1 name string
	jmp			MAIN						; DOS Command1 Entry Point
	;DOSCMD2L	db DOSCMD2E - DOSCMD2S		; Length of DOS Command2 name
	;DOSCMD2S	db "ALT"					; DOS Command2 name string
	;DOSCMD2E:								; End of Command2 name string
	;jmp		ALT							; DOS Command2 Entry Point
	CARTEOH		db 00h						; End of header
ELSE 	;; DOS COM Entry
	ORG	100h
	PROGRAM:
	jmp			MAIN						; DOS Command Entry Point
ENDIF

INIT PROC FAR 	; BIOS enters
	;; Insert BIOS INIT code here
	ret ; Far Return
INIT ENDP

MAIN PROC FAR
	;; Insert DOS MAIN code here
	mov		ax,4C00h ; DOS Service 4Ch (Terminate), exit code 0
	int		21h ; DOS Interrupt
MAIN ENDP

;ALT PROC FAR
	;; Insert DOS ALT code here
;	mov		ax,4C00h ; DOS Service 4Ch (Terminate), exit code 0
;	int		21h ; DOS Interrupt
;ALT ENDP

IF ROM 	; Align CARTCRC to end of a 512 byte boundary
	IF ($-PROGRAM+2) MOD 512 ; If end of next word (+2) is not on a 512 byte boundary
		ORG ($-PROGRAM+2)+512-(($-PROGRAM+2) MOD 512) - 2 ; Round up, minus 2
	ENDIF
	CARTCRC dw 0000h ; Placeholder for cartridge CRC
ENDIF
ENDLOC EQU $ ; Used for CARTSIZ calculation

CODESEG ENDS
END PROGRAM
