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
#include "keyboard.h"
#include "proto.h"

PRIVATE void cleanup(struct proc* proc);

/**
 * do fork
 *
 * Perform the fork() syscall.
 *
 * @return Zero when success, otherwise -1.
 *
 */
PUBLIC int do_fork()
{
	/* find a free slot in proc_table */
	struct proc* p = proc_table;
	int i;
	for(i = 0; i < NR_TASKS + NR_PROCS; i++, p++) {
		if(p->p_flags == FREE_SLOT)
			break;
	}

	int child_pid = i;
	assert(p == &proc_table[child_pid]);
	assert(child_pid >= NR_TASKS + NR_NATIVE_PROCS);

	if(i == NR_TASKS + NR_PROCS)	/* no free slot */
		return -1;
	assert(i < NR_TASKS + NR_PROCS);

	/* duplicate the process table */
	int pid = mm_msg.source;
	u16 child_ldt_sel = p->ldt_sel;
	*p = proc_table[pid];
	p->ldt_sel = child_ldt_sel;
	p->p_parent = pid;
	sprintf(p->name, "%s_%d", proc_table[pid].name, child_pid);

	/* duplicate the process: T, D & S */
	struct descriptor *ppd;

	/* Text segment */
	ppd = &proc_table[pid].ldts[INDEX_LDT_C];
	/* base of T-seg, in bytes */
	int caller_T_base = reassembly(ppd->base_high, 24, ppd->base_mid, 16, ppd->base_low);
	/* limit of T-seg, in 1 or 4096 bytes, depending on the G bit of descriptor */	
	int caller_T_limit = reassembly(0, 0, (ppd->limit_high_attr2 & 0xF), 16, ppd->limit_low);
	/* size of T-seg, in bytes */
	int caller_T_size = ((caller_T_limit + 1) * ((ppd->limit_high_attr2 & (DA_LIMIT_4K >> 8)) \
		? 4096 : 1));

	/* Data & Stack segments */
	ppd = &proc_table[pid].ldts[INDEX_LDT_RW];
	/* base of D&S-seg, in bytes */
	int caller_D_S_base = reassembly(ppd->base_high, 24, ppd->base_mid, 16, ppd->base_low);
	/* limit of D&S-seg, in 1 or 4096 bytes, depending on the G bit of descriptor */
	int caller_D_S_limit = reassembly((ppd->limit_high_attr2 & 0xF), 16, 0, 0, ppd->limit_low);
	/* size of D&S-seg, in bytes */
	int caller_D_S_size = (caller_T_limit + 1) * ((ppd->limit_high_attr2 & (DA_LIMIT_4K >> 8)) ? 4096 : 1);

	/* we don't separate T, D & S segments, so we have: */
	assert((caller_T_base == caller_D_S_base) && \
		(caller_T_limit == caller_D_S_limit) && \
		(caller_T_size == caller_D_S_size));

	/* base of child proc, T, D & S segments share the same space, so we allocate
	 * memory just once. */
	int child_base = alloc_mem(child_pid, caller_T_size);

	/* child is a copy of the parent */
	phys_copy((void*)child_base, (void*)caller_T_base, caller_T_size);

	/* child's LDT */
	init_desc(&p->ldts[INDEX_LDT_C], child_base, (PROC_IMAGE_SIZE_DEFAULT - 1) \
		>> LIMIT_4K_SHIFT, DA_LIMIT_4K | DA_32 | DA_C | PRIVILEGE_USER << 5);
	init_desc(&p->ldts[INDEX_LDT_RW], child_base, (PROC_IMAGE_SIZE_DEFAULT - 1) \
		>> LIMIT_4K_SHIFT, DA_LIMIT_4K | DA_32 | DA_DRW | PRIVILEGE_USER << 5);

	/* tell FS, see fs_fork() */
	MESSAGE msg2fs;
	msg2fs.type = FORK;
	msg2fs.PID = child_pid;
	send_recv(BOTH, TASK_FS, &msg2fs);

	/* child PID will be returned to the parent proc */
	mm_msg.PID = child_pid;

	/* birth of the child */
	MESSAGE m;
	m.type = SYSCALL_RET;
	m.RETVAL = 0;
	m.PID = 0;
	send_recv(SEND, child_pid, &m);

	return 0;
}
