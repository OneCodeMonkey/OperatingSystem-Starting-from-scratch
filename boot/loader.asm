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


