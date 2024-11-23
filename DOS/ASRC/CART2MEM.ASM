TITLE CART2MEM Program
PAGE 66,80 ; 66 lines per page, 80 characters/line

;; This program is trying to determine if
;; running a cartridge program that reserves memory
;; and TSRs breaks another cartridge Program
;; due to the lower load address 

ROM EQU 1 ; Set to 0 if COM, Set to 1 if ROM
IF ROM
	%OUT Building CART2MEM ROM
ELSE
	%OUT Building CART2MEM COM
ENDIF

%OUT PROCESSING PROGRAM EQUATES
interrupt_vector_table_segment		EQU 0000h
int_bios_keypress_09h				EQU 09h
int_bios_video_10					EQU 10h
	svc_bios_video_setmode_00			EQU	00h
	svc_bios_video_tty_0E				EQU 0Eh
	svc_bios_video_getmode_0F			EQU 0Fh
		val_bios_video_col_white_0F			EQU 0Fh
	svc_dos_free_allocated_mem_49			EQU 49h
		val_dos_env_offset_2C				EQU 2Ch
	svc_dos_setblock_4A					EQU	4Ah
int_dos_21							EQU	21h
    svc_dos_print_char_02			EQU 02h
	svc_dos_print_str_09			EQU 09h
	svc_dos_set_int_vector_25		EQU 25h
	svc_dos_keep_resident_31		EQU 31h
	svc_dos_get_int_vector_35		EQU 35h
	svc_dos_terminate_4C			EQU 4Ch
		val_dos_terminate_00				EQU 00h
		val_dos_terminate_01			EQU 01h
int_pkt_driver_60					EQU 60h

UTILM_PRINT_STR MACRO str
	push	ds
	push	dx
	push	si
	push	ax
	
	push	cs
	pop		ds ; set DS
	
	mov		dx,offset str ; set DX
	call	UTIL_PRINT_STR
	
	pop		ax
	pop		si
	pop		dx
	pop		ds
ENDM

UTILM_PRINT_CHAR MACRO chr ; Assumes al or constant
	push	bx
	push	ax ; in case user passed us al
	mov		al, chr
	call	UTIL_PRINT_CHAR
	pop		ax
	pop		bx
ENDM
UTILM_PRINT_STRN MACRO str
	UTILM_PRINT_STR str
	UTILM_PRINT_NEWLINE
ENDM
UTILM_PRINT_NEWLINE MACRO
	UTILM_PRINT_CHAR 0dh ; \r
	UTILM_PRINT_CHAR 0ah ; \n
ENDM
UTILM_PRINT_SPACE MACRO
	UTILM_PRINT_CHAR " "
ENDM
UTILM_PRINT_COLON MACRO
	UTILM_PRINT_CHAR ":"
ENDM
UTILM_PRINT_HEX_NIBBLES MACRO nibbles
	push	cx
	push	ax
	mov		cx,nibbles
	call	UTIL_PRINT_HEX_NIBBLES
	pop		ax
	pop		cx
ENDM
UTILM_PRINT_WREG MACRO str,reg
	UTILM_PRINT_STR str
	UTILM_PRINT_COLON
	push	ax
	mov		ax,reg
	UTILM_PRINT_HEX_NIBBLES 4
	pop		ax
ENDM
UTILM_PRINT_BREG MACRO str,reg
	UTILM_PRINT_STR str
	UTILM_PRINT_COLON
	push	ax
	mov		ax,reg
	UTILM_PRINT_HEX_NIBBLES 2
	pop		ax
ENDM
UTILM_PRINT_SEGS MACRO
	UTILM_PRINT_WREG str_cs,cs
	UTILM_PRINT_SPACE
	UTILM_PRINT_WREG str_ds,ds
	UTILM_PRINT_SPACE
	UTILM_PRINT_WREG str_es,es
	UTILM_PRINT_SPACE
	UTILM_PRINT_WREG str_ss,ss
	UTILM_PRINT_SPACE
	UTILM_PRINT_WREG str_sp,sp
	UTILM_PRINT_SPACE
	UTILM_PRINT_NEWLINE
ENDM

CODESEG SEGMENT
	assume CS:CODESEG, DS:CODESEG, SS:CODESEG
