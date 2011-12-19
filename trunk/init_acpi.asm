; =============================================================================
; Pure64 -- a 64-bit OS loader written in Assembly for x86-64 systems
; Copyright (C) 2008-2011 Return Infinity -- see LICENSE.TXT
;
; INIT ACPI
; =============================================================================


init_acpi:
	mov rsi, 0x00000000000E0000	; Start looking for the Root System Description Pointer Structure
	mov rbx, 'RSD PTR '		; This in the Signature for the ACPI Structure Table (0x2052545020445352)
searchingforACPI:
	lodsq				; Load a quad word from RSI and store in RAX, then increment RSI by 8
	cmp rax, rbx
	je foundACPI
	cmp rsi, 0x00000000000FFFFF	; Keep looking until we get here
	jge noMP			; We can't find ACPI either.. bail out and default to single cpu mode
	jmp searchingforACPI

foundACPI:
	lodsb				; Checksum
	lodsd				; OEMID (First 4 bytes)
	lodsw				; OEMID (Last 2 bytes)
	lodsb				; Grab the Revision value (0 is v1.0, 1 is v2.0, 2 is v3.0, etc)
	add al, 49
	mov [0x000B8098], al		; Print the ACPI version number
	sub al, 49
	cmp al, 0
	je foundACPIv1			; If AL is 0 then the system is using ACPI v1.0
	jmp foundACPIv2			; Otherwise it is v2.0 or higher

foundACPIv1:
	xor eax, eax
	lodsd				; Grab the 32 bit physical address of the RSDT (Offset 16).
	mov rsi, rax			; RSI now points to the RSDT
	lodsd				; Grab the Signiture
	cmp eax, 'RSDT'			; Make sure the signiture is valid
	jne novalidacpi			; Not the same? Bail out
	sub rsi, 4
	mov [os_ACPITableAddress], rsi	; Save the RSDT Table Address
	add rsi, 4
	xor eax, eax
	lodsd				; Length
	add rsi, 28			; Skip to the Entry offset
	sub eax, 36			; EAX holds the table size. Subtract the preamble
	shr eax, 2			; Divide by 4
	mov rdx, rax			; RDX is the entry count
	xor ecx, ecx
foundACPIv1_nextentry:
	lodsd
	push rax
	add ecx, 1
	cmp ecx, edx
	je findAPICTable
	jmp foundACPIv1_nextentry

foundACPIv2:
	lodsd				; RSDT Address
	lodsd				; Length
	lodsq				; Grab the 64 bit physical address of the XSDT (Offset 24).
	mov rsi, rax			; RSI now points to the XSDT
	lodsd				; Grab the Signiture
	cmp eax, 'XSDT'			; Make sure the signiture is valid
	jne novalidacpi			; Not the same? Bail out
	sub rsi, 4
	mov [os_ACPITableAddress], rsi	; Save the XSDT Table Address
	add rsi, 4
	xor eax, eax
	lodsd				; Length
	add rsi, 28			; Skip to the start of the Entries (offset 36)
	sub eax, 36			; EAX holds the table size. Subtract the preamble
	shr eax, 3			; Divide by 8
	mov rdx, rax			; RDX is the entry count
	xor ecx, ecx
foundACPIv2_nextentry:
	lodsq
	push rax
	add ecx, 1
	cmp ecx, edx
	jne foundACPIv2_nextentry

findAPICTable:
	mov al, '3'			; Search for the APIC table
	mov [0x000B809C], al
	mov al, '4'
	mov [0x000B809E], al
	mov ebx, 'APIC'
	xor ecx, ecx
searchingforAPIC:
	pop rsi
	lodsd
	add ecx, 1
	cmp eax, ebx
	je foundAPICTable
	cmp ecx, edx
	jne searchingforAPIC
	jmp noMP

fixstack:
	pop rax
	add ecx, 1

foundAPICTable:
	; fix the stack
	cmp ecx, edx
	jne fixstack

	lodsd				; Length of MADT in bytes
	mov ecx, eax			; Store the length in ECX
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
;	call os_print_newline
;	call os_debug_dump_al
;	push rax
;	mov al, ' '
;	call os_print_char
;	pop rax
	cmp al, 0			; Processor Local APIC
	je APICcpu
	cmp al, 1			; I/O APIC
	je APICioapic
	cmp al, 2			; Interrupt Source Override
	je APICinterruptsourceoverride
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
	push rdi
	mov rdi, os_IOAPICAddress
	xor ecx, ecx
	mov cl, [os_IOAPICCount]
	shl cx, 3			; Quick multiply by 3
	add rdi, rcx
	stosq
	pop rdi
;	call os_debug_dump_eax
;	mov [os_IOAPICAddress], rax
	lodsd				; System Vector Base
	add byte [os_IOAPICCount], 1
	jmp readAPICstructures		; Read the next structure

APICinterruptsourceoverride:
	xor eax, eax
	lodsb				; Length (will be set to 10)
	add ebx, eax
	lodsb				; Bus
	lodsb				; Source
;	call os_debug_dump_al
;	mov al, ' '
;	call os_print_char
	lodsd				; Global System Interrupt
;	call os_debug_dump_eax
	lodsw				; Flags
	jmp readAPICstructures		; Read the next structure

APICignore:
	xor eax, eax
	lodsb				; We have a type that we ignore, read the next byte
	add ebx, eax
	add rsi, rax
	sub rsi, 2			; For the two bytes just read
	jmp readAPICstructures		; Read the next structure

init_smp_acpi_done:
	ret

novalidacpi:
	mov al, 'X'
	mov [0x000B809A], al	
	jmp $
; =============================================================================
; EOF
