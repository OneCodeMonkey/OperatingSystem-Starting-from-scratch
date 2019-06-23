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
 * read
 *
 * Read from a file descriptor.
 *
 * @param fd: File descriptor.
 * @param buf: Buffer to accept the bytes read.
 * @param count: How many bytes to read.
 * @retrun if success, return the number of bytes read.
 * 		   if error, return -1
 *
 */
PUBLIC int read(int fd, void* buf, int count)
{
	MESSAGE msg;
	msg.type = READ;
	msg.FD = fd;
	msg.BUF = buf;
	msg.CNT = count;

	send_recv(BOTH, TASK_FS, &msg);

	return msg.CNT;
}

