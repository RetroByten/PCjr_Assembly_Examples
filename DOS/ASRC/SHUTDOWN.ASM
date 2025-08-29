TITLE SHUTDOWN Program
PAGE 66,80 ; 66 lines per page, 80 characters/line

;; A simple program to halt interrupts and infinite loop the PC

int_bios_video_10h				EQU 10h
	svc_set_video_mode			EQU 00h
		val_160x200_16_graphics	EQU 08h
		val_color_brown			EQU 06h
	svc_set_cursor_pos			EQU 02h
	svc_get_cursor_pos			EQU 03h
	svc_teletype				EQU 0Eh
	svc_get_video_mode			EQU 0Fh

int_bios_keyboard_16h			EQU 16h
	svc_read_keypress			EQU 00h
	svc_get_key_buffer_state	EQU 01h			
	
pcjr_char						EQU 01h ; ':)'
pcjr_char_print_disable			EQU 01h

CODESEG SEGMENT
	assume CS:CODESEG, DS:CODESEG, SS:CODESEG
BEGIN = $
	ORG	100h
	PROGRAM:
	
	; 1.) Change video mode to 160x200, 16 Color Graphics
	mov		ax,(svc_set_video_mode SHL 8) OR val_160x200_16_graphics
	int		int_bios_video_10h
	
	; 2.) Get video mode to get active page
	mov		ah,svc_get_video_mode
	int		int_bios_video_10h
	mov		active_page,bh ; store active page

	; 3.) Set Cursor position to 11,0
	mov		bh,active_page
	mov		dh,11 ; decimal
	mov		dl,0  ; decimal
	mov		ah,svc_set_cursor_pos
	int		int_bios_video_10h

	; 4.) Print message
	mov		si,offset str_shutdown
PRINT_LOOP:
	lodsb ; Load AL with DS:[SI], inc si
	cmp		al,'$'
	jz		START_HALT
	mov		bh,active_page
	mov		bl,val_color_brown
	mov		ah,svc_teletype
	int		int_bios_video_10h
	jmp		PRINT_LOOP
	
	; 5.) Empty keybuffer, disable interrupts, and halt forever
START_HALT:
	; Clear out the keyboard buffer to avoid beeps if the user hits keys
	mov		ah,svc_get_key_buffer_state
	int		int_bios_keyboard_16h
	jz		DISABLE_INT ; If no key presses in buffer, we're done
	mov		ah,svc_read_keypress ; otherwise read it out
	int		int_bios_keyboard_16h
	jmp		START_HALT
DISABLE_INT:
	cli ; Disable interrupts
HALT:
	hlt ; Halt!
	
PCJR:	; Hey! How'd you get here...
		; NMI (keyboard for PCjr) can revive from a halt
		; Could disable NMI, but leaving it
		; also allows ctrl+alt+del to still work
	mov		al,pcjr_status
	cmp		al,pcjr_char_print_disable
	jz		START_HALT
	mov		al,pcjr_char_print_disable  ; Only trigger once
	mov		pcjr_status,al
	mov		si,offset str_pcjr
	jmp		PRINT_LOOP
	
	; Variables
	active_page db 00h
	pcjr_status db 00h
	
	; Messages
	;               "01234567890123456789"
	str_shutdown db "  It's now safe to  "
				 db "   shutdown your    "
				 db "     computer.$     "
	str_pcjr   db pcjr_char,'$'

ENDOFPROG EQU $ ; Used for CARTSIZ calculation
CODESEG ENDS
END PROGRAM
