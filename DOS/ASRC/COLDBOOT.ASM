TITLE COLDBOOT Program
PAGE 66,80 ; 66 lines per page, 80 characters/line

;; A simple program to clear the WARMBOOT flag and then reset the system
;; ADDRESS (RESET_FLAG): 40:0072h
;; WARM_START = 1234h
;; COLD_START = 0000h

cold_start					EQU 0000h


BIOS_DATA SEGMENT AT 0040h
	ORG 0072h
	reset_flag dw ?
BIOS_DATA ENDS

BIOS_ROM SEGMENT AT 0F000h
	ORG 0FFF0h
	RESTART LABEL FAR
BIOS_ROM ENDS

CODESEG SEGMENT
	assume CS:CODESEG, DS:CODESEG, SS:CODESEG
BEGIN = $
	ORG	100h
	PROGRAM:
	
; 1.) Change RESET_FLAG to COLD_START
mov		ax,BIOS_DATA
mov		ds,ax			; Set DS to BIOS_DATA segment
assume	DS:BIOS_DATA
mov		ax,cold_start	; Set value to COLD_START
mov		[reset_flag],ax ; Set reset_flag to COLD_START

; 2.) Jump to the system reset vector
jmp		RESTART

ENDOFPROG EQU $ ; Used for CARTSIZ calculation
CODESEG ENDS
END PROGRAM
