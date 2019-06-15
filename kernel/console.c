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
