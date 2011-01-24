; =============================================================================
; Pure64 -- a 64-bit OS loader written in Assembly for x86-64 systems
; Copyright (C) 2008-2011 Return Infinity -- see LICENSE.TXT
;
; Interrupts
; =============================================================================


; -----------------------------------------------------------------------------
; Default exception handler
exception_gate:
	mov rsi, int_string00
	call os_print_string
	mov rsi, exc_string
	call os_print_string
	jmp $					; hang
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; Default interrupt handler
interrupt_gate:				; handler for all other interrupts
	iretq
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; Real-time clock interrupt. IRQ 0x00, INT 0x20
align 16
timer:
	add qword [os_Counter], 1	; 64-bit counter started at bootup
	mov al, 0x20			; Acknowledge the IRQ
	out 0x20, al
	iretq
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; CPU Exception Gates
exception_gate_00:
	mov al, 0x00
	jmp exception_gate_main

exception_gate_01:
	mov al, 0x01
	jmp exception_gate_main

exception_gate_02:
	mov al, 0x02
	jmp exception_gate_main

exception_gate_03:
	mov al, 0x03
	jmp exception_gate_main

exception_gate_04:
	mov al, 0x04
	jmp exception_gate_main

exception_gate_05:
	mov al, 0x05
	jmp exception_gate_main

exception_gate_06:
	mov al, 0x06
	jmp exception_gate_main

exception_gate_07:
	mov al, 0x07
	jmp exception_gate_main

exception_gate_08:
	mov al, 0x08
	jmp exception_gate_main

exception_gate_09:
	mov al, 0x09
	jmp exception_gate_main

exception_gate_10:
	mov al, 0x0A
	jmp exception_gate_main

exception_gate_11:
	mov al, 0x0B
	jmp exception_gate_main

exception_gate_12:
	mov al, 0x0C
	jmp exception_gate_main

exception_gate_13:
	mov al, 0x0D
	jmp exception_gate_main

exception_gate_14:
	mov al, 0x0E
	jmp exception_gate_main

exception_gate_15:
	mov al, 0x0F
	jmp exception_gate_main

exception_gate_16:
	mov al, 0x10
	jmp exception_gate_main

exception_gate_17:
	mov al, 0x11
	jmp exception_gate_main

exception_gate_18:
	mov al, 0x12
	jmp exception_gate_main

exception_gate_19:
	mov al, 0x13
	jmp exception_gate_main

exception_gate_main:
	call os_print_newline
	mov rsi, int_string00
	call os_print_string
	mov rsi, exc_string00
	and rax, 0xFF			; Clear out everything in RAX except for AL
	mov bl, 52
	mul bl				; AX = AL x BL
	add rsi, rax			; Use the value in RAX as an offset to get to the right message
	call os_print_string
	call os_print_newline
	call os_dump_regs

exception_gate_main_hang:
	nop
	jmp exception_gate_main_hang	; Hang. User must reset machine at this point

; Strings for the error messages
int_string00 db 'Pure64 - ', 0
exc_string db 'Unknown Fatal Exception!', 0
align 16
exc_string00 db 'Interrupt 00 - Divide Error Exception (#DE)        ', 0
exc_string01 db 'Interrupt 01 - Debug Exception (#DB)               ', 0
exc_string02 db 'Interrupt 02 - NMI Interrupt                       ', 0
exc_string03 db 'Interrupt 03 - Breakpoint Exception (#BP)          ', 0
exc_string04 db 'Interrupt 04 - Overflow Exception (#OF)            ', 0
exc_string05 db 'Interrupt 05 - BOUND Range Exceeded Exception (#BR)', 0
exc_string06 db 'Interrupt 06 - Invalid Opcode Exception (#UD)      ', 0
exc_string07 db 'Interrupt 07 - Device Not Available Exception (#NM)', 0
exc_string08 db 'Interrupt 08 - Double Fault Exception (#DF)        ', 0
exc_string09 db 'Interrupt 09 - Coprocessor Segment Overrun         ', 0	; No longer generated on new CPU's
exc_string10 db 'Interrupt 10 - Invalid TSS Exception (#TS)         ', 0
exc_string11 db 'Interrupt 11 - Segment Not Present (#NP)           ', 0
exc_string12 db 'Interrupt 12 - Stack Fault Exception (#SS)         ', 0
exc_string13 db 'Interrupt 13 - General Protection Exception (#GP)  ', 0
exc_string14 db 'Interrupt 14 - Page-Fault Exception (#PF)          ', 0
exc_string15 db 'Interrupt 15 - Undefined                           ', 0
exc_string16 db 'Interrupt 16 - x87 FPU Floating-Point Error (#MF)  ', 0
exc_string17 db 'Interrupt 17 - Alignment Check Exception (#AC)     ', 0
exc_string18 db 'Interrupt 18 - Machine-Check Exception (#MC)       ', 0
exc_string19 db 'Interrupt 19 - SIMD Floating-Point Exception (#XM) ', 0


; =============================================================================
; EOF
