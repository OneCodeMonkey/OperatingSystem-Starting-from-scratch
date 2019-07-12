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