BEGINOFPROG EQU $
IF ROM 	;; Cartridge Header
	ORG 0h
	PROGRAM:
	CARTSIG		dw 0AA55h					; Cartridge Signature
	CARTSIZ		db (ENDOFPROG - BEGINOFPROG) / 512 ; Cartride size in 512 byte chunks
	jmp			NEAR PTR INIT				; Cartridge BIOS Init Entry Point
	DOSCMD1L	db DOSCMD1E - DOSCMD1S		; Length of DOS Command1 name
	DOSCMD1S	db "CART1TSR"				; DOS Command1 name string
	DOSCMD1E:								; End of Command1 name string
	jmp			NEAR PTR CART1TSR				; DOS Command1 Entry Point
	DOSCMD2L	db DOSCMD2E - DOSCMD2S		; Length of DOS Command2 name
	DOSCMD2S	db "CART2MEM"				; DOS Command2 name string
	DOSCMD2E:								; End of Command2 name string
	jmp			NEAR PTR CART2MEM				; DOS Command2 Entry Point
	CARTEOH		db 00h						; End of cartridge header
ELSE 	;; DOS COM Entry
	ORG	100h
	PROGRAM:
	jmp			NEAR PTR CART1TSR				; DOS Command Entry Point
ENDIF

INIT PROC FAR
	ret
INIT ENDP

;; CX = # of nibbles to print
;; AX = 1-4 nibbles to print from AH high -> AL low
;	Calls interrupts, don't trust regs
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

; Input: AL = character to print
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

;; Input: DS:DX = seg:offset of message
UTIL_PRINT_STR PROC NEAR ; Uses BIOS function
	mov		si,dx ; first offset
UTIL_PRINT_STR_LOOP:
	mov		al,[si]
	cmp		al,'$'
	je		UTIL_PRINT_STR_DONE
	call	UTIL_PRINT_CHAR
	inc		si
	jmp		UTIL_PRINT_STR_LOOP
UTIL_PRINT_STR_DONE:
	ret
UTIL_PRINT_STR ENDP


CART1TSR PROC FAR
	UTILM_PRINT_SEGS
	;; TSR
	mov		dx,MEMORY_RESERVE_PARA
	mov		ax,(svc_dos_keep_resident_31 SHL 8) OR val_dos_terminate_00
	int		int_dos_21 ; DOS Interrupt
CART1TSR ENDP

CART2MEM PROC FAR
	UTILM_PRINT_SEGS
	mov		ax,(svc_dos_terminate_4C SHL 8) OR val_dos_terminate_00
	int		int_dos_21 ; DOS Interrupt
CART2MEM ENDP

str_cs db "CS$"
str_ds db "DS$"
str_es db "ES$"
str_ss db "SS$"
str_sp db "SP$"

%OUT PROCESSING END OF FILE ALIGNMENT
IF ($-BEGINOFPROG) MOD 16
	ORG ($-BEGINOFPROG)+16-(($-BEGINOFPROG) MOD 16)
ENDIF
align_signature db "DDDDCCCCBBBBAAAA" ; Aligned

IF ROM
	IF ($-BEGINOFPROG+2) MOD 512 ; If end of next word (+2) is not on a 512 byte boundary
		ORG ($-BEGINOFPROG+2)+512-(($-BEGINOFPROG+2) MOD 512) - 2 ; Round up, minus 2
	ENDIF
	CARTCRC dw 0FEC0h ; Placeholder for cartridge CRC, Aligned
ELSE
	IF ($-BEGINOFPROG+2) MOD 16 ; If end of next word (+2) is not on a paragraph boundary
		ORG ($-BEGINOFPROG+2)+16-(($-BEGINOFPROG+2) MOD 16) - 2 ; Round up, minus 2
	ENDIF
	MARKER dw 0EFBEh ; Placeholder for marker
ENDIF
ENDOFPROG EQU $ ; Used for CARTSIZ calculation, aligned
CODESEG ENDS

%OUT PROCESSING MEMORY CALCULATION EQUATES
PSP_SIZE EQU 100h
MEMORY_RESERVE_PARA EQU PSP_SIZE SHR 4
END PROGRAM
