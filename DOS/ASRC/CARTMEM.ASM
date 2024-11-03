TITLE CARTMEM Program
PAGE 66,80 ; 66 lines per page, 80 characters/line

; NOTE1: CRC needs to be calculated externally

;; This program shows how to move the stack,
; shrink the memory allocation to be well behaved
; and optionally allocate/deallocate a dynamic block of memory
; 
; By default, the stack is at the end of the DS memory segment

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

UTIL_PRINT_HEX_NIBBLES PROC NEAR ;; TODO - THESE ARE NOT BIOS COMPATIBLE
	; CX = # Of nibbles to print
	; AX = 1-4 nibbles to print from AH high -> AL Low
	push	dx
	push	ax
UTIL_PRINT_HEX_NIBBLES_LOOP:
	rol		ax,1 ; Grab the highest nibble by Rotating left 4x into al low nibble
	rol		ax,1 ;
	rol		ax,1 ;
	rol		ax,1 ; 
	push	ax ; Save off the Nth rotated AX
	and		al,0Fh ; Isolate the nibble
	add		al,'0' ; Shift into the ASCII Numeric Range
	cmp		al,'9' ; Check if <= 9
	jle		UTIL_PRINT_HEX_NIBBLES_CONT
	add		al,'A'-'9'-1 ; If not, shift up to ASCII 'A' range
UTIL_PRINT_HEX_NIBBLES_CONT:
	mov		dl,al ; character to print
	mov		ah,svc_dos_print_chr_02 ; Select DOS Character Output service
	int		int_dos_21 ; Print current character
	pop		ax ; Restore Nth rotated AX
	loop	UTIL_PRINT_HEX_NIBBLES_LOOP ; dec CX until 0
	pop		ax
	pop		dx
	ret
UTIL_PRINT_HEX_NIBBLES ENDP

UTILM_PRINT_HEX_NIBBLES MACRO nibbles
	push	cx
	mov		cx,nibbles
	call	UTIL_PRINT_HEX_NIBBLES
	pop		cx
ENDM

UTILM_PRINT_CHAR MACRO chr
	push	dx
	push	ax
	mov		dl,chr
	mov		ah,svc_dos_print_chr_02
	int		int_dos_21
	pop		ax
	pop		dx
ENDM

UTILM_PRINT_NEWLINE MACRO
	UTILM_PRINT_CHAR 0dh ; \r
	UTILM_PRINT_CHAR 0ah ; \n
ENDM

UTILM_PRINT_STR MACRO str
	push	ds ; Save DS
	push	dx
	push	ax
	mov		ax,cs
	mov		ds,ax
	mov		dx,offset str
	mov		ah,svc_dos_print_string_09
	int		int_dos_21
	pop		ax
	pop		dx
	pop		ds ; Restore DS
ENDM

UTILM_PRINT_REG MACRO str,reg
	UTILM_PRINT_STR str
	push	ax
	mov		ax,reg
	UTILM_PRINT_HEX_NIBBLES 4
	pop		ax
ENDM

PRINT_SEGS PROC NEAR
	UTILM_PRINT_REG str_cs,cs
	UTILM_PRINT_CHAR " "
	UTILM_PRINT_REG str_ds,ds
	UTILM_PRINT_CHAR " "
	UTILM_PRINT_REG str_es,es
	UTILM_PRINT_CHAR " "
	UTILM_PRINT_REG str_ss,ss
	UTILM_PRINT_CHAR " "
	UTILM_PRINT_REG str_sp,sp
	UTILM_PRINT_NEWLINE
	ret
PRINT_SEGS ENDP

; BX = number of paragraphs to request
; Returns AX if success
ALLOC PROC NEAR
	UTILM_PRINT_STR str_alloc
	UTILM_PRINT_CHAR " "
	UTILM_PRINT_REG str_bx,bx
	UTILM_PRINT_CHAR " "
	mov		ah,svc_dos_allocate_48
	int		int_dos_21
	jc		ALLOC_ERROR
ALLOC_SUCCESS:
	UTILM_PRINT_STR str_success
	UTILM_PRINT_CHAR " "
	UTILM_PRINT_REG str_ax,ax
	jmp		ALLOC_DONE
ALLOC_ERROR:
	UTILM_PRINT_STR str_error
	UTILM_PRINT_CHAR " "
	UTILM_PRINT_REG str_ax,ax
	UTILM_PRINT_CHAR " "
	UTILM_PRINT_REG str_bx,bx
ALLOC_DONE:
	UTILM_PRINT_NEWLINE
	ret
ALLOC ENDP

