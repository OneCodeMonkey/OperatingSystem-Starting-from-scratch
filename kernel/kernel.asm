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
