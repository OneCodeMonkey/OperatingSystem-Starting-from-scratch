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


; ------------------------------------------------------------------------
; read_sector
; before:
;		- fields (disk_address_packet) should have been filled
;		  before invoking the routine
; after:
;		- es:bx -> data read
; registers changed:
;		- eax, ebx, dl, si, es
; ------------------------------------------------------------------------
read_sector:
	xor ebx, ebx

	mov dword [disk_address_packet + 12], 0

	mov ah, 0x42
	mov dl, 0x80
	mov si, disk_address_packet
	int 0x13

	mov ax, [disk_address_packet + 6]
	mov es, ax
	mov bx, [disk_address_packet + 4]

	ret
; ------------------------------------------------------------------------


; ------------------------------------------------------------------------
; get_inode
; before:
; 		- eax: inode nr.
; after:
;		- eax: sector nr.
;		- ecx: the_inode.i_size
;		- es:ebx: inodes sector buffer
; registers changed:
;		- eax, ebx, ecx, edx
; ------------------------------------------------------------------------
get_inode:
	dec eax			; eax <- inode_nr - 1
	mov bl, [fs:SB_INODE_SIZE]
	mul bl 			; eax <- (inode_nr - 1) * INODE_SIZE
	mov edx, SECT_BUF_SIZE
	sub edx, dword [fs:SB_INODE_SIZE]
	cmp eax, edx
	jg err
	push eax

	mov ebx, [fs:SB_NR_IMAP_SECTS]
	mov edx, [fs:SB_NR_SMAP_SECTS]
	lea eax, [ebx+edx+ROOT_BASE+2]
	mov dword [disk_address_packet + 8], eax
	call read_sector

	pop eax			; [es:ebx+eax] -> the inode

	mov edx, dword [fs:SB_INODE_ISIZE_OFF]
	add edx, ebx
	add edx, eax	; [es:edx] -> the_inode.i_size
	mov ecx, [es:edx]	; ecx <- the_inode.i_size

	add ax, word [fs:SB_INODE_START_OFF]	; es:[ebx+eax] -> the_inode.i_start_sect
	add bx, ax
	mov eax, [es:bx]
	add eax, ROOT_BASE		; eax <- the_inode.i_start_sect
	ret 		; return
; ------------------------------------------------------------------------


; 下面进入保护模式
; 32 位代码段，由实模式跳入
[section .s32]
ALIGN 32

[BITS 32]
LABEL_PM_START:
	mov ax, SelectorVideo
	mov gs, ax
	mov ax, SelectorFlatRW
	mov ds, ax
	mov es, ax
	mov fs, ax
	mov ss, ax
	mov esp, TopOfStack

	call DispMemInfo

	call SetupPaging

	call InitKernel

	; jmp $
	mov dword [BOOT_PARAM_ADDR], BOOT_PARAM_MAGIC	; BootParam[0] = BootParamMagic;
	mov eax, [dwMemSize]
	mov [BOOT_PARAM_ADDR + 4], eax					; BootParam[1] = MemSize;
	mov eax, KERNEL_FILE_SEG
	shl eax, 4
	add eax, KERNEL_SIZE_OFF
	mov [BOOT_PARAM_ADDR + 8], eax					; BootParam[2] = KernelFilePhyAddr;

