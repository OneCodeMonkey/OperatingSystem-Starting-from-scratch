/**
 * @brief   The terminal driver.
 *
 * As a common driver, TTY accepts these MESSAGEs:
 *	 - DEV_OPEN
 *	 - DEV_READ
 *	 - DEV_WRITE
 *
 * Besides, it accepts the other two types of MESSAGE from clock_handler()
 * and a PROC (who is not FS):
 *   - MESSAGE from clock_handler(): HARD_INT
 		- Every time clock interrupt occurs, the clock handler
 * 		  will check whether any key has been pressed. If so, it'll 
 *		  invoke inform_int() to wake up TTY. It is a special MESSAGE
 * 		  because it is not from a process -- clock handler is not a 
 *		  process.
 *	 - MESSAGE from a PROC: TTY_WRITE
 		- TTY is a driver. In most cases MESSAGE is passed from a PROC to FS then to TTY.
 *		  For some historical reason, PROC is allowed to pass TTY_WRITE 
 *		  MESSAGE directly to TTY. Thus a PROC can write to a tty directly.
 * @note  Do not get confused by these function names:
 * 			- tty_dev_read() —— tty_do_read()
 *			- tty_dev_read(): reads chars from keyboard buffer
 *			- tty_do_read(): handles DEV_READ message
 *			- tty_dev_write() —— tty_do_write() —— tty_write()
 *			- tty_dev_write(): return chars to a process waiting for input
 *			- tty_do_write(): handles DEV_WRITE message
 *			- tty_write(): handles TTY_WRITE message
 *
 */
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

#define TTY_FIRST (tty_table)
#define TTY_END (tty_table + NR_CONSOLES)

PRIVATE void init_tty(TTY* tty);
PRIVATE void tty_dev_read(TTY* tty);
PRIVATE void tty_dev_write(TTY* tty);
PRIVATE void tty_do_read(TTY* tty, MESSAGE* msg);
PRIVATE void tty_do_write(TTY* tty, MESSAGE* msg);
PRIVATE void put_key(TTY* tty, u32 key);

/**
 * task_tty
 *
 * <Ring 1> Main loop of task TTY.
 *
 */
PUBLIC void task_tty()
{
	TTY* tty;
	MESSAGE msg;
	init_keyboard();

	for(tty = TTY_FIRST; tty < TTY_END; tty++)
		init_tty(tty);

	select_console(0);

	while(1) {
		for(tty = TTY_FIRST; tty < TTY_END; tty++) {
			do{
				tty_dev_read(tty);
				tty_dev_write(tty);
			}while(tty->ibuf_cnt);
		}

		send_recv(RECEIVE, ANY, &msg);

		int src = msg.source;
		assert(src != TASK_TTY);

		TTY* ptty = &tty_table[msg.DEVICE];

		switch(msg.type) {
			case DEV_OPEN:
				reset_msg(&msg);
				msg.type = SYSCALL_RET;
				send_recv(SEND, src, &msg);
				break;
			case DEV_READ:
				tty_do_read(ptty, &msg);
				break;
			case DEV_WRITE:
				tty_do_write(ptty, &msg);
				break;
			case HARD_INT:
				/* waked up by clock_handler -- a key was just pressed
				 * @see: clock_handler() inform_int()
				 */
				key_pressed = 0;
				continue;
			default:
				dump_msg("TTY::unknown msg", &msg);
				break;
		}
	}
}
