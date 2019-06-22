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

OBJS = kernel/kernel.o kernel/start.o kernel/main.o kernel/clock.o kernel/kerboard.o \
		kernel/tty.o kernel/console.o kernel/i8259.o kernel/global.o kernel/protect.o \
		kernel/proc.o kernel/systask.o kernel/hd.o kernel/klib.o lib/syslog.o \
		mm/main.o mm/forkexit.o mm/exec.o fs/main.o fs/open.o fs/misc.o fs/read_write.o \
		fs/link.o fs/disklog.o

LOBJS = lib/syscall.o lib/printf.o lib/vsprintf.o lib/string.o lib/misc.o lib/open.o \
		lib/read.o lib/write.o lib/close.o lib/unlink.o lib/lseek.o lib/getpid.o \
		lib/stat.o lib/fork.o lib/exit.o lib/wait.o lib/exec.o

DASMOUTPUT = kernel.bin.asm

# All phony targets
.PHONY : everything final image clean realclean disasm all building

# Default starting position
nop :
	@echo "why not \'make image' huh? :)"

everything : $(ORANGESBOOT) $(ORANGESKERNEL)

all : realclean everything

image : realclean everything clean building

clean : 
	rm -f $(OBJS) $(LOBJS)

realclean :
	rm -f $(OBJS) $(LOBJS) $(LIB) $(ORANGESBOOT) $(ORANGESKERNEL)

disasm :
	$(DASM) $(DASMFLAGS) $(ORANGESKERNEL) > $(DASMOUTPUT)

building :
	dd if=boot/boot.bin of=$(FD) bs=512 count=1 conv=notrunc
	dd if=boot/hdboot.bin of=$(HD) bs=1 count=446 conv=notrunc
	dd if=boot/hdboot.bin of=$(HD) seek=510 skip=510 bs=1 count=2 conv=notrunc

	sudo mount -o loop $(FD) /mnt/floppy/
	sudo cp -fv boot/leader.bin /mnt/floppy/
	sudo cp -fv kernel.bin /mnt/floppy
	sudo umount /mnt/floppy

