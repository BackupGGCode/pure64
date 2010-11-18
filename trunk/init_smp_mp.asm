; =============================================================================
; Pure64 -- a 64-bit OS loader written in Assembly for x86-64 systems
; Copyright (C) 2008-2010 Return Infinity -- see LICENSE.TXT
;
; INIT SMP MP
; =============================================================================


init_smp_mp:
	mov al, 'M'
	mov [0x000B809A], al
	xor rax, rax
	lodsd
	mov [os_MPTableAddress], eax	; Address of the MP Configuration Table


; Step 2: Parse the MP Configuration Table.
	mov eax, [os_MPTableAddress]
	mov rsi, rax
	lodsd				; Signature
	cmp eax, 'PCMP'			; check for the signiture to confirm that the table is present
	jne near noMP 			; If the signiture is not there then we bail out

foundvalidMP:
	lodsw				; Base Table Length
	mov [os_MPBaseTableLength], ax	; Save the Length of the MP Table
	lodsb				; Specification Revision
	lodsb				; Checksum
	lodsq				; OEM ID
	lodsd				; Product ID
	lodsd				; Product ID
	lodsd				; Product ID
	lodsd				; OEM Table Pointer
	lodsw				; OEM Table Size
	lodsw				; Entry Count
	mov [os_MPTableEntriesCount], ax
	lodsd				; Address of Local APIC
	mov [os_LocalAPICAddress], eax	; Save the Address of the Local APIC
	lodsw				; Extended Table Length
	mov [os_MPExtendedTableLength], ax

	mov eax, [os_MPTableAddress]
	add eax, 0x0000002c
	mov [os_MPTableEntriesAddress], eax
	
; Parse the table
	xor rsi, rsi
	mov esi, [os_MPTableEntriesAddress]
	mov cx, [os_MPTableEntriesCount]
	
checktable:
;	cmp dx, cx
;	jge near theend
	lodsb
	cmp al, 0x00
	je mpcpu
	cmp al, 0x01
	je mpbus
	cmp al, 0x02
	je mpioapic
;	cmp al, 0x03
;	je mpioint
;	cmp al, 0x04
;	je near mplocalint
	jmp init_smp_mp_done
	
mpcpu:					; 20 bytes each
	xor rax, rax
	lodsb				; Local APIC ID of the processor
;	mov rdi, 0x0000F700		; The location where the cpu values are stored
;	add rdi, rax			; RDI points to infomap CPU area + APIC ID. ex F701 would be APIC ID 1
	lodsb				; Local APIC Version
	lodsb				; CPU Enabled Bit (bit 0) and CPU Bootstrap Processor Bit (bit 1)
;	stosb				; Store the CPU info bits to the infomap
	lodsd				; CPU Signature
	lodsd				; Feature Flags
	lodsd				; Padding
	lodsd				; Padding
	inc dx
	jmp checktable

mpbus:					; 8 bytes each
	lodsd				; ???
	lodsw				; ???
	lodsb				; ???
	inc dx
	jmp checktable

mpioapic:				; 8 bytes each
	inc dx
	lodsb				; IO APIC ID
	lodsb				; APIC Version
	lodsb				; IO APIC Enabled bit (bit 0) if 0 do not use!
	lodsd				; IO APIC physical base address in memory
	mov [os_IOAPICAddress], eax	; Save the Address of the Local APIC
	jmp checktable

;mpioint:
;	push rsi
;	lea esi, [mp_ioint]
;	call os_print_string
;	pop rsi
;	inc dx
;	lodsd	; EAX now stores ???
;	lodsw	; AX now stores ???
;	lodsb	; AL now stores ???
;	jmp checktable

;mplocalint:
;	push rsi
;	lea esi, [mp_localint]
;	call os_print_string
;	pop rsi
;	inc dx
;	lodsd	; EAX now stores ???
;	lodsw	; AX now stores ???
;	lodsb	; AL now stores ???
;	jmp checktable

init_smp_mp_done:
	ret

; =============================================================================
; EOF
