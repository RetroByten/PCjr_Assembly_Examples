TITLE CMDNAME Program
PAGE 66,80 ; 66 lines per page, 80 characters/line

;; Program to test various aspects of the DOS CMD parsing
;; logic.
; NOTE1: CRC needs to be calculated externally


ROM EQU 0 ; Set to 0 if COM, Set to 1 if ROM
EXE EQU 0 ; Set to 0 if COM, Set to 1 if EXE

CODESEG SEGMENT
	assume CS:CODESEG, DS:CODESEG, SS:CODESEG
BEGIN = $	; Mark 0000h for calculations
IF ROM 	;; Cartridge Header
	ORG 0
	PROGRAM:
	CARTSIG		dw 0AA55h					; Cartridge Signature
	CARTSIZ		db (ENDOFPROG - PROGRAM) / 512 ; Cartride size in 512 byte chunks
	jmp			NEAR PTR INIT				; Cartridge BIOS Init Entry Point
	DOSCMD1L	db DOSCMD1E - DOSCMD1S		; Length of DOS Command1 name
	DOSCMD1S	db "CMDNAME"					; DOS Command1 name string
	DOSCMD1E:								; End of Command1 name string
	jmp			NEAR PTR MAIN				; DOS Command1 Entry Point
	;DOSCMD2L	db DOSCMD2E - DOSCMD2S		; Length of DOS Command2 name
	;DOSCMD2S	db "ALT"					; DOS Command2 name string
	;DOSCMD2E:								; End of Command2 name string
	;jmp		NEAR PTR ALT				; DOS Command2 Entry Point
	CARTEOH		db 00h						; End of cartridge header
ELSE 	;; DOS COM Entry
	ORG	100h
	PROGRAM:
	jmp			NEAR PTR MAIN				; DOS Command Entry Point
ENDIF

IF ROM
	printchar EQU 'R'
ELSE
	IF EXE
		printchar EQU 'E'
	ELSE
		printchar EQU 'C'
	ENDIF
ENDIF



INIT PROC FAR 	; BIOS enters
	;; Insert BIOS INIT code here
	ret ; Far Return
INIT ENDP

MAIN PROC FAR
	push	ds
	xor		ax,ax
	push	ax ; Setup DOS Return
	
	mov		ah,0Eh ; BIOS Video Interrupt TTY Service
	mov		al,printchar
	int		10h ; BIOS Video interrupt

	ret ; return to DOS
MAIN ENDP

db "0123456789ABCDEF" ; Helps with debugging alignment
IF ROM 	; Align CARTCRC to end of a 512 byte boundary
	IF ($-BEGIN+2) MOD 512 ; If end of next word (+2) is not on a 512 byte boundary
		ORG ($-BEGIN+2)+512-(($-BEGIN+2) MOD 512) - 2 ; Round up, minus 2
	ENDIF
	CARTCRC dw 0000h ; Placeholder for cartridge CRC
ELSE
	IF ($-BEGIN+2) MOD 16 ; If end of next word (+2) is not on a 16 byte boundary
		ORG ($-BEGIN+2)+16-(($-BEGIN+2) MOD 16) - 2 ; Round up, minus 2
	ENDIF
	ENDMARK dw 0EFBEh ; Marker for end to help in debugging
ENDIF
ENDOFPROG EQU $ ; Used for CARTSIZ calculation
CODESEG ENDS
END PROGRAM
