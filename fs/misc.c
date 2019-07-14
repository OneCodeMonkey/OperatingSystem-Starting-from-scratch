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
#include "hd.h"
#include "fs.h"

/**
 * do_stat()
 *
 * Perform the stat() syscall.
 *
 * @return: Zero if success, -1 when error occurs.
 * 
 */
PUBLIC int do_stat()
{
	char pathname[MAX_PATH];	/* parameter from the caller */
	char filename[MAX_PATH];	/* directory has been stipped */

	/* get parameters from the message */
	int name_len = fs_msg.NAME_LEN;		/* length of filename */
	int src = fs_msg.source;		/* caller proc nr. */
	assert(name_len < MAX_PATH);
	phys_copy((void*)va2la(TASK_FS, pathname), (void*)va2la(src, fs_msg.PATHNAME), name_len);

	pathname[name_len] = 0;		/* terminate the string */
	int inode_nr = search_file(pathname);
	if(inode_nr == INVALID_INODE) {		/* file not found */
		printl("{FS} FS::do_stat():: search_file() returns invalid inode: %s\n", pathname);
		return -1;
	}

	struct inode* pin = 0;
	struct inode* dir_inode;

	if(strip_path(filename, pathname, &dir_inode) != 0) {
		/* theoretically never fail here(it would have failed earlier when search_file() called) */
		assert(0);
	}

	pin = get_inode(dir_inode->i_dev, inode_nr);

	struct stat s;		/* the thing requested */
	s.st_dev = pin->i_dev;
	s.st_ino = pin->i_num;
	s.st_mode = pin->i_mode;
	s.st_rdev = is_special(pin->i_mode) ? pin->i_start_sect : NO_DEV;
	s.st_size = pin->i_size;

	put_inode(pin);

	phys_copy((void*)va2la(src, fs_msg.BUF), (void*)va2la(TASK_FS, &s), sizeof(struct stat));

	return 0;
}
