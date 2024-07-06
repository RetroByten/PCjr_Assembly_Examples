TITLE TSR2LOAD Program
PAGE 66,80 ; 66 lines per page, 80 characters/line

;; This loads or unloads TSR2

%OUT Processing EQUATES...
interrupt_vector_table_segment		EQU 0000h
int_video							EQU	10h
	svc_video_write_char_tty	EQU	0Eh
	tty_page					EQU 00h
int_dos_21					EQU	21h
	svc_dos_print_str		EQU 09h
	svc_dos_keep_resident	EQU 31h ; Only needed if loading in DOS
	svc_dos_free_memory		EQU 49h
		val_dos_env_offset	EQU 2Ch
	svc_dos_terminate		EQU	4Ch
		val_dos_terminate_0	EQU 00h

int_tsr2_61			EQU 61h
int_tsr2_offset		EQU int_tsr2_61 * 4
int_tsr2_segment	EQU int_tsr2_offset + 2

%OUT Processing CODE Segment
CODESEG SEGMENT
	assume CS:CODESEG, DS:CODESEG, SS:CODESEG
ORG 100h
PROGRAM: ; Needed for COM to later terminate the program
jmp MAIN
;                    "0123456789ABCDEF"
begin_fingerprint db "RETROBYTEN_TSR2$"
begin_fingerprint_end:
store_offset dw ? ; Save old interrupt
store_segment dw ?
;;;;; DO NOT ADD CODE ABOVE THIS POINT
INT_TSR2 PROC FAR
	sti ; Re-enable hardware interrupts that were disabled when invoked
	push	ax
	push	dx
	push	ds
	mov		ax,cs
	mov		ds,ax ; set DS for int_dos_21
	mov		ah,svc_dos_print_str
	mov		dx,offset begin_fingerprint
	int		int_dos_21
	pop		ds
	pop		dx
	pop		ax
	iret
INT_TSR2 ENDP
;;;;; DO NOT ADD TSR CODE BELOW THIS POINT
; Want to align with PARA boundry
IF ($-(PROGRAM-100h)) MOD 16 ; If not already on 16 byte boundary
ORG ($-(PROGRAM-100h)) + 16 - (($-(PROGRAM-100h)) MOD 16)
ENDIF
end_fingerprint db "RETROBYTEN_TSR2$" ; 16 byte signature
;                  "0123456789ABCDEF"
ENDOFTSR:

;;;;; ADD LOADER PROGRAM BELOW THIS POINT
label_msg db "UTILITIES$"
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
	mov		ah,svc_video_write_char_tty ; Select DOS Print TTY service
	mov		bh,tty_page
	int		int_video ; Print current character
	pop		ax ; Restore Nth rotated AX
	loop	UTIL_PRINT_HEX_NIBBLES_LOOP ; dec CX until 0
	pop		bx
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
	mov		ax,(svc_video_write_char_tty SHL 8) OR 0Dh ; /r
	push	bx
	mov		bh,tty_page
	int		int_video
	mov		ax,(svc_video_write_char_tty SHL 8) OR 0Ah ; /n
	mov		bh,tty_page
	int		int_video
	pop		bx
	pop		ax
	ret
UTIL_PRINT_NEWLINE ENDP

loaded_tsr_msg db "Loaded TSR1",0Dh,0Ah,"$"
LOAD_TSR2 PROC NEAR
	; Retrieve and save original system interrupt offset & segment
	mov		ax,es:[int_tsr2_offset]
	mov		[store_offset],ax
	mov		ax,es:[int_tsr2_segment]
	mov		[store_segment],ax
	
	; Set int_tsr1_offset/segment to point to us instead
	mov		ax,offset INT_TSR2
	mov		es:[int_tsr2_offset],ax
	mov		ax,cs
	mov		es:[int_tsr2_segment],ax
	
	; Tell the world
	mov		ah,svc_dos_print_str
	mov		dx,offset loaded_tsr_msg
	int		int_dos_21
	
	ret
LOAD_TSR2 ENDP

