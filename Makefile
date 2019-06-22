# Entry point of Operation System
# It must have the same value with 'KernelEntryPointPhyAddr' in load.inc!
ENTRYPOINT = 0x1000

FD = a.img
HD = 100m.img

# Programs, flags, etc.
ASM = nasm
DASM = objdump
CC = gcc
LD = ld
ASMBFLAGS = -I boot/include/
ASMKFLAGS = -I include/ -I include/sys/ -f elf
CFLAGS = -I include/ -I include/sys/ -c -fno-builtin -Wall
LDFLAGS = -Ttext $(ENTRYPOINT) -Map krnl.map
DASMFLAGS = -D
ARFLAGS = rcs

# This Program
ORANGESBOOT = boot/boot.bin boot/hdboot.bin boot/loader.bin boot/hdldr.bin
ORANGESKERNEL = kernel.bin
LIB = lib/orangescrt.a