;***************************************************************
jmp	SelectorFlatC:KRNL_ENT_PT_PHY_ADDR	; 正式进入内核 *
;***************************************************************
; 内存看上去是这样的：
;              ┃                                    ┃
;              ┃                 .                  ┃
;              ┃                 .                  ┃
;              ┃                 .                  ┃
;              ┣━━━━━━━━━━━━━━━━━━┫
;              ┃■■■■■■■■■■■■■■■■■■┃
;              ┃■■■■■■Page  Tables■■■■■■┃
;              ┃■■■■■(大小由LOADER决定)■■■■┃
;    00101000h ┃■■■■■■■■■■■■■■■■■■┃ PAGE_TBL_BASE
;              ┣━━━━━━━━━━━━━━━━━━┫
;              ┃■■■■■■■■■■■■■■■■■■┃
;    00100000h ┃■■■■Page Directory Table■■■■┃ PAGE_DIR_BASE  <- 1M
;              ┣━━━━━━━━━━━━━━━━━━┫
;              ┃□□□□□□□□□□□□□□□□□□┃
;       F0000h ┃□□□□□□□System ROM□□□□□□┃
;              ┣━━━━━━━━━━━━━━━━━━┫
;              ┃□□□□□□□□□□□□□□□□□□┃
;       E0000h ┃□□□□Expansion of system ROM □□┃
;              ┣━━━━━━━━━━━━━━━━━━┫
;              ┃□□□□□□□□□□□□□□□□□□┃
;       C0000h ┃□□□Reserved for ROM expansion□□┃
;              ┣━━━━━━━━━━━━━━━━━━┫
;              ┃□□□□□□□□□□□□□□□□□□┃ B8000h ← gs
;       A0000h ┃□□□Display adapter reserved□□□┃
;              ┣━━━━━━━━━━━━━━━━━━┫
;              ┃□□□□□□□□□□□□□□□□□□┃
;       9FC00h ┃□□extended BIOS data area (EBDA)□┃
;              ┣━━━━━━━━━━━━━━━━━━┫
;              ┃■■■■■■■■■■■■■■■■■■┃
;       90000h ┃■■■■■■■LOADER.BIN■■■■■■┃ somewhere in LOADER ← esp
;              ┣━━━━━━━━━━━━━━━━━━┫
;              ┃■■■■■■■■■■■■■■■■■■┃
;       80000h ┃■■■■■■■KERNEL.BIN■■■■■■┃
;              ┣━━━━━━━━━━━━━━━━━━┫
;              ┃■■■■■■■■■■■■■■■■■■┃
;       30000h ┃■■■■■■■■KERNEL■■■■■■■┃ 30400h ← KERNEL 入口 (KRNL_ENT_PT_PHY_ADDR)
;              ┣━━━━━━━━━━━━━━━━━━┫
;              ┃                                    ┃
;        7E00h ┃              F  R  E  E            ┃
;              ┣━━━━━━━━━━━━━━━━━━┫
;              ┃■■■■■■■■■■■■■■■■■■┃
;        7C00h ┃■■■■■■BOOT  SECTOR■■■■■■┃
;              ┣━━━━━━━━━━━━━━━━━━┫
;              ┃                                    ┃
;         500h ┃              F  R  E  E            ┃
;              ┣━━━━━━━━━━━━━━━━━━┫
;              ┃□□□□□□□□□□□□□□□□□□┃
;         400h ┃□□□□ROM BIOS parameter area □□┃
;              ┣━━━━━━━━━━━━━━━━━━┫
;              ┃◇◇◇◇◇◇◇◇◇◇◇◇◇◇◇◇◇◇┃
;           0h ┃◇◇◇◇◇◇Int  Vectors◇◇◇◇◇◇┃
;              ┗━━━━━━━━━━━━━━━━━━┛ ← cs, ds, es, fs, ss
;
;
;		┏━━━┓		┏━━━┓
;		┃■■■┃ 我们使用 	┃□□□┃ 不能使用的内存
;		┗━━━┛		┗━━━┛
;		┏━━━┓		┏━━━┓
;		┃      ┃ 未使用空间	┃◇◇◇┃ 可以覆盖的内存
;		┗━━━┛		┗━━━┛
;
; 注：KERNEL 的位置实际上是很灵活的，可以通过同时改变 LOAD.INC 中的 KRNL_ENT_PT_PHY_ADDR 和 MAKEFILE 中参数 -Ttext 的值来改变。
;     比如，如果把 KRNL_ENT_PT_PHY_ADDR 和 -Ttext 的值都改为 0x400400，则 KERNEL 就会被加载到内存 0x400000(4M) 处，入口在 0x400400。
;


; ------------------------------------------------------------------------
; 显示AL中的数字
; ------------------------------------------------------------------------
DispAL:
	push ecx
	push edx
	push edi

	mov edi, [dwDispPos]

	mov ah, 0Fh 			; 0000b: 黑底  1111b: 白字
	mov dl, al 
	shr al, 4
	mov ecx, 2

.begin:
	and al, 01111b
	cmp al, 9
	ja .1
	add al, '0'
	jmp .2
.1:
	sub al, 0Ah
	add al, 'A'
.2:
	mov [gs:edi], ax
	add edi, 2

	mov al, dl
	loop .begin
	;add edi, 2

	mov [dwDispPos], edi
	pop edi
	pop edx
	pop ecx

	ret 		; return
; ------------------------------------------------------------------------


; ------------------------------------------------------------------------
; 显示一个整型数
; ------------------------------------------------------------------------
DispInt：
	mov eax, [esp + 4]
	shr eax, 24
	call DispAL

	mov eax, [esp + 4]
	shr eax, 16
	call DispAL

	mov eax, [esp + 4]
	shr eax, 8
	call DispAL

	mov eax, [esp + 4]
	call DispAL

	mov ah, 07h 			; 0000b: 黑底  0111b: 灰字
	mov al, 'h'
	push edi
	mov edi, [dwDispPos]
	mov [gs:edi], ax
	add edi, 4
	mov [dwDispPos], edi
	pop edi

	ret 			; return