unload_tsr_msg db "Unloading TSR...",0Dh,0Ah,"$"
unload_tsr_pass_msg db "Freed memory...",0Dh,0Ah,"$"
UNLOAD_TSR2 PROC NEAR
	push	ds
	push	es
	;; Print that we're unloading
	mov		ah,svc_dos_print_str
	mov		dx,offset unload_tsr_msg
	int		int_dos_21
	
	;; Step 1: unset the system interrupt vector
	;1a - we previously saved the segment of the currently loaded TSR
	mov		ax,[store_segment]
	mov		ds,ax ; DS now contains TSR segment
	mov		si,offset store_offset ; offset from TSR segment
	mov		ax,interrupt_vector_table_segment
	mov		es,ax ; ES now contains interrupt vector table
	mov		di,int_tsr2_offset ; offset in system interrupt vector table
	mov		cx,2 ; 2 words
	cld		; clear direction
	rep		movsw

	;; Step 2: attempt to free memory - TODO - check if it's the memory above us
	mov		ax,cs
	mov		ds,ax ; allow us to access our memory again
	mov		ax,[store_segment] ; grab the segment of the currently loaded TSR
	push	ax ; save for second call
	
	; Free loaded TSR's environment
	mov		es,ax ; set ES to the currently loaded TSR
	mov		es,es:[val_dos_env_offset] ; get address of TSR environment block
	mov		ah,svc_dos_free_memory ; DOS deallocate block
	int		int_dos_21
		
	; Free loaded TSR's psp
	pop		ax ; restore segment of currently loaded TSR
	mov		es,ax
	mov		ah,svc_dos_free_memory
	int		int_dos_21
	
	; Cleanup
	pop		es
	pop		ds
	ret
UNLOAD_TSR2 ENDP

; Returns ax = 0 if not loaded, ax = 1 if already loaded
msg_yes db "CHECK_YES",0Dh,0Ah,"$"
msg_no db "CHECK_NO",0Dh,0Ah,"$"
CHECK_IF_LOADED PROC NEAR
	push	es
	; Read offset of currently loaded int60, temporarily save it to this instance
	mov		ax,es:[int_tsr2_offset]
	mov		[store_offset],ax
	; Read segment of currently loaded int60, temporarily save it to this instance
	mov		ax,es:[int_tsr2_segment]
	mov		[store_segment],ax ; AX now also still hols potential old interrupt segment
		
	;; Compare begin_fingerprint
	;; DS:SI = this program fingerprint
	;; ES:DI = old program fingerprint
	mov		es,ax ; Setup ES Segment to potential old interrupt segment
	mov		di,offset begin_fingerprint ; this offset should be the same in both old and new
	mov		si,di
	mov		cx,(offset begin_fingerprint_end - offset begin_fingerprint) ; number of bytes
	cld
	repe	cmpsb
	jne		CHECK_IF_LOADED_NO ; if the first finger print doesn't match, we're clear to load!
CHECK_IF_LOADED_YES:
	mov		ax,1
	push	ax
	mov		dx,offset msg_yes
	jmp		CHECK_IF_LOADED_END
CHECK_IF_LOADED_NO:
	xor		ax,ax
	push	ax
	mov		dx,offset msg_no
CHECK_IF_LOADED_END:
	mov		ah,svc_dos_print_str
	int		int_dos_21 ;; Print the result of the check
	pop		ax
	pop		es
	ret
CHECK_IF_LOADED ENDP

MAIN:
	mov		ax,interrupt_vector_table_segment
	mov		es,ax 
	mov		ax,cs
	mov		ds,ax 
	;; Print out CS segment
	call	UTIL_PRINT_WORD
	call	UTIL_PRINT_NEWLINE
	
	;; Check if the TSR is already resident
	call	CHECK_IF_LOADED
	cmp		ax,0
	je		LOAD_TSR
UNLOAD_TSR: ;; BLOCKER, unload it
	call	UNLOAD_TSR2
EXIT2DOS:
	mov		ax,(svc_dos_terminate SHL 8) OR val_dos_terminate_0 
	int		int_dos_21 ;; EXIT to DOS
	
LOAD_TSR: ;; No blockers, load it!
	call	LOAD_TSR2
	;; Successfully loaded, terminate and stay resident
EXITTSRDOS: ;Terminate and stay resident
	mov		dx,(offset ENDOFTSR - offset PROGRAM + 100h + 15) SHR 4 ; end-begin + PSP + round up to next paragraph, convert to paragraph
	mov		ax,(svc_dos_keep_resident SHL 8) OR val_dos_terminate_0
	int		int_dos_21 ;; EXIT to DOS
HALT:
	jmp		HALT
CODESEG ENDS
END PROGRAM
