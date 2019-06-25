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

; ------------------------------------------------------------------------
; void disable_irq(int irq);
; ------------------------------------------------------------------------
; Disable an interrupt request line by setting an 8259 bit.
; Equivalent code:
;     if(irq < 8) {
;		  out_byte(INT_M_CTLMASK, in_byte(INT_M_CTLMASK) | (1 << irq));	
;	  } else {
;		  out_byte(INT_S_CTLMASK, in_byte(INT_S_CTLMASK) | (1 << irq));
;	  }
; ------------------------------------------------------------------------

disable_irq:
	mov ecx, [esp + 4]		; irq
	pushf
	cli
	mov ah, 1
	rol ah, cl 			; ah = (1 << (irq % 8))
	cmp cl, 8
	jae disable_8		; disable irq >= 8 at the slave 8259

disable_0:
	in al, INT_M_CTLMASK
	test al, ah
	jnz dis_already		; already disabled?
	or al, ah
	out INT_M_CTLMASK, al 	; set bit at master 8259
	popf
	mov eax, 1			; disabled by this function
	ret 		; return

disable_8:
	int al, INT_S_CTLMASK
	test al, ah
	jnz dis_already		; already disabled?
	or al, ah
	out INT_S_CTLMASK, al 	; set bit at slave 8259
	popf
	mov eax, 1			; disabled by this function
	ret 		; return

dis_already:
	popf
	xor eax, eax 		; already disabled
	ret 		; return
; ------------------------------------------------------------------------

; ------------------------------------------------------------------------
; void enable_irq(int irq)
; ------------------------------------------------------------------------
; Enable an interrupt request line by clearing an 8259 bit.
; Equivalent code:
;     if(irq < 8) {
;		  out_byte(INT_M_CTLMASK, in_byte(INT_M_CTLMASK) | ~(1 << irq));	
;	  } else {
;		  out_byte(INT_S_CTLMASK, in_byte(INT_S_CTLMASK) | ~(1 << irq));
;	  }
; ------------------------------------------------------------------------

enable_irq:
	mov ecx, [esp + 4]		; irq
	pushf
	cli
	mov ah, ~1
	rol ah, cl 			; ah = (1 << (irq % 8))
	cmp cl, 8
	jae enable_8		; enable irq >= 8 at the slave 8259

enable_0:
	in al, INT_M_CTLMASK
	and al, ah
	out INT_M_CTLMASK, al 	; clear bit at master 8259
	popf
	ret 	; return

enable_8:
	in al, INT_S_CTLMASK
	and al, ah
	out INT_S_CTLMASK, al 	; clear bit at slave 8259
	popf
	ret 	; return
; ------------------------------------------------------------------------

; ------------------------------------------------------------------------
; void disable_int();
; ------------------------------------------------------------------------
disable_int:
	cli
	ret
; ------------------------------------------------------------------------

; ------------------------------------------------------------------------
; void enable_int();
; ------------------------------------------------------------------------
enable_int:
	sti
	ret
; ------------------------------------------------------------------------

; ------------------------------------------------------------------------
; void glitter(int row, int col);
; ------------------------------------------------------------------------
glitter:
	push eax
	push ebx
	push edx

	mov eax, [.current_char]
	inc eax
	cmp eax, .strlen
	je .1
	jmp .2

.1:
	xor eax, eax

.2:
	mov [.current_char], eax
	mov dl, byte [eax + .glitter_str]	; todo check [] need to closer ?

	xor eax, eax
	mov al, [esp + 16]		; row
	mov bl, .line_width
	mul bl				; ax <- row * 80
	mov bx, [esp + 20]	; col
	add ax, bx
	shl ax, 1
	movzx eax, ax

	mov [gs:eax], dl

	inc eax
	mov byte [gs:eax], 4

	jmp .end

.current_char: dd 0
.glitter_str: db '-\|/'
		db '1234567890'
		db 'abcdefghijklmnopqrstuvwxyz'
		db 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
.strlen equ $ - .glitter_str
.line_width equ 80

.end:
	pop edx
	pop ebx
	pop eax
	ret 	; return
; ------------------------------------------------------------------------

