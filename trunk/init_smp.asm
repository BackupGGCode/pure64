; =============================================================================
; Pure64 -- a 64-bit OS loader written in Assembly for x86-64 systems
; Copyright (C) 2008-2011 Return Infinity -- see LICENSE.TXT
;
; INIT SMP
; =============================================================================


smp_setup:
	mov al, '5'			; Start of MP init
	mov [0x000B809C], al
	mov al, '0'
	mov [0x000B809E], al
;	mov al, 'S'
;	call serial_send_64

; Step 1: Get APIC Information via ACPI
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

	mov al, '5'			; ACPI tables detected
	mov [0x000B809C], al
	mov al, '2'
	mov [0x000B809E], al

foundACPI:
	call init_smp_acpi 

	mov al, '5'			; ACPI tables parsed
	mov [0x000B809C], al
	mov al, '6'
	mov [0x000B809E], al

; Step 2: Enable Local APIC on BSP
	mov rsi, [os_LocalAPICAddress]
	cmp rsi, 0x00000000
	je noMP				; Skip MP init if we didn't get a valid LAPIC address
	
;	mov ecx, 0x0000001B		; IA32_APIC_BASE MSR
;	rdmsr				; Test bit 11
;	call os_debug_dump_eax

	mov eax, dword [rsi+0x80]	; Task Priority Register (TPR)
	mov al, 0			; Clear Task Priority (bits 7:4) and Task Priority Sub-Class (bits 3:0)
	mov dword [rsi+0x80], eax

	mov eax, dword [rsi+0xE0]	; Destination Format Register
	or eax, 0xF0000000		; Set bits 31-28 for Flat Mode
	mov dword [rsi+0xE0], eax

	mov eax, dword [rsi+0xF0]	; Spurious Interrupt Register
	mov al, 0xF8
	bts eax, 8			; Enable APIC (Set bit 8)
	bts eax, 12			;bit12: EOI-Broadcast Suppression (0==Enabled, 1== Disabled)
	bts eax, 9			;bit9: Focus Processor Checking (0==Enabled 1==Disabled)
	mov dword [rsi+0xF0], eax

	mov eax, dword [rsi+0x320]	; LVT Timer Register
	bts eax, 16			;bit16:Mask interrupts (0==Unmasked, 1== Masked)
	mov dword [rsi+0x320], eax

	mov eax, dword [rsi+0x350]	; LVT LINT0 Register
	mov al, 0			;Set interrupt vector (bits 7:0)
	bts eax, 8			;Delivery Mode (111b==ExtlNT] (bits 10:8)
	bts eax, 9
	bts eax, 10
	bts eax, 15			;bit15:Set trigger mode to Level (0== Edge, 1== Level)  
	btr eax, 16			;bit16:unmask interrupts (0==Unmasked, 1== Masked)
	mov dword [rsi+0x350], eax

	mov eax, dword [rsi+0x360]	; LVT LINT1 Register
	mov al, 0			;Set interrupt vector (bits 7:0)
	bts eax, 8			;Delivery Mode (111b==ExtlNT] (bits 10:8)
	bts eax, 9
	bts eax, 10
	bts eax, 15			;bit15:Set trigger mode to Edge (0== Edge, 1== Level)
	btr eax, 16			;bit16:unmask interrupts (0==Unmasked, 1== Masked)
	mov dword [rsi+0x360], eax

	mov eax, dword [rsi+0x370]	; LVT Error Register
	mov al, 0			;Set interrupt vector (bits 7:0)
	bts eax, 16			;bit16:Mask interrupts (0==Unmasked, 1== Masked)
	mov dword [rsi+0x370], eax

; Step 3: Prepare the I/O APIC
	xor eax, eax
	mov rcx, 1			; Register 1 - IOAPIC VERSION REGISTER
	call ioapic_reg_read
	shr eax, 16			; Extract bytes 16-23 (Maximum Redirection Entry)
	and eax, 0xFF			; Clear bits 16-31
	add eax, 1
	mov rcx, rax
	xor rax, rax
	bts rax, 16			; Interrupt Mask Enabled
