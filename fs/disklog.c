#include "type.h"
#include "config.h"
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

#define DISKLOG_RD_SECT(dev, sect_nr) rw_sector(DEV_READ, \
			dev, (sect_nr) * SECTOR_SIZE, \
			SECTOR_SIZE,	/* read one sector */\
			getpid(), \
			logdiskbuf);
#define DISKLOG_WR_SECT(dev, sect_nr) rw_sector(DEV_WRITE, \
			dev, (sect_nr) * SECTOR_SIZE, \
			SECTOR_SIZE,	/* read one sector */\
			getpid(), \
			logdiskbuf);

/**
 * disklog()
 *
 * <Ring 1> Write log string directly into disk.
 *
 * @param p: Ptr to the MESSAGE.
 *
 */
PUBLIC int disklog(char* logstr)
{
	int device = root_inode->i_dev;
	struct super_block* sb = get_super_block(device);
	int nr_log_blk0_nr = sb->nr_sects - NR_SECTS_FOR_LOG;

	static int pos = 0;
	if(!pos) {		/* first time invoking this routine */
#ifdef SET_LOG_SECT_SMAP_AT_STARTUP
	/* set sector-map so that other files cannot use the log sectors */
		int bits_per_sect = SECTOR_SIZE * 8;	/* 4096 */
		int smap_blk0_nr = 1 + 1 + sb->nr_imap_sects;	/* 3 */
		int sect_nr = smap_blk0_nr + nr_log_blk0_nr / bits_per_sect;	/* 3+9=12 */
		int byte_off = (nr_log_blk0_nr % bits_per_sect) / 8;
		int bit_off = (nr_log_blk0_nr % bits_per_sect) % 8;
		int sect_off = NR_SECTS_FOR_LOG / bits_per_sect + 2;
		int bit_left = NR_SECTS_FOR_LOG;

		int i;

		for(i = 0; i < sect_cnt; i++) {
			DISKLOG_RD_SECT(device, sect_nr + i);
			for(; byte_off < SECTOR_SIZE && bit_left > 0; byte_off++) {
				for(; byte_off < 8; byte_off++) {	/* repeat till enough bits are set */
					assert(((logdiskbuf[byte_off] >> bit_off) & 1) == 0);
					
				}
			}
		} 
	}
}
