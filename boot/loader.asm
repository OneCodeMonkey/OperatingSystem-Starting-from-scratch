; ------------------------------------------------------------------------
; boot/loader.asm
; ------------------------------------------------------------------------
org 0100h
	jmp LABEL_START 	; start

; 下面是 FAT12 磁盘头，之所以包含这个是因为它下面用到了磁盘的一些信息
%include "fat12hdr.inc"
%include "load.inc"
%include "pm.inc"

; ------------------------------------------------------------------------
; GDT
; ------------------------------------------------------------------------
LABEL_GDT:	Descriptor	0,	0,	0	; 空描述符
LABEL_DESC_FLAT_C:	Descriptor	0, 0fffffh,	DA_CR | DA_32 | DA_LIMIT_4K	; 0 ~ 4G
LABEL_DESC_FLAT_RW:	Descriptor	0, 0fffffh, DA_DRW | DA_32 | DA_LIMIT_4K	; 0 ~ 4G
LABEL_DESC_VIDEO: 	Descriptor	0B8000h, 0ffffh, DA_DRW | DA_DPL3	; 显存首地址

; ------------------------------------------------------------------------


GdtLen equ $ - LABEL_GDT
GdtPtr dw GdtLen - 1		; 段界限
dd LOADER_PHY_ADDR + LABEL_GDT	; 基地址（此处可优化，将基地址8字节对齐将起到速度优化效果）
; The GDT isn't a segment itself; instead, it is a data structure in linear address space.
; The base linear address and limit of the GDT must be loaded into the GDTR register. -- IA-32 Software Developer's Manual, Vol.3A


; GDT 选择子--------------------------------------------------------------
SelectorFlatC equ LABEL_DESC_FLAT_C - LABEL_GDT
SelectorFlatRW equ LABEL_DESC_FLAT_RW - LABEL_GDT
SelectorVideo equ LABEL_DESC_VIDEO - LABEL_GDT + SA_RPL3
; ------------------------------------------------------------------------


BaseOfStack equ 0100h

LABEL_START:			; start loading
	mov ax, cs
	mov ds, ax
	mov es, ax
	mov ss, ax
	mov sp, BaseOfStack

	mov dh, 0		; "Loading  "
	call DispStrRealMode		; 显示字符串

	; 得到内存数
	mov ebx, 0		; ebx = 后续值，开始时需要为0
	mov di, _MemChkBuf	; es:di 指向一个地址范围描述符结构（Address Rang Descriptor Structure）

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
	; 下面在 A盘根目录找 KERNEL.BIN
	mov word [wSectorNo], SectorNoOfRootDirectory
	xor ah, ah			; ┓
	xor dl, dl 			; ┣ 软驱复位
	int 13h				; ┛

LABEL_SEARCH_IN_ROOT_DIR_BEGIN:
	cmp word [wRootDirSizeForLoop], 0	; ┓
	jz LABEL_NO_KERNEL_BIN				; ┣ 判断根目录是否已经读完，如果读完，表示没有找到
	dec word [wRootDirSizeForLoop]		; ┛
	mov ax, KERNEL_FILE_SEG
	mov es, ax			; es <- KERNEL_FILE_SEG
	mov bx, KERNEL_FILE_OFF		; bx <- KERNEL_FILE_OFF 于是，es:bx = KERBEL_FILE_SEG:KERNEL_FILE_OFF = KERNEL_FILE_SEG * 10h + KERNEL_FILE_OFF
	mov ax, [wSectorNo]			; ax <- Root Director 中的某个 Sector 号
	mov cl, 1
	call ReadSector

	mov si, KernelFileName		; ds:si -> "KERNEL  BIN"
	mov di, KERNEL_FILE_OFF		; es:di -> KERNEL_FILE_SEG:???? = KERNEL_FILE_SEG * 10h + ????
	cld
	mov dx, 10h

LABEL_SEARCH_FOR_KERNELBIN:
	cmp dx, 0								; ┓
	jz LABEL_GOTO_NEXT_SECTOR_IN_ROOT_DIR	; ┣ 循环次数控制，如果已经读完一个 Sector, 那么跳到下一个 Sector
	dec dx									; ┛
	mov cx, 11

LABEL_CMP_FILENAME:
	cmp cx, 0				; ┓
	jz LABEL_FILENAME_FOUND	; ┣ 循环次数控制，如果比较了11个字符全都相等。
	dec cx					; ┛
	lodsb			; ds:si -> al
	cmp al, byte [es:di]	; if al == es:di
	jz LABEL_GO_ON
	jmp LABEL_DIFFERENT