; BX = size of block, ES = pointer to PSP
SETBLOCK PROC NEAR
	push	bx
	UTILM_PRINT_STR str_setblock
	UTILM_PRINT_CHAR " "
	UTILM_PRINT_REG str_bx,bx
	UTILM_PRINT_CHAR " "
	pop		bx
	; Convert to PARA
	push	ax
	mov		ah,svc_dos_setblock_4a
	int		int_dos_21
	jc		SETBLOCK_ERROR
SETBLOCK_SUCCESS:
	UTILM_PRINT_STR str_success
	jmp		SETBLOCK_DONE
SETBLOCK_ERROR:
	UTILM_PRINT_STR str_error
	UTILM_PRINT_CHAR " "
	UTILM_PRINT_REG str_ax,ax
	UTILM_PRINT_CHAR " "
	UTILM_PRINT_REG str_bx,bx
SETBLOCK_DONE:
	UTILM_PRINT_NEWLINE
	pop		ax
	ret
SETBLOCK ENDP

; es = segment to return
; Returns AX if success
DEALLOC PROC NEAR
	UTILM_PRINT_STR str_dealloc
	UTILM_PRINT_CHAR " "
	UTILM_PRINT_REG str_es,es
	UTILM_PRINT_CHAR " "
	mov		ah,svc_dos_deallocate_48
	int		int_dos_21
	jc		DEALLOC_ERROR
DEALLOC_SUCCESS:
	UTILM_PRINT_STR str_success
	jmp		DEALLOC_DONE
DEALLOC_ERROR:
	UTILM_PRINT_STR str_error
	UTILM_PRINT_CHAR " "
	UTILM_PRINT_REG str_ax,ax
DEALLOC_DONE:
	UTILM_PRINT_NEWLINE
	ret
DEALLOC ENDP

INIT PROC FAR 	; BIOS enters
	;; Insert BIOS INIT code here
	ret ; Far Return
INIT ENDP

PSP_SIZE EQU 100h
STACK_SIZE EQU 100h
IF ROM
	END_OF_STACK EQU PSP_SIZE + STACK_SIZE
ELSE
	END_OF_STACK EQU (offset ENDOFPROG) + STACK_SIZE
ENDIF

MAIN PROC FAR
	call	PRINT_SEGS
	
	;; Attempt to allocate, should fail since by default
	; all mem is allocated already
	mov		bx,100h ; Request 256 bytes
	call	ALLOC
	call	PRINT_SEGS
	
	;; Rebuild STACK, cannot be a function call!
	UTILM_PRINT_STR str_stack
	UTILM_PRINT_NEWLINE
	mov		sp,END_OF_STACK
	xor		ax,ax 
	push	ax ; DOS compatible return
	call	PRINT_SEGS
	
	;; Re-size Program
	mov		bx,END_OF_STACK
	mov		cl,4
	shr		bx,cl ; Covert to paragraphs
	;inc	bx ; If not aligned to a para, would need to round up
	call	SETBLOCK
	
	;; Attempt to allocate, should succeed and be placed above our STACK
	; + a 16 byte (1 para) Memory control block
	mov		bx,100h ; Request 256 bytes
	call	ALLOC ; AX contains segment
	
	;;;;
	;; Use memory as desired
	;;;;
	
	;; Free the memory before returning
	mov		es,ax ; Free
	call	DEALLOC
	
	mov		ax,(svc_dos_terminate_4c SHL 8) OR val_dos_terminate_0 ; DOS Service 4Ch (Terminate), exit code 0
	int		int_dos_21 ; DOS Interrupt
MAIN ENDP
str_cs db "CS:$"
str_ds db "DS:$"
str_es db "ES:$"
str_ss db "SS:$"
str_sp db "SP:$"
str_ax db "AX:$"
str_bx db "BX:$"
str_stack db "Moving stack...$"
str_alloc db "Attempting allocation...$"
str_dealloc db "Attempting free...$"
str_setblock db "Attempting SETBLOCK...$"
str_error db "Error!$"
str_success db "Success!$"

IF ROM 	; Align CARTCRC to end of a 512 byte boundary
	IF ($-BEGIN+2) MOD 512 ; If end of next word (+2) is not on a 512 byte boundary
		ORG ($-BEGIN+2)+512-(($-BEGIN+2) MOD 512) - 2 ; Round up, minus 2
	ENDIF
	CARTCRC dw 0000h ; Placeholder for cartridge CRC
ELSE
	db "0123456789ABCDEF" ; Helps with debugging alignment
	IF ($-BEGIN+2) MOD 16 ; If end of next word (+2) is not on a 16 byte boundary
		ORG ($-BEGIN+2)+16-(($-BEGIN+2) MOD 16) - 2 ; Round up, minus 2
	ENDIF
	ENDMARK dw 0EFBEh ; Marker for end to help in debugging
ENDIF
ENDOFPROG EQU $ ; Used for CARTSIZ calculation
CODESEG ENDS
END PROGRAM
