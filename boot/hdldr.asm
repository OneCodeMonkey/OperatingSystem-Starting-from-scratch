; ------------------------------------------------------------------------
; boot/hdldr.asm
; ------------------------------------------------------------------------
org 0100h
	jmp LABEL_START			; Start

%include "load.inc"
%include "pm.inc"

TRANS_SECT_NR equ 2
SECT_BUF_SIZE equ TRANS_SECT_NR * 512

disk_address_packet: db 0x10		; [0] Packet size in bytes. Must be 0x10 or greater

					 db 0 			; [1] Reserved, must be 0.
sect_cnt:			 db TRANS_SECT_NR	; [2] Number of blocks to transfer.
					 db 0			; [3] Reserved, must be 0.
					 dw KERNEL_FILE_OFF ; [4] Address of transfer buffer. Offset
					 dw KERNEL_FILE_SEG	; [6] Address of transfer buffer. Seg
lba_addr:			 dd 0			; [8] Starting LBA address, Low 32-bits
					 dd 0 			; [12] Starting LBA address, High 32-bits.

; GDT --------------------------------------------------------------------
;								段基址	段界限	属性
LABEL_GDT:	Descriptor			0,		0,		0		; 空描述符
LABEL_DESC_FLAT_C: Descriptor	0,		0fffffh DA_CR | DA_32 | DA_LIMIT_4K	; 0 - 4G
LABEL_DESC_FLAT_RW: Descriptor 	0,		0fffffh	DA_DRW | DA_32 | DA_LIMIT_4K ; 0 - 4G
LABEL_DESC_VIDEO: Descriptor	0B8000h,0ffffh,	DA_DRW | DA_DPL3	; 显存首地址
; GDT --------------------------------------------------------------------

GdtLen equ $ - LABEL_GDT
GdtPtr dw GdtLen - 1		; 段界限
dd LOADER_PHY_ADDR + LABEL_GDT		; 基地址（让基地址8字节对齐，将起到优化速度的效果，暂未优化）

; The GDT is not a segment itself; instead, it is a data structure in linear address space.
; The base linear address and limit of the GDT must be loaded into the GDTR register. -- IA-32 Software Developer's Manual, Vol.3A


; GDT 选择子---------------------------------------------------------------
SelectorFlatC equ LABEL_DESC_FLAT_C 	- LABEL_GDT
SelectorFlatRW equ LABEL_DESC_FLAT_RW 	- LABEL_GDT
SelectroVideo equ LABEL_DESC_VIDEO		- LABEL_GDT + SA_RPL3
; GDT 选择子---------------------------------------------------------------


BaseOfStack equ 0100h

err:
	mov dh, 5			; "Error 0  "
	call real_mode_disp_str		; display the string
	jmp $
LABEL_START:			; <--- 从这里开始 ----------
	mov ax, cs
	mov ds, ax
	mov es, ax
	mov ss, ax
	mov sp, BaseOfStack

	mov dh, 0			; "Loading "
	call real_mode_disp_str	; 显示字符串

	; 得到内存数
	mov ebx, 0			; ebx = 后续值，开始时需要为0
	mov di, _MemChkBuf	; es:di 指向一个地址范围描述符结构（Address Range Descriptor Structure）

.MemChkLoop:
	mov eax, 0E820h		; eax = 0000E820h
	mov ecx, 20			; ecx = 地址范围描述符结构的大小
	mov edx, 0534D4150h	; edx = 'SMAP'
	int 15h				; int 15h
	jc .MemChkFail
	add di, 20
	inc dword [_dwMCRNumber]	; dwMCRNumber = ARDS 的个数
	cmp ebx, 0
	jne .MemChkLoop
	jmp .MemChkOK

.MemChkFail:
	mov dword [_dwMCRNumber], 0

.MemChkOK:
	; get the sector nr of '/'(ROOT_INODE), it'll be stored in eax
	mov eax, [fs:SB_ROOT_INODE]		; fs -> super_block (see hdboot.asm)
	call get_inode

	; read '/' into es:bx
	mov dword [disk_address_packet + 8], eax
	call read_sector

	; let's search '/' for the kernel
	mov si, KernelFileName
	push bx							; <- save

