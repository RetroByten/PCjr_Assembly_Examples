TITLE PROCSTAC Program
PAGE 66,80 ; 66 lines per page, 80 characters/line

;; This program is intended to be loaded by DEBUG
; and stepped through to view the stack after various
; near, far, and interrupt calls
; See bottom of the file for comments

%OUT Processing EQUATES...

seg_interrupt_table			EQU 0000h

int_bios_18h				EQU 18h
	int_bios_18h_offset		EQU int_bios_18h * 4h
	int_bios_18h_seg		EQU int_bios_18h_offset + 2

int_dos_21					EQU	21h
	svc_dos_terminate		EQU	4Ch
		val_dos_terminate_0	EQU 00h

%OUT Processing CODE Segment
CODESEG SEGMENT
	assume CS:CODESEG, DS:CODESEG, SS:CODESEG
ORG 100h
PROGRAM: ; Needed for COM to later terminate the program
jmp SETUPSEGS

PROCNEAR PROC NEAR
	ret
PROCNEAR ENDP
PROCFAR PROC FAR
	ret
PROCFAR ENDP
PROCINTERRUPT:
	sti ; Re-enable interrupts in a normal non-critical interrupt routine
	iret

SETUPSEGS:
	mov		ax,cs
	mov		ds,ax
	mov		ax,seg_interrupt_table
	mov		es,ax
SAVEINT18H:
	mov		ax,es:[int_bios_18h_offset]
	mov		[ram_oldint18h_offset],ax
	mov		ax,es:[int_bios_18h_seg]
	mov		[ram_oldint18h_seg],ax

SETNEWINT18H:
	cli
		mov		ax,offset PROCINTERRUPT
		mov		es:[int_bios_18h_offset],ax
		mov		ax,cs
		mov		es:[int_bios_18h_seg],ax
	sti

CALLPROCS:
	call	PROCNEAR
	call	FAR PTR PROCFAR
	;int		int_bios_18h

EXIT2DOS:
	mov		ax,(svc_dos_terminate SHL 8) OR val_dos_terminate_0 
	int		int_dos_21 ;; EXIT to DOS
HALT:
	jmp		HALT ; In case DOS somehow doesn't end the program, should never reach

ram_oldint18h_offset	dw ?
ram_oldint18h_seg		dw ?

CODESEG ENDS
END PROGRAM
