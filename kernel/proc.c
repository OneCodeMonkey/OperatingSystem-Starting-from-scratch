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

/**
 * va2la
 *
 * <Ring 0~1> Virtual addr -> Linear addr
 * 
 * @param pid: PID of the proc whose address is to be calculated.
 * @param va: Virtual address
 * @return    the linear address for the given virtual address
 *
 */
PUBLIC void* va2la(int pid, void* va)
{
	struct proc* p = &proc_table[pid];

	u32 seg_base = ldt_seg_linear(p, INDEX_LDT_RW);
	u32 la = seg_base + (u32)va;

	if(pid < NR_TASKS + NR_NATIVE_PROCS) {
		assert(la == (u32)va);
	}

	return (void*)la;
}

/**
 * reset_msg
 * 
 * <Ring 0~3> Clear up a MESSAGE by setting each byte to 0.
 *
 * @param p: The message to be cleared
 *
 */
PUBLIC void reset_msg(MESSAGE* p)
{
	memset(p, 0, sizeof(MESSAGE));
}

/**
 * block
 * 
 * <Ring 0> This routine is called after `p_flags` has been set(but != 0),
 * it calls `schedule()` to choose another proc as the `proc_ready`.
 * 
 * @attention: This routine doesn't change `p_flags`. Make sure the `p_flags`
 * of the proc to be blocked has been set properly.
 * @param p: The proc to be blocked.
 *
 */
PRIVATE void block(struct proc* p)
{
	assert(p->p_flags);
	schedule();
}

/**
 * unblock
 *
 * <Ring 0> This is a dummy routine. Actually it does nothing. When it is
 * called, the `p_flags` should have been cleared (== 0).
 *
 * @param p: The unblocked proc.
 *
 */
PRIVATE void unblock(struct proc* p)
{
	assert(p->p_flags == 0);
}

/**
 * deadlock
 *
 * <Ring 0> Check whether it is safe to send a message from src to dest.
 * The routine will detect if the messaging graph contains a cycle. For
 * instance, if we have procs trying to send messages like this:
 *
 *     A -> B -> C -> A, 
 *
 * then a deadlock occurs, because all of them will wait forever.
 * If no cycles detected, it is considered as safe.
 *
 * @param src: Who wants to send message.
 * @param dest: To whom the message is sent.
 * @return 0 if success.
 *
 */
PRIVATE int deadlock(int src, int dest)
{
	struct proc* p = proc_table + dest;

	while(1) {
		if(p->p_flags & SENDING) {
			if(p->p_sendto == src) {
				/* print the chain */
				p = proc_table + dest;
				printl("=_=%s", p->name);

				do{
					assert(p->p_msg);
					p = proc_table + p->p_sendto;
					printl("->%s", p->name);
				}while(p != proc_table + src);
				printl("=_=");

				return 1;
			}
			p = proc_table + p->p_sendto;
		} else {
			break;
		}
	}

	return 0;
}