LABEL_GO_ON:
	inc di
	jmp LABEL_CMP_FILENAME	; 继续循环

LABEL_DIFFERENT:
	and di, 0FFE0h					; else┓ 这时 di 的值不知道是什么，di &= e0 为了让它是 20h 的整数倍
	add di, 20h						;     ┃
	mov si, KernelFileName			;     ┣ di += 20h 下一个目录条目
	jmp LABEL_SEARCH_FOR_KERNELBIN	; 	  ┛

LABEL_GOTO_NEXT_SECTOR_IN_ROOT_DIR:
	add word [wSectorNo], 1
	jmp LABEL_SEARCH_IN_ROOT_DIR_BEGIN

LABEL_NO_KERNELBIN:
	mov dh, 3				; "No KERNEL."
	call DispStrRealMode	; 显示字符串
	jmp $					; 没有找到 KERNEL.BIN, 进入死循环

LABEL_FILENAME_FOUND:		; 找到 KERNEL.BIN 后来此继续
	mov ax, RootDirSectors
	and di, 0FFF0h			; di -> 当前条目的开始
	push eax
	mov eaxm [es:di + 01Ch]			; ┓
	mov dword [dwKernelSize], eax 	; ┛ 保存 KERNEL.BIN 的文件大小
	cmp eax, KERNEL_VALID_SPACE
	ja .1
	pop eax
	jmp .2
.1:
	mov dh, 4				; "Too Large"
	call DispStrRealMode	; 显示字符串
	jmp $					; KERNEL.BIN 太大，进入死循环
.2:
	add di, 01Ah			; di -> 首 Sector
	mov cx, word [es:di]
	push cx					; 保存此 Sector 在 FAT 中的序号
	add cx, ax
	add cx, DeltaSectorNo	; 这时 cl 里面是 LOADER.BIN 的起始扇区号（从0开始数的序号）
	mov ax, KERNEL_FILE_SEG
	mov es, ax				; es <- KERNEL_FILE_SEG
	mov bx, KERNEL_FILE_OFF	; bx <- KERNEL_FILE_OFF 于是，es:bx = KERNEL_FILE_SEG:KERNEL_FILE_OFF = KERBEL_FILE_SEG * 10h + KERNEL_FILE_OFF
	mov ax, cx				; ax <- Sector 号

LABEL_GOON_LOADING_FILE:
	push ax					; ┓
	push bx					; ┃
	mov ah, 0Eh 			; ┃ 每读一个扇区，就在 "Loading  " 后面
	mov al, '.' 			; ┃ 打一个点，形成这样的进度条效果：
	mov bl, 0Fh 			; ┃ Loading ......
	int 10h 				; ┃
	pop bx					; ┃
	pop ax					; ┛

	mov cl, 1
	call ReadSector
	pop ax					; 取出此 Sector 在 FAT 中的序号
	call GetFATEntry
	cmp ax, 0FFFh
	jz LABEL_FILE_LOADED
	push ax					; 保存 Sector 在 FAT 中的序号
	mov dx, RootDirSectors
	add ax, dx
	add ax, DeltaSectorNo
	add bx, [BPB_BytsPerSec]
	jc .1					; 如果 bx 重新变成0，说明内核大于 64K
	jmp .2
.1:
	push ax 			; es += 0x1000  ← es 指向下一个段
	mov ax, es
	add ax, 1000h
	mov es, ax
	pop ax
.2:
	jmp LABEL_GOON_LOADING_FILE		; 继续循环

LABEL_FILE_LOADED:
	call KillMotor		; 关闭软驱马达

	xor ax, ax
	mov es, ax
	mov ax, 0201h		; AH = 02
						; AL = Number of Sectors to read(must be nonzero)
	mov cx, 1			; CH = low eight bits of cylinder number
						; CL = sector number 1-63(bits 0-5)
						; high two bits of cylinder(bits 6-7, hard disk only)
	mov dx, 80h			; DH = head number
						; DL = driver number(bit 7 set for hard disk)
	mov bx, 500h 		; ES:BX -> data buffer
	int 13h
	;; 硬盘操作完毕

	mov dh, 2			; "Ready."
	call DispStrRealMode	; 显示字符串


; ------------------------------------------------------------------------
; 下面准备跳入保护模式

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
jmp dword SelectorFlatC:(LOADED_PHY_ADDR+LABEL_PM_START)


; ------------------------------------------------------------------------
; Some variables
; ------------------------------------------------------------------------
wRootDirSizeForLoop dw RootDirSectors	; Root Directory 占用的扇区数
wSectorNo dw 0							; 要读取的扇区号
bOdd db 0								; 奇数还是偶数
dwKernelSize dd 0						; KERNEL.BIN 文件大小

