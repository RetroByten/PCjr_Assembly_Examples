int_bios_video_10					EQU 10h
	svc_bios_video_setmode_00			EQU	00h
	svc_bios_video_tty_0E				EQU 0Eh
	svc_bios_video_getmode_0F			EQU 0Fh
		val_bios_video_col_white_0F			EQU 0Fh

AI EQU 0 ; Set AI = 1 for AI, 0 for HUMAN

CODESEG SEGMENT
assume CS:CODESEG, DS:CODESEG
ORG	100h
PROGRAM:
	jmp			NEAR PTR MAIN	; DOS Command Entry Point

IF AI
%OUT Using AI
; Routine to convert a single hexadecimal ASCII character to its decimal equivalent
; Input: AL = ASCII character ('0'-'9', 'A'-'F', or 'a'-'f')
; Output: AL = Decimal equivalent value (if valid hex char)
;         CF = 0 if valid hex char
;         CF = 1 if invalid hex char

HexToDec PROC
    CMP AL, '0'          ; Check if AL >= '0'
    JB InvalidChar       ; If less, it's invalid
    CMP AL, '9'          ; Check if AL <= '9'
    JBE IsDigit          ; If yes, it's a valid digit

    CMP AL, 'A'          ; Check if AL >= 'A'
    JB LowerCaseCheck    ; If less, it might be lowercase
    CMP AL, 'F'          ; Check if AL <= 'F'
    JBE IsUpperHex       ; If yes, it's a valid uppercase hex letter

LowerCaseCheck:
    CMP AL, 'a'          ; Check if AL >= 'a'
    JB InvalidChar       ; If less, it's invalid
    CMP AL, 'f'          ; Check if AL <= 'f'
    JBE IsLowerHex       ; If yes, it's a valid lowercase hex letter
    JMP InvalidChar      ; Otherwise, invalid

IsDigit:
    SUB AL, '0'          ; Convert '0'-'9' to 0-9
    CLC                  ; Clear carry flag (valid character)
    RET

IsUpperHex:
    SUB AL, 'A'          ; Convert 'A'-'F' to 0-5
    ADD AL, 10           ; Add 10 to get the decimal equivalent
    CLC                  ; Clear carry flag (valid character)
    RET

IsLowerHex:
    SUB AL, 'a'          ; Convert 'a'-'f' to 0-5
    ADD AL, 10           ; Add 10 to get the decimal equivalent
    CLC                  ; Clear carry flag (valid character)
    RET

InvalidChar:
    STC                  ; Set carry flag (invalid character)
    RET
HexToDec ENDP
ELSE ;; HUMAN
%OUT Using HUMAN
; Input: AL = ASCII '0'-'9', 'A'-'F', 'a'-'f'
; Does not touch AH
; Output: Success	CF=0, al = 00h - 0Fh
; Output: Error		CF=1, al = undefined/don't care
UTIL_ASCII_NUM_TO_HEX PROC NEAR
	sub		al,'0' ; Check if between '0'-'9'
	cmp		al,9
	jbe		UTIL_ASCII_NUM_TO_HEX_S0 ; jump if below or equal
	sub		al,'A' - '0' ; Check result if between 'A'-'F'
	cmp		al,05h
	jbe		UTIL_ASCII_NUM_TO_HEX_S10
	sub		al,'a'-'A' ; Check result if between 'a'-'f'
	cmp		al,05h
	jbe		UTIL_ASCII_NUM_TO_HEX_S10
UTIL_ASCII_NUM_TO_HEX_F: ; Fail
	stc
	ret ; No need to jump, we're done
UTIL_ASCII_NUM_TO_HEX_S10: ; Success
	add		al,0Ah
UTIL_ASCII_NUM_TO_HEX_S0:
	clc
	ret
UTIL_ASCII_NUM_TO_HEX ENDP
ENDIF

; Input: AL = character to print
UTIL_PRINT_CHAR PROC NEAR ; Assumes al or constant
	push	bx
	push	ax						; preserve regs
	
	push	ax						; Temporarily store AL
	
	; Get video mode for page
	mov		ah,svc_bios_video_getmode_0F
	int		int_bios_video_10
	
	; bh = active page now
	mov		bl,val_bios_video_col_white_0F
	pop		ax 						; Retrieve AL
	
	mov		ah,svc_bios_video_tty_0E
	int		int_bios_video_10 
	
	pop		ax
	pop		bx
	ret
UTIL_PRINT_CHAR ENDP

;; CX = # of nibbles to print
;; AX = 1-4 nibbles to print from AH high -> AL low
UTIL_PRINT_HEX_NIBBLES PROC NEAR
UTIL_PRINT_HEX_NIBBLES_LOOP:
	rol		ax,1	; Grab the highest nibble by Rotating left 4x into al low nibble
	rol		ax,1	;
	rol		ax,1	;
	rol		ax,1 	; AL now contains "highest remaining nibble" in lowest place
	push	ax ; Save off the Nth rotated AX
	and		al,0Fh ; Isolate nibble
	add		al,'0' ; Attempt to shift into ASCII numeric range
	cmp		al,'9' ; Check if <= '9' ASCII
	jbe		UTIL_PRINT_HEX_NIBBLES_CONT ; Yup, continue
	add		al,'A'-'9'-1 ; If not, shift up to ASCII 'A' range
UTIL_PRINT_HEX_NIBBLES_CONT:
	call	UTIL_PRINT_CHAR
	pop		ax ; recover AX
	loop	UTIL_PRINT_HEX_NIBBLES_LOOP ; dec CX until 0
	ret
UTIL_PRINT_HEX_NIBBLES ENDP


MAIN PROC FAR
	;; Set up old-school DOS return, DS:0000
	push	ds					; Push DS (PSP) segment
	mov 	ax,0000h			; Set AX = 0
	push	ax					; Push offset onto stack
	
	;; Set DS register to CS
	push	cs
	pop 	ds					; Set DS = CS
	
	;;;;;;;;;;;;;;;;;
	;; INSERT CODE HERE
	;;;;;;;;;;;;;;;;;
	
	;; Uncomment one of these
	;mov al,5h ; FFFF
	;mov al,'0' ; 0
	;mov al,'9' ; 9
	;mov	al,'<' ; FFFF
	;mov al,'A' ; A
	;mov al,'F' ; F
	;mov	al,'^' ; FFFF
	;mov	al,'a' ; A
	;mov	al,'f' ; F
	;mov	al,'{' ; FFFF
	
IF AI
	call	HexToDec
ELSE
	call	UTIL_ASCII_NUM_TO_HEX
ENDIF
	jc		INVALID
VALID:
	ror		ax,1
	ror		ax,1
	ror		ax,1
	ror		ax,1 ; move it up to top of AH
	mov		cx,1h ; print just the top nibble
	call	UTIL_PRINT_HEX_NIBBLES
	jmp		DONE
INVALID:
	mov		cx,4h
	mov		ax,0FFFFh ; aka ERROR
	call	UTIL_PRINT_HEX_NIBBLES
	jmp		DONE
DONE:
	;;;;;;;;;;;;;;;;;
	;; END OF CODE
	;;;;;;;;;;;;;;;;;

	;; Exit to DOS
	ret 						; return to DS:0000
MAIN ENDP

CODESEG ENDS
END PROGRAM
