TITLE ALIGNMENT Program
PAGE 66,80 ; 66 lines per page, 80 characters/line

;; This program shows calculations for aligning to 512K chunk or PAGE
; + an offset for an end of file marker

; NOTE1: CRC needs to be calculated externally

ROM EQU 0 ; Set to 0 if COM, Set to 1 if ROM

int_dos_21					EQU	21h
	svc_dos_print_chr_02		EQU 02h
	svc_dos_print_string_09		EQU 09h
	svc_dos_keep_resident_31	EQU 31h 
	svc_dos_terminate_4c			EQU 4Ch
		val_dos_terminate_0			EQU 00h
	svc_dos_allocate_48			EQU 48h
	svc_dos_deallocate_48		EQU 49h
	svc_dos_setblock_4a			EQU 4Ah


CODESEG SEGMENT
	assume CS:CODESEG, DS:CODESEG, SS:CODESEG
BEGIN = $
IF ROM 	;; Cartridge Header
	ORG 0
	PROGRAM:
	CARTSIG		dw 0AA55h					; Cartridge Signature
	CARTSIZ		db (ENDOFPROG - PROGRAM) / 512 ; Cartride size in 512 byte chunks
	jmp			NEAR PTR INIT				; Cartridge BIOS Init Entry Point
	DOSCMD1L	db DOSCMD1E - DOSCMD1S		; Length of DOS Command1 name
	DOSCMD1S	db "MAIN"					; DOS Command1 name string
	DOSCMD1E:								; End of Command1 name string
	jmp			NEAR PTR MAIN				; DOS Command1 Entry Point
	CARTEOH		db 00h						; End of cartridge header
ELSE 	;; DOS COM Entry
	ORG	100h
	PROGRAM:
	jmp			NEAR PTR MAIN				; DOS Command Entry Point
ENDIF

INIT PROC FAR 	; BIOS enters
	;; Insert BIOS INIT code here
	ret ; Far Return
INIT ENDP

MAIN PROC FAR
	mov		ax,(svc_dos_terminate_4c SHL 8) OR val_dos_terminate_0 ; DOS Service 4Ch (Terminate), exit code 0
	int		int_dos_21 ; DOS Interrupt
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