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
enum driver_pc {		/* POSTCODE driver identifier tuples */
	/* visorbus driver files */
	VISOR_BUS_PC = 0xF0,
	VISOR_BUS_PC_visorbus_main_c = 0xFF,
	VISOR_BUS_PC_visorchipset_c = 0xFE,
};

enum event_pc {			/* POSTCODE event identifier tuples */
	BUS_CREATE_ENTRY_PC = 0x001,
	BUS_CREATE_FAILURE_PC = 0x002,
	BUS_CREATE_EXIT_PC = 0x003,
	BUS_CONFIGURE_ENTRY_PC = 0x004,
	BUS_CONFIGURE_FAILURE_PC = 0x005,
	BUS_CONFIGURE_EXIT_PC = 0x006,
	CHIPSET_INIT_ENTRY_PC = 0x007,
	CHIPSET_INIT_SUCCESS_PC = 0x008,
	CHIPSET_INIT_FAILURE_PC = 0x009,
	CHIPSET_INIT_EXIT_PC = 0x00A,
	CONTROLVM_INIT_FAILURE_PC = 0x00B,
	DEVICE_CREATE_ENTRY_PC = 0x00C,
	DEVICE_CREATE_FAILURE_PC = 0x00D,
	DEVICE_CREATE_SUCCESS_PC = 0x00E,
	DEVICE_CREATE_EXIT_PC = 0x00F,
	DEVICE_ADD_PC = 0x010,
	DEVICE_REGISTER_FAILURE_PC = 0x011,
	DEVICE_CHANGESTATE_FAILURE_PC = 0x012,
	DRIVER_ENTRY_PC = 0x013,
	DRIVER_EXIT_PC = 0x014,
	MALLOC_FAILURE_PC = 0x015,
	CRASH_DEV_ENTRY_PC = 0x016,
	CRASH_DEV_EXIT_PC = 0x017,
	CRASH_DEV_RD_BUS_FAIULRE_PC = 0x018,
	CRASH_DEV_RD_DEV_FAIULRE_PC = 0x019,
	CRASH_DEV_BUS_NULL_FAILURE_PC = 0x01A,
	CRASH_DEV_DEV_NULL_FAILURE_PC = 0x01B,
	CRASH_DEV_CTRL_RD_FAILURE_PC = 0x01C,
	CRASH_DEV_COUNT_FAILURE_PC = 0x01D,
	SAVE_MSG_BUS_FAILURE_PC = 0x01E,
	SAVE_MSG_DEV_FAILURE_PC = 0x01F,
};

#ifdef __GNUC__

#define POSTCODE_SEVERITY_ERR DIAG_SEVERITY_ERR
#define POSTCODE_SEVERITY_WARNING DIAG_SEVERITY_WARNING
/* TODO-> Info currently doesn't show, so we set info=warning */
#define POSTCODE_SEVERITY_INFO DIAG_SEVERITY_PRINT

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
