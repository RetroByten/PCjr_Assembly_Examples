TITLE TSR Program
PAGE 66,80 ; 66 lines per page, 80 characters/line

; NOTE1: CRC needs to be calculated externally

ROM EQU 0 ; Set to 0 if COM, Set to 1 if ROM
IF ROM
	%OUT Building CARTTSR ROM
ELSE
	%OUT Building CARTTSR COM
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
		val_dos_terminate_01			EQU 01h ; error
int_pkt_driver_60					EQU 60h
int_pkt_data_61						EQU 61h

%OUT PROCESSING DATA SEGMENT
DATASEG SEGMENT AT 0 ; Dummy segment that will hold data
	ORG 0
	DATASEGSTART EQU $
	orig_int_60_offset dw ?
	orig_int_60_segment dw ?
	orig_int_61_offset dw ?
	orig_int_61_segment dw ?
	IF ($-DATASEGSTART) MOD 16
		ORG ($-DATASEGSTART)+16-(($-DATASEGSTART) MOD 16)
	ENDIF
	DATASEGEND EQU $
DATASEG ENDS

%OUT PROCESSING MEMORY CALCULATION EQUATES
PSP_SIZE EQU 100h
IF ROM
	CODE_SIZE EQU 0h
ELSE
	CODE_SIZE EQU ENDOFPROG - BEGINOFPROG
ENDIF
DATA_SIZE EQU DATASEGEND - DATASEGSTART
DATA_DS_OFFSET EQU PSP_SIZE + CODE_SIZE
STACK_DOS_SIZE EQU 80h
STACK_USER_SIZE EQU 80h
STACK_SIZE EQU STACK_DOS_SIZE + STACK_USER_SIZE
MEMORY_SIZE EQU PSP_SIZE + CODE_SIZE + DATA_SIZE + STACK_SIZE
PARA_SIZE EQU 0Fh
MEMORY_RESERVE_PARA EQU (MEMORY_SIZE + PARA_SIZE) SHR 4

CODESEG SEGMENT
	assume CS:CODESEG;, DS:CODESEG, SS:CODESEG
BEGINOFPROG EQU $
IF ROM 	;; Cartridge Header
	ORG 0h
	PROGRAM:
	CARTSIG		dw 0AA55h					; Cartridge Signature
	CARTSIZ		db (ENDOFPROG - BEGINOFPROG) / 512 ; Cartride size in 512 byte chunks
	jmp			NEAR PTR INIT				; Cartridge BIOS Init Entry Point
	DOSCMD1L	db DOSCMD1E - DOSCMD1S		; Length of DOS Command1 name
	DOSCMD1S	db "CCARTTSR"				; DOS Command1 name string
	DOSCMD1E:								; End of Command1 name string
	jmp			NEAR PTR MAIN				; DOS Command1 Entry Point
	CARTEOH		db 00h						; End of cartridge header
ELSE 	;; DOS COM Entry
	ORG	100h
	PROGRAM:
	jmp			NEAR PTR MAIN				; DOS Command Entry Point
ENDIF
prog_signature db "PKT PROG",00h
prog_vendor 	db "RETROBYTEN",00h
prog_card		db "JRNIC",00h
prog_signature_end db "$"

INT_PKT_DRIVER PROC FAR
	jmp		INT_PKT_DRIVER_CONT
	drvr_signature	db "PKT DRVR",00h
	drvr_vendor 	db "RETROBYTEN",00h
	drvr_card		db "JRNIC",00h ; Used to detect if already running
	drvr_signature_end db "$"
INT_PKT_DRIVER_CONT:
	sti		; Re-Enable interrupts ;; TODO - this should check if they were enabled before call
	push	ds
	call	SET_DS_INT_DATA ; interrupt needs it's original DATA_STORE, retrieve from int 61
	assume	ds:DATASEG
	;;;;;;;;;;;;;;;;;;;
	; User interrupt code can now use DS to reference it's resident data
	; If it needs PSP instead for ENV or similar ;call	SET_DS_INT_PSP
	;;;;;;;;;;;;;;;;;;;
	stc ;; HARD CODE ERROR FOR EXAMPLE
	;; Ensure stack is fully clear of INT stuff
	pop		ds
	;; Set interrupt carry flag accordingly on known stack
	push	bp
	;          +0     +2        +4       +6 
	; BP + 6 = BP -> OFFSET -> SEG -> [FLAGS]
	mov		bp,sp
	jc		RET_BAD
RET_GOOD:
	and		word ptr ss:[bp+6],0FFFEh
	jmp		INT_EXIT
RET_BAD:
	or		word ptr ss:[bp+6],0001h
INT_EXIT:
	pop		bp
	iret
INT_PKT_DRIVER ENDP

%OUT PROCESSING USER CODE
INIT PROC FAR ;; BIOS enters
	;; Insert BIOS INIT code here
	ret ; Far Return
INIT ENDP

;; Assumes DS = PSP
SET_BLOCK PROC NEAR
	push	es
	mov		ax,ds
	mov		es,ax ; set ES to PSP
	mov		bx,MEMORY_RESERVE_PARA ; set BX to needed memory
	mov		ah,svc_dos_setblock_4A
	int		int_dos_21
	pop		es
	ret
