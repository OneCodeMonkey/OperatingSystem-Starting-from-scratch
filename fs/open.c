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

PRIVATE struct inode* create_file(char* path, int flags);
PRIVATE int alloc_imap_bit(int dev);
PRIVATE int alloc_smap_bit(int dev, int nr_sects_to_alloc);
PRIVATE struct inode* new_inode(int dev, int inode_nr, int start_sect);
PRIVATE void new_dir_entry(struct inode* dir_inode, int inode_nr, char* filename);

/**
 * do_open()
 *
 * Open a file and return the file descriptor.
 * @return File descriptor if success, -1 when error occurs.
 *
 */
PUBLIC int do_open()
{
	// todo
}

/**
 * create_file()
 *
 * Create a file and return it's inode ptr.
 *
 * @param[in] path: The full path of the new file
 * @param[in] flags: Attributes of the new file
 * @return Ptr to i-node of the new file if success, otherwise return 0.
 *
 * @see open()
 * @see do_open()
 *
 */
PRIVATE struct inode* create_file(char* path, int flags)
{
	// todo
}

/**
 * do_close()
 *
 * Handle the message CLOSE.
 *
 * @return Zero if success.
 *
 */
PUBLIC int do_close()
{
	// todo
}

/**
 * do_lseek()
 *
 * Handle the message LSEEK.
 *
 * @return The new offset in bytes from the beginning of the file if success, -1 otherwise.
 *
 */
PUBLIC int do_lseek()
{
	// todo
}

/**
 * alloc_imap_bit()
 *
 * Allocate a bit in inode-map.
 *
 * @param dev: In which device the inode-map is located.
 * @return I-node nr.
 *
 */
PRIVATE int alloc_imap_bit(int dev)
{
	// todo
}

/**
 * alloc_smap_bit()
 *
 * Allocate a bit in sector-map.
 *
 * @param dev: In which device the sector-map is located.
 * @param nr_sects_to_alloc: How many sectors are allocated.
 * @return I-node nr.
 *
 */
PRIVATE int alloc_smap_bit(int dev, int nr_sects_to_alloc)
{
	// todo
}

/**
 * new_inode()
 *
 * Generate a new i-node and write it to disk.
 *
 * @param dev: Home device of the i-node.
 * @param inode_nr: I-node nr.
 * @param start_sect: Start sector of the file pointed by the new i-node.
 * @return Ptr of the new i-node.
 *
 */
PRIVATE struct inode* new_inode(int dev, int inode_nr, int start_sect)
{
	// todo
}

/**
 * new_dir_entry()
 *
 * Write a new entry into the directory.
 *
 * @param dir_inode: I-node of the directory.
 * @param inode_nr: I-node nr of the new file.
 * @param filename: Filename of the new file.
 *
 */
PRIVATE void new_dir_entry(struct inode* dir_inode, int inode_nr, char* filename)
{
	// todo
}
