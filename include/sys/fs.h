/**
 * Header file for File System.
 *
 */
#ifndef _ORANGES_FS_H_
#define _ORANGES_FS_H_

/**
 * @struct dev_drv_map fs.h "include/sys/fs.h"
 * @brief The Device_nr.\ - Driver_nr.\ MAP.
 *
 */
struct dev_drv_map {
	int Driver_nr;	// The proc nr.\ of the device driver.
};

/**
 * @def MAGIC_V1
 * @brief Magic number of FS v1.0
 */
#define MAGIC_V1 0x111

/**
 * @struct super_block fs.h "include/sys/fs.h"
 * @brief The 2nd sector of the FS
 *
 * Remember to change SUPER_BLOCK_SIZE if the members are changed.
 *
 */
struct super_block {
	u32 magic;	// magic number
	u32 nr_inodes;	// How many inodes
	u32 nr_sects;	// How many sectors
	u32 nr_imap_sects;	// How many inode-map sectors
	u32 nr_smap_sects;	// How many sector-map sectors
	u32 n_1st_sect;	// Number of the 1st data sector
	u32 nr_inode_sects;	// How many inode sectors
	u32 root_inode;	// Inode nr of root directory
	u32 inode_size;	// INODE_SIZE
	u32 inode_isize_off;	// Offset of `struct inode::i_size`
	u32 inode_start_off;	// Offset of `struct inode::i_start_sect`
	u32 dir_ent_size;	// DIR_ENTRY_SIZE
	u32 dir_ent_inode_off;	// Offset of `struct dir_entry::inode_nr`
	u32 dir_ent_fname_off;	// Offset of `struct dir_entry::name`

	// the following items are present in memory
	int sb_dev;		// the super block's home device
};

/**
 * @def SUPER_BLOCK_SIZE
 * @brief The size of super block \b in \b the \b device.
 *
 * Note that this is the size of the struct in the device, \b NOT in memory.
 * The size in memory is larger because of some more members.
 *
 */
#define SUPER_BLOCK_SIZE 56

/**
 * @struct inode
 * @brief i-node
 *
 * The \c start_sect and \c nr_sects locate the file in the device,
 * and the size show how many bytes is used.
 * If <tt> size < (nr_sects * SECTOR_SIZE) </tt>, the rest bytes
 * are wasted and reserved for later writing.
 *
 * \b Note: Remember to change INODE_SIZE if the members are changed
 *
 */
struct inode{
	u32 i_mode;		// Access mode
	u32 i_size;		// File size
	u32 i_start_sect;	// The first sector of the data
	u32 i_nr_sects;		// How many sectors the file occupies
	u32 _unused[16];	// Stuff for alignment

	// The following items are only present in memory
	int i_dev;
	int i_cnt;		// How many procs share this inode
	int i_num;		// inode nr.
};

/**
 * @def INODE_SIZE
 * @brief The size of i-node stored \b in \b the \b device.
 *
 * Note: this is the size of the struct in the device, \b Not in memory.
 * The size in memory is larger because of some more members.
 *
 */
#define INODE_SIZE 32

/**
 * @def MAX_FILENAME_LEN
 * @brief Max len of a filename
 * @see dir_entry
 *
 */
#define MAX_FILENAME_LEN 12

/**
 * @struct dir_entry
 * @brief Directory entry
 *
 */
struct dir_entry {
	int inode_nr;	// inode nr.
	char name[MAX_FILENAME_LEN];
};

/**
 * @def DIR_ENTRY_SIZE
 * @brief The size of directory entry in the device.
 *
 * It is as same as the size in memory.
 *
 */
#define DIR_ENTRY_SIZE sizeof(struct dir_entry)

/**
 * @struct file_desc
 * @brief File Descriptor
 *
 */
struct file_desc {
	int fd_mode;	// R or N
	int fd_pos;		// Current position for R/W.
	int fd_cnt;		// How many procs share this desc
	struct inode* fd_inode;	// Ptr to the i-node
};

/**
 * Since all invocations of `rw_sector()` in FS look similar (most 
 * of the params are the same), we use this marco to make code more
 * readable
 *
 */
#define RD_SECT(dev, sect_nr) rw_sector(DEV_READ, dev, (sect_nr) * SECTOR_SIZE, \
										SECTOR_SIZE, /* READ ONE SECTOR*/ \
										TASK_FS, fsbuf);
#define WR_SECT(dev, sect_nr) rw_sector(DEV_WRITE, dev, (sect_nr) * SECTOR_SIZE, \
										SECTOR_SIZE, /* WRITE ONE SECTOR*/ \
										TASK_FS, fsbuf);

#endif
