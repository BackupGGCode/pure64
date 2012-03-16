; =============================================================================
; Pure64 -- a 64-bit OS loader written in Assembly for x86-64 systems
; Copyright (C) 2008-2012 Return Infinity -- see LICENSE.TXT
;
; INIT HPET
; =============================================================================

; Search the web for 'Intel_HPET_Specification.pdf' for config doc
; This code only enables Timer 0 to replace the legacy Timer
; Timer 1 should be left disabled as to not interfere with the RTC

init_hpet:
; the first HPET chip should be at 0xFED00000
	mov rsi, [os_HPETAddress]
	cmp rsi, 0
	je noHPET

	mov rax, [rsi+0x10]		; General Configuration Register
	call os_print_newline
	call os_debug_dump_rax
	btc rax, 0			; ENABLE_CNF - Disable the HPET
	btc rax, 1			; LEG_RT_CNF - Disable legacy routing
	mov [rsi+0x10], rax

	xor eax, eax
	mov [rsi+0xF0], rax		; Clear the Main Counter Register
	
	; Configure and enable Timer 0 (n = 0)
	mov rax, [rsi+0x100]
	xor eax, eax
	bts rax, 1			; Tn_INT_TYPE_CNF - Interrupt Type Level
	bts rax, 2			; Tn_INT_ENB_CNF - Interrupt Enable
	bts rax, 3			; Tn_TYPE_CNF - Periodic Enable
	bts rax, 6			; Tn_VAL_SET_CNF
	mov [rsi+0x100], rax
	xor eax, eax
	mov [rsi+0x108], rax		; Clear the Timer 0 Comparator Register
	
;	mov rax, [rsi+0x10]		; General Configuration Register
;	bts rax, 0			; ENABLE_CNF - Enable the HPET
;	bts rax, 1			; LEG_RT_CNF - Enable legacy routing
;	mov [rsi+0x10], rax

noHPET:
	ret


; =============================================================================
; EOF
