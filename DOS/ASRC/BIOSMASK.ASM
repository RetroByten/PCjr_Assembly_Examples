TITLE CART Template Program
PAGE 66,80 ; 66 lines per page, 80 characters/line

;; Template for a DOS program that can either
; Run from cartridge or run from DOS

; NOTE1: CRC needs to be calculated externally
; NOTE2: Does not add JRC header for emulators

ROM EQU 1 ; Set to 0 if COM, Set to 1 if ROM
int_bios_video_10					EQU 10h
	svc_bios_video_setmode_00			EQU	00h
	svc_bios_video_tty_0E				EQU 0Eh
	svc_bios_video_getmode_0F			EQU 0Fh
		val_bios_video_col_white_0F			EQU 0Fh
int_keyboard_16				EQU 16h
	svc_keyboard_read_key	EQU	00h
port_pic_data				EQU 21h ; 8259A PIC data port


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
	DOSCMD1S	db "BIOSMASK"				; DOS Command1 name string
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

UTIL_PRINT_CHAR PROC NEAR ; Assumes al or constant
	push	bx
	push	ax ; Temporarily store AL
	mov		ah,svc_bios_video_getmode_0F ; Get video mode for page
	int		int_bios_video_10 ; bh = active page now
	mov		bl,val_bios_video_col_white_0F
	pop		ax ; Retrieve AL
	
	mov		ah,svc_bios_video_tty_0E ; Req: AL = chr, BH = pag, bl = col
	int		int_bios_video_10
	pop		bx
	ret
UTIL_PRINT_CHAR ENDP

UTIL_PRINT_HEX_NIBBLES PROC NEAR ; BIOS compatible
UTIL_PRINT_HEX_NIBBLES_LOOP:
	rol		ax,1 ; Grab the highest nibble by Rotating left 4x into al low nibble
	rol		ax,1 ;
	rol		ax,1 ;
	rol		ax,1 	; AL now contains "highest remaining nibble"
	push	ax ; Save off the Nth rotated AX
	and		al,0Fh ; Isolate nibble
	add		al,'0' ; Attempt to shift into ASCII numeric range
	cmp		al,'9' ; Check if <= '9' ASCII
	jle		UTIL_PRINT_HEX_NIBBLES_CONT ; Yup, continue
	add		al,'A'-'9'-1 ; If not, shift up to ASCII 'A' range
UTIL_PRINT_HEX_NIBBLES_CONT:
	call	UTIL_PRINT_CHAR
	pop		ax ; recover AX
	loop	UTIL_PRINT_HEX_NIBBLES_LOOP ; dec CX until 0
	ret
UTIL_PRINT_HEX_NIBBLES ENDP

UTIL_PRINT_STR PROC NEAR ; Uses BIOS function
	xchg		si,dx ; Use SI as index, save old SI
UTIL_PRINT_STR_LOOP:
	lodsb	; mov al,ds:[si], inc si
	cmp		al,'$'
	je		UTIL_PRINT_STR_DONE
	call	UTIL_PRINT_CHAR
	jmp		UTIL_PRINT_STR_LOOP
UTIL_PRINT_STR_DONE:
	mov		si,dx ; Get back SI
	ret
UTIL_PRINT_STR ENDP

str_mask db "Interrupt Mask: $"
str_press_enter db "Press Enter to Continue...$"
INIT PROC FAR 	; BIOS enters
	;; Insert BIOS INIT code here
	mov		ax,cs
	mov		ds,ax ; DS = CS
	
	mov		dx,offset str_mask
	call	UTIL_PRINT_STR
	
	mov		cx,0002h ; Print 2 nibbles
	in		al,port_pic_data ; Get current mask
	mov		ah,al
	call	UTIL_PRINT_HEX_NIBBLES
	
	mov		dx,offset str_press_enter
	call	UTIL_PRINT_STR
	
	;; Wait for key press
	mov		ah,svc_keyboard_read_key
	int		int_keyboard_16
	
	ret ; Far Return
INIT ENDP

MAIN PROC FAR
	;; Insert DOS MAIN code here
	push	cs ; for INIT far return
	call	NEAR PTR INIT
	
	
	mov		ax,4C00h ; DOS Service 4Ch (Terminate), exit code 0
	int		21h ; DOS Interrupt
MAIN ENDP

;ALT PROC FAR
	;; Insert DOS ALT code here
;	mov		ax,4C00h ; DOS Service 4Ch (Terminate), exit code 0
;	int		21h ; DOS Interrupt
;ALT ENDP

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