initentry:				; Initialize all entries 1:1
	dec rcx
	call ioapic_entry_write
	cmp rcx, 0
	jne initentry

	; Enable the Timer
	mov rcx, 2
	mov rax, 0x20
	call ioapic_entry_write

	; Enable the RTC
	mov rcx, 8			; IRQ value
	mov rax, 0x28			; Interrupt value
	call ioapic_entry_write

	sti				; Enable interrupts
jmp $
; Check if we want the AP's to be enabled.. if not then skip to end
;	cmp byte [cfg_smpinit], 1	; Check if SMP should be enabled
;	jne noMP			; If not then skip SMP init

; Step 4: Start the AP's one by one
	xor eax, eax
	xor ecx, ecx
	xor edx, edx
	mov rsi, [os_LocalAPICAddress]
	add rsi, 0x20		; Add the offset for the APIC ID location
	lodsd			; APIC ID is stored in bits 31:24
	shr rax, 24		; AL now holds the BSP CPU's APIC ID
	mov dl, al		; Store BSP APIC ID in DL
	mov rsi, 0x0000000000005800
	xor eax, eax

	mov al, '5'		; Start the AP's
	mov [0x000B809C], al
	mov al, '8'
	mov [0x000B809E], al

smp_send_INIT:
	cmp rsi, 0x0000000000005900
	je smp_send_INIT_done
	lodsb
	cmp al, 1		; Is it enabled?
	jne smp_send_INIT_skipcore

;	push rax		; Debug - display APIC ID
;	mov al, cl
;	add al, 48
;	call os_print_char
;	call serial_send_64
;	pop rax

	cmp cl, dl		; Is it the BSP?
	je smp_send_INIT_skipcore

	; Broadcast 'INIT' IPI to APIC ID in AL
	mov al, cl
	shl eax, 24
	mov rdi, [os_LocalAPICAddress]
	add rdi, 0x310
	stosd
	mov eax, 0x00004500
	mov rdi, [os_LocalAPICAddress]
	add rdi, 0x300
	stosd
	push rsi
smp_send_INIT_verify:
	mov rsi, [os_LocalAPICAddress]
	add rsi, 0x300
	lodsd
	bt eax, 12			; Verify that the command completed
	jc smp_send_INIT_verify
	pop rsi

smp_send_INIT_skipcore:
	inc cl
	jmp smp_send_INIT	

smp_send_INIT_done:

	mov rax, [os_Counter_RTC]
	add rax, 10
wait1:
	mov rbx, [os_Counter_RTC]
	cmp rax, rbx
	jg wait1
;	mov al, 'i'
;	call serial_send_64

	mov rsi, 0x0000000000005800
	xor ecx, ecx
smp_send_SIPI:
	cmp rsi, 0x0000000000005900
	je smp_send_SIPI_done
	lodsb
	cmp al, 1		; Is it enabled?
	jne smp_send_SIPI_skipcore

;	push rax		; Debug - display APIC ID
;	mov al, cl
;	add al, 48
;	call os_print_char
;	call serial_send_64
;	pop rax

	cmp cl, dl		; Is it the BSP?
	je smp_send_SIPI_skipcore

	; Broadcast 'Startup' IPI to destination using vector 0x08 to specify entry-point is at the memory-address 0x00008000
	mov al, cl
	shl eax, 24
	mov rdi, [os_LocalAPICAddress]
	add rdi, 0x310
	stosd
	mov eax, 0x00004608		; Vector 0x08
	mov rdi, [os_LocalAPICAddress]
	add rdi, 0x300
	stosd
	push rsi
smp_send_SIPI_verify:
	mov rsi, [os_LocalAPICAddress]
	add rsi, 0x300
	lodsd
	bt eax, 12			; Verify that the command completed
	jc smp_send_SIPI_verify
	pop rsi

smp_send_SIPI_skipcore:
	inc cl
	jmp smp_send_SIPI	

smp_send_SIPI_done:

	mov al, '5'
	mov [0x000B809C], al
	mov al, 'A'
	mov [0x000B809E], al
