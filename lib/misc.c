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
 * send_rev()
 *
 * <Ring 1~3> IPC syscall.
 * 
 * It is an encapsulation of `sendrec`.
 * Invoking `sendrec` directly should be in avoided.
 *
 * @param function: SEND, RECEIVE or BOTH
 * @param src_dest: The caller's proc_nr
 * @param msg: Pointer to the MESSAGE struct
 *
 * @return 0 always.
 *
 */
PUBLIC int send_recv(int function, int src_dest, MESSAGE* msg)
{
	int ret = 0;

	if(function == RECEIVE) {
		memset(msg, 0, sizeof(MESSAGE));
	}

	switch(function) {
		case BOTH:
			ret = sendrec(SEND, src_dest, msg);
			if(ret == 0)
				ret = sendrec(RECEIVE, src_dest, msg);
			break;
		case SEND:
		case RECEIVE:
			ret = sendrec(function, src_dest, msg);
			break;
		default:
			assert((function == BOTH) || (function == SEND) || (function == RECEIVE));
			break;		
	}

	return ret;
}

/**
 * memcmp
 * 
 * Compare memory areas.
 *
 * @param s1: The 1st area.
 * @param s2: The 2nd area.
 * @param n: The first n bytes will be compared.
 *
 * @return an integer less than or equal to or greater than 0 if the first
 *  	n bytes of s1 is found, respectively, to be less than, to match,
 *		or be greater then the first n bytes of s2.
 *
 */
PUBLIC int memcmp(const void* s1, const void* s2, int n)
{
	if((s1 == 0) || (s2 == 0)) {	/* for stablity( robustness) */
		return (s1 - s2);
	}

	const char* p1 = (const char*)s1;
	const char* p2 = (const char*)s2;

	int i;
	for(i = 0; i < n; i++, p1++, p2++) {
		if(*p1 != *p2)
			return (*p1 - *p2);
	}

	return 0;
}

/**
 * strcmp()
 *
 * Compare two strings.
 *
 * @param s1: The 1st string.
 * @param s2: The 2nd string.
 *
 * @return an integer less than or equal to or greater than zero if s1(or the first
 *		n bytes thereof) is found, respectively, to be less than, to match, or
 *		be greater than s2.
 *
 */
PUBLIC int strcmp(const char* s1, const char* s2)
{
	if((s1 == 0) || (s2 == 0)) {	/* for stablity( robustness) */
		return (s1 - s2);
	}

	const char* p1 = s1;
	const char* p2 = s2;

	for(; *p1 && *p2; p1++, p2++) {
		if(*p1 != *p2)
			break;
	}

	return (*p1 - *p2);
}

/**
 * strcat()
 *
 * Concatenate two strings.
 *
 * @param s1: The 1st string.
 * @param s2: The 2nd string.
 * @return Ptr: to the 1st string.
 *
 */
PUBLIC char* strcat(char* s1, const char* s2)
{
	if((s1 == 0) || (s2 == 0)) {	/* for stablity( robustness) */
		return 0;
	}

	char* p1 = s1;

	for(; *p1; p1++) {
		//
	}

	const char* p2 = s2;
	for(; *p2; p1++, p2++) {
		*p1 = *p2;
	}
	*p1 = 0;

	return s1;
}

/**
 * spin()
 *
 */
PUBLIC void spin(char* func_name)
{
	printl("\n spinning in %s ...\n", func_name);

	while(1) {
		//
	}
}
