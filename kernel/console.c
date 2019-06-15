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

/**
 *	out_char
 *
 *	Print a char in a certain console.
 *
 *	@param con: The console to which the char is printed.
 *	@param ch: The char to print.
 */
PUBLIC void out_char(CONSOLE* con, char ch)
{
	u8* pch = (u8*)(V_MEM_BASE + con->cursor * 2);

	assert(con->cursor - con->orig < con->con_size);

	// calculate the coordinate of cursor in current console( not in current screen)
	int cursor_x = (con->cursor - con->orig) % SCR_WIDTH;
	int cursor_y = (con->cursor - con->orig) / SCR_WIDTH;

	switch(ch) {
		case '\n':
			con->cursor = con->orig + SCR_WIDTH * (cursor_y + 1);
			break;
		case '\b':
			if(con->cursor > con->orig) {
				con->cursor--;
				*(pch - 2) = ' ';
				*(pch - 1) = DEFAULT_CHAR_COLOR;
			}
			break;
		default:
			*pch++ = ch;
			*pch++ = DEFAULT_CHAR_COLOR;
			con->cursor++;
			break;
	}

	if(con->cursor - con->orig >= con->con_size) {
		cursor_x = (con->cursor - con->orig) % SCR_WIDTH;
		cursor_y = (con->cursor - con->orig) / SCR_WIDTH;
		int cp_orig = con->orig + (cursor_y + 1) * SCR_WIDTH - SCR_SIZE;
		w_copy(con->orig, cp_orig, SCR_SIZE - SCR_WIDTH);
		con->crtc_start = con->orig;
		con->cursor = con->orig + (SCR_SIZE - SCR_WIDTH) + cursor_x;

		clear_screen(con->cursor, SCR_WIDTH);

		if(!con->is_full)
			con->is_full = 1;
	}

	assert(con->cursor - con->orig < con->con_size);

	while(con->cursor >= con->crtc_start + SCR_SIZE || con->cursor < con->crtc_start) {
		scroll_screen(con, SCR_UP);

		clear_screen(con->cursor, SCR_WIDTH);
	}

	flush(con);
}	
