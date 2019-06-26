#include "type.h"
#include "stdio.h"
#include "const.h"
#include "protect.h"
#include "tty.h"
#include "console.h"
#include "string.h"
#include "fs.h"
#include "proc.h"
#include "global.h"
#include "proto.h"

PRIVATE void block(struct proc* p);
PRIVATE void unblock(struct proc* p);
PRIVATE int msg_send(struct proc* current, int dest, MESSAGE* m);
PRIVATE int msg_receive(struct proc* current, int src, MESSAGE* m);
PRIVATE int deadlock(int src, int dest);

/**
 * schedule
 * 
 * <Ring 0> Choose one proc to run.
 *
 */
PUBLIC void schedule()
{
	struct proc* p;
	int greatest_ticks = 0;

	while(!greatest_ticks) {
		for(p = &FIRST_PROC; p <= &LAST_PROC; p++) {
			if(p->p_flags == 0) {
				if(p->ticks > greatest_ticks) {
					greatest_ticks = p->ticks;
					p_proc_ready = p;
				}
			}
		}
		if(!greatest_ticks)
			for(p = &FIRST_PROC; p <= &LAST_PROC; p++)
				if(p->p_flags == 0)
					p->ticks = p->priority;
	}
}

/**
 * sys_sendrec
 *
 * <Ring 0> The core routine of system call `sendrec()`
 *
 * @param function: SEND or RECEIVE
 * @param src_dest: To or From whom the message is transferred
 * @param m: Ptr to the MESSAGE body
 * @param p: The caller proc.
 * @return 0 if success.
 *
 */
PUBLIC int sys_sendrec(int function, int src_dest, MESSAGE* m, struct proc* p)
{
	assert(k_reenter == 0);		/* make sure we are not in ring 0. */
	assert((src_dest >= 0 && src_dest < NR_TASKS + NR_PROCS) || \
		src_dest == ANY || src_dest == INTERRUPT);

	int ret = 0;
	int caller = proc2pid(p);
	MESSAGE* mla = (MESSAGE*)va2la(caller, m);
	mla->source = caller;

	assert(mla->source != src_dest);

	/**
	 * Actually we have the third message type: BOTH, However, it is not 
	 * allowed to be passed to the kernel directly. Kernel doesn't know it
	 * at all. It is transformed into a SEND followed by a RECEIVE by 
	 * `send_recv()`
	 *
	 */
	if(function == SEND) {
		ret = msg_send(p, src_dest, m);
		if(ret != 0)
			return ret;
	} else if(function == RECEIVE) {
		ret = msg_receive(p, src_dest, m);
		if(ret != 0)
			return ret;
	} else {
		panic("{sys_sendrec} invalid function: %d (SEND:%d, RECEIVE:%d).", \
			function, SEND, RECEIVE);
	}

	return 0;
}

/**
 * ldt_seg_linear
 *
 * <Ring 0~1> Calculate the linear address of a certain segment of a given
 * proc.
 * 
 * @param p: whose(the proc ptr)
 * @param idx: which(one proc has more than one segments)
 * @return    the required linear address
 *
 */
PUBLIC int ldt_seg_linear(struct proc* p, int idx)
{
	struct descriptor* d = &p->ldts[idx];

	return d->base_high << 24 | d->base_mid << 16 | d->base_low;
}
