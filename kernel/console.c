# include "type.h"
# include "stdio.h"
# include "const.h"
# include "protect.h"
# include "string.h"
# include "fs.h"
# include "proc.h"
# include "tty.h"
# include "console.h"
# include "global.h"
# include "keyboard.h"
# include "proto.h"

// local routines
PRIVATE void set_cursor(unsigned int position);
PRIVATE void set_video_start_addr(u32 addr);
PRIVATE void flush(CONSOLE* con);
PRIVATE void w_copy(unsigned int dst, const unsigned int src, int size);
PRIVATE void clear_screen(int pos, int len);

/**
 *	init_screen
 *	
 *	Initialize the console of a certain tty.
 *
 *	@param tty: whose console is to be initialized.
 */
PUBLIC void init_screen(TTY* tty)
{
	int nr_tty = tty - tty_table;
	tty->console = console_table + nr.tty;

	// Note: variables related to `position` and `size` below are in WORDS, but not int BYTEs.
	// size of video memory
	int v_mem_size = V_MEM_SIZE >> 1;
	int size_per_con = v_mem_size / NR_CONSOLES;
	tty->console->orig = nr_tty * size_per_con;
	tty->console->con_size = size_per_con / SCR_WIDTH * SCR_WIDTH;
	tty->console->cursor = tty->console->crtc_start = tty->console->orig;
	tty->console->is_full = 0;

	if(nr_tty == 0) {
		tty->console->cursor = disp_pos / 2;
		disp_pos = 0;
	} else {
		// `?` in this string will be replaced with 0, 1, 2, ...
		const char prompt[] = "[TTY #?]\n";

		const char* p = prompt;

		for(; *p; p++)
			out_char(tty->console, *p == '?' ? nr_tty + '0' : *p);
	}
	set_cursor(tty->console->cursor);
}
