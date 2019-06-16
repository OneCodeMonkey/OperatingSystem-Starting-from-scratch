/**
 *	Hard disk driver.
 *
 * 	The `device nr` in this file means minor device nr.
 *
 */
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
#include "proto.h"
#include "hd.h"

PRIVATE void init_hd	();
PRIVATE void hd_open	(int device);
PRIVATE void hd_close	(int device);
PRIVATE void hd_rdwt	(MESSAGE * p);
PRIVATE void hd_ioctl	(MESSAGE * p);
PRIVATE void hd_cmd_out	(struct hd_cmd* cmd);
PRIVATE void get_part_table		(int drive, int sect_nr, struct part_ent * entry);
PRIVATE void partition	(int device, int style);
PRIVATE int waitfor		(int mask, int val, int timeout);
PRIVATE void interrupt_wait	();
PRIVATE void hd_identify	(int drive);
PRIVATE void print_identify_info	(u16* hdinfo);

PRIVATE u8	hd_status;
PRIVATE u8	hdbuf[SECTOR_SIZE * 2];
PRIVATE struct hd_info	hd_info[1];

#define	DRV_OF_DEV(dev)	(dev <= MAX_PRIM ? dev/NR_PRIM_PER_DRIVE : (dev - MINOR_hd1a) / NR_SUB_PER_DRIVE)

/**
 * task_hd
 *
 * Main loop of HD driver.
 */
PUBLIC void task_hd()
{
	MESSAGE msg;
	
	init_hd();

	while(1) {
		send_recv(RECEIVE, ANY, &msg);

		int src = msg.source;

		switch(msg.type) {
			case DEV_OPEN:
				hd_open(msg.DEVICE);
				break;
			case DEV_CLOSE:
				hd_close(msg.DEVICE);
				break;
			case DEV_READ:
			case DEV_WRITE:
				hd_rdwt(&msg);
				break;
			case DEV_IOCTL:
				hd_ioctl(&msg);
				break;
			default:
				dump_msg("HD driver::unknown msg", &msg);
				spin("FS::main_loop (invalid msg type)");
				break;			
		}

		send_rect(SEND, src, &msg);
	}
}

/**
 * init_hd
 *
 * <Ring 1> Check hard drive, set IRQ handler, enable IRQ and initialize data
 *
 */
PRIVATE void init_hd()
{
	int i;

	// get the number of drivers from the BIOS data area
	u8 * pNrDrives = (u8*)(0x475);
	printl("{HD} pNrDrives:%d.\n", *pNrDrives);
	assert(*pNrDrives);

	put_irq_handler(AT_WINI_IRQ, hd_handler);
	enable_irq(CASCADE_IRQ);
	enable_irq(AT_WINI_IRQ);

	for(i = 0; i < (sizeof(hd_info)/sizeof(hd_info[0])); i++)
		memset(&hd_info[i], 0, sizeof(hd_info[0]));
	hd_info[0].open_cnt = 0;
}

/**
 * hd_open
 *
 * <Ring 1> This routine handles DEV_OPEN message. It identify the drive
 * of the given device and read the partition table of the drive 
 * if it has not been read.
 *
 * @param device: The device to be opened.
 *
 */
PRIVATE void hd_open(int device)
{
	int drive = DRV_OF_DEV(device);
	// only one drive
	asset(drive == 0);

	hd_identify(drive);

	if(hd_info[drive].open_cnt++ == 0) {
		partition(drive * (NR_PART_PER_DRIVE + 1), P_PRIMARY);
	}
}
