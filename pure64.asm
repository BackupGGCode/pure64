; =============================================================================
; Pure64 -- a 64-bit OS loader written in Assembly for x86-64 systems
; Copyright (C) 2008-2011 Return Infinity -- see LICENSE.TXT
;
; Loaded from the first stage. Gather information about the system while
; in 16-bit mode (BIOS is still accessable), setup a minimal 64-bit
; enviroment, load the 64-bit kernel from the filesystem into memory and
; jump to it!
;
; Bytes
; 0    - 511   : 16-bit code (512 bytes)
; 512  - 1023  : 32-bit code (512 bytes)
; 1024 - 8191  : 64-bit code (7168 bytes)
; 8192 - 10239 : AP code (2048 bytes)
;
; =============================================================================


USE16
ORG 0x00008000

start16:
	cli				; Disable all interrupts
	xor eax, eax
	xor ebx, ebx
	xor ecx, ecx
	xor edx, edx
	xor esi, esi
	xor edi, edi
	xor ebp, ebp
	mov ds, ax
	mov es, ax
	mov ss, ax
	mov fs, ax
	mov gs, ax
	mov esp, 0x8000			; Set a known free location for the stack
	jmp 0x0000:clearcs
	
clearcs:

	mov ax, [0x07FE]		; MBR sector is copied to 0x0600
	cmp ax, 0xAA55			; Check if the word at 0x07FE is set to 0xAA55 (Boot sector marker)
	jne no_mbr
	mov byte [cfg_mbr], 1		; Set for booting from a disk with a MBR
no_mbr:

; Make sure the screen is set to 80x25 color text mode
	mov ax, 0x0003			; Set to normal (80x25 text) video mode
	int 0x10

; Hide the cursor
;	mov ax, 0x0100
;	mov cx, 0x200F
;	int 0x10

; Print message
	mov si, initStartupMsg
	call print_string_16
	
; Check to make sure the CPU supports 64-bit mode... If not then bail out
	mov eax, 0x80000000		; Extended-function 8000000h.
	cpuid				; Is largest extended function
	cmp eax, 0x80000000		; any function > 80000000h?
	jbe near no_long_mode		; If not, no long mode.
	mov eax, 0x80000001		; Extended-function 8000001h.
	cpuid				; Now EDX = extended-features flags.
	bt edx, 29			; Test if long mode is supported.
	jnc near no_long_mode		; Exit if not supported.

	call isa_setup			; Setup legacy hardware

; At this point we are done with real mode and BIOS interrupts. Jump to 32-bit mode.
	lgdt [cs:GDTR32]		; Load GDT register

	mov eax, cr0
	or al, 0x01			; Set protected mode bit
	mov cr0, eax

	jmp 8:start32			; Jump to 32-bit protected mode

; 16-bit Function to print a sting to the screen
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

; Display an error message that the CPU does not support 64-bit mode
no_long_mode:
	mov si, no64msg
	call print_string_16
	jmp $

%include "init_isa.asm"

align 16
GDTR32:					; Global Descriptors Table Register
dw gdt32_end - gdt32 - 1		; limit of GDT (size minus one)
dq gdt32				; linear address of GDT

align 16
gdt32:
dw 0x0000, 0x0000, 0x0000, 0x0000	; Null desciptor
dw 0xFFFF, 0x0000, 0x9A00, 0x00CF	; 32-bit code desciptor
dw 0xFFFF, 0x0000, 0x9200, 0x008F	; 32-bit data desciptor
gdt32_end:

; Pad the first part of Pure64 to 512 bytes.
times 512-($-$$) db 0x90


; =============================================================================
; 32-bit mode
USE32

start32:
	mov eax, 16			; load 4 GB data descriptor
	mov ds, ax			; to all data segment registers
	mov es, ax
	mov fs, ax
	mov gs, ax
	mov ss, ax
	xor eax, eax
	xor ebx, ebx
	xor ecx, ecx
	xor edx, edx
	xor esi, esi
	xor edi, edi
	xor ebp, ebp
	mov esp, 0x8000			; Set a known free location for the stack

