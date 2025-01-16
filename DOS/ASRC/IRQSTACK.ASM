TITLE INTSTACK Program
PAGE 66,80 ; 66 lines per page, 80 characters/line

;; This program is showing an example of how an INT
;; might safely swap to its own internal stack when servicing
;; a hardware IRQ
;; It is not meant to be a fully functional program!

;; Update - NMI disabling did not work the way I thought it did (see NMIOFF.ASM)

int_dos_21 EQU 21h
	svc_dos_set_interrupt_25 EQU 25h
	svc_dos_terminate_4C EQU 4Ch
		val_dos_terminate_00 EQU 00h
		
port_nmi_mask_reg			EQU 0A0h ; 
;	nmi_bit					EQU 10000000B ; Enable NMI BIT
	nmi_enable				EQU 10000000B ; Bit 7 = NMI
	nmi_disable				EQU 00000000B ; Bit 7 = NMI

port_pic_cmd				EQU 20h ; 8259A PIC Command port
	val_pic_eoi					EQU 20h ; 8259A PIC "End of Interrupt" value

CODESEG SEGMENT
	assume CS:CODESEG, DS:CODESEG, SS:CODESEG
ORG	100h
PROGRAM:
	jmp			NEAR PTR MAIN				; DOS Command Entry Point

;; Note - In general, IRQs ideally would not need their own stack
;;		- as they should be quick in and out
;;		- without the requirement to change stack, all of this
;;		- dance about NMI and interrupts would not be necessary

;; Note:
;; mov ss,<reg_a> implicitly suppresses interrupts on most 8088s
;; mov sp,<reg_b> (next instruction) lifts CPU interrupt suppression
;; However, early 8088s lack this feature, so cannot rely on it
;; 	- Most sources just say to do:
;; cli
;; mov ss,<reg_a>
;; mov sp,<reg_b>
;; sti
;;  - However, unlike most PCs the PCjr uses the NMI regularly
;;		for keyboard so that should also be masked to prevent
;;		potential transient crashes
;; Other note: this interrupt suppression on later 8088s also
;; works for push/pop on segment registers, and mov to any segment
;; register, not just SS

;; Note - currently assumes NMI and interrupts were enabled
;;		- this assumption may be invalid...maybe try to fix this
;;		- However:
;;			a.) Anything disabling interrupts would've prevented this
;;				from being called, can unconditionally re-enable
;;			b.) Anything disabling NMI absolutely should disable
;;				interrupts, (preventing this), do its thing, and
;;				then re-enable
;; Note - All of the above assumes an IRQ and not an INT, believe
;;		  INTS can be called even if cli?

IRQ_PROC PROC FAR ;;	Pushes 6 bytes to pre-existing stack
				;	Flags, Segment, Offset
	;; Note: IRQ Interrupts disabled as we entered the interrupt
	;; 		 Except keyboard NMI!
	
	sti ; Re-enable interrupts
	
	;; 1.) Preserve caller's AX on pre-existing stack
	push	ax ;; Pushes 2 more bytes onto pre-existing stack
	
	;; 2.) Preserve original DX and BP on pre-existing stack
	push	dx
	push	bp ;; Pushed another 4 bytes on existing stack
	
	;; 3.) Save caller's stack (SS:SP)
	mov		dx,ss ; Save existing stack segment
	mov		bp,sp ; Save existing stack pointer

	;; 4.) Disable NMI (to protect Stack swap)
	;in		al,port_nmi_mask_reg
	;and		al,NOT nmi_bit
	mov		al,nmi_disable
	out		port_nmi_mask_reg,al
	
	;; 5.) Setup new stack to CS:INT_STACK_END
	mov		ax,cs ; Get our segment - assumes code and stack in RAM
	cli ; Disable interrupts
	mov		ss,ax ; Set interrupt stack segment to CS
	mov		sp,offset INT_STACK_END	; Set interrupt stack pointer
	sti ; Enable interrupts
	
	
	;; 6.) Re-enable NMI
	;in		al,port_nmi_mask_reg
	;or		al,nmi_bit
	mov		al,nmi_enable
	out		port_nmi_mask_reg,al
	in		al,port_nmi_mask_reg ; Clear any latched data
	
	; 7.) Preserve all registers used except AX to new stack
	push	bp ; Example pushed to new stack
	; More registers, etc.

	;; 8a.)	---	Do interrupt things, Ensure card side of IRQ line is reset
	;; 		--- Insert Code Here
	;; 8b.)	--- Done doing interrupt things, card side of IRQ line is reset
	
	;; 9.) Restore registers used except AX from new stack
	; More registers, etc.
	pop		bp ; Example restored from new stack
	 
	;; 10.) Disable NMI
	;in		al,port_nmi_mask_reg
	;and		al,NOT nmi_bit
	mov		al,nmi_disable
	out		port_nmi_mask_reg,al
	
	;; 11.) Restore pre-existing stack (DX:BP)
	cli ; Disable interrupts
	mov		ss,dx
	mov		sp,bp
	sti ; Enable interrupts
	
	;; 12.) Re-Enable NMI
	;in		al,port_nmi_mask_reg
	;or		al,nmi_bit
	mov		al,nmi_enable
	out		port_nmi_mask_reg,al
	in		al,port_nmi_mask_reg ; Clear any latched NMI
	
	; 13.) Restore original BP and DX from pre-existing stack
	pop		bp
	pop		dx
	
	;; 14.) Acknowledge the PIC interrupt
	mov		al,val_pic_eoi	; If done with a hardware interrupt, have to ACK
	out		port_pic_cmd,al ; Ack hardware Interrupt
	
	;; 15.) Restore original AX from pre-existing stack
	pop		ax
	iret
IRQ_PROC  ENDP	

MAIN PROC FAR
	mov		ax,(svc_dos_terminate_4C SHL 8) OR val_dos_terminate_00
	int		int_dos_21 ; DOS Interrupt
MAIN ENDP

IRQ_STACK_BEGIN:
	interrupt_stack db 100h dup(00h)
IRQ_STACK_END:

CODESEG ENDS
END PROGRAM
