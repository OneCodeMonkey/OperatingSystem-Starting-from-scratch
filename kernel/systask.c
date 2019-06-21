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

PRIVATE int read_register(char reg_addr);
PRIVATE u32 get_rtc_time(struct time *t);

/**
 * task_sys
 *
 * <Ring 1> The main loop of TASK SYS.
 *
 */
PUBLIC void task_sys()
{
	MESSAGE msg;
	struct time t;

	while(1) {
		send_rect(RECEIVE, ANY, &msg);
		int src = msg.source;

		switch(msg.type) {
			case GET_TICKS:
				msg.RETVAL = ticks;
				send_recv(SEND, src, &msg);
				break;
			case GET_PID:
				msg.type = SYSCALL_RET;
				msg.PID = src;
				send_recv(SEND, src, &msg);
				break;
			case GET_RTC_TIME:
				msg.type = SYSCALL_RET;
				get_rtc_time(va2la(src, msg.BUF), va2la(TASK_SYS, &t), sizeof(t));
				send_recv(SEND, src, &msg);
				break;
			default:
				panic("unknown msg type");
				break;		
		}
	}
}
