TITLE INFLOOP Program
PAGE 66,80 ; 66 lines per page, 80 characters/line

;; This is just an infinite loop with hardware interrupts disabled
; NMI remains enabled
; Used to help capture wait-state bus traces
; Should be launched from DOS 2.1 on a 128K jr
; can vary display mode before hand (40 vs. 80 column)

%OUT Processing EQUATES...

%OUT Processing CODE Segment
CODESEG SEGMENT
	assume CS:CODESEG, DS:CODESEG, SS:CODESEG
ORG 100h
PROGRAM: ; Needed for COM to later terminate the program
jmp MAIN

MAIN:
	cli ; Disable Interrupts so the hardware interrupts
		; don't pull us into the BIOS
		; Make sure not to touch keyboard to avoid NMI
INFLOOP:
	jmp		INFLOOP

CODESEG ENDS
END PROGRAM
