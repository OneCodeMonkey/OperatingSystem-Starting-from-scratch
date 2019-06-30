; ------------------------------------------------------------------------
; boot.asm
; ------------------------------------------------------------------------

; %define _BOOT_DEBUG_		; 做 Boot Sector 时一定要将此行注释掉！将此行打开后用 nasm Boot.asm -o Boot.com 做成一个 .COM 文件易于调试

%ifdef _BOOT_DEBUG_
	org 0100h			; 调试状态，做成 .COM 文件，可调试
%else
	org 07c00h			; Boot 状态， Bios 将把 Boot Sector 加载到 0:7C00 处并开始执行
%endif

; ------------------------------------------------------------------------
%ifdef _BOOT_DEBUG_
BaseOfStack equ 0100h		; 调试状态下的堆栈基地址（栈底，从这个位置向低地址生长）
%else
BaseOfStack equ 07c00h		; Boot 状态下的堆栈基地址（栈底，从这个位置向低地址生长）
%endif

%include "load.inc"
; ------------------------------------------------------------------------

	jmp short LABEL_START		; Start to boot.
	nop			; 延迟一会

; 下面是 FAT12 磁盘的头，之所以包含它是因为下面用到了磁盘的一些信息
%include "fat12hdr.inc"

LABEL_START:
	mov ax, cs
	mov ds, ax
	mov es, ax
	mov ss, ax
	mov sp, BaseOfStack

	; 清屏
	mov ax, 0600h		; AH = 6, AL = 0h
	mov bx, 0700h 		; 黑底白字（BL = 07h）
	mov cx, 0 			; 左上角（0，0）
	mov dx, 0184fh 		; 右下角（80，50）
	int 10h 		； int 10h

	mov db, 0 		; "Booting "
	call DispStr 	; 显示字符串

	xor ah, ah 		; ┓
	xor dl, dl 		; ┣ 软驱复位
	int 13h 		; ┛

; 下面在 A 盘的根目录寻找 LOADER.BIN
	mov word[wSectorNo], SectorNoOfRootDirectory
LABEL_SEARCH_IN_ROOT_DIR_BEGIN:
	cmp word[wRootDirSizeForLoop], 0 	; ┓
	jz LABEL_NO_LOADERBIN 				; ┣ 判断根目录区是否已经读取完
	dec word[wRootDirSizeForLoop]		; ┛ 如果已读完，表示没有找到 LOADER.BIN
	mov ax, LOADER_SEG
	mov es, ax 				; es <- LOADER_SEG
	mov bx, LOADER_OFF 		; bx <- LOADER_OFF  于是， es:bx = LOADER_SEG:LOADER_OFF
	mov ax, [wSectorNo]		; ax <- Root Directory 中的某个 Sector 号
	mov cl, 1
	call ReadSector

	mov si, LoaderFileName 	; ds:si -> "LOADER BIN"
	mov di, LOADER_OFF 		; es:di -> LOADER_SEG:0100 = LOADER_SEG*10h+100
	cld
	mov dx, 10h

LABEL_SERACH_FOR_LOADERBIN:
	cmp dx, 0								; ┓ 循环次数控制
	jz LABEL_GOTO_NEXT_SECTOR_IN_ROOT_DIR 	; ┣ 如果已读完了一个 Sector
	dec dx 									; ┛ 跳到下一个 Sector
	mov cx, 11

LABEL_CMP_FILENAME:
	cmp cx, 0
	jz LABEL_FILENAME_FOUND		; 如果比较了 11 个字符都相等，表示找到
	dec cx
	lodsb			; ds:si -> al
	cmp al, byte [es:di]
	jz LABEL_GO_ON
	jmp LABEL_DIFFERENT 		; 只要发现不一样的字符就表明此 Directory 不是 LOADER.BIN

LABEL_GO_ON:
	inc di
	jmp LABEL_CMP_FILENAME 		; 继续循环

LABEL_DIFFERENT:
	and di, 0FFE0h					; else ┓ di &= E0 为了让它指向本条目的开头
	and di, 20h						;	   ┃
	mov si, LoaderFileName			;	   ┣ di += 20h 下一个目录条目
	jmp LABEL_SERACH_FOR_LOADERBIN  ;	   ┛

LABEL_GOTO_NEXT_SECTOR_IN_ROOT_DIR:
	add word [wSectorNo], 1
	jmp LABEL_SEARCH_IN_ROOT_DIR_BEGIN

LABEL_NO_LOADERBIN:
	mov dh, 2			; "No LOADER."
	call DispStr		; 显示字符串
%ifdef _BOOT_DEBUG_
	mov ax, 4c00h 		; ┓
	int 21h 			; ┛ 没有找到 LOADER.BIN ，回到 DOS
%else
	jmp $				; 没有找到 LOADER.BIN, 这里产生死循环
%endif

LABEL_FILENAME_FOUND:	; 找到 LOADER.BIN 后便跳到这里继续
	mov ax, RootDirSectors
	and di, 0FFE0h 		; di -> 当前条目的开始
	add di, 01Ah 		; di -> 首 Sector
	mov cx, word [es:di]
	push cx 			; 保存此 Sector 在 FAT 中的序号
	add cx, ax
	add cx, DeltaSectorNo 	; 这句执行完时， cl里面变成 LOADER.BIN 的起始扇区号（从0开始计数）
	mov ax, LOADER_SEG
	mov es, ax 			; es <- LOADER_SEG
	mov bx, LOADER_OFF 	; bx <- LOADER_OFF ,于是 es:bx = LOADER_SEG:LOADER_OFF = LOADER_SEG*10h + LOADER_OFF
	mov ax, cx 			; ax <- Sector 号

