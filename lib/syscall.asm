%include "sconst.inc"

INT_VECTOR_SYS_CALL equ 0x90
_NR_printx equ 0
_NR_sendrec equ 1

; 导出符号
global printx
global sendrec

bits 32
[section .text]

; -------------------------------------------------------------------------
; sendrec(int function, int src_dest, MESSAGE* msg);
; -------------------------------------------------------------------------

; Notice:Never call sendrec() directly, call send_recv() instead.

sendrec:
	push ebx	; .
	push ecx	;  > 12 bytes
	push edx	; /

	mov eax, _NR_sendrec
	mov ebx, [esp + 12 + 4]		; function
	mov ecx, [esp + 12 + 8]		; src_dest
	mov edx, [esp + 12 + 12]	; msg
	int INT_VECTOR_SYS_CALL

	pop edx
	pop ecx
	pop ebx

	ret		; 函数结束
; -------------------------------------------------------------------------

; -------------------------------------------------------------------------
; void printx(char* s);
; -------------------------------------------------------------------------
printx:
	push edx		; 4 bytes

	mov eax, _NR_printx
	mov edx, [esp + 4 + 4]	; s
	int INT_VECTOR_SYS_CALL

	pop edx

	ret		; 函数结束
; -------------------------------------------------------------------------
