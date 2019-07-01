; ------------------------------------------------------------------------
; boot/hdboot.asm
; ------------------------------------------------------------------------

org 0x7c00			; bios always loads boot sector to 0000:7C00

	jmp boot_start

%include "load.inc"

STACK_BASE equ 0x7C00 		; base address of stack when booting
TRANS_SECT_NR equ 2
SECT_BUF_SIZE equ TRANS_SECT_NR * 512

disk_address_packet: db 0x10		; [0] Packet size in bytes.
					 db 0 			; [1] Reserved, must be 0
					 db TRANS_SECT_NR 	; [2] Nr of blocks to transfer
					 db 0			; [3] Reserved, must be 0
					 db 0 			; [4] Addr of transfer - Offset
					 db SUPER_BLK_SEG	; [6] buffer. - Seg
					 db 0 			; [8] LBA. Low 32-bits.
					 db 0 			; [12] LBA. High 32-bits.

err:
	mov dh, 3		; "Error 0 "
	call disp_str	; display the string
	jmp $

boot_start:
	mov ax, cs
	mov ds, ax
	mov es, ax
	mov ss, ax
	mov sp, STACK_BASE

	call clear_screen

	mov dh, 0			; "Booting "
	call disp_str		; display the string

	; read the super block to SUPER_BLK_SEG::0
	mov dword [disk_address_packet + 8], ROOT_BASE + 1
	call read_sector
	mov ax, SUPER_BLK_SEG
	mov fs, ax

	mov dword [disk_address_packet + 4], LOADER_OFF
	mov dword [disk_address_packet + 6], LOADER_SEG

	; get the sector nr of '/' (ROOT_INODE), it'll be stored in eax
	mov eax, [fs:SB_ROOT_INODE]
	call get_inode

	; read '/' into ex:bx
	mov dword [disk_address_packet + 8], eax
	call read_sector

	; let's search '/' for the loader
	mov si, LoaderFileName
	push bx 		; <- save

.str_cmp:
	; before comparation:
	; es:bx -> dir_entry @ disk
	; ds:si -> filename we want
	add bx, [fs:SB_DIR_ENT_FNAME_OFF]
.1:
	lodsb			; ds:si -> al
	cmp al, byte [es:bx]
	jz .2
	jmp .different		; oops
.2:
	cmp al, 0			; both arrive at a '\0', match
	jz .found
	inc bx				; next char @ disk
	jmp .1				; on and on
.different:
	pop bx			; -> restore
	add bx, [fs:SB_DIR_ENT_SIZE]
	sub ecx, [fs:SB_DIR_ENT_SIZE]
	jz .not_found

	mov dx, SECT_BUF_SIZE
	cmp bx, dx
	jge .not_found

	push bx
	mov si, LoaderFileName
	jmp .str_cmp
.not_found:
	mov dh, 2
	call disp_str
	jmp $
.found:
	pop bx
	add bx, [fs:SB_DIR_ENT_INODE_OFF]
	mov eax, [es:bx]			; eax <- inode nr of loader
	call get_inode				; eax <- start sector nr of loader
	mov dword [disk_address_packet + 8], eax
load_loader:
	call read_sector
	cmp ecx, SECT_BUF_SIZE
	jl .done
	sub ecx, SECT_BUF_SIZE		; bytes_left -= SECT_BUF_SIZE
	add word [disk_address_packet + 4], SECT_BUF_SIZE	; transfer buffer
	jc err
	add dword [disk_address_packet + 8], TRANS_SECT_NR	; LBA
	jmp load_loader
.done:
	mov dh, 1
	call disp_str
	jmp LOADER_SEG:LOADER_OFF
	jmp $

; ------------------------------------------------------------------------
