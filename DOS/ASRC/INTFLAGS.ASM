TITLE INTFLAGS Program
PAGE 66,80 ; 66 lines per page, 80 characters/line

;; iret from an interrupt tosses out the flags
; if you need to edit the flags you can do a few different things
; 1.) if your interrupt contract allows modification of all flags
;	use "ret 2" instead - possibly assumes the INT PROC is declared FAR?
; 2.) if not, you need to edit the one in the stack before iret

%OUT Processing EQUATES...
interrupt_vector_table_segment		EQU 0000h
int_video						EQU	10h
	svc_video_write_char_tty	EQU	0Eh
	tty_page					EQU 00h

int_dos_21					EQU	21h
	svc_dos_print_str		EQU 09h
	svc_dos_keep_resident	EQU 31h ; Only needed if loading in DOS
	svc_dos_terminate		EQU	4Ch
		val_dos_terminate_0	EQU 00h


int_60			EQU 60h
int_60_offset	EQU int_60 * 4
int_60_segment	EQU int_60_offset + 2

int_61			EQU 61h
int_61_offset	EQU int_61 * 4
int_61_segment	EQU int_61_offset + 2

int_62			EQU 62h
int_62_offset	EQU int_62 * 4
int_62_segment	EQU int_62_offset + 2


%OUT Processing CODE Segment
CODESEG SEGMENT
	assume CS:CODESEG, DS:CODESEG, SS:CODESEG
ORG 100h
PROGRAM: ; Needed for COM to later terminate the program
jmp MAIN



UTIL_PRINT_HEX_NIBBLES PROC NEAR
	; CX = # Of nibbles to print
	; AX = 1-4 nibbles to print from AH high -> AL Low
	push	ax
	push	bx
UTIL_PRINT_HEX_NIBBLES_LOOP:
	rol		ax,1 ; Grab the highest nibble by Rotating left 4x
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
	mov		ah,svc_video_write_char_tty ; Select DOS Print TTY service
	mov		bh,tty_page
	int		int_video ; Print current character
	pop		ax ; Restore Nth rotated AX
	loop	UTIL_PRINT_HEX_NIBBLES_LOOP ; dec CX until 0
	pop		bx
	pop		ax
	ret
UTIL_PRINT_HEX_NIBBLES ENDP

UTIL_PRINT_BYTE PROC NEAR
	; Print 2 Nibbles from AH
	; AH = byte
	push	cx
	mov		cx,02h
	call 	UTIL_PRINT_HEX_NIBBLES
	pop		cx
	ret
UTIL_PRINT_BYTE ENDP

UTIL_PRINT_WORD PROC NEAR
	; Print 4 Nibbles from AX
	; AX = word
	push	cx
	mov		cx,04h
	call 	UTIL_PRINT_HEX_NIBBLES
	pop		cx
	ret
UTIL_PRINT_WORD ENDP

UTIL_PRINT_NEWLINE PROC NEAR
	;; Print \r\n
	push	ax
	push	bx
	mov		ax,(svc_video_write_char_tty SHL 8) OR 0Dh ; /r
	mov		bh,tty_page
	int		int_video
	mov		ax,(svc_video_write_char_tty SHL 8) OR 0Ah ; /n
	mov		bh,tty_page
	int		int_video
	pop		bx
	pop		ax
	ret
UTIL_PRINT_NEWLINE ENDP

;; TODO - eventually re-write as a BIOS call to remove DOS dependency
UTIL_PRINT_STRING MACRO str
; Assumes DS is set
		push	ax
		push	dx
		mov		dx,offset str
		mov		ah,svc_dos_print_str
		int		int_dos_21
		pop		dx
		pop		ax
ENDM

INT_60_PROC PROC FAR
	sti ; re-enable interrupts
	stc ; set carry flags, needs to be done another way
	
	iret ; tosses away "current" flags", but we set them in the stack
INT_60_PROC ENDP

INT_61_PROC PROC FAR
	sti ; re-enable interrupts
	stc ; set carry flags
	
	ret 2 ; tosses away original flags
INT_61_PROC ENDP

INT_62_PROC PROC FAR
	sti ; re-enable interrupts
	

	
	;push	bp ; -2 from existing stack
	;; At this point call stack is:
	; flags
	; segments
	; offset
	; bp  <-SP pointing here, +2 would be offset, +4 would be segments, +6 would be flags
	
	;mov		bp,sp ; save current sp
	;add		bp,6
	;push	ax
	;mov		ax,ss:[bp] ; grab flags
	;or		ax,1 ; OR 01 to set, AND FE to clear
	;mov		ss:[bp],ax
	;pop		ax
	
	;mov		bp,sp
	;push	ax
	;or	word ptr	ss:[bp+6],1
	;pop		ax
	
	;pop		bp
	
	push	bp
	mov		bp,sp
	or	word ptr ss:[bp+6],1 ; and word ptr ss:[bp+6],0FFFEh
	pop		bp
	
	
	iret
