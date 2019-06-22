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
#include "keyboard.h"
#include "proto.h"

PUBLIC void do_fork_test();

PRIVATE void init_mm();

/**
 * task_mm
 *
 * <Ring 1> The main loop of TASK MM.
 *
 */
PUBLIC void task_mm()
{
	init_mm();

	while(1) {
		send_recv(RECEIVE, ANY, &mm_msg);
		int src = mm_msg.source;
		int reply = 1;

		int msgtype = mm_msg.type;

		switch(msgtype) {
			case FORK:
				mm_msg.RETVAL = do_fork();
				break;
			case EXIT:
				do_exit(mm_msg.STATUS);
				reply = 0;
				break;
			case EXEC:
				mm_msg.RETVAL = do_exec();
				break;
			case WAIT:
				do_wait();
				reply = 0;
				break;
			default:
				dump_msg("MM::unknown msg", &mm_msg);
				assert(0);
				break;		
		}

		if(reply) {
			mm_msg.type = SYSCALL_RET;
			send_recv(SEND, src, &mm_msg);
		}
	}
}

/**
 * init_mm()
 *
 * Do some initialization work.
 *
 */
PRIVATE void init_mm()
{
	struct boot_params bp;
	get_boot_params(&bp);

	memory_size = bp.mem_size;

	/* print memory size */
	printl("{MM} memsize: %dMB\n", memory_size / (1024 * 1024));
}
