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

/**
 * i2a()
 *
 */
PRIVATE char* i2a(int val, int base, char** ps)
{
	int m = val % base;
	int q = val / base;

	if(q) {
		i2a(q, base, ps);
	}

	*(*ps)++ = (m < 10) ? (m + '0') : (m - 10 + 'A');

	return *ps;
}
