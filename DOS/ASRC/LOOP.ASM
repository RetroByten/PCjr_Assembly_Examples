TITLE LOOP Program
PAGE 66,80 ; 66 lines per page, 80 characters/line

;; This program is intended to be loaded by DEBUG to show the LOOP
; exit conditions when stepped through with -t trace
; Intent is to read/shift all 8 bits to figure out
; how to set CX without overflowing the low bx byte

%OUT Processing EQUATES...

int_dos_21					EQU	21h
	svc_dos_terminate		EQU	4Ch
		val_dos_terminate_0	EQU 00h

%OUT Processing CODE Segment
CODESEG SEGMENT
	assume CS:CODESEG, DS:CODESEG, SS:CODESEG
ORG 100h
PROGRAM: ; Needed for COM to later terminate the program
jmp MAIN


MAIN:
	mov		cx,8
	mov		bx,0
LOOPY:
	;; Would output current top bit here
	shl		bx,1
	or		bx,1 ; Pretend to read in new value
	loop	loopy
;; At this point, we have output and input all 8 bits

EXIT2DOS:
	mov		ax,(svc_dos_terminate SHL 8) OR val_dos_terminate_0 
	int		int_dos_21 ;; EXIT to DOS
HALT:
	jmp		HALT ; In case DOS somehow doesn't end the program, should never reach

CODESEG ENDS
END PROGRAM