LABEL_GOON_LOADING_FILE:
	push ax 			; ┓
	push bx				; ┃
	mov ah, 0Eh 		; ┃ 每读取一个扇区，就在 “Booting ” 后面打一个点
	mov al, '.'			; ┃
	mov bl, 0Fh 		; ┃ Booting ......
	int 10h				; ┃
	pop bx				; ┃
	pop ax				; ┛

	mov cl, 1
	call ReadSector
	pop ax 			; 取出此 Sector 在 FAT 中的序号
	call GetFATEntry
	cmp ax, 0FFFh
	jz LABEL_FILE_LOADER
	push ax 			; 保存 Sector 在 FAT 中的序号
	mov dx, RootDirSectors
	add ax, dx
	add ax, DeltaSectorNo
	add bx, [BPB_BytsPerSec]
	jmp LABEL_GOON_LOADING_FILE

LABEL_FILE_LOADER:
	mov dh, 1			; "Ready."
	call DispStr		; 显示字符串

; ------------------------------------------------------------------------
	jmp LOADER_SEG:LOADER_OFF 	; 这句正式跳转到已加载到内存中的 LOADER.BIN 开始处
; 开始执行 LOADER.BIN 的代码
; Boot Sector 的使命到此结束
; ------------------------------------------------------------------------


; ------------------------------------------------------------------------
; 变量
; ------------------------------------------------------------------------
wRootDirSizeForLoop dw RootDirSectors 	; Root Directory 占用的扇区数，在循环中会递减至 0
wSectorNo dw 0			; 要读取的扇区号
bOdd db 0 				; 奇数还是偶数

; ------------------------------------------------------------------------


; ------------------------------------------------------------------------
; 字符串
; ------------------------------------------------------------------------
LoaderFileName db "LOADER BIN", 0 	; LOADER.BIN 之文件名
; 为简化代码，下面每个字符串的长度均为 MessageLength
MessageLength equ 9
BootMessage: db "Booting  "	; 9字节，不够处由空格补齐，序号0
Message1 db "Ready.   "		; 9字节，不够处由空格补齐，序号1
Message2 db "No LOADER"		; 9字节，不够处由空格补齐，序号2
; ------------------------------------------------------------------------

; ------------------------------------------------------------------------
; 函数名：DispStr
; ------------------------------------------------------------------------
; 作用：显示一个字符串，函数开始时 dh 中应该是字符串序号（0-based）
DispStr:
	mov ax, MessageLength
	mul dh
	add ax, BootMessage
	mov bp, ax				; ┓
	mov ax, ds 				; ┣ ES:BP = 串地址
	mov es, ax 				; ┛
	mov cx, MessageLength	; CX = 串长度
	mov ax, 01301h			; AH=13, AL=01h
	mov bx, 0007h			; 页号为0（BH = 0）黑底白字（BL=07h）
	mov dl, 0
	int 10h					; int 10h
	ret 		; return
; ------------------------------------------------------------------------

; ------------------------------------------------------------------------
; 函数名：ReadSector
; ------------------------------------------------------------------------
; 作用： 从第 ax 个 Sector 开始，将 cl 个 Sector 读到 es:bx 中去
; ------------------------------------------------------------------------
; 怎样由扇区号求扇区在磁盘中的位置（扇区号->柱面号，起始扇区，磁头号）
; ------------------------------------------------------------------------
; 设扇区号为 x
;                          ┌ 柱面号 = y >> 1
;       x           ┌ 商 y ┤
; -------------- => ┤      └ 磁头号 = y & 1
;  每磁道扇区数      │
;                   └ 余 z => 起始扇区号 = z + 1
; ------------------------------------------------------------------------
ReadSector:
	push bp
	mov bp, sp
	sub esp, 2 			; 辟出两个字节的堆栈区域保存要读的扇区数：byte[bp-2]

	mov byte [bp-2], cl
	push bx				; 保存bx
	mov bl, [BPB_SecPerTrk]	; bl: 除数
	div bl 				; y 在 al 中，z 在 ah 中
	inc ah 				; z++
	mov cl, ah 			; cl <- 起始扇区号
	mov dh, al 			; dh <- y
	shr al, 1			; y >> 1(其实是 y/BPB_NumHeads, 这里 BPB_NumHeads=2)
	mov ch, al 			; ch <- 柱面号
	and dh, 1 			; dh & 1 = 磁头号
	pop bx 				; 恢复bx

	; 至此，“柱面号，起始扇区，磁头号” 全部找到了！

	mov dl, [BS_DrvNum]	; 驱动器号（0表示A盘）

.GoOnReading:
	mov ah, 2			; 读
	mov al, byte [bp-2]	; 读 al 个 Sector
	int 13h
	jc .GoOnReading		; 如果读取错误，CF 会被置为1，这时就不停地读，直到正确为止

	add esp, 2
	pop bp

	ret 		; return

; ------------------------------------------------------------------------