; ------------------------------------------------------------------------
; 字符串定义
; ------------------------------------------------------------------------
KernelFileName db "KERNEL  BIN", 0		; KERNEL.BIN 之文件名
; 为简化代码，下面每个字符串的长度均为 MessageLength
MessageLenth equ 9
LoadMessage: db "Loading  "
Message1 db "         "
Message2 db "Ready.   "
Message3 db "No KERNEL"
Message4 db "Too Large"
; ------------------------------------------------------------------------


; ------------------------------------------------------------------------
; 函数：DispStrRealMode()
; ------------------------------------------------------------------------
; 运行环境：
; 	  实模式(保护模式下显示字符串由函数 DispStr() 完成)
; 作用：
;     显示一个字符串，函数开始时 dh 中应该是字符串序号（从0开始起）
DispStrRealMode:
	mov ax, MessageLength
	mul dh
	add ax, LoadMessage
	mov bp, ax				; ┓
	mov ax, ds 				; ┣ ES:BP = 串地址
	mov es, ax				; ┛
	mov cx, MessageLength	; CX = 字符串长度
	mov ax, 01301h 			; AH = 13, AL = 01h
	mov bx, 0007h 			; 页号为0（BH = 0），黑底白字（BL = 07h）
	mov dl, 0
	add dh, 3 				; 从第3行往下显示
	int 10h 		; int 10h
	ret 		; return

; ------------------------------------------------------------------------


; ------------------------------------------------------------------------
; 函数名：ReadSector()
; ------------------------------------------------------------------------
; 作用：从序号（Directory Entry 中的 Sector 号）为 ax 的 Sector 开始，将 cl 个
;      Sector 读入 es:bx 中
ReadSector:
	; -----------------------------------------------------------------------
	; 怎样由扇区号求扇区在磁盘中的位置 (扇区号 -> 柱面号, 起始扇区, 磁头号)
	; -----------------------------------------------------------------------
	; 设扇区号为 x
	;                           ┌ 柱面号 = y >> 1
	;       x           ┌ 商 y ┤
	; -------------- => ┤      └ 磁头号 = y & 1
	;  每磁道扇区数     │
	;                   └ 余 z => 起始扇区号 = z + 1
	push bp
	mov bp, sp
	sub esp, 2			; 开辟出两个字节的堆栈区域，保存要读的扇区数：byte [bp - 2]

	mov byte [bp - 2], cl
	push bx 			; 保存bx
	mov bl, [BPB_SecPerTrk]		; bl: 除数
	div bl 				; y 在 al 中，z 在 ah 中
	inc ah 				; z++
	mov cl, ah 			; cl <- 起始扇区号
	mov dh, al 			; dh <- y
	shr al, 1 			; y >> 1（其实是 y/BPB_NumHeads, 这里 BPB_NumHeads=2）
	mov ch, al 			; ch <- 柱面号
	and dh, 1 			; dh & 1 = 磁头号
	pop bx 				; 恢复 bx

	; 至此，“柱面号，起始扇区，磁头号” 全部获取到了
	mov dl, [BS_DrvNum]	; 驱动器号（0 表示 A盘）
.GoOnReading:
	mov ah, 2			; 读
	mov al, byte [bp - 2] 	; 读 al 个扇区
	int 13h
	jc .GoOnReading 		; 如果读取错误 CF 会被置为1，这时就不停地读，直到正确为止

	add esp, 2
	pop bp
	ret 		; return

; ------------------------------------------------------------------------


; ------------------------------------------------------------------------
; 函数名： GetFATEntry()
; ------------------------------------------------------------------------
; 作用：找到序号为 ax 的 Sector 在 FAT 中的条目，结果放到 ax 中
;      需要注意的是，中间需要读 FAT 的扇区到 es:bx 处，所以函数一开始保存了 es,bx
GetFATEntry:
	push es
	push bx
	push ax
	mov ax, KERNEL_FILE_SEG		;
	sub ax, 0100h				;
	mov es, ax					;
	pop ax
	mov byte [bOdd], 0
	mov bx, 3
	mul bx 			; dx:ax = ax * 3
	mov bx, 2
	div bx 			; dx:ax / 2 ==> ax <- 商，dx <- 余数
	cmp dx, 0 		; if dx == 0
	jz LABEL_EVEN
	mov byte [bOdd], 1