;	mov al, 'S'
;	call serial_send_64	

; Let things settle (Give the AP's some time to finish)
	mov rax, [os_Counter_RTC]
	add rax, 10
wait3:
	mov rbx, [os_Counter_RTC]
	cmp rax, rbx
	jg wait3

; Step 5: Finish up
noMP:
	lock
	inc word [cpu_activated]	; BSP adds one here

	xor eax, eax
	mov rsi, [os_LocalAPICAddress]
	add rsi, 0x20			; Add the offset for the APIC ID location
	lodsd				; APIC ID is stored in bits 31:24
	shr rax, 24			; AL now holds the CPU's APIC ID (0 - 255)
	mov rdi, 0x00005700		; The location where the cpu values are stored
	add rdi, rax			; RDI points to infomap CPU area + APIC ID. ex F701 would be APIC ID 1
	mov al, 3			; This is the BSP so bits 0 and 1 are set
	stosb

	mov al, '5'
	mov [0x000B809C], al
	mov al, 'C'
	mov [0x000B809E], al

; Calculate speed of CPU (At this point the RTC is firing at 1024Hz)
	cpuid
	xor edx, edx
	xor eax, eax
	mov rcx, [os_Counter_RTC]
	add rcx, 10
	rdtsc
	push rax
speedtest:
	mov rbx, [os_Counter_RTC]
	cmp rbx, rcx
	jl speedtest
	rdtsc
	pop rdx
	sub rax, rdx
	xor edx, edx
	mov rcx, 10240
	div rcx
	mov [cpu_speed], ax

	mov al, '5'
	mov [0x000B809C], al
	mov al, 'E'
	mov [0x000B809E], al
	
	cli				; Disable Interrupts

ret


; -----------------------------------------------------------------------------
; ioapic_reg_write -- Write to an I/O APIC register
;  IN:	EAX = Value to write
;	ECX = Index of register 
; OUT:	Nothing. All registers preserved
ioapic_reg_write:
	push rsi
	mov rsi, [os_IOAPICAddress]
	mov dword [rsi], ecx		; Write index to register selector
	mov dword [rsi + 0x10], eax	; Write data to window register
	pop rsi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; ioapic_reg_read -- Read from an I/O APIC register
;  IN:	ECX = Index of register 
; OUT:	EAX = Value of register
;	All other registers preserved
ioapic_reg_read:
	push rsi
	mov rsi, [os_IOAPICAddress]
	mov dword [rsi], ecx		; Write index to register selector
	mov eax, dword [rsi + 0x10]	; Read data from window register
	pop rsi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; ioapic_entry_write -- Write to an I/O APIC entry in the redirection table
;  IN:	RAX = Data to write to entry
;	ECX = Index of the entry
; OUT:	Nothing. All registers preserved
ioapic_entry_write:
	push rax
	push rcx

	; Calculate index for lower DWORD
	shl rcx, 1				; Quick multiply by 2
	add rcx, 0x10				; IO Redirection tables start at 0x10

	; Write lower DWORD
	call ioapic_reg_write

	; Write higher DWORD
	shr rax, 32
	add rcx, 1
	call ioapic_reg_write

	pop rcx
	pop rax
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; ioapic_entry_read -- Read an I/O APIC entry from the redirection table
;  IN:	ECX = Index of the entry
; OUT:	RAX = Data that was read
;	All other registers preserved
ioapic_entry_read:
	push rbx
	push rcx

	; Calculate index for lower DWORD
	shl rcx, 1				; Quick multiply by 2
	add rcx, 0x10				; IO Redirection tables start at 0x10

	; Read lower DWORD
	call ioapic_reg_read
	mov rbx, rax

	; Read higher DWORD
	add rcx, 1
	call ioapic_reg_read

	; Combine
	shr rax, 32
	or rbx, rax
	xchg rbx, rax

	pop rcx
	pop rbx
	ret
; -----------------------------------------------------------------------------


%include "init_smp_acpi.asm"


; =============================================================================
; EOF
