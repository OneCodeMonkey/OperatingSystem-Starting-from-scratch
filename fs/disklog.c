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
					logdiskbuf[byte_off] |= (1 << bit_off);
					if(--bits_left == 0)
						break;
				}
				bit_off = 0;
			}
			byte_off = 0;
			bit_off = 0;

			DISKLOG_WR_SECT(device, sect_nr + i);

			if(bits_left == 0)
				break;
		}
		assert(bits_left == 0);
#endif

		pos = 0x40;

#ifdef MEMSET_LOG_SECTS
		int chunk = min(MAX_IO_BYTES, LOGDISKBUF_SIZE >> SECTOR_SIZE_SHIFT);
		assert(chunk == 256);
		int sects_left = NR_SECTS_FOR_LOG;
		for(i = nr_log_blk0_nr; i < nr_log_blk0_nr + NR_SECTS_FOR_LOG; i += chunk) {
			memset(logdiskbuf, 0x20, chunk * SECTOR_SIZE);
			rw_sector(DEV_WRITE, device, i * SECTOR_SIZE, chunk * SECTOR_SIZE, getpid(), logdiskbuf);
			sects_left -= chunk;
		}
		if(sects_left != 0)
			panic("sects_left should be 0, current: %d.", sects_left);
#endif	
	}

	char* p = logstr;
	int bytes_left = strlen(logstr);
	int sect_nr = nr_log_blk0_nr + (pos >> SECTOR_SIZE_SHIFT);

	while(bytes_left) {
		DISKLOG_RD_SECT(device, sect_nr);
		int off = pos % SECTOR_SIZE;
		int bytes = min(byte_left, SECTOR_SIZE - off);
		memcpy(&logdiskbuf[off], p, bytes);
		off += bytes;
		bytes_left -= bytes;

		DISKLOG_WR_SECT(device, sect_nr);
		sect_nr++;
		pos += bytes;
		p += bytes;
	}

	struct time t;
	MESSAGE msg;
	msg.type = GET_RTC_TIME;
	msg.BUF = &t;
	send_recv(BOTH, TASK_SYS, &msg);

	/* write `pos` and time into the log file header */
	DISKLOG_RD_SECT(device, nr_log_blk0_nr);

	sprintf((char*)logdiskbuf, "%8d\n", pos);
	memset(logdiskbuf + 9, ' ', 22);
	logdiskbuf[31] = '\n';

	sprintf((char*)logdiskbuf + 32, "<%d-%02d-%02d %02d:%02d:%02d>\n", \
		t.year,
		t.month,
		t.day,
		t.hour,
		t.minute,
		t.second);
	memset(logdiskbuf + 32 + 22, ' ', 9);
	logdiskbuf[63] = '\n';

	DISKLOG_WR_SECT(device, nr_log_blk0_nr);
	memset(logdiskbuf + 64, logdiskbuf[32 + 19], 512 - 64);
	DISKLOG_WR_SECT(device, nr_log_blk0_nr + NR_SECTS_FOR_LOG - 1);

	return pos;
}

