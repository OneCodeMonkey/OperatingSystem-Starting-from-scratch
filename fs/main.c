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

/**
 * rw_sector()
 *
 * <Ring 1> R/W a sector via messaging with the corresponding driver.
 *
 * @param io_type: DEV_READ or DEV_WRITE
 * @param dev: device nr
 * @param pos: Byte offset from/to where to r/w.
 * @param bytes: r/w count in bytes.
 * @param proc_nr: To whom the buffer belongs.
 * @param buf: r/w buffer.
 * @return Zero if success.
 *
 */
 PUBLIC int rw_sector(int io_type, int dev, u64 pos, int bytes, int proc_nr, void* buf)
 {
 	// todo
 } 

 /**
  * read_super_block()
  *
  * <Ring 1> Read super block from the given device then write it into a free super_block[] slot.
  *
  * @param dev: From which device the super block comes.
  *
  */
 PRIVATE void read_super_block(int dev)
 {
 	// todo
 }
 