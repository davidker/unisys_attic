/* Copyright (C) 2010 - 2013 UNISYS CORPORATION
 * All rights reserved.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or (at
 * your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY OR FITNESS FOR A PARTICULAR PURPOSE, GOOD TITLE or
 * NON INFRINGEMENT.  See the GNU General Public License for more
 * details.
 */

#ifndef __GUESTLINUXDEBUG_H__
#define __GUESTLINUXDEBUG_H__

/*
 * This file contains supporting interface for "vmcallinterface.h", particularly
 * regarding adding additional structure and functionality to linux
 * ISSUE_IO_VMCALL_POSTCODE_SEVERITY
 */

/******* INFO ON ISSUE_POSTCODE_LINUX() BELOW *******/
#ifdef __GNUC__

#define POSTCODE_SEVERITY_ERR DIAG_SEVERITY_ERR
#define POSTCODE_SEVERITY_WARNING DIAG_SEVERITY_WARNING
#define POSTCODE_SEVERITY_INFO DIAG_SEVERITY_PRINT
/* TODO-> Info currently doesn't show, so we set info=warning */

/* Write a 64-bit value to the hypervisor's log file
 * POSTCODE_LINUX generates a value in the form 0xAABBBCCCDDDDEEEE where
 *	A is an identifier for the file logging the postcode
 *	B is an identifier for the event logging the postcode
 *	C is the line logging the postcode
 *	D is additional information the caller wants to log
 *	E is additional information the caller wants to log
 * Please also note that the resulting postcode is in hex, so if you are
 * searching for the __LINE__ number, convert it first to decimal.  The line
 * number combined with driver and type of call, will allow you to track down
 * exactly what line an error occurred on, or where the last driver
 * entered/exited from.
 */

#define POSTCODE_LINUX(EVENT_PC, pc16bit1, pc16bit2, severity)		\
do {									\
	unsigned long long post_code_temp;				\
	post_code_temp = (((u64)CURRENT_FILE_PC) << 56) |		\
		(((u64)EVENT_PC) << 44) |				\
		((((u64)__LINE__) & 0xFFF) << 32) |			\
		((((u64)pc16bit1) & 0xFFFF) << 16) |			\
		(((u64)pc16bit2) & 0xFFFF);				\
	ISSUE_IO_VMCALL_POSTCODE_SEVERITY(post_code_temp, severity);	\
} while (0)

#endif
#endif