LABEL_EVEN:			; 偶数
	xor dx, dx		; 现在 ax 中是 FATEntry 在 FAT 中的偏移量，下面来计算 FATEntry 在那个扇区中（FAT 占用不止一个扇区）
	mov bx, [BPB_BytsPerSec]
	div bx 			; dx:ax / BPB_BytsPerSec ==> ax <- 商 （FATEntry 所在的扇区相对于 FAT 的扇区号）
					; dx <- 余数 （FATEntry 在扇区内的偏移）
	push dx
	mov bx, 0		; bx <- 0 于是，es:bx = (KERNEL_FILE_SEG - 100):00 = (KERNEL_FILE_SEG - 100) * 10h
	add ax, SectorNoOfFAT1 	; 此句执行之后的 ax 就是 FATEntry 所在的扇区号
	mov cl, 2
	call ReadSector 		; 读取 FATEntry 所在的扇区，一次读两个。避免在边界处发生错误，因为一个 FATEntry 可能跨越两个扇区
	pop bx
	add bx, dx
	mov ax, [es:bx]
	cmp byte [bOdd], 1
	jnz LABEL_EVEN_2
	shr ax, 4
LABEL_EVEN_2:
	and ax, 0FFFh 
LABEL_GET_FAT_ENRY_OK:
	pop bx
	pop es
	ret 		; return

; ------------------------------------------------------------------------


; ------------------------------------------------------------------------
; 函数名：KillMotor
; ------------------------------------------------------------------------
; 作用： 关闭软驱的马达
KillMotor:
	push dx
	mov dx, 03F2h
	mov al, 0
	out dx, al
	pop dx
	ret 		; return

; ------------------------------------------------------------------------


; ------------------------------------------------------------------------
; 从这里开始，后面的代码都是在保护模式下执行的
; 32 位代码段，由实模式跳入
; ------------------------------------------------------------------------
[SECTION .s32]
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

	;; fill in BootParam[]
	mov dword [BOOT_PARAM_ADDR], BOOT_PARAM_MAGIC 	; Magic Number
	mov eax, [dwMemSize]
	mov [BOOT_PARAM_ADDR + 4], eax 		; memory size
	mov eax, KERNEL_FILE_SEG
	shl eax, 4
	add eax, KERNEL_FILE_OFF
	mov [BOOT_PARAM_ADDR + 8], eax 		; phy-addr of kernel.bin

	;***************************************************************
	jmp	SelectorFlatC:KRNL_ENT_PT_PHY_ADDR	; 正式进入内核 *
	;***************************************************************
	; 内存看上去是这样的：
	;              ┃                                    ┃
	;              ┃                 .                  ┃
	;              ┃                 .                  ┃
	;              ┃                 .                  ┃
	;      501000h ┃                                    ┃
	;              ┣━━━━━━━━━━━━━━━━━━┫
	;      500FFFh ┃■■■■■■■■■■■■■■■■■■┃  4GB ram needs 4MB  for page tables: [101000h, 501000h)
	;              ┃■■■■■■■■■■■■■■■■■■┃
	;              ┃■■■■■■■■■■■■■■■■■■┃
	;              ┃■■■■■■■■■■■■■■■■■■┃
	;              ┃■■■■■■■■■■■■■■■■■■┃
	;              ┃■■■■■■■■■■■■■■■■■■┃
	;              ┃■■■■■■■■■■■■■■■■■■┃
	;              ┣■■■■■■■■■■■■■■■■■■┫
	;      108FFFh ┃■■■■■■■■■■■■■■■■■■┃ 32MB ram needs 32KB for page tables: [101000h, 109000h)
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
	;              ┃■■■■■■■■■■■■■■■■■■┃
	;       70000h ┃■■■■■■■KERNEL.BIN■■■■■■┃
	;              ┣━━━━━━━━━━━━━━━━━━┫
	;              ┃■■■■■■■■■■■■■■■■■■┃
	;              ┃■■■■■■■■■■■■■■■■■■┃
	;              ┃■■■■■■■■■■■■■■■■■■┃
	;              ┃■■■■■■■■■■■■■■■■■■┃
	;              ┃■■■■■■■■■■■■■■■■■■┃
	;              ┃■■■■■■■■■■■■■■■■■■┃
	;              ┃■■■■■■■■■■■■■■■■■■┃ 7C00h~7DFFh : BOOT SECTOR, overwritten by the kernel
	;              ┃■■■■■■■■■■■■■■■■■■┃
	;              ┃■■■■■■■■■■■■■■■■■■┃
	;              ┃■■■■■■■■■■■■■■■■■■┃
	;        1000h ┃■■■■■■■■KERNEL■■■■■■■┃ 1000h ← KERNEL 入口 (KRNL_ENT_PT_PHY_ADDR)
	;              ┣━━━━━━━━━━━━━━━━━━┫
	;         900h ┃Boot Params                         ┃
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

