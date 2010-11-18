; =============================================================================
; Pure64 -- a 64-bit OS loader written in Assembly for x86-64 systems
; Copyright (C) 2008-2010 Return Infinity -- see LICENSE.TXT
;
; INIT SMP ACPI
; =============================================================================


init_smp_acpi:
	mov al, 'A'
	mov [0x000B809A], al
	add rsi, 7			; Skip the Checksum and OEMID for now
	lodsb				; Grab the Revision value (0 is v1.0, 1 is v2.0, 2 is v3.0, etc)
	cmp al, 0
	je foundACPIv1
	jmp foundACPIv2

foundACPIv1:
	xor eax, eax
	lodsd				; Grab the 32 bit physical address of the RSDT (Offset 16).
	mov rsi, rax
	lodsd
	cmp eax, 'RSDT'
	jne novalidacpi
	jmp findAPIC

foundACPIv2:
	add rsi, 8
	lodsq				; Grab the 64 bit physical address of the XSDT (Offset 24).
	mov rsi, rax			; RSI now points to the XSDT
	lodsd				; Grab the Signiture
	cmp eax, 'XSDT'
	jne novalidacpi

findAPIC:	
	mov ebx, 'APIC'			; This in the signature for the Multiple APIC Description Table
	mov ecx, 1000
searchingforAPIC:
	lodsd				; Load a double word from RSI and store in EAX, then increment RSI by 4
	dec ecx
	cmp eax, ebx
	je foundAPIC
	cmp ecx, 0			; Keep looking until we get here
	je noMP				; We can't find a MP either.. bail out and default to single cpu mode
	jmp searchingforAPIC

foundAPIC:
	add rsi, 32
	lodsd
	mov [os_LocalAPICAddress], eax	; Save the Address of the Local APIC

init_smp_acpi_done:
	ret

novalidacpi:
	mov al, 'X'
	mov [0x000B809A], al	
	jmp $
; =============================================================================
; EOF
