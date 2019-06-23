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
 * write()
 *
 * Write to a file descriptor.
 *
 * @param fd: File descritpor.
 * @param buf: Buffer including the bytes to write.
 * @param count: How many bytes to write.
 *
 * @return if success, return the number of bytes written,
 *		   if error, return -1.
 *
 */
PUBLIC int write(int fd, const void* buf, int count)
{
	MESSAGE msg;

	msg.type = WRITE;
	msg.FD = fd;
	msg.BUF = (void*)buf;
	msg.CNT = count;

	send_recv(BOTH, TASK_FS, &msg);

	return msg.CNT;
}

