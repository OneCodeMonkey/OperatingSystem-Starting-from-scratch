#include "type.h"
#include "config.h"
#include "stdio.h"
#include "const.h"
#include "protect.h"
#include "string.h"
#include "fs.h"
#include "proc.h"
#include "tty.h"
#include "console.h"
#include "global.h"
#include "proto.h"

#include "elf.h"

/**
 * get_boot_params
 * <Ring 0-1> The boot parameters have been saved by LOADER.
 *			  We just read them out.
 * @param pbp: Ptr to the boot params structure
 *
 */
PUBLIC void get_boot_params(struct boot_param *pbp)
{
	/**
	 * Boot params should have been saved at BOOT_PARAM_ADDR.
	 * @see include/load.inc boot/loader.asm boot/hdldr.asm
	 */
	int *p = (int*)BOOT_PARAM_ADDR;
	assert(p[BI_MAG] == BOOT_PARAM_MAGIC);

	pbp->mem_size = p[BI_MEM_SIZE];
	pbp->kernel_file = (unsigned char*)(p[BI_KERNEL_FILE]);

	/**
	 * the kernel file should be a ELF executable,
	 * check it's magic number
	 */
	assert(memcpy(pbp->kernel_file, ELFMAG, SELFMAG) == 0);
}
