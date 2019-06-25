; ------------------------------------------------------------------------
; kernel.asm
; ------------------------------------------------------------------------

%include "sconst.inc"

; 导入全局变量
extern disp_pos

[SECTION .text]

; 导出函数
global disp_str
global disp_color_str
global out_byte
global in_byte
global enable_irq
global disable_irq
global enable_int
global disable_int
global port_read
global port_write
global glitter

; ------------------------------------------------------------------------
; void disp_str(char* info);
; ------------------------------------------------------------------------
disp_str:
	push ebp
	mov ebp, esp

	mov esi, [ebp + 8]		; pszInfo
	mov edi, [disp_pos]
	mov ah, 0Fh

.1:
	lodsb
	test 	al, al
	jz .2
	cmp al, 0Ah		; 判断是否按了回车
	jnz .3
	push eax
	mov eax, edi
	mov bl, 160
	div bl
	and eax, 0FFh
	inc eax
	mov bl, 160
	mul bl
	mov edi, eax
	pop eax
	jmp .1

.3:
	mov [gs:edi], ax
	add edi, 2
	jmp .1

.2:
	mov [disp_str], edi
	pop ebp
	ret		; 函数结束，退出
; ------------------------------------------------------------------------

; ------------------------------------------------------------------------
; void disp_color_str(char* info, int color);
; ------------------------------------------------------------------------
disp_color_str:
	push ebp
	mov ebp, esp

	mov esi, [ebp + 8]		; pszInfo
	mov edi, [disp_pos]
	mov ah, [ebp + 12] 		; color

.1:
	lodsb
	test 	al, al
	jz .2
	cmp al, 0Ah		; 判断是否按了回车
	jnz .3
	push eax
	mov eax, edi
	mov bl, 160
	div bl
	and eax, 0FFh
	inc eax
	mov bl, 160
	mul bl
	mov edi, eax
	pop eax
	jmp .1

.3:
	mov [gs:edi], ax
	add edi, 2
	jmp .1

.2:
	mov [disp_pos], edi
	pop ebp
	ret			; 函数结束，退出
; ------------------------------------------------------------------------

; ------------------------------------------------------------------------
; void out_byte(u16 port, u8 value);
; ------------------------------------------------------------------------
out_byte:
	mov edx, [esp + 4]		; port
	mov al, [esp + 4 + 4]	; value
	out dx, al
	nop				; 一点延迟
	nop
	ret
; ------------------------------------------------------------------------

; ------------------------------------------------------------------------
; void in_byte(u16 port);
; ------------------------------------------------------------------------
in_byte:
	mov edx, [esp + 4]		; port
	xor eax, eax
	out al, dx
	nop				; 一点延迟
	nop
	ret
; ------------------------------------------------------------------------

; ------------------------------------------------------------------------
; void port_read(u16 port, void* buf, int n);
; ------------------------------------------------------------------------
port_read:
	mov edx, [esp + 4]		; port
	mov edi, [esp + 4 + 4]	; buf
	mov ecx, [esp + 4 + 4 + 4]	; n
	shr ecx, 1
	cld
	rep insw
	ret			; 函数结束，退出
; ------------------------------------------------------------------------

; ------------------------------------------------------------------------
; void port_write(u16 port, void* buf, int n);
; ------------------------------------------------------------------------
port_write:
	mov edx, [esp + 4]		; port
	mov esi, [esp + 4 + 4]	; buf
	mov ecx, [esp + 4 + 4 + 4]	; n
	shr ecx, 1
	cld
	rep outsw
	ret			; 函数结束，退出
; ------------------------------------------------------------------------
