; =============================================================================
; Pure64 -- a 64-bit OS loader written in Assembly for x86-64 systems
; Copyright (C) 2008-2010 Return Infinity -- see LICENSE.TXT
;
; INIT ISA
; =============================================================================


isa_setup:

; Get the BIOS E820 Memory Map
; use the INT 0x15, eax= 0xE820 BIOS function to get a memory map
; inputs: es:di -> destination buffer for 24 byte entries
do_e820:
	mov edi, 0x0000E000		; location that memory map will be stored to
	xor ebx, ebx			; ebx must be 0 to start
	mov edx, 0x0534D4150		; Place "SMAP" into edx
	mov eax, 0xe820
	mov [es:di + 20], dword 1	; force a valid ACPI 3.X entry
	mov ecx, 24			; ask for 24 bytes
	int 0x15
	jc nomemmap			; carry set on first call means "unsupported function"
	mov edx, 0x0534D4150		; Some BIOSes apparently trash this register?
	cmp eax, edx			; on success, eax must have been reset to "SMAP"
	jne nomemmap
	test ebx, ebx			; ebx = 0 implies list is only 1 entry long (worthless)
	je nomemmap
	jmp jmpin
e820lp:
	mov eax, 0xe820			; eax, ecx get trashed on every int 0x15 call
	mov [es:di + 20], dword 1	; force a valid ACPI 3.X entry
	mov ecx, 24			; ask for 24 bytes again
	int 0x15
	jc memmapend			; carry set means "end of list already reached"
	mov edx, 0x0534D4150		; repair potentially trashed register
jmpin:
	jcxz skipentry			; skip any 0 length entries
	cmp cl, 20			; got a 24 byte ACPI 3.X response?
	jbe notext
	test byte [es:di + 20], 1	; if so: is the "ignore this data" bit clear?
	je skipentry
notext:
	mov ecx, [es:di + 8]		; get lower dword of memory region length
	test ecx, ecx			; is the qword == 0?
	jne goodentry
	mov ecx, [es:di + 12]		; get upper dword of memory region length
	jecxz skipentry			; if length qword is 0, skip entry
goodentry:
	add di, 32
skipentry:
	test ebx, ebx			; if ebx resets to 0, list is complete
	jne e820lp
nomemmap:
	mov byte [cfg_e820], 0		; No memory map function	
memmapend:
	xor eax, eax			; Create a blank record for termination (32 bytes)
	mov ecx, 8
	rep stosd

; Enable the A20 gate
set_A20:
	in al, 0x64
	test al, 0x02
	jnz set_A20
	mov al, 0xD1
	out 0x64, al
check_A20:
	in al, 0x64
	test al, 0x02
	jnz check_A20
	mov al, 0xDF
	out 0x60, al

; Configure serial port 1
	mov dx, 0
	mov al, 11100011b		; 9600 baud, no parity, 8 data bits, 1 stop bit
	mov ah, 0
	int 14h

; Set the PIT to fire at 100Hz (Divisor = 1193180 / hz)
	mov al, 0x34			; Set Timer
	out 0x43, al
	mov al, 0x9B			; We want 100MHz so 0x2E9B
	out 0x40, al
	mov al, 0x2E
	out 0x40, al

; Set keyboard repeat rate to max
	mov al, 0xf3
	out 0x60, al			; Set Typematic Rate/Delay
	xor al, al
	out 0x60, al			; 30 cps and .25 second delay
	mov al, 0xed
	out 0x60, al			; Set/Reset LEDs
	xor al, al
	out 0x60, al			; all off

; Set up RTC
	mov al, 0x0B
	out 0x70, al
	in al, 0x71
	or al, 00000010b		; Bit 2 (0) Data Mode to BCD, Bit 1 (1) 24 hour mode
	push ax
	mov al, 0x0B
	out 0x70, al
	pop ax
	out 0x71, al

; Remap IRQ's
; What will it take to activate the IOAPIC and ditch the 8259 PIC?
; http://osdever.net/tutorials/apicarticle.php
	mov al, 00010001b		; begin PIC 1 initialization
	out 0x20, al
	mov al, 00010001b		; begin PIC 2 initialization
	out 0xA0, al
	mov al, 0x20			; IRQ 0-7: interrupts 20h-27h
	out 0x21, al
	mov al, 0x28			; IRQ 8-15: interrupts 28h-2Fh
	out 0xA1, al
	mov al, 4
	out 0x21, al
	mov al, 2
	out 0xA1, al
	mov al, 1
	out 0x21, al
	out 0xA1, al
	
	in al, 0x21
	mov al, 11111111b		; Disable all IRQs
	out 0x21, al
	in al, 0xA1
	mov al, 11111111b
	out 0xA1, al

ret


; =============================================================================
; EOF