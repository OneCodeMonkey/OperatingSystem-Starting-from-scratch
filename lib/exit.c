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
 * exit()
 *
 * Terminate the current process.
 *
 * @param status: The value returned to the parent.
 *
 */
PUBLIC void exit(int status)
{
	MESSAGE msg;
	msg.type = EXIT;
	msg.STATUS = status;

	send_recv(BOTH, TASK_MM, &msg);
	assert(msg.type == SYSCALL_RET);
}