INT_62_PROC ENDP

SETUP_INT60 PROC NEAR
	; Save old int60
	push	ax
	mov		ax,es:[int_60_offset]
	mov		[old_int60_offset],ax
	mov		ax,es:[int_60_segment]
	mov		[old_int60_segment],ax
	
	; Set new int60
	mov		ax,offset INT_60_PROC
	mov		es:[int_60_offset],ax
	mov		ax,cs
	mov		es:[int_60_segment],ax
	pop		ax
	ret
SETUP_INT60 ENDP

RELEASE_INT60 PROC NEAR
	push	ax
	; Reset the int60 interrupt
	mov		ax,[old_int60_offset]
	mov		es:[int_60_offset],ax
	mov		ax,[old_int60_segment]
	mov		es:[int_60_segment],ax
	pop		ax
	ret
RELEASE_INT60 ENDP

SETUP_INT61 PROC NEAR
	; Save old int61
	push	ax
	mov		ax,es:[int_61_offset]
	mov		[old_int61_offset],ax
	mov		ax,es:[int_61_segment]
	mov		[old_int61_segment],ax
	
	; Set new int61
	mov		ax,offset INT_61_PROC
	mov		es:[int_61_offset],ax
	mov		ax,cs
	mov		es:[int_61_segment],ax
	pop		ax
	ret
SETUP_INT61 ENDP

RELEASE_INT61 PROC NEAR
	; Reset the int61 interrupt
	push	ax
	mov		ax,[old_int61_offset]
	mov		es:[int_61_offset],ax
	mov		ax,[old_int61_segment]
	mov		es:[int_61_segment],ax
	pop		ax
	ret
RELEASE_INT61 ENDP

SETUP_INT62 PROC NEAR
	; Save old int62
	push	ax
	mov		ax,es:[int_62_offset]
	mov		[old_int62_offset],ax
	mov		ax,es:[int_62_segment]
	mov		[old_int62_segment],ax
	
	; Set new int62
	mov		ax,offset INT_62_PROC
	mov		es:[int_62_offset],ax
	mov		ax,cs
	mov		es:[int_62_segment],ax
	pop		ax
	ret
SETUP_INT62 ENDP

RELEASE_INT62 PROC NEAR
	; Reset the int62 interrupt
	push	ax
	mov		ax,[old_int62_offset]
	mov		es:[int_62_offset],ax
	mov		ax,[old_int62_segment]
	mov		es:[int_62_segment],ax
	pop		ax
	ret
RELEASE_INT62 ENDP

MAIN:
	; Setup default segments
	mov		ax,cs
	mov		ds,ax
	mov		ax,interrupt_vector_table_segment
	mov		es,ax

	xor		ax,ax

	call SETUP_INT60
	clc ; clear carry flag
	
	pushf ;; Print initial flags
	pop	ax
	
	pushf
	call	UTIL_PRINT_WORD
	call	UTIL_PRINT_NEWLINE
	popf

	int	 int_60
	
	pushf ; print resultant flags
	pop	ax
	
	pushf
	call	UTIL_PRINT_WORD
	call	UTIL_PRINT_NEWLINE
	popf
	
	call RELEASE_INT60
	
	call SETUP_INT61
	clc ; clear carry flag
	
	pushf ;; print initial flags
	pop	ax
	pushf
	call	UTIL_PRINT_WORD
	call	UTIL_PRINT_NEWLINE
	popf
	
	int	 int_61
	
	pushf ; print resultant flags
	pop	ax
	pushf
	call	UTIL_PRINT_WORD
	call	UTIL_PRINT_NEWLINE
	popf
	
	call RELEASE_INT61
	
	
	call SETUP_INT62
	clc ; clear carry flag
	
	pushf ;; print initial flags
	pop	ax
	pushf
	call	UTIL_PRINT_WORD
	call	UTIL_PRINT_NEWLINE
	popf
	
	int	 int_62
	
	pushf ; print resultant flags
	pop	ax
	pushf
	call	UTIL_PRINT_WORD
	call	UTIL_PRINT_NEWLINE
	popf
	
	call RELEASE_INT62
	
EXIT2DOS:
	mov		ax,(svc_dos_terminate SHL 8) OR val_dos_terminate_0 
	int		int_dos_21 ;; EXIT to DOS
old_int60_offset dw ?
old_int60_segment dw ?
old_int61_offset dw ?
old_int61_segment dw ?
old_int62_offset dw ?
old_int62_segment dw ?

CODESEG ENDS
END PROGRAM
