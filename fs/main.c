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
#include "config.h"
#include "proto.h"

#include "hd.h"

PRIVATE void init_fs();
PRIVATE void mkfs();
PRIVATE void read_super_block(int dev);
PRIVATE int fs_fork();
PRIVATE int fs_exit();

/**
 * task_fs()
 *
 * <Ring 1> The main loop of TASK FS.
 *
 */
PUBLIC void task_fs()
{
	// todo
}

/**
 * init_fs()
 *
 * <Ring 1> Do some preparation.
 *
 */
PRIVATE void init_fs()
{
	// todo
}

/**
 * mkfs()
 *
 * <Ring 1> Make a available OS's FS in the disk. It will
 *	   - Write a super block to sector 1.
 * 	   - Create three special files: dev_tty0, dev_tty1, dev_tty2
 *	   - Create a file cmd.tar
 *     - Create the inode map
 * 	   - Create the sector map
 *	   - Create the inodes of the files
 *	   - Create '/', the root directory
 *
 */
PRIVATE void mkfs()
{
	// todo
}
