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
