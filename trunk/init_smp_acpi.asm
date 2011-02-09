; =============================================================================
; Pure64 -- a 64-bit OS loader written in Assembly for x86-64 systems
; Copyright (C) 2008-2011 Return Infinity -- see LICENSE.TXT
;
; INIT SMP ACPI
; =============================================================================


init_smp_acpi:
	mov al, 'A'
	mov [0x000B809A], al

	lodsb				; Checksum
	lodsd				; OEMID (First 4 bytes)
	lodsw				; OEMID (Last 2 bytes)
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
	lodsd				; RSDT Address
	lodsd				; Length
	lodsq				; Grab the 64 bit physical address of the XSDT (Offset 24).
	mov rsi, rax			; RSI now points to the XSDT
	lodsd				; Grab the Signiture
	cmp eax, 'XSDT'
	jne novalidacpi

findAPIC:
	mov [os_ACPITableAddress], rsi

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
	lodsd				; Length of MADT in bytes
	mov ecx, eax
	xor ebx, ebx
	lodsb				; Revision
	lodsb				; Checksum
	lodsd				; OEMID (First 4 bytes)
	lodsw				; OEMID (Last 2 bytes)
	lodsq				; OEM Table ID
	lodsd				; OEM Revision
	lodsd				; Creator ID
	lodsd				; Creator Revision
	xor eax, eax
	lodsd				; Local APIC Address
	mov [os_LocalAPICAddress], rax	; Save the Address of the Local APIC
	lodsd				; Flags
	add ebx, 44
	mov rdi, 0x0000000000005800

readAPICstructures:
	cmp ebx, ecx
	jge init_smp_acpi_done
	lodsb				; APIC Structure Type
	cmp al, 0
	je APICcpu
	cmp al, 1
	je APICioapic
	jmp APICignore

APICcpu:
	inc word [cpu_detected]
	xor eax, eax
	lodsb				; Length (will be set to 8)
	add ebx, eax
	lodsb				; ACPI Processor ID
	lodsb				; APIC ID
	push rdi
	add rdi, rax
	lodsd				; Flags
	stosb
	pop rdi
	jmp readAPICstructures		; Read the next structure

APICioapic:
	xor eax, eax
	lodsb				; Length (will be set to 12)
	add ebx, eax
	lodsb				; IO APIC ID
	lodsb				; Reserved
	xor eax, eax
	lodsd				; IO APIC Address
	mov [os_IOAPICAddress], rax
	lodsd				; System Vector Base
	jmp readAPICstructures		; Read the next structure

APICignore:
	xor eax, eax
	lodsb				; We have a type that we ignore, read the next byte
	add ebx, eax
	add rsi, rax
	sub rsi, 2			; For the two bytes just read
	jmp readAPICstructures		; Read the next structure

init_smp_acpi_done:
	jmp makempgonow

novalidacpi:
	mov al, 'X'
	mov [0x000B809A], al	
	jmp $
; =============================================================================
; EOF