; Debug
	mov al, '1'			; Now in 32-bit protected mode
	mov [0x000B809C], al
	mov al, '0'
	mov [0x000B809E], al

; Clear out the first 4096 bytes of memory. This will store the 64-bit IDT, GDT, PML4, and PDP
	mov ecx, 1024
	xor eax, eax
	mov edi, eax
	rep stosd

; Clear memory for the Page Descriptor Entries (0x10000 - 0x4FFFF)
	mov edi, 0x00010000
	mov ecx, 65536
	rep stosd

; Copy the GDT to its final location in memory
	mov esi, gdt64
	mov edi, 0x00001000		; GDT address
	mov ecx, (gdt64_end - gdt64)
	rep movsb			; Move it to final pos.

; Create the Level 4 Page Map. (Maps 4GBs of 2MB pages)
; First create a PML4 entry.
; PML4 is stored at 0x0000000000002000, create the first entry there
; A single PML4 entry can map 512GB with 2MB pages.
	cld
	mov edi, 0x00002000		; Create a PML4 entry for the first 4GB of RAM
	mov eax, 0x00003007
	stosd
	xor eax, eax
	stosd

	mov edi, 0x00002800		; Create a PML4 entry for higher half (starting at 0xFFFF800000000000)
	mov eax, 0x00003007		; The higher half is identity mapped to the lower half
	stosd
	xor eax, eax
	stosd

; Create the PDP entries.
; The first PDP is stored at 0x0000000000003000, create the first entries there
; A single PDP entry can map 1GB with 2MB pages
	mov ecx, 64			; number of PDPE's to make.. each PDPE maps 1GB of physical memory
	mov edi, 0x00003000
	mov eax, 0x00010007		; location of first PD
create_pdpe:
	stosd
	push eax
	xor eax, eax
	stosd
	pop eax
	add eax, 0x00001000		; 4K later (512 records x 8 bytes)
	dec ecx
	cmp ecx, 0
	jne create_pdpe

; Create the PD entries.
; PD entries are stored starting at 0x0000000000010000 and ending at 0x000000000004FFFF (256 KiB)
; This gives us room to map 64 GiB with 2 MiB pages
	mov edi, 0x00010000
	mov eax, 0x0000008F		; Bit 7 must be set to 1 as we have 2 MiB pages
	xor ecx, ecx
pd_again:				; Create a 2 MiB page
	stosd
	push eax
	xor eax, eax
	stosd
	pop eax
	add eax, 0x00200000
	inc ecx
	cmp ecx, 2048
	jne pd_again			; Create 2048 2 MiB page maps.

; Load the GDT
	lgdt [GDTR64]

; Enable physical-address extensions (set CR4.PAE=1)
	mov eax, cr4
	or eax, 0x000000020		; PAE (Bit 5)
	mov cr4, eax

; Point cr3 at PML4
	mov eax, 0x00002008		; Write-thru (Bit 3)
	mov cr3, eax

; Enable long mode (set EFER.LME=1)
	mov ecx, 0xC0000080		; EFER MSR number
	rdmsr				; Read EFER
	or eax, 0x00000100 		; LME (Bit 8)
	wrmsr				; Write EFER

; Debug
	mov al, '1'			; About to make the jump into 64-bit mode
	mov [0x000B809C], al
	mov al, 'E'
	mov [0x000B809E], al

; Enable paging to activate long mode (set CR0.PG=1)
	mov eax, cr0
	or eax, 0x80000000		; PG (Bit 31)
	mov cr0, eax

	jmp SYS64_CODE_SEL:start64	; Jump to 64-bit mode


; Pad the second part of Pure64 to 1024 bytes.
times 1024-($-$$) db 0x90


; =============================================================================
; 64-bit mode
USE64

