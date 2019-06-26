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

/**
 * kernel_main
 *
 * jmp from kernel.asm::_start.
 *
 */
PUBLIC int kernel_main()
{
	disp_str("\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n");

	int i, j, eflags, prio;
	u8 rpl;
	u8 priv;	/* privilege */

	struct task *t;
	struct proc *p = proc_table;

	char* stk = task_stack + STACK_SIZE_TOTAL;

	for(i = 0; i < NR_TASKS + NR_PROCS; i++, p++, t++) {
		if(i >= NR_TASKS + NR_NATIVE_PROCS) {
			p->p_flags = FREE_SLOT;
			continue;
		}
		if(i < NR_TASKS) {		/* TASK */
			t = task_table + i;
			priv = PRIVILEGE_TASK;
			rpl = RPL_TASK;
			eflags = 0x1202;	/* IF=1, IOPL=1, bit 2 is always 1 */
			prio = 15;
		} else {		/* USER PROC */
			t = user_proc_table + (i - NR_TASKS);
			priv = PRIVILEGE_USER;
			rpl = RPL_USER;
			eflags = 0x202;		/* IF=1, bit 2 is always 1 */
			prio = 5;
		}
		strcpy(p->name, t->name);		/* name of the process */
		p->p_parent = NO_TASK;

		if(strcmp(t->name, "INIT") != 0) {
			p->ldts[INDEX_LDT_C] = gdt[SELECTOR_KERNEL_CS >> 3];
			p->ldts[INDEX_LDT_RW] = gdt[SELECTOR_KERNEL_DS >> 3];

			/* change the DPLs */
			p->ldts[INDEX_LDT_C].attr1 = DA_C | priv << 5;
			p->ldts[INDEX_LDT_RW].attr1 = DA_DRW | priv << 5;
		} else {	/* INIT Process */
			unsigned int k_base;
			unsigned int k_limit;
			int ret = get_kernel_map(&k_base, &k_limit);
			assert(ret == 0);
			init_desc(&p->ldts[INDEX_LDT_C],
				0,	/* bytes before the entry point are useless(wasted) for the
					 * INIT process, doesn't matter
					 */
				(k_base + k_limit) >> LIMIT_4K_SHIFT,
				DA_32 | DA_LIMIT_4K | DA_C | priv << 5
				);
			int_desc(&p->ldts[INDEX_LDT_RW],
				0,  /* bytes before the entry point are useless(wasted) for the
					 * INIT process, doesn't matter
					 */
				(k_base + k_limit) >> LIMIT_4K_SHIFT,
				DA_32 | DA_LIMIT_4K | DA_DRW | priv << 5
				);
		}

		p->regs.cs = INDEX_LDT_C << 3 | SA_TIL | rpl;
		p->regs.ds = p->regs.es = p->regs.fs = p->regs.ss = \
			INDEX_LDT_RW << 3 | SA_TIL | rpl;
		p->regs.gs = (SELECTOR_KERNEL_GS & SA_RPL_MASK) | rpl;
		p->regs.eip = (u32)t->initial_eip;
		p->regs.esp = (u32)stk;
		p->regs.eflags = eflags;

		p->ticks = p->priority = prio;

		p->p_flags = 0;
		p->p_msg = 0;
		p->p_recvfrom = NO_TASK;
		p->p_sendto = NO_TASK;
		p->has_int_msg = 0;
		p->q_sending = 0;
		p->next_sending = 0;

		for(j = 0; j < NR_FILES; j++)
			p->flip[j] = 0;
		stk -= t->stacksize;
	}

	k_render = 0;
	ticks = 0;

	p_proc_ready = proc_table;

	init_clock();
	init_keyboard();

	restart();
	while(1) {
		//
	}
}
