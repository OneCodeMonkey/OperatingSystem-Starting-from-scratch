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
	printl("{FS} task fs begins.\n");

	init_fs();

	while(1) {
		send_recv(RECEIVE, ANY, &fs_msg);
		int msgtype = fs_msg.type;
		int src = fs_msg.source;
		pcaller = &proc_table[src];

		switch(msgtype) {
			case OPEN:
				fs_msg.FD = do_open();
				break;
			case CLOSE:
				fs_msg.RETVAL = do_close();
				break;
			case READ:
			case WRITE:
				fs_msg.CNT = do_rdwt();
				break;
			case UNLINK:
				fs_msg.RETVAL = do_unlink();
				break;
			case RESUME_PROC:
				src = fs_msg.PROC_NR;
				break;
			case FORK:
				fs_msg.RETVAL = fs_fork();
				break;
			case EXIT:
				fs_msg.RETVAL = fs_exit();
				break;
			case LSEEK:
				fs_msg.OFFSET = do_lseek();
				break;
			case STAT:
				fs_msg.RETVAL = do_stat();
				break;
			default:
				dump_msg("FS::unknown message:", &fs_msg);
				assert(0);
				break;
		}

#ifdef ENABLE_DISK_LOG
		char* msg_name[128];
		msg_name[OPEN] = "OPEN";
		msg_name[CLOSE] = "CLOSE";
		msg_name[READ] = "READ";
		msg_name[WRITE] = "WRITE";
		msg_name[LSEEK] = "LSEEK";
		msg_name[UNLINK] = "UNLINK";
		msg_name[FORK] = "FORK";
		msg_name[EXIT] = "EXIT";
		msg_name[STAT] = "STAT";

		switch(msgtype) {
			case UNLINK:
				dump_fd_graph("%s just finished.(pid:%d)", msg_name[msgtype], src);
			case OPEN:
			case CLOSE:
			case READ:
			case WRITE:
			case FORK:
			case EXIT:
			case LSEEK:
			case STAT:
				break;
			case RESUME_PROC:
				break;
			default:
				assert(0);
		}
#endif

		if(fs_msg.type != SUSPEND_PROC) {
			fs_msg.type = SYSCALL_RET;
			send_recv(SEND, src, &fs_msg);
		}
	}
}

/**
 * init_fs()
 *
 * <Ring 1> Do some preparation.
 *
 */
PRIVATE void init_fs()
{

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

/**
 * get_super_block()
 *
 * <Ring 1> Get the super block from super_block[]
 * @param dev: Device nr.
 * @return  The ptr of super block.
 *
 */
PUBLIC struct super_block* get_super_block(int dev)
{
	// todo
}

/**
 * get_inode()
 *
 * <Ring 1> Get the inode ptr of given inode nr. A cache -- inode_table[] -- is maintained to make things faster.
 * If the inode requested is already there, just return it.
 * Otherwise the inode will be read from the disk.
 *
 * @param dev: Device nr.
 * @param num: I-node nr.
 * @return  The inode ptr requested.
 *
 */
PUBLIC struct inode* get_inode(int dev, int num)
{
	// todo
}

/**
 * put_inode()
 *
 * Decrease the reference nr of a slot in inode_table[]. When the nr
 * reaches zero, it means the inode is not used any more and can be overwritten by a new inode.
 *
 * @param pinode: I-node ptr.
 *
 */
PUBLIC void put_inode(struct inode* pinode)
{
	// todo
}

/**
 * sync_inode()
 *
 * <Ring 1> Write the inode back to the disk. Commonly invoked as soon as the inode is changed.
 *
 * @param p: I-node ptr.
 *
 */
PUBLIC void sync_inode(struct inode* p)
{
	// todo
}

/**
 * fs_fork()
 *
 * Perform the aspects of fork() that relate to files.
 *
 * @return Zero if success, -1 otherwise.
 *
 */
PRIVATE int fs_fork()
{
	// todo
}

/**
 * fs_exit()
 *
 * Perform the aspects of exit() that relate to files.
 *
 * @return Zero if success.
 *
 */
PRIVATE int fs_exit()
{
	// todo
}