start64:
; Debug
	mov al, '2'			; Now in 64-bit mode
	mov [0x000B809C], al
	mov al, '0'
	mov [0x000B809E], al

	mov al, 2
	mov ah, 22
	call os_move_cursor

	xor rax, rax			; aka r0
	xor rbx, rbx			; aka r3
	xor rcx, rcx			; aka r1
	xor rdx, rdx			; aka r2
	xor rsi, rsi			; aka r6
	xor rdi, rdi			; aka r7
	xor rbp, rbp			; aka r5
	mov rsp, 0x8000			; aka r4
	xor r8, r8
	xor r9, r9
	xor r10, r10
	xor r11, r11
	xor r12, r12
	xor r13, r13
	xor r14, r14
	xor r15, r15

	mov ds, ax			; Clear the legacy segment registers
	mov es, ax
	mov ss, ax
	mov fs, ax
	mov gs, ax

	mov rax, clearcs64		; Do a proper 64-bit jump. Should not be needed as the ...
	jmp rax				; ... jmp SYS64_CODE_SEL:start64 would have sent us ...
	nop				; .. out of compatibilty mode and into 64-bit mode
clearcs64:
	xor rax, rax

	lgdt [GDTR64]			; Reload the GDT

; Debug
	mov al, '2'
	mov [0x000B809C], al
	mov al, '2'
	mov [0x000B809E], al

; Build the rest of the page tables (4GiB+)
	mov rcx, 0x0000000000000000
	mov rax, 0x000000010000008F
	mov rdi, 0x0000000000014000
buildem:
	stosq
	add rax, 0x0000000000200000
	add rcx, 1
	cmp rcx, 30720			; Another 60 GiB (We already mapped 4 GiB)
	jne buildem
	; We have 64 GiB mapped now

; Build a temporary IDT
	xor rdi, rdi 			; create the 64-bit IDT (at linear address 0x0000000000000000)

	mov rcx, 32
make_exception_gates: 			; make gates for exception handlers
	mov rax, exception_gate
	push rax			; save the exception gate to the stack for later use
	stosw				; store the low word (15..0) of the address
	mov ax, SYS64_CODE_SEL
	stosw				; store the segment selector
	mov ax, 0x8E00
	stosw				; store exception gate marker
	pop rax				; get the exception gate back
	shr rax, 16
	stosw				; store the high word (31..16) of the address
	shr rax, 16
	stosd				; store the extra high dword (63..32) of the address.
	xor rax, rax
	stosd				; reserved
	dec rcx
	jnz make_exception_gates

	mov rcx, 256-32
make_interrupt_gates: 			; make gates for the other interrupts
	mov rax, interrupt_gate
	push rax			; save the interrupt gate to the stack for later use
	stosw				; store the low word (15..0) of the address
	mov ax, SYS64_CODE_SEL
	stosw				; store the segment selector
	mov ax, 0x8F00
	stosw				; store interrupt gate marker
	pop rax				; get the interrupt gate back
	shr rax, 16
	stosw				; store the high word (31..16) of the address
	shr rax, 16
	stosd				; store the extra high dword (63..32) of the address.
	xor rax, rax
	stosd				; reserved
	dec rcx
	jnz make_interrupt_gates

	; Set up the exception gates for all of the CPU exceptions
	; The following code will be seriously busted if the exception gates are moved above 16MB
	mov word [0x00*16], exception_gate_00
	mov word [0x01*16], exception_gate_01
	mov word [0x02*16], exception_gate_02
	mov word [0x03*16], exception_gate_03
	mov word [0x04*16], exception_gate_04
	mov word [0x05*16], exception_gate_05
	mov word [0x06*16], exception_gate_06
	mov word [0x07*16], exception_gate_07
	mov word [0x08*16], exception_gate_08
	mov word [0x09*16], exception_gate_09
	mov word [0x0A*16], exception_gate_10
	mov word [0x0B*16], exception_gate_11
	mov word [0x0C*16], exception_gate_12
	mov word [0x0D*16], exception_gate_13
	mov word [0x0E*16], exception_gate_14
	mov word [0x0F*16], exception_gate_15
	mov word [0x10*16], exception_gate_16
	mov word [0x11*16], exception_gate_17
	mov word [0x12*16], exception_gate_18
	mov word [0x13*16], exception_gate_19

	mov rdi, 0x20			; Set up Timer IRQ handler
	mov rax, timer
	call create_gate

	lidt [IDTR64]			; load IDT register

; Debug
	mov al, '2'
	mov [0x000B809C], al
	mov al, '4'
	mov [0x000B809E], al

