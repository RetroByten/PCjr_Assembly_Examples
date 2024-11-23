TITLE JMPOLINE Program
PAGE 66,80 ; 66 lines per page, 80 characters/line

ROM EQU 0 ; Set to 0 if COM, Set to 1 if ROM
IF ROM
	%OUT Building JMPOLINE ROM
ELSE
	%OUT Building JMPOLINE COM
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

PROGRAM_SIGNATURE MACRO
	prog_signature db "PKT PROG",00h
	prog_vendor 	db "RETROBYTEN",00h
	prog_card		db "JRNIC",00h
	prog_signature_end db "$"
ENDM

PLACEHOLDER SEGMENT AT 0h
	assume CS:PLACEHOLDER
	ORG 100h
	jmp			NEAR PTR PLACEHOLDER_JMP		; Dummy
	PLACEHOLDER_JMP:
PLACEHOLDER ENDS
	
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
	DOSCMD1S	db "CJMPOLIN"				; DOS Command1 name string
	DOSCMD1E:								; End of Command1 name string
	jmp			NEAR PTR MAIN				; DOS Command1 Entry Point
	CARTEOH		db 00h						; End of cartridge header
	;; Add any Cartridge signature here
	PROGRAM_SIGNATURE	; Needs to fit between CARTEOH and 100h
	ORG	100h ; Aligning the DATA_VARS with a com file
	jmp			NEAR PTR DATASEGSTART		; Dummy
ELSE 	;; DOS COM Entry
	ORG	100h
	PROGRAM:
	jmp			NEAR PTR MAIN				; DOS Command Entry Point
ENDIF

;;;;;;; DATA VARS - live here for COM, need to be copied to RAM for ROM
	DATASEGSTART:
	jmp		NEAR PTR DATA_VARS_START
	drvr_signature	db "PKT DRVR",00h
	drvr_vendor 	db "RETROBYTEN",00h
	drvr_card		db "JRNIC",00h ; Used to detect if already running
	drvr_signature_end db "$"
	DATA_VARS_START:
	push	cs ; DATASEG
	DATA_PLACEHOLDER_JMP:
	jmp		FAR PTR PLACEHOLDER_JMP ; Placeholder for jump target
	orig_int60_offset dw ?
	orig_int60_segment dw ?
	IF ($-DATASEGSTART) MOD 16
		ORG ($-DATASEGSTART)+16-(($-DATASEGSTART) MOD 16) + 100h; offset from start
	ENDIF
DATASEGEND:
;;;;;;; END DATA VARS

INIT PROC FAR
	ret
INIT ENDP

INT_PKT_DRIVER PROC FAR
	pop		ds
	assume  DS:CODESEG ; for the offsets
	iret
INT_PKT_DRIVER ENDP

MAIN PROC FAR
	;;; Step 0.) TODO - Resize memory (SET_BLOCK)
	mov		ax,ds
	mov		es,ax ; set ES to PSP
	mov		bx,MEMORY_RESERVE_PARA ; set BX to needed memory
	mov		ah,svc_dos_setblock_4A
	int		int_dos_21
	
	;;; Step 1.) Copy CS:DATASEGSTART block to DS:RAM
		; Essentially a NO-CHANGE on COM
	push	ds ; save DS (DS=PSP)
	; set ES:DI to destination (PSP:DATASEGSTART)
	mov		ax,ds
	mov		es,ax ; ES = PSP
	mov		di,offset CODESEG:DATASEGSTART
	
	; set DS:SI to source (CS:DATASEGSTART)
	mov		ax,cs
	mov		ds,ax ; DS = CODE
	mov		si,offset CODESEG:DATASEGSTART
	
	mov		cx,offset CODESEG:DATASEGEND - offset CODESEG:DATASEGSTART	
	cld
	rep		movsb
	pop		ds ; restore DS=PSP
	
	;;; Step 2.) Set PSP:DATA_PLACEHOLDER_JMP to CS:INT_PKT_DRIVER
	mov		ax,offset CODESEG:INT_PKT_DRIVER
	mov		WORD PTR [DATA_PLACEHOLDER_JMP+1],ax
	mov		ax,cs
	mov		WORD PTR [DATA_PLACEHOLDER_JMP+3],ax
	
	;; Step 3.) Retrieve old int60 + store in DS:
	mov		ax,(svc_dos_get_int_vector_35 SHL 8) OR int_pkt_driver_60
	int		int_dos_21 ; ES:BX has original values
	mov		[orig_int60_offset],bx
	mov		bx,es
	mov		[orig_int60_segment],bx
	
	;; Step 4.) Set int60 to jmpoline shim PSP:DATASEGSTART
	; DS is already PSP
	mov		dx,offset CODESEG:DATASEGSTART
	mov		ax,(svc_dos_set_int_vector_25 SHL 8) OR int_pkt_driver_60
	int		int_dos_21 	;; Set AL=INT# to DS:DX
	
	;; TSR
	mov		dx,MEMORY_RESERVE_PARA
	mov		ax,(svc_dos_keep_resident_31 SHL 8) OR val_dos_terminate_00
	int		int_dos_21 ; DOS Interrupt
MAIN ENDP

IFE ROM ; COM Signature
	PROGRAM_SIGNATURE
ENDIF

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
IF ROM
	DATA_SIZE EQU DATASEGEND - DATASEGSTART
	CODE_SIZE EQU 0h
ELSE
	DATA_SIZE EQU 0h
	CODE_SIZE EQU ENDOFPROG - BEGINOFPROG
ENDIF
STACK_DOS_SIZE EQU 80h
STACK_USER_SIZE EQU 80h
STACK_SIZE EQU STACK_DOS_SIZE + STACK_USER_SIZE
MEMORY_SIZE EQU PSP_SIZE + DATA_SIZE + CODE_SIZE + STACK_SIZE
PARA_SIZE EQU 0Fh ; Round up
MEMORY_RESERVE_PARA EQU (MEMORY_SIZE + PARA_SIZE) SHR 4
END PROGRAM
