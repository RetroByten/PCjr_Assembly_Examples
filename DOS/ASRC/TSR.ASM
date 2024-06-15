TITLE TSR Program
PAGE 66,80 ; 66 lines per page, 80 characters/line

;; This program will implement a TSR that hooks INT9 and looks
; for the ESC key:
; If ESC is pressed, print a message and then hand control to original INT9
; If no, hand control to original INT9

%OUT Processing EQUATES...

int_bios_keypress			EQU 09h

int_video						EQU	10h
	svc_video_get_mode			EQU 0Fh
	svc_video_write_char_tty	EQU	0Eh

int_dos_21					EQU	21h
	svc_dos_print_string	EQU 09h
	svc_dos_set_int_vector  EQU 25h
	svc_dos_terminate		EQU	4Ch
		val_dos_terminate_0	EQU 00h
	svc_dos_keep_resident	EQU 31h
	svc_dos_get_int_vector	EQU 35h

%OUT PROCESSING MACRO
UTIL_PRINT_BYTE MACRO
	; Print 2 Nibbles from AH
	; AH = byte
	push	cx
	mov		cx,02h
	call 	UTIL_PRINT_HEX_NIBBLES
	pop		cx
ENDM
UTIL_PRINT_WORD MACRO
	; Print 4 Nibbles from AX
	; AX = word
	push	cx
	mov		cx,04h
	call 	UTIL_PRINT_HEX_NIBBLES
	pop		cx
ENDM
UTIL_PRINT_NEWLINE MACRO
	;; Print \r\n
	push	bx
	; get page into bh
	mov		ah,svc_video_get_mode
	int		int_video
	mov		ax,(svc_video_write_char_tty SHL 8) OR 0Dh
	int		int_video
	; get page
	mov		ah,svc_video_get_mode
	int		int_video
	mov		ax,(svc_video_write_char_tty SHL 8) OR 0Ah;
	int		int_video
	pop		bx
ENDM

%OUT Processing CODE Segment
CODESEG SEGMENT
	assume CS:CODESEG, DS:CODESEG, SS:CODESEG
ORG 100h
PROGRAM: ; Needed for COM to later terminate the program
jmp INIT
UTIL_PRINT_HEX_NIBBLES PROC NEAR
	; CX = # Of nibbles to print
	; AX = 1-4 nibbles to print from AH high -> AL Low
	push	bx
UTIL_PRINT_HEX_NIBBLES_LOOP:
	rol		ax,1 ; Grab the highest nibble by Rotating left 4x
	rol		ax,1 ;
	rol		ax,1 ;
	rol		ax,1 ; 
	push	ax ; Save off the Nth rotated AX
	and		al,00Fh ; Isolate the nibble
	add		al,'0' ; Shift into the ASCII Numeric Range
	cmp		al,'9' ; Check if <= 9
	jle		UTIL_PRINT_HEX_NIBBLES_CONT
	add		al,'A'-'9'-1 ; If not, shift up to ASCII 'A' range
UTIL_PRINT_HEX_NIBBLES_CONT:
	push	ax ; save character
	; Get current video PAGE, sets bh
	mov		ah,svc_video_get_mode
	int		int_video
	pop		ax ; restore character
	mov		ah,svc_video_write_char_tty ; Select DOS Print TTY service
	int		int_video ; Print current character
	pop		ax ; Restore Nth rotated AX
	loop	UTIL_PRINT_HEX_NIBBLES_LOOP
	pop		bx
	ret
UTIL_PRINT_HEX_NIBBLES ENDP

TSR_MAIN:
	push	ax
	cmp		al,1 ; check if ESC was hit
	jne		CALL_ORIG ; bail if not
	push	cx
	push	bp
	UTIL_PRINT_NEWLINE ; Print newline
	mov		bp,sp ; set base pointer
	add		bp,6 ; get past the pushed BP,CX,AX
	mov		cx,16
TSR_LOOP:
	mov		ax,[bp]
	push	bp
	UTIL_PRINT_WORD
	UTIL_PRINT_NEWLINE
	pop		bp
	inc		bp
	inc		bp
	loop	TSR_LOOP
	pop		bp
	pop		cx
CALL_ORIG:
	pop		ax
	jmp DWORD PTR cs:[old_int9_offset]
old_int9_offset dw ?
old_int9_segment dw ?
ENDOFTSR:

INIT:
	;; Set DS as CS, Save DS
	mov		ax,cs
	mov		ds,ax ; setup DS
	;; Get & Save old INT9
	mov		ax, (svc_dos_get_int_vector SHL 8) OR int_bios_keypress
	int		int_dos_21
	mov		[old_int9_offset],bx
	mov		bx,es ; Get segment
	mov		[old_int9_segment],bx
	;; Set New INT9
	mov		ax,(svc_dos_set_int_vector SHL 8) OR int_bios_keypress
	mov		dx,offset TSR_MAIN ; DS is already Set
	int		int_dos_21
	;; Print success
	mov		dx,offset setup_complete_msg
	mov		ah,svc_dos_print_string
	int		int_dos_21
	;; Exit to DOS
EXIT2DOS:
	mov		dx,(offset ENDOFTSR - offset PROGRAM + 100h + 15) SHR 4 ; end-begin + PSP + round up, convert to para
	mov		ax,(svc_dos_keep_resident SHL 8) OR val_dos_terminate_0
	int		int_dos_21 ;; EXIT to DOS
HALT:
	jmp		HALT ; In case DOS somehow doesn't end the program, should never reach

setup_complete_msg db "Setup complete",0dh,0ah,'$'

CODESEG ENDS
END PROGRAM
