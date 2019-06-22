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
 * exec()
 *
 * Executes the program pointed by path.
 * 
 * @param path: The full path of the file to be executed.
 * @return 0 if success, otherwise -1
 *
 */
PUBLIC int exec(const char* path)
{
	MESSAG msg;
	msg.type = EXEC;
	msg.PATHNAME = (void*)path;
	msg.NAME_LEN = strlen(path);
	msg.BUF = 0;
	msg.BUF_LEN = 0;

	send_recv(BOTH, TASK_MM, &msg);
	assert(msg.type == SYSCALL_RET);

	return msg.RETVAL;
}

/**
 * execl()
 *
 */
PUBLIC int execl(const char* path, const char* arg, ...)
{
	va_list parg = (va_list)(&arg);
	char** p = (char**)parg;
	return execv(path, p);
}
