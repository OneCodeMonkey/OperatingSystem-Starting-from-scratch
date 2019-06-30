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

