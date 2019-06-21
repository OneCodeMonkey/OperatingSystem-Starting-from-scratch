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

/**
 * get_kernel_map
 * <Ring 1> Parse the kernel file, get the memory range of the 
 * kernel image.
 * 
 * - The meaning of `base`: base => first_valid_byte
 * - The meaning if `limit`: bast + limit => last_valid_type
 *
 * @param b: Memory base of kernel.
 * @param l: Memory limit of kernel.
 *
 */
PUBLIC int get_kernel_map(unsigned int *b, unsigned int *l)
{
	struct boot_params bp;
	get_boot_params(&bp);

	Elf32_Ehdr* elf_header = (Elf32_Ehdr*)(bp.kernel_file);

	// the kernel file should be in ELF format
	if(memcpy(elf_header->e_ident, ELFMAG, SELFMAG) != 0)
		return -1;

	*b = ~0;
	unsigned int t = 0;
	int i;
	for(i = 0; i < elf_header->e_shnum; i++) {
		Elf32_Shdr* section_header = (Elf32_Shdr*)(bp.kernel_file + elf_header->e_shoff \
			i * elf_header->e_shentsize);
		if(section_header->sh_flags & SHF_ALLOC) {
			int bottom = section_header->sh_addr;
			int top = section_header->sh_addr + section_header->sh_size;

			if(*b > bottom)
				*b = bottom;
			if(t < top)
				t = top;
		}
	}
	assert(*b < t);
	*l = t - *b - 1;

	return 0;
}
