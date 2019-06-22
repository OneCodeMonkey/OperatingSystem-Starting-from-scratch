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

/**
 * send_rev()
 *
 * <Ring 1~3> IPC syscall.
 * 
 * It is an encapsulation of `sendrec`.
 * Invoking `sendrec` directly should be in avoided.
 *
 * @param function: SEND, RECEIVE or BOTH
 * @param src_dest: The caller's proc_nr
 * @param msg: Pointer to the MESSAGE struct
 *
 * @return 0 always.
 *
 */
PUBLIC int send_recv(int function, int src_dest, MESSAGE* msg)
{
	int ret = 0;

	if(function == RECEIVE) {
		memset(msg, 0, sizeof(MESSAGE));
	}

	switch(function) {
		case BOTH:
			ret = sendrec(SEND, src_dest, msg);
			if(ret == 0)
				ret = sendrec(RECEIVE, src_dest, msg);
			break;
		case SEND:
		case RECEIVE:
			ret = sendrec(function, src_dest, msg);
			break;
		default:
			assert((function == BOTH) || (function == SEND) || (function == RECEIVE));
			break;		
	}

	return ret;
}