; ------------------------------------------------------------------------


; ------------------------------------------------------------------------
; 函数: DispStr()
; ------------------------------------------------------------------------
DispStr:
	push ebp
	mov ebp, esp
	push ebx
	push esi
	push edi

	mov esi, [ebp + 8]		; pszInfo
	mov edi, [dwDispPos]
	mov ah, 0Fh 

.1:
	lodsb
	test al, al
	jz .2
	cmp al, 0Ah 	; 判断是否按了回车
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
	mov [dwDispPos], edi
	pop edi
	pop esi
	pop ebx
	pop ebp
	ret 		; return
; ------------------------------------------------------------------------


; ------------------------------------------------------------------------
; 输出换行
; ------------------------------------------------------------------------
DispReturn:
	push szReturn
	call DispStr 		; printf("\n");
	add esp, 4

	ret 		; return
; ------------------------------------------------------------------------


; ------------------------------------------------------------------------
; 函数： 内存拷贝，仿 memcpy()
; ------------------------------------------------------------------------
MemCpy:
	push ebp
	mov ebp, esp

	push esi
	push edi
	push ecx

	mov edi, [ebp + 8]		; Destination
	mov esi, [ebp + 12]		; Source
	mov ecx, [ebp + 16]		; Counter

.1:
	cmp ecx, 0 		; 判断计数器
	jz .2			; 若计数器为0，跳出

	mov al, [ds:esi]		; ┓
	inc esi 				; ┃
							; ┣  逐字节移动
	mov byte [es:edi], al 	; ┃
	inv edi					; ┛

	dec ecx			; 计数器减1
	jmp .1			; 循环

.2:
	mov eax, [ebp + 8]		; 返回值
	pop ecx
	pop edi
	pop esi
	mov esp, ebp
	pop ebp

	ret 		; return
; ------------------------------------------------------------------------


; ------------------------------------------------------------------------
; 函数： DispMemInfo()
; ------------------------------------------------------------------------
DispMemInfo:
	push esi
	push edi
	push ecx

	push szMemChkTitle
	call DispStr
	add esp, 4

	mov esi, MemChkBuf
	mov ecx, [dwMCRNumber]		; for(int i = 0; i < [MCRNumber]; i++)
								; 每次循环得到一个 ARDS(Address Range Descriptor Structure) 结构
.loop:
	mov edx, 5 			; for(int j = 0; j < 5; j++) 每次得到一个ARDS中的成员，共5个成员
	mov edi, ARDStruct	; 依次显示: BaseAddrLow, BaseAddrHigh, LengthLow, LengthHigh, Type
.1:
	push dword [esi]	;
	call DispInt 		; DispInt(MemChkBuf[j * 4]); 显示一个成员
	pop eax
	stosd				; ARDStruct[j * 4] = MemChkBuf[j * 4];
	add esi, 4
	dec edx
	cmp edx, 0
	jnz .1
	call DispReturn 	; 换行
	cmp dword [dwType], 1	; if(Type == AddressRangeMemory)
	jne .2
	mov eax, [dwBaseAddrLow]
	add eax, [dwLengthLow]
	cmp eax, [dwMemSize]	; if(BaseAddrLow + LengthLow > MemSize)
	jb .2
	mov [dwMemSize], eax 	; MemSize = BaseAddrLow + LengthLow;
.2:
	loop .loop
	call DispReturn	
	push szRAWSize
	call DispStr
	add esp, 4

	push dword [dwMemSize]
	call DispInt
	add esp, 4

	pop ecx
	pop edi
	pop esi
	ret 		; return
; ------------------------------------------------------------------------

;;; ; 显示内存信息 --------------------------------------------------------------
;;; DispHDInfo:
;;; 	push	eax

;;; 	cmp	dword [dwNrHead], 0FFFFh
;;; 	je	.nohd

;;; 	push	szCylinder
;;; 	call	DispStr			; printf("C:");
;;; 	add	esp, 4

;;; 	push	dword [dwNrCylinder] 	; NR Cylinder
;;; 	call	DispInt
;;; 	pop	eax

;;; 	push	szHead
;;; 	call	DispStr			; printf(" H:");
;;; 	add	esp, 4

;;; 	push	dword [dwNrHead] 	; NR Head
;;; 	call	DispInt
;;; 	pop	eax

;;; 	push	szSector
;;; 	call	DispStr			; printf(" S:");
;;; 	add	esp, 4

;;; 	push	dword [dwNrSector] 	; NR Sector
;;; 	call	DispInt
;;; 	pop	eax
	
;;; 	jmp	.hdinfo_finish
	
