TITLE CMPS Program
PAGE 66,80 ; 66 lines per page, 80 characters/line

;; This program is a reference for how to use cmps/repe
; Goal is to compare two strings that are the same
; and two strings that are different

;; 8088 ASM considers a string a sequence of bytes or words

%OUT Processing EQUATES...
int_dos_21					EQU	21h
	svc_dos_print_str		EQU 09h
	svc_dos_terminate		EQU	4Ch
		val_dos_terminate_0	EQU 00h

%OUT Processing CODE Segment
CODESEG SEGMENT
	assume CS:CODESEG, DS:CODESEG, SS:CODESEG, ES:CODESEG
ORG 100h
PROGRAM: ; Needed for COM to later terminate the program
jmp MAIN

STR_EQUAL PROC NEAR
	push	dx
	mov		dx,offset match
	call	PRT_STR
	pop		dx
	ret
STR_EQUAL ENDP

STR_NEQUAL PROC NEAR
	push	dx
	mov		dx,offset nomatch
	call	PRT_STR
	pop		dx
	ret
STR_NEQUAL ENDP

PRT_STR PROC NEAR ; Assumes DS:DX is set
	push	ax
	mov		ah,svc_dos_print_str
	int		int_dos_21
	pop		ax
	ret
PRT_STR ENDP

MAIN:
	;; Step 0 Setup DS and ES segments
	mov		ax,cs
	mov		ds,ax
	mov		es,ax 
	
	;; Step 1 Compare str1 to str2 bytewise, should match
	mov		cx,offset str1end - offset str1 ; Number of bytes, Can't use LENGTH str1 since it looks like MASM just says "byte length = 1?"
							; in bytes, if using string WORD compare, need to ensure it is even and divide by 2
	; DS:SI = str1, ES:DI = str2
	mov		si,offset str1
	mov		di,offset str2
	cld						; Clear Direction Flag (set to increment mode)
	repe	cmpsb			; repe = repeate while equal
							; cmpsb = compare string bytes
							; Compare CX (LENGTH str1) bytes of STR1 and STR2, while equal, if not equal modify flags
							; ZF = 1 (jz) if equal, ZF = 0 (jnz) if unequal
	jne		STR1NE
STR1E:
	call	STR_EQUAL
	jmp		STR1DONE	
STR1NE:
	call	STR_NEQUAL
STR1DONE:

	;; Step 2 Compare str1 and str3 bytewise, should not match
	mov		cx,offset str1end - offset str1
	mov		si,offset str1
	mov		di,offset str3
	cld
	repe	cmpsb
	jne		STR2NE
STR2E:
	call	STR_EQUAL
	jmp		STR2DONE
STR2NE:
	call	STR_NEQUAL
STR2DONE:

	;; Step 3 Compare str1 and str2 wordwise, should match (ASSUMES THEY ARE EVEN LENGTH!!)
	mov		cx,(offset str1end - offset str1) / 2 ; Number of words, need to ensure this is even
	mov		si,offset str1
	mov		di,offset str2
	cld
	repe	cmpsw		; cmpsw = compare string words
	jne		STR3NE
STR3E:
	call	STR_EQUAL
	jmp		STR3DONE
STR3NE:
	call	STR_NEQUAL
STR3DONE:
	
	;; Step 4 Compare str1 and str3 wordwise, should not match (ASSUMES THEY ARE EVEN LENGTH!!)
	mov		cx,(offset str1end - offset str1) / 2 ; Number of words
	mov		si,offset str1
	mov		di,offset str3
	cld
	repe	cmpsw
	jne		STR4NE
STR4E:
	call	STR_EQUAL
	jmp		STR4DONE
STR4NE:
	call	STR_NEQUAL
STR4DONE:
	
EXIT2DOS:
		mov		ax,(svc_dos_terminate SHL 8) OR val_dos_terminate_0 
		int		int_dos_21 ;; EXIT to DOS
HALT:
		jmp		HALT ; safety catch
		
str1 db "Hola Mundo" ;
str1end: ; needed to make length calculations easier
str2 db "Hola Mundo" ;
str2end:
str3 db "hola mundo" ;
str3end:

match db "Strings match :)!",0Dh,0Ah,"$"
nomatch db "Strings do not match :(!",0Dh,0Ah,"$"	



CODESEG ENDS
END PROGRAM
