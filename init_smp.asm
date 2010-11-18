; =============================================================================
; Pure64 -- a 64-bit OS loader written in Assembly for x86-64 systems
; Copyright (C) 2008-2010 Return Infinity -- see LICENSE.TXT
;
; INIT SMP
; =============================================================================


smp_setup:

smp_check_for_mp:			; Look for the MP Floating Pointer Structure
	mov rsi, 0x00000000000F0000	; We want to start looking here
	mov ebx, '_MP_'			; This in the Anchor String for the MP Structure Table
searchingforMP:
	lodsd				; Load a double word from RSI and store in EAX, then increment RSI by 4
	cmp eax, ebx
	je foundMP
	cmp rsi, 0x00000000000FFFFF	; Keep looking until we get here
	jge smp_check_for_acpi		; We can't find a MP.. try ACPI
	jmp searchingforMP

smp_check_for_acpi:			; Look for the Root System Description Pointer Structure
	mov rsi, 0x00000000000E0000	; We want to start looking here
	mov rbx, 'RSD PTR '		; This in the Signature for the ACPI Structure Table (0x2052545020445352)
searchingforACPI:
	lodsq				; Load a quad word from RSI and store in RAX, then increment RSI by 8
	cmp rax, rbx
	je foundACPI
	cmp rsi, 0x00000000000FFFFF	; Keep looking until we get here
	jge noMP			; We can't find ACPI either.. bail out and default to single cpu mode
	jmp searchingforACPI

foundACPI:
	call init_smp_acpi
	jmp makempgonow

foundMP:
	call init_smp_mp

makempgonow:


; Step 3: Enable Local APIC on BSP
	xor esi, esi
	mov esi, [os_LocalAPICAddress]
	cmp esi, 0x00000000
	je noMP				; Skip MP init if we didn't get a valid LAPIC address
	add rsi, 0xf0			; Offset to Spurious Interrupt Register
	mov rdi, rsi
	lodsd
	or eax, 0000000100000000b
	stosd

; Check if we want the AP's to be enabled.. if not then skip step 4
	cmp byte [cfg_smpinit], 1	; Check if SMP should be enabled
	jne no_smp			; If not then skip SMP init

; Step 4: Start the AP's
	mov eax, 0xFF000000		; broadcast 'INIT' IPI to all-except-self
	xor edi, edi
	mov edi, [os_LocalAPICAddress]
	add rdi, 0x310
	stosd

	mov eax, 0x000C4500
	xor edi, edi
	mov edi, [os_LocalAPICAddress]
	add rdi, 0x300
	stosd

	; DELAY 10 milliseconds. A millisecond is one thousandth of a second.
	mov eax, 10000			; ten-thousand microseconds (aka 10 milliseconds)
	call delay_EAX_microseconds	; execute programmed delay

.B0:
	xor esi, esi
	mov esi, [os_LocalAPICAddress]
	add rsi, 0x300
	lodsd
	bt eax, 12			; Verify that the command completed
	jc .B0

; broadcast 'Startup' IPI to all-except-self using vector 0x0A to specify entry-point is at the memory-address 0x0000A000
	mov eax, 0xFF000000
	xor edi, edi
	mov edi, [os_LocalAPICAddress]
	add rdi, 0x310
	stosd

	mov eax, 0x000C460A
	xor edi, edi
	mov edi, [os_LocalAPICAddress]
	add rdi, 0x300
	stosd

	mov eax, 200			; DELAY 200 microseconds. A microsecond is one millionth of a second.
	call delay_EAX_microseconds	; execute programmed delay

.B1:
	xor esi, esi
	mov esi, [os_LocalAPICAddress]
	add rsi, 0x300
	lodsd
	bt eax, 12			; Verify that the command completed
	jc .B1
	mov eax, 250000			; delay 1/4 of a second to let things settle down
	call delay_EAX_microseconds	; execute programmed delay

; broadcast 'Startup' IPI to all-except-self using vector 0x0A to specify entry-point is at the memory-address 0x0000A000
	mov eax, 0x000C460A
	xor edi, edi
	mov edi, [os_LocalAPICAddress]
	add rdi, 0x300
	stosd

	mov eax, 200			; DELAY 200 microseconds. A microsecond is one millionth of a second.
	call delay_EAX_microseconds	; execute programmed delay

.B2:
	xor esi, esi
	mov esi, [os_LocalAPICAddress]
	add rsi, 0x300
	lodsd
	bt eax, 12			; Verify that the command completed
	jc .B2
	mov eax, 250000			; delay 1/4 of a second to let things settle down
	call delay_EAX_microseconds	; execute programmed delay

no_smp:

; Prepare the IOAPIC



	
noMP:
	lock
	inc word [cpu_amount]		; BSP adds one here

	xor eax, eax
	xor esi, esi
	mov esi, [os_LocalAPICAddress]
	add rsi, 0x20			; Add the offset for the APIC ID location
	lodsd				; APIC ID is stored in bits 31:24
	shr rax, 24			; AL now holds the CPU's APIC ID (0 - 255)
	mov rdi, 0x0000F700		; The location where the cpu values are stored
	add rdi, rax			; RDI points to infomap CPU area + APIC ID. ex F701 would be APIC ID 1
	mov al, 3			; This is the BSP so bits 0 and 1 are set
	stosb

ret


;------------------------------------------------------------------------------
; This helper-function will implement the timed delays which are
; specified in Intel's 'Multiprocessor Initialization Protocol',
; where the delay-duration (in microseconds) is in register EAX.
; 1 second = 1000000 microseconds
; 1 milisecond = 1000 microseconds
delay_EAX_microseconds:
	push rax
	push rcx

	mov ecx, eax			; copy microseconds count

	; enable the 8254 Channel-2 counter
	in al, 0x61			; get PORT_B settings
	and al, 0x0D			; turn PC speaker off
	or al, 0x01			; turn on Gate2 input
	out 0x61, al			; output new settings

	; program channel-2 for one-shot countdown
	mov al, 0xB0			; chan2,LSB/MSB,one-shot
	out 0x43, al			; output command to PIT 

	; compute value for channel-2 latch-register
	mov eax, 1193182		; input-pulses-per-second
	mul ecx				; * number of microseconds
	mov ecx, 1000000		; microseconds-per-second
	div ecx				; division by doubleword

	; write latch-resister value to channel-2
	out 0x42, al
	mov al, ah
	out 0x42, al
	
	; wait for channel-2 countdown to conclude
nxpoll:
	in al, 0x61
	test al, 0x20
	jz nxpoll

	; disable the 8254 Channel-2 counter
	in al, 0x61			; get PORT_B settings
	and al, 0x0C			; turn off channel-2 
	out 0x61, al			; output new settings

	pop rcx
	pop rax
	ret
;------------------------------------------------------------------------------


%include "init_smp_acpi.asm"
%include "init_smp_mp.asm"


; =============================================================================
; EOF
