#include "type.h"
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

/* cstart */
PUBLIC void cstart()
{
	disp_str("\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n-----\"cstart\" begins-----");

	/* 将LOADER 中的 GDT 复制到新的 GDT 中 */
	memcpy(&gdt, \ /*New GDT*/
		(void*)(*((u32*)(&gdt_ptr[2]))), \ /* base of old gdt*/
		*((u16*)(&gdt_ptr[0])) + 1 \ /* limit of old gdt */
		);

	/* gdt_ptr[6] 共6个字节： 0-15:Limit  16-47: Base. 用作 sgdt 和 lgdt 的参数 */
	u16* p_gdt_limit = (u16*)(&gdt_ptr[0]);
	u32* p_gdt_base = (u32*)(&gdt_ptr[2]);
	*p_gdt_limit = GDT_SIZE * sizeof(struct descriptor) - 1;
	*p_gdt_base = (u32)&gdt;

	/* idt_ptr[6] 共6个字节：0-15:Limit 16-47: Base. 用作 sidt 以及 lidt 的参数。 */
	u16* p_idt_limit = (u16*)(&idt_ptr[0]);
	u32* p_idt_base = (u32*)(&idt_ptr[2]);
	*p_idt_limit = IDT_SIZE * sizeof(struct gate) - 1;
	*p_idt_base = (u32)&idt;

	init_prot();

	disp_str("-----\"cstart\" finished-----\n");
}
