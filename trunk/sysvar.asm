; =============================================================================
; Pure64 -- a 64-bit OS loader written in Assembly for x86-64 systems
; Copyright (C) 2008-2011 Return Infinity -- see LICENSE.TXT
;
; System Variables
; =============================================================================


;CPU
cpu_speed:		dw 0x0000	; MHz 
cpu_activated:		dw 0x0000	; Number of CPU cores activated
cpu_detected:		dw 0x0000	; Number of CPU cores detected

;MEM
mem_amount:		dw 0x0000	; MB

;HDD
hd1_enable:		db 0x00			; 1 if the drive is there and enabled
hd1_lba48:		db 0x00			; 1 if LBA48 is allowed
hd1_size:		dd 0x00000000		; size in MiB
hd1_maxlba:		dq 0x0000000000000000	; we need at least a 64-bit value since at most it will hold a 48-bit value
hdtempstring:		times 8 db 0

;MISC
screen_cols:		db 80
screen_rows:		db 25
hextable: 		db '0123456789ABCDEF'
screen_cursor_x:	db 0x00
screen_cursor_y:	db 0x00
screen_cursor_offset:	dq 0x0000000000000000
hdbuffer:		equ 0x0000000000070000	; 32768 bytes = 0x6000 -> 0xDFFF VERIFY THIS!!!
hdbuffer1:		equ 0x000000000007E000	; 512 bytes = 0xE000 -> 0xE1FF VERIFY THIS!!!
os_Counter:		equ 0x000000000000F900

;CONFIG
cfg_smpinit:		db 1	; By default SMP is enabled so set to 1
cfg_default:		db 0	; By default we don't need a config file so set to 0. If a config file is found set to 1.
cfg_e820:		db 1	; By default E820 should be present. Pure64 will set this to 0 if not found/usable.
cfg_mbr:		db 0	; Did we boot off of a disk with a proper MBR

;STRINGS
memtempstring:		times 6 db 0	; Max is "99999"
speedtempstring:	times 5 db 0	; Max is "9999"
cpu_amount_string:	times 4 db 0	; Max is "999"
kernelerror:		db 'FATAL ERROR: Software not found.', 0
kernelname:		db 'KERNEL64SYS', 0
configname:		db 'PURE64  CFG', 0
msg_done:		db ' Done', 0
msg_CPU:		db '[CPU: ', 0
msg_MEM:		db ']  [MEM: ', 0
msg_HDD:		db '  [HDD: ', 0
msg_mb:			db ' MiB]', 0
msg_mhz:		db 'MHz x', 0
msg_loadingkernel:	db 'Loading software...', 0
msg_startingkernel:	db 'Starting software.', 0
msg_noconfig:		db '(default config)', 0
no64msg:		db 'FATAL ERROR: CPU does not support 64-bit mode. Please run on supported hardware.', 0
initStartupMsg:		db 'Pure64 v0.4.9-dev - http://www.returninfinity.com', 13, 10, 13, 10, 'Initializing system...', 0
msg_date:		db '2011/03/10', 0

; Multi-processor variables
os_LocalAPICAddress:		dq 0x0000000000000000	; Default adddres for LAPIC
os_IOAPICAddress:		dq 0x0000000000000000	; Default address for IOAPIC

; Misc
os_ACPITableAddress:		dq 0x0000000000000000

; HDD variables
fat16_BytesPerSector:		dw 0x0000
fat16_SectorsPerCluster:	db 0x00
fat16_ReservedSectors:		dw 0x0000
fat16_FatStart:			dd 0x00000000
fat16_Fats:			db 0x00
fat16_SectorsPerFat:		dw 0x0000
fat16_TotalSectors:		dd 0x00000000
fat16_RootDirEnts:		dw 0x0000
fat16_DataStart:		dd 0x00000000
fat16_RootStart:		dd 0x00000000
fat16_PartitionOffset:		dd 0x00000000

; -----------------------------------------------------------------------------
align 16
GDTR64:					; Global Descriptors Table Register
	dw gdt64_end - gdt64 - 1	; limit of GDT (size minus one)
	dq 0x0000000000001000		; linear address of GDT

align 16
gdt64:					; This structure is copied to 0x0000000000001000
SYS64_NULL_SEL equ $-gdt64		; Null Segment
	dq 0x0000000000000000
SYS64_CODE_SEL equ $-gdt64		; Code segment, read/execute, nonconforming
	dq 0x0020980000000000		; 0x00209A0000000000
SYS64_DATA_SEL equ $-gdt64		; Data segment, read/write, expand down
	dq 0x0000900000000000		; 0x0020920000000000
gdt64_end:

align 16
IDTR64:					; Interrupt Descriptor Table Register
	dw 256*16-1			; limit of IDT (size minus one) (4096 bytes - 1)
	dq 0x0000000000000000		; linear address of IDT
; -----------------------------------------------------------------------------


; =============================================================================
; EOF