; Clear memory 0xf000 - 0xf7ff for the infomap (2048 bytes)
	xor rax, rax
	mov rcx, 256
	mov rdi, 0x000000000000F000
clearmapnext:
	stosq
	dec rcx
	cmp rcx, 0
	jne clearmapnext

	call init_cpu			; Setup CPU

; Debug
	mov al, '2'			; CPU Init complete
	mov [0x000B809C], al
	mov al, '6'
	mov [0x000B809E], al

; Make sure exceptions are working.
;	xor rax, rax
;	xor rbx, rbx
;	xor rcx, rcx
;	xor rdx, rdx
;	div rax

	call hdd_setup			; Gather Hard Drive information

; Debug
	mov al, '2'			; HDD Init complete
	mov [0x000B809C], al
	mov al, '8'
	mov [0x000B809E], al

; Find init64.cfg
;	mov rbx, configname
;	call findfile
;	cmp rbx, 0
;	je near noconfig		; If the config file was not found we just use the default settings.
	mov al, 1
	mov byte [cfg_default], al	; We have a config file

; Read in the first cluster of init64.cfg
;	mov rdi, 0x0000000000100000
;	call readcluster

; Parse init64.cfg
; Get Kernel name
; get SMP setting

; noconfig:

; Init of SMP
	call smp_setup
	
; Reset the stack to the proper location (was set to 0x8000 previously)
	mov rsi, [os_LocalAPICAddress]	; We would call os_smp_get_id here but the stack is not ...
	add rsi, 0x20			; ... yet defined. It is safer to find the value directly.
	lodsd				; Load a 32-bit value. We only want the high 8 bits
	shr rax, 24			; Shift to the right and AL now holds the CPU's APIC ID
	shl rax, 10			; shift left 10 bits for a 1024byte stack
	add rax, 0x0000000000050400	; stacks decrement when you "push", start at 1024 bytes in
	mov rsp, rax			; Pure64 leaves 0x50000-0x9FFFF free so we use that

; Debug
	mov al, '3'			; SMP Init complete
	mov [0x000B809C], al
	mov al, 'E'
	mov [0x000B809E], al

; Calculate amount of usable RAM from Memory Map
	xor rcx, rcx
	mov rsi, 0x0000000000004000	; E820 Map location
readnextrecord:
	lodsq
	lodsq
	lodsd
	cmp eax, 0	; Are we at the end?
	je endmemcalc
	cmp eax, 1	; Usuable RAM
	je goodmem
	cmp eax, 3	; ACPI Reclaimable
	je goodmem
	cmp eax, 6	; BIOS Reclaimable
	je goodmem
	lodsd
	lodsq
	jmp readnextrecord
goodmem:
	sub rsi, 12
	lodsq
	add rcx, rax
	lodsq
	lodsq
	jmp readnextrecord

endmemcalc:
	shr rcx, 20		; Value is in bytes so do a quick divide by 1048576 to get MiB's
	add cx, 1		; The BIOS will usually report actual memory minus 1
	and cx, 0xFFFE		; Make sure it is an even number (in case we added 1 to an even number)
	mov word [mem_amount], cx


	mov rdi, speedtempstring
	call os_int_to_string

; Convert CPU amount value to string
	xor rax, rax
	mov ax, [cpu_activated]
	mov rdi, cpu_amount_string
	call os_int_to_string

; Convert RAM amount value to string
	xor rax, rax
	mov ax, [mem_amount]
	mov rdi, memtempstring
	call os_int_to_string

; Build the infomap
	mov rdi, 0x0000000000005000
	mov rax, [os_LocalAPICAddress]
	stosq
	mov rax, [os_IOAPICAddress]
	stosq

	mov rdi, 0x0000000000005010
	mov ax, [cpu_speed]
	stosw
	mov ax, [cpu_activated]
	stosw
	mov ax, [cpu_detected]
	stosw

	mov rdi, 0x0000000000005020
	mov ax, [mem_amount]
	stosw

	mov rdi, 0x0000000000005030
	mov al, [cfg_mbr]
	stosb

	mov rdi, 0x0000000000005040
	mov rax, [os_ACPITableAddress]
	stosq

