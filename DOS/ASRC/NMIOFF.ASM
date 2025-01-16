TITLE NMIOFF Program
PAGE 66,80 ; 66 lines per page, 80 characters/line

;; This is a program that attempts to disable and enable PCjr NMI
;  The PCjr Technical Reference indicates that an in on NMI clears the NMI latch
;  But does *not* actually read the current register value
;  So any writes must set *all* bitfields, not just AND (NOT SINGLE BIT), OUT

;  Bit 7, 1 = NMI enable, 0 = NMI disable

;; Other bit options are:
;; Bit 6 - 1 = IR test Enable, 0 = Disable (Should set to 0) 
;; Bit 5 - 1 = timer 0 output -> timer 1 input, 0 = 1.1925MHz -> timer 1 input
									; Should set to 0
;; Bit 4 (not actually implemented) - 1 = Disable -HRQ (DMA), 0 = Enable -HRQ
									; Depends on what you want to do
;; Bits 3-0, unused


int_dos_21 EQU 21h
	svc_dos_print_str_09	EQU 09h
	svc_dos_set_interrupt_25 EQU 25h
	svc_dos_terminate_4C EQU 4Ch
		val_dos_terminate_00 EQU 00h
		
port_nmi_mask_reg			EQU 0A0h ; 
;	nmi_bit					EQU 10000000B ; Enable NMI BIT
	nmi_enable				EQU 10000000B ; Bit 7 = NMI, 1 = on
	nmi_disable				EQU 00000000B ; Bit 7 = NMI, 0 = off

	
port_pic_cmd				EQU 20h ; 8259A PIC Command port
	val_pic_eoi					EQU 20h ; 8259A PIC "End of Interrupt" value

val_delay_inner					EQU 0080h

CODESEG SEGMENT
	assume CS:CODESEG, DS:CODESEG, SS:CODESEG
ORG	100h
PROGRAM:
	jmp			NEAR PTR MAIN				; DOS Command Entry Point

DELAYM MACRO
	local	DELAY_OUTER
	local	DELAY_INNER
		mov		cx,0FFFFh
DELAY_OUTER:
	push	cx
;;	mov		cx,00FFh
	mov		cx,val_delay_inner
DELAY_INNER:
	loop	DELAY_INNER
	pop		cx
	loop	DELAY_OUTER	
ENDM

DISABLE_NMIM MACRO
	mov		al,nmi_disable
	out		port_nmi_mask_reg,al
ENDM

ENABLE_NMIM MACRO
	mov		al,nmi_enable
	out		port_nmi_mask_reg,al
	in		al,port_nmi_mask_reg	; Read Port to clear latch,
									; For case a key was pressed
									; while NMI was masked
ENDM

debug_str_disable db "Disabling NMI",0dh,0ah,"$"
debug_str_delay db "Delaying...",0dh,0ah,"$"
debug_str_enable db "Enabling NMI",0dh,0ah,"$"
MAIN PROC FAR
	;; 1.) Delaying
	mov		dx,offset debug_str_delay
	mov		ah,svc_dos_print_str_09
	int		int_dos_21 ; Print Delaying string
	DELAYM

	;; 1.) Disable NMI
	mov		dx,offset debug_str_disable
	mov		ah,svc_dos_print_str_09
	int		int_dos_21 ; Print Disabling NMI string
	DISABLE_NMIM

	;; 2.) Delaying
	mov		dx,offset debug_str_delay
	mov		ah,svc_dos_print_str_09
	int		int_dos_21 ; Print Delaying string
	DELAYM
	
	;; 3.) Re-enable NMI
	mov		dx,offset debug_str_enable
	mov		ah,svc_dos_print_str_09
	int		int_dos_21 ; Print Enabling string
	ENABLE_NMIM

	mov		ax,(svc_dos_terminate_4C SHL 8) OR val_dos_terminate_00
	int		int_dos_21 ; DOS Interrupt
MAIN ENDP

CODESEG ENDS
END PROGRAM
