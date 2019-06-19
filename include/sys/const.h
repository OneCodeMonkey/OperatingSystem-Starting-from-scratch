#ifndef _ORANGES_CONST_H_
#define _ORANGES_CONST_H_

#define max(a,b) ((a) > (b) ? (a) : (b))
#define min(a,b) ((a) < (b) ? (a) : (b))

/**
 * Color
 * eg. MAKE_COLOR(BLUE, RED)
 *	   MAKE_COLOR(BLACK, RED) | BRIGHT
 *	   MAKE_COLOR(BLACK, RED) | BRIGHT | FLASH
 *
 */
#define BLACK 0x0	// 0000
#define WHITE 0x7	// 0111
#define RED	0x4		// 0100
#define GREEN 0x2	// 0010
#define BLUE 0x1	// 0001
#define FLASH 0x80	// 1000 0000
#define BRIGHT 0x80	// 0000 1000
#define MAKE_COLOR(x,y) ((x<<4) | y)	// MAKE_COLOR(Background,Foreground)

// GDT 和 IDT 中描述符的个数
#define GDT_SIZE 128
#define IDT_SIZE 256

// 权限
#define PRIVILEGE_KRNL	0
#define PRIVILEGE_TASK 	1
#define PRIVILEGE_USER	3

// RPL
#define RPL_KRNL SA_RPL0
#define RPL_TASK SA_RPL1
#define RPL_USER SA_RPL3

// Process
#define SENDING 0x02	// set when proc trying to send
#define RECEIVING 0x04	// set when proc trying to recv
#define WAITING 0x08 	// set when proc waiting for the child to terminate
#define HANGING 0x10	// set when proc exits without being waited by parent
#define FREE_SLOT 0x20 	// set when proc table entry is not used (ok to allocated to a new process)

// tty
#define	NR_CONSOLES 3	// consoles

// 8259A interrupt controller ports.
#define INT_M_CTL 0x20 	// I/O port for interrupt controller <Master>
#define INT_M_CTLMASK 0x21 	// setting bits in this port disables ints <Master>
#define INT_S_CTL 0xA0	// I/O port for second interrupt controller <Slave>
#define INT_S_CTL_MASK 0xA1 // setting bits in this port disbales ints <Slave>

// 8253/8254 PIT (programmable Interval Timer)
#define TIMER0	0x40 	// I/O port for timer channel 0
#define TIMER_MODE 0x43 // I/O port for timer mode control
#define RATE_GENERATOR 0x34 // 00-11-010-0: Counter0 - LSB then MSB - rate generator - binary
#define TIMER_FREQ 1193182L // clock frequency for timer in PC and AT
#define HZ 100	// clock freq (software settable on IBM-PC)

// AT keyboard
// 8042 ports
#define KB_DATA 0x60 /* I/O port for keyboard data.
						Read: Read Output Buffer
						Write: Write Input Buffer(8042 Data&8048 Command) */
#define KB_CMD	0x64 /* I/O port for keyboard command
						Read: Read Status Register
						Write: Write Input Buffer(8042 Command) */
#define LED_CODE 0xED
#define KB_ACK 0xFA

// VGA
#define CRTC_ADDR_REG 0x3D4	// CRT Controller Registers - Addr Register
#define CRTC_DATA_REG 0x3D5	// CRT Controller Registers - Data Register
#define START_ADDR_H 0xC // reg index of video mem start addr (MSB)
#define START_ADDR_L 0xD // reg index of video mem start addr (LSB)
#define CURSOR_H 0xE // reg index of cursor position (MSB)
#define CURSOR_L 0xF // reg index of cursor position (LSB)
#define V_MEM_BASE 0xB8000	// base of color video memory
#define V_MEM_SIZE 0x8000 // 32K: B8000H -> BFFFFH

// CMOS
#define CLK_ELE 0x70 /* CMOS RAM addr register port (write only)
						Bit 7 = 1 NMI disable
							0 NMI enable
						Bits 6-0 = RAM addr
					 */
#define CLK_IO 0x71	// CMOS RAM data register port(read/write)

#define YEAR 9	// Clock Register addresses in CMOS RAM
#define MONTH 8
#define Day 7
#define HOUR 4
#define MINUTE 2
#define SECOND 0
#define CLK_STATUS 0x0B // Status register B: RTC configuration
#define CLK_HEALTH 0x0E	/* Diagnostic status: (should be set by Power On Self-Test [POST])
						   Bit 7 = RTC lost power
						   	   6 = CheckSum(for addr 0x10-0x2d) bad
						   	   5 = Config. Info. bad at POST
						   	   4 = Mem. size error at POST
						   	   3 = I/O board failed initialization
						   	   2 = CMOS time invalid
						   	   1,0 reserved
						*/
// Hardware interrupts
#define NR_IRQ 16 // Number of IRQs
#define CLOCK_IRQ 0
#define KEYBOARD_IRQ 1
#define CASCADE_IRQ 2	// cascade enable for 2nd AT controller
#define ETHER_IRQ 3	// default ethernet interrupt vector
#define SECONDARY_IRQ 3	// RS232 interrupt vector for port 2
#define RS232_IRQ 4	// RS232 interrupt vector for port 1
#define XT_WINI_IRQ 5	// xt winchester
#define FLOPPY_IRQ 6	// floppy disk
#define PRINTER_IRQ 7
#define AT_WINI_IRQ 14	// at winchester

// task
// 注意 TASK_XXX 定义要与 global.c 中的对应
#define INVALID_DRIVER -20
#define INTERRUPT -10
#define TASK_TTY 0
#define TASK_SYS 1
#define TASK_HD 2
#define TASK_FS 3
#define TASK_MM 4
#define INIT 5
#define ANY (NR_TASKS + NR_PROCS + 10)
#define NO_TASK (NR_TASKS + NR_PROCS + 20)

#define MAX_TICKS 0x7FFFABCD

// system call
#define NR_SYS_CALL 3