TITLE READKEY Program
PAGE 66,80 ; 66 lines per page, 80 characters/line

;; This program reads key presses and prints them OUT
; Primarily exists as a reference because I always
; forget theorder of the flags
; Press 'esc' to quit

; INT16h
;svc1 - get state of keyboard buffer
; JNZ - ZF = 0 = Unset - Key Pressed 
; JZ - ZF = 1 = Set - No Key Pressed

%OUT Processing EQUATES...

int_bios_keypress			EQU 09h

int_video_10						EQU	10h
	svc_video_get_mode			EQU 0Fh
	svc_video_write_char_tty	EQU	0Eh
		tty_page			EQU 00h
int_keyboard_16				EQU 16h
	svc_keyboard_read_key	EQU	00h
	svc_keyboard_get_state	EQU 01h
		val_esc_key			EQU 1Bh ; 27 decimal

int_dos_21					EQU	21h
	svc_dos_print_character	EQU 02h
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
jmp MAIN

MAIN:
		mov		ax,cs
		mov		ds,ax ; Set DS
		
		mov		dx,offset msg ; Print Welcome message
		mov		ah,svc_dos_print_string
		int		int_dos_21
KEYLOOP: ; Keyread loop
		mov		ah,svc_keyboard_get_state
		int		int_keyboard_16 ; Check keyboard state
		jz		KEYLOOP ; If no key pressed, wait until one is
		; Key was pressed, read it
		mov		ah,svc_keyboard_read_key
		int		int_keyboard_16
		cmp		al,val_esc_key ; if ESC, exit
		je		EXIT2DOS
		; else, print it
		mov		dl,al
		mov		ah,svc_dos_print_character
		int		int_dos_21
		jmp		KEYLOOP
EXIT2DOS:
	mov		ax,(svc_dos_terminate SHL 8) OR val_dos_terminate_0 
	int		int_dos_21 ;; EXIT to DOS
HALT:
	jmp		HALT ; In case DOS somehow doesn't end the program, should never reach

msg		db "Press keys to print them out, press ESC to quit...",0Dh,0Ah,"$"

CODESEG ENDS
END PROGRAM
