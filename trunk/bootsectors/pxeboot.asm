; copy /b pxeboot.bin + pure64.sys + kernel64.sys pxe.sys

USE16
org 0x7C00

start:
	xor eax, eax
	xor esi, esi
	xor edi, edi
	mov ds, ax
	mov es, ax
	mov bp, 0x7c00

; Make sure the screen is set to 80x25 color text mode
	mov ax, 0x0003			; Set to normal (80x25 text) video mode
	int 0x10

; Print message
	mov si, msg_Load
	call print_string_16

	jmp 0x0000:0x8000

;------------------------------------------------------------------------------
; 16-bit Function to print a sting to the screen
; input: SI - Address of start of string
print_string_16:			; Output string in SI to screen
	pusha
	mov ah, 0x0E			; int 0x10 teletype function
.repeat:
	lodsb				; Get char from string
	cmp al, 0
	je .done			; If char is zero, end of string
	int 0x10			; Otherwise, print it
	jmp short .repeat
.done:
	popa
	ret
;------------------------------------------------------------------------------


msg_Load db "Loading via PXE... ", 0

times 510-$+$$ db 0

sign dw 0xAA55

times 1024-$+$$ db 0