;;; .nohd:
;;; 	push	szNOHD
;;; 	call	DispStr			; printf("No hard drive. System halt.");
;;; 	add	esp, 4
;;; 	jmp	$			; 没有硬盘，死在这里
	
;;; .hdinfo_finish:
;;; 	call	DispReturn

;;; 	pop	eax
;;; 	ret
;;; ; ---------------------------------------------------------------------------


; 启动分页机制 -------------------------------------------------------------------
SetupPaging:
	; 根据内存大小计算应初始化多少PDE以及多少页表
	xor edx, edx
	mov eax, [dwMemSize]
	mov ebx, 400000h		; 400000h = 4M = 4096 * 1024, 一个页表对应的内存大小
	div ebx
	mov ecx, eax 			; 此时 ecx 为页表的个数，也即 PDE 应该的个数
	test edx, edx
	jz .no_remainder
	inc ecx 				; 如果余数不为0，就需增加的一个页表

.no_remainder:
	push ecx				; 暂存页表个数

	; 为简化处理，所有线性地址对应相等的物理地址，并且不考虑内存空间。
	; 首先初始化页目录
	mov ax, SelectorFlatRW
	mov es, ax
	mov edi, PAGE_DIR_BASE 	; 此断首地址为 PAGE_DIR_BASE
	xor eax, eax
	mov eax, PAGE_TBL_BASE | PG_P | PG_USU | PG_RWW
.1:
	stosd
	add eax, 4096		; 为了简化，所在页表在内存中是连续的
	loop .1

	; 再初始化所有页表
	pop eax 			; 页表个数
	mov ebx, 1024		; 每个页表 1024 个 PTE
	mul ebx
	mov ecx, eax 		; PTE 个数 = 页表个数 * 1024
	mov edi, PAGE_TBL_BASE	; 此断首地址为 PAGE_TBL_BASE
	xor eax, eax
	mov eax, PG_P | PG_USU | PG_RWW
.2:
	stosd
	add eax, 4096		; 每一页指向 4K 的空间
	loop .2

	mov eax, PAGE_DIR_BASE
	mov cr3, eax
	mov eax, cr0
	or eax, 80000000h
	mov cr0, eax
	jmp short .3
.3:
	nop 		; 一点延迟
	ret 		; return
; ------------------------------------------------------------------------


; ------------------------------------------------------------------------
; InitKernel
; ------------------------------------------------------------------------
InitKernel:	; 遍历每一个 Program Header, 根据 Program Header 中的信息来确定把什么放进内存，放到什么位置，以及放多少。
	xor esi, esi
	mov cx, word [KERNEL_FILE_PHY_ADDR + 2Ch]	; ┓ ecx <- pELFHdr->e_phnum
	movzx ecx, cx 								; ┛
	mov esi, [KERNEL_FILE_PHY_ADDR + 1Ch]		; esi <- pELFHdr->e_phoff
	add esi, KERNEL_FILE_PHY_ADDR				; esi <- OffsetOfKernel + pELFHdr->e_phoff
.Begin:
	mov eax, [esi + 0]				
	cmp eax, 0				; PT_NULL
	jz .NoAction
	push dword [esi + 010h] 	; size  ┓
	mov eax, [esi + 04h]		;		┃
	add eax, KERNEL_FILE_PHY_ADDR	; 	┣ ::memcpy((void*)(pPHdr->p_vaddr)),
	push eax 				; src 	; 	┃ uchCode + pPHdr->p_offset,
	push dword [esi + 08h]	; dst 		┃ pPHdr->p_filesze
	call MemCpy 			; 			┃
	add esp, 12				;			┛
.NoAction:
	add esi, 020h 			; esi += PELFHdr->e_phentsize
	dec ecx
	jnz .Begin

	ret 			; return
; InitKernel

; ------------------------------------------------------------------------


; SECTION .data1 ---------------------------------------------------------
[SECTION .data1]
ALIGN 32

LABEL_DATA:
	; 实模式下使用这些符号
	; 字符串
	_szMemChkTitle: 	db 	"BaseAddrL BaseAddrH LengthLow LengthHigh Type", 0Ah, 0
	_szRAMSize:	db "RAM size: ", 0
	;;; _szCylinder db "HD Info: C=", 0
	;;; _szHead db " H=", 0
	;;; _szSector db " S=", 0
	;;; _szNOHD	db "No hard drive. System halt.", 0
	_szReturn: db 0Ah, 0
	;; 变量
	;;; _dwNrCylinder dd 0
	;;; _dwNrHead dd 0
	;;; _dwNrSector dd 0
	_dwMCRNumber: dd 0	; Memory Check Result
	_dwDispPos: dd (80 * 7 + 0) * 2		; 屏幕第7行，第0列
	_dwMemSize: dd 0
