TITLE PRTLOGO Program
PAGE 66,80 ; 66 lines per page, 80 characters/line

;; Inspired by Trixter's post on the PCjr forum
;;  where he wrote a program to invoke the PCjr
;;  BIOS logo screen, I wrote a variant of it
;;  to see if I could avoid the memcopy
;; Trixter's post: https://www.brutman.com/forums/viewtopic.php?t=1351


;; This program attempts to invoke the PCjr Logo

;; Outline
; 1.) Load diagnostic int 82h
; 2.) Push FAR RET address (segment of this program, offset of WAIT4KEY)
; 3.) Push NEAR RET address (offset of a CBh byte to borrow as a RETF in F000:0000-FFFF)
; 4.) Set video mode (Color Text [40x25])
; 5.) JMP FAR to F000:0C21
; 6.) Wait for any key
; 7.) Reset video to 40x25 BW
; 8.) Exit to DOS

%OUT Processing EQUATES...
seg_int_vec_table				EQU 0000h
int_bas_82h						EQU	82h
	int_bas_82h_offset			EQU int_bas_82h * 4h
	int_bas_82h_seg				EQU int_bas_82h_offset + 2h

int_bios_video_10h				EQU 10h
	svc_set_video_mode			EQU 00h
		val_40x25_bw			EQU 00h
		val_40x25_col			EQU 01h

int_bios_keyboard_16h			EQU 16h
	svc_keyboard_input_status	EQU 01h

int_dos_21						EQU	21h
	svc_dos_terminate			EQU	4Ch
		val_dos_terminate_0		EQU 00h

seg_bios_rom					EQU 0F000h
	off_bios_print				EQU 1A2Ah
	off_bios_retf				EQU 1369h ;; Random BIOS 0CBh byte, will borrow as a RETF instruction

%OUT Processing CODE Segment
CODESEG SEGMENT
	assume CS:CODESEG, DS:CODESEG, SS:CODESEG
ORG 100h
PROGRAM: ; Needed for COM to later terminate the program

;; Setup DS to point to CS
	mov		ax,cs
	mov		ds,ax

;; Setup ES to point to Interrupt Vector Table segment
	mov		ax,seg_int_vec_table
	mov		es,ax
	
;; Setup INT82H - needed for BIOS call
	mov		ax,off_bios_print
	mov		es:[int_bas_82h_offset],ax
	mov		ax,seg_bios_rom
	mov		es:[int_bas_82h_seg],ax

;; Setup FAR return (final return back to our code)
	mov		ax,cs
	push	ax
	mov		ax,offset WAIT4KEY
	push	ax
	
;; Setup NEAR return (first return)
	mov		ax,off_bios_retf
	push	ax

;; Change Video Mode (also clears the screen)
	mov		ax,(svc_set_video_mode SHL 8) OR val_40x25_col
	int		int_bios_video_10h

;; FAR JMP to put_logo, jmp will RETF here
	jmp DWORD PTR [ram_put_logo_addr]

;; Wait for key to be pressed...
WAIT4KEY:
	mov		ah,svc_keyboard_input_status
	int		int_bios_keyboard_16h
	jz		WAIT4KEY

;; Change Video Mode (also clears the screen)
	mov		ax,(svc_set_video_mode SHL 8) OR val_40x25_bw
	int		int_bios_video_10h

;; Exit to DOS
EXIT2DOS:
	mov		ax,(svc_dos_terminate SHL 8) OR val_dos_terminate_0 
	int		int_dos_21 ;; EXIT to DOS
HALT:
	jmp		HALT ; In case DOS somehow doesn't end the program, should never reach

;	off_bios_put_logo			EQU 0C21h
ram_put_logo_addr	dw 0C21h,0F000h

CODESEG ENDS
END PROGRAM