; Initialization is now complete... write a message to the screen
	mov rsi, msg_done
	call os_print_string

; Write an extra message if we are using the default config
	cmp byte [cfg_default], 1
	je nodefaultconfig
	mov al, 2
	mov ah, 28
	call os_move_cursor
	mov rsi, msg_noconfig
	call os_print_string
nodefaultconfig:

; Print info on CPU, MEM, and HD
	mov ax, 0x0004
	call os_move_cursor
	mov rsi, msg_CPU
	call os_print_string
	mov rsi, speedtempstring
	call os_print_string
	mov rsi, msg_mhz
	call os_print_string
	mov rsi, cpu_amount_string
	call os_print_string

	mov rsi, msg_MEM
	call os_print_string
	mov rsi, memtempstring
	call os_print_string
	mov rsi, msg_mb
	call os_print_string

	mov rsi, msg_HDD
	call os_print_string
	mov rsi, hdtempstring
	call os_print_string
	mov rsi, msg_mb
	call os_print_string

; =============================================================================
; Chainload the kernel attached to the end of the pure64.sys binary
; Windows - copy /b pure64.sys + kernel64.sys
; Unix - cat pure64.sys kernel64.sys > pure64.sys
; Max size of the resulting pure64.sys is 28672 bytes
; Uncomment the following 5 lines if you are chainloading
;	mov rsi, 0x8000+10240	; Memory offset to end of pure64.sys
;	mov rdi, 0x100000	; Destination address at the 1MiB mark
;	mov rcx, 0x800		; For a 16KiB kernel (2048 x 8)
;	rep movsq		; Copy 8 bytes at a time
;	jmp fini		; Print starting message and jump to kernel
; =============================================================================	

; Print a message that the kernel is being loaded
	mov ax, 0x0006
	call os_move_cursor
	mov rsi, msg_loadingkernel
	call os_print_string

; Find the kernel file
	mov rsi, kernelname
	call findfile
	cmp ax, 0x0000
	je near nokernel

; Load 64-bit kernel from drive to 0x0000000000010000
	mov rdi, 0x0000000000100000
readfile_getdata:
;	push rax
;	mov al, '.'		; Show loading progress
;	call os_print_char
;	pop rax
	call readcluster	; store in memory
	cmp ax, 0xFFFF		; Value for end of cluster chain.
	jne readfile_getdata	; Are there more clusters? If so then read again.. if not fall through.

; Print a message that the kernel has been loaded
	mov rsi, msg_done
	call os_print_string

fini:	; For chainloading

; Print a message that the kernel is being started
	mov ax, 0x0008
	call os_move_cursor
	mov rsi, msg_startingkernel
	call os_print_string

; Debug
	mov al, ' '			; Clear the debug messages
	mov [0x000B809A], al
	mov [0x000B809C], al
	mov [0x000B809E], al

; Clear all registers (skip the stack pointer)
	xor rax, rax			; aka r0
	xor rbx, rbx			; aka r3
	xor rcx, rcx			; aka r1
	xor rdx, rdx			; aka r2
	xor rsi, rsi			; aka r6
	xor rdi, rdi			; aka r7
	xor rbp, rbp			; aka r5
	xor r8, r8
	xor r9, r9
	xor r10, r10
	xor r11, r11
	xor r12, r12
	xor r13, r13
	xor r14, r14
	xor r15, r15

	jmp 0x0000000000100000	; Jump to the kernel

nokernel:
	mov al, 6
	mov ah, 0
	call os_move_cursor
	mov rsi, kernelerror
	call os_print_string
	jmp $

%include "syscalls.asm"
%include "init_cpu.asm"
%include "init_hdd.asm"
%include "fat16.asm"
%include "init_smp.asm"
%include "interrupt.asm"
%include "sysvar.asm"

; Pad the third part of Pure64 to 8192 bytes.
times 8192-($-$$) db 0x90

; AP init code is on a 4K boundry (0x0000A000)
%include "init_smp_ap.asm"

; Padding so we get an even KB file (10KB)
times 10240-($-$$) db 0x90


; =============================================================================
; EOF