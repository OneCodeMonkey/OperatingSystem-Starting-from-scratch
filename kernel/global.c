# define GLOBAL_VARIABLES_HERE

# include "type.h"
# include "stdio.h"
# include "const.h"
# include "protect.h"
# include "fs.h"
# include "tty.h"
# include "console.h"
# include "proc.h"
# include "global.h"
# include "proto.h"

PUBLIC struct proc proc_table[NR_TASKS + NR_PROCS];

// 注意下面 TASK 书顺序要与 const.h 中对应
PUBLIC struct task task_table[NR_TASKS] = {
	/* entry		stack_size		task_name */
	/* -----		----------		--------- */
	{task_tty,		STACK_SIZE_TTY,	"TTY"		},
	{task_sys,		STACK_SIZE_SYS,	"SYS"		},
	{task_hd,		STACK_SIZE_HD,	"HD"		},
	{task_fs,		STACK_SIZE_FS,	"FS"		},
	{task_mm,		STACK_SIZE_MM,	"MM"		}
};