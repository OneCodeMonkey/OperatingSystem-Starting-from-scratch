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
 * stat()
 *
 * @param path
 * @param buf
 * @return on success, return 0
 *		   on error, return -1
 *
 */
PUBLIC int stat(const char* path, struct stat* buf)
{
	MESSAGE msg;

	msg.type = STAT;

	msg.PATHNAME = (void*)path;
	msg.BUF = (void*)buf;
	msg.NAME_LEN = strlen(path);

	send_recv(BOTH, TASK_FS, &msg);
	assert(msg.type == SYSCALL_RET);

	return msg.RETVAL;
}