SET_BLOCK ENDP

;; This sets DS to the "INT61" instance Data store
SET_DS_INT_DATA PROC NEAR
	push	es
	push	bx
	push	ax
	
	;; Get INT61 PSP_SEG:DS_DATA_STORE_SEG
	mov		ax,(svc_dos_get_int_vector_35 SHL 8) OR int_pkt_data_61
	int		int_dos_21 ; ES:BX has original values
	
	mov		ds,bx ; DS now contains INT DS_DATA_STORE_SEG
	
	pop		ax
	pop		bx
	pop		es
	ret
SET_DS_INT_DATA ENDP

;; This sets DS to the "INT61" instance PSP
SET_DS_INT_PSP PROC NEAR
	push	es
	push	bx
	push	ax
	
	;; Get INT61 PSP_SEG:DS_DATA_STORE_SEG
	mov		ax,(svc_dos_get_int_vector_35 SHL 8) OR int_pkt_data_61
	int		int_dos_21 ; ES:BX has original values
	
	mov		bx,es ; Get PSP_SEG instead
	mov		ds,bx ; DS = PSP_SEG
	
	pop		ax
	pop		bx
	pop		es
	ret
SET_DS_INT_PSP ENDP

;; This sets DS to the "current" instances Data store
SET_DS_LOCAL_DATA PROC NEAR
	mov		ax,ds ; Get PSP
	mov		cl,4
	shl		ax,cl ; convert PSP segment to absolute
	add		ax,DATA_DS_OFFSET ; Add Data absolute offset
	mov		cl,4
	shr		ax,cl ; Convert back to segment
	mov		ds,ax ; DS Now has segment
	ret
SET_DS_LOCAL_DATA ENDP

SAVE_CURRENT_INTS PROC NEAR
	push	ds
	push	es
	call	SET_DS_LOCAL_DATA 
	assume	ds:DATASEG
	
	;; Save orig INT 61 to DS_LOCAL_DATA
	mov		ax,(svc_dos_get_int_vector_35 SHL 8) OR int_pkt_data_61
	int		int_dos_21 ; ES:BX has original values
	mov		[orig_int_61_offset],bx
	mov		bx,es
	mov		[orig_int_61_segment],bx
	
	;; Save orig INT 60 to DS_LOCAL_DATA
	mov		ax,(svc_dos_get_int_vector_35 SHL 8) OR int_pkt_driver_60
	int		int_dos_21 ; ES:BX has original values
	mov		[orig_int_60_offset],bx
	mov		bx,es
	mov		[orig_int_60_segment],bx

	pop		es
	pop		ds
	ret
SAVE_CURRENT_INTS ENDP

SET_INTS PROC NEAR
	push	ds ; Save DS=PSP seg
	
		;; Need to set INT61 to PSP_SEG:DS_DATA_STORE_SEG
	push	ds ; temporarily save DS=PSP again
	call	SET_DS_LOCAL_DATA
	assume ds:DATASEG
	
	mov		dx,ds ; set DX = DS_DATA_STORE_SEG
	pop		ds ; DS=PSP
	mov		ax,(svc_dos_set_int_vector_25 SHL 8) OR int_pkt_data_61
	int		int_dos_21 	;; Set AL=INT# to DS:DX
	
	;; Need to set INT60 to CS:INT_PKT_DRIVER
	mov		ax,cs ; get CS
	mov		ds,ax ; set DS = CS
	assume ds:CODESEG
	mov		dx,offset INT_PKT_DRIVER
	mov		ax,(svc_dos_set_int_vector_25 SHL 8) OR int_pkt_driver_60
	int		int_dos_21 	;; Set AL=INT# to DS:DX
		
	pop		ds ; Restore DS=PSP seg
	ret
SET_INTS ENDP

; CS = code
; DS = PSP (if ROM, not the same place)
MAIN PROC FAR
	;; Move STACK in
	mov		sp,MEMORY_SIZE
	;; Rebuild STACK
	xor		ax,ax
	push	ax
	;; Release unneeded memory
	call	SET_BLOCK
	;; Save int60 & int61 to local DS_DATA_STORE
	call	SAVE_CURRENT_INTS
	;; Set int60 to point at INT_PKT_DRIVER
	call	SET_INTS
	;; TSR
	mov		dx,MEMORY_RESERVE_PARA
	mov		ax,(svc_dos_keep_resident_31 SHL 8) OR val_dos_terminate_00
	int		int_dos_21 ; DOS Interrupt
MAIN ENDP
eouc_signature db "ENDOFUSERCODE$" ; Not aligned intentionally

%OUT PROCESSING END OF FILE ALIGNMENT
;;; End of Alignment Signature
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
	MARKER dw 0EFBEh ; Placeholder for cartridge CRC, Aligned
ENDIF

ENDOFPROG EQU $ ; Used for CARTSIZ calculation, aligned
CODESEG ENDS
END PROGRAM
