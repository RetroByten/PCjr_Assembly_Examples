TITLE JMP Program
PAGE 66,80 ; 66 lines per page, 80 characters/line

;; This is to understand JMP offsets

%OUT Processing EQUATES...

int_bios_keypress			EQU 09h

int_video						EQU	10h
	svc_video_get_mode			EQU 0Fh
	svc_video_write_char_tty	EQU	0Eh
		tty_page			EQU 00h
int_keyboard				EQU 16h
	svc_keyboard_read_key	EQU	00h
	svc_keyboard_get_state	EQU 01h

int_dos_21					EQU	21h
	svc_dos_print_string	EQU 09h
	svc_dos_set_int_vector  EQU 25h
	svc_dos_terminate		EQU	4Ch
		val_dos_terminate_0	EQU 00h
	svc_dos_keep_resident	EQU 31h
	svc_dos_get_int_vector	EQU 35h
%OUT Processing CODE Segment
CODESEG SEGMENT
	assume CS:CODESEG, DS:CODESEG, SS:CODESEG
ORG 100h
PROGRAM: ; Needed for COM to later terminate the program
jmp MAIN ; E9 FD 01 = 300h - 100h - <jmp_length[3]>
dw MAIN - PROGRAM - 3 ; attempting to calculate relative offset

ORG 300h
MAIN:
jmp EXITJMP
db "ORG 303h"

ORG 500h
EXITJMP:
jmp	EXIT2DOS
db "ORG 503h"
EXIT2DOS:
	mov		ax,(svc_dos_terminate SHL 8) OR val_dos_terminate_0 
	int		int_dos_21 ;; EXIT to DOS
HALT:
	jmp		HALT ; In case DOS somehow doesn't end the program, should never reach

CODESEG ENDS
END PROGRAM
