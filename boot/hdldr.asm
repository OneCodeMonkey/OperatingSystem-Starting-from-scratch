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