.str_cmp:
	; before comparation:
	; 	 	es:bx -> dir_entry @ disk
	;		ds:si -> filename we want
	add bx, [fs:SB_DIR_ENT_FNAME_OFF]

.1:
	lodsb				; ds:si -> al
	cmp al, byte[es:bx]
	jz .2
	jmp .different		; oops
.2:
	cmp al, 0			; both arrive at a '\0', match
	jz .found
	inc bx				; next char @ disk
	jmp .1				; on and on

.different:
	pop bx 		; -> restore
	add bx, [fs:SB_DIR_ENT_SIZE]
	sub ecx, [fs:SB_DIR_ENT_SIZE]
	jz .not_found
	push bx
	mov si, KernelFileName
	jmp .str_cmp
.not_found:
	mov dh, 3
	call real_mode_disp_str
	jmp $
.found:
	pop bx
	add bx, [fs:SB_DIR_ENT_INODE_OFF]
	mov eax, [es:bx]		; eax <- inode nr of kernel
	call get_inode			; eax <- start sector nr of kernel
	mov dword [disk_address_packet + 8], eax
load_kernel:
	call read_sector
	cmp ecx, SECT_BUF_SIZE
	jl .done
	sub ecx, SECT_BUF_SIZE 	; bytes_left -= SECT_BUF_SIZE
	add word [disk_address_packet + 4], SECT_BUF_SIZE		; transfer buffer
	jc .1
	jmp .2

.1:
	add word [disk_address_packet + 6], 1000h

.2:
	add dword [disk_address_packet + 8], TRANS_SECT_NR	; LBA
	jmp load_kernel

.done:
	mov dh, 2
	call real_mode_disp_str

; ------------------------------------------------------------------------
; 下面准备跳入保护模式
; ------------------------------------------------------------------------
; 加载 GDTR
lgdt [GdtPtr]

; 关闭中断
cli

; 打开地址线 A20
in al, 92h
or al, 00000010b
out 92h, al

; 准备切换到保护模式
mov eax, cr0
or eax, 1
mov cr0, eax

; 真正进入保护模式
jmp dword SelectorFlatC:(LOADER_PHY_ADDR+LABEL_PM_START)
jmp $				; never arrive here

; ------------------------------------------------------------------------

; ------------------------------------------------------------------------
; variables
; ------------------------------------------------------------------------
wSectorNo dw 0			; 要读取的扇区号
bOdd db 0				; 奇数还是偶数
dwKernelSize dd 0		; KERNEL.BIN 文件大小


; ------------------------------------------------------------------------
; 字符串
; ------------------------------------------------------------------------
KernelFileName db "kernel.bin", 0		; KERNEL.BIN 的文件名
; 为简化代码，下面每个字符串的长度均为 MessageLength
MessageLength equ 9
LoadMessage: db "Loading  "	; 补齐9个字符
Message1 db "         "		; 补齐9个字符
Message2 db "in HD LDR"		; 补齐9个字符
Message3 db "No KERNEL"		; 补齐9个字符
Message4 db "Too Large"		; 补齐9个字符
Message5 db "Error 0  "		; 补齐9个字符
; ------------------------------------------------------------------------


; ------------------------------------------------------------------------
clear_screen:
	mov ax, 0x600		; AH = 6, AL = 0
	mov bx, 0x700		; 黑底白字（BL=0x7）
	mov cx, 0			; 左上角:(0, 0)
	mov dx, 0x184f		; 右下角:(80, 50)
	int 0x10			; int 0x10
	ret 		; return
; ------------------------------------------------------------------------


; ------------------------------------------------------------------------
; 函数名: disp_str
; 作用: 显示一个字符串，函数开始时 dh 中应该是字符串序号（从0开始）
; ------------------------------------------------------------------------
real_mode_disp_str:
	mov ax, MessageLength
	mul dh
	add ax, LoadMessage
	mov bp, ax				; ┓
	mov ax, ds 				; ┣ ES:BP = 串地址
	mov es, ax				; ┛
	mov cx, MessageLength	; CX = 串长度
	mov ax, 0x1301			; AH = 0x13, AL = 0x1
	mov bx, 0x7 			; 页号为0（BH=0），黑底白字（BL=0x7）
	mov dl, 0
	int 0x10 				; int 0x10
	ret 		; return
; ------------------------------------------------------------------------
