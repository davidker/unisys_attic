/* visorbus.h
 *
 * Copyright (C) 2010 - 2013 UNISYS CORPORATION
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

/*
 *  This header file is to be included by other kernel mode components that
 *  implement a particular kind of visor_device.  Each of these other kernel
 *  mode components is called a visor device driver.  Refer to visortemplate
 *  for a minimal sample visor device driver.
 *
 *  There should be nothing in this file that is private to the visorbus
 *  bus implementation itself.
 *
 */

#ifndef __VISORBUS_H__
#define __VISORBUS_H__

#include <linux/device.h>
#include <linux/module.h>
#include <linux/poll.h>
#include <linux/kernel.h>
#include <linux/uuid.h>
#include <linux/seq_file.h>
#include <linux/slab.h>

#include "channel.h"

struct visor_driver;
struct visor_device;
extern struct bus_type visorbus_type;

typedef void (*visorbus_state_complete_func) (struct visor_device *dev,
					      int status);
struct visorchipset_state {
	u32 created:1;
	u32 attached:1;
	u32 configured:1;
	u32 running:1;
	/* Add new fields above. */
	/* Remaining bits in this 32-bit word are unused. */
};

/** This struct describes a specific Supervisor channel, by providing its
 *  GUID, name, and sizes.
 */
struct visor_channeltype_descriptor {
	const uuid_le guid;
	const char *name;
};

/**
 * struct visor_driver - Information provided by each visor driver when it
 * registers with the visorbus driver.
 * @name:		Name of the visor driver.
 * @version:		The numbered version of the driver (x.x.xxx).
 * @vertag:		A human readable version string.
 * @owner:		The module owner.
 * @channel_types:	Types of channels handled by this driver, ending with
 *			a zero GUID. Our specialized BUS.match() method knows
 *			about this list, and uses it to determine whether this
 *			driver will in fact handle a new device that it has
 *			detected.
 * @probe:		Called when a new device comes online, by our probe()
 *			function specified by driver.probe() (triggered
 *			ultimately by some call to driver_register(),
 *			bus_add_driver(), or driver_attach()).
 * @remove:		Called when a new device is removed, by our remove()
 *			function specified by driver.remove() (triggered
 *			ultimately by some call to device_release_driver()).
 * @channel_interrupt:	Called periodically, whenever there is a possiblity
 *			that "something interesting" may have happened to the
 *			channel.
 * @pause:		Called to initiate a change of the device's state.  If
 *			the return valu`e is < 0, there was an error and the
 *			state transition will NOT occur.  If the return value
 *			is >= 0, then the state transition was INITIATED
 *			successfully, and complete_func() will be called (or
 *			was just called) with the final status when either the
 *			state transition fails or completes successfully.
 * @resume:		Behaves similar to pause.
 * @driver:		Private reference to the device driver. For use by bus
 *			driver only.
 * @version_attr:	Private version field. For use by bus driver only.
 */
struct visor_driver {
	const char *name;
	const char *version;
	const char *vertag;
	struct module *owner;
	struct visor_channeltype_descriptor *channel_types;
	int (*probe)(struct visor_device *dev);
	void (*remove)(struct visor_device *dev);
	void (*channel_interrupt)(struct visor_device *dev);
	int (*pause)(struct visor_device *dev,
		     visorbus_state_complete_func complete_func);
	int (*resume)(struct visor_device *dev,
		      visorbus_state_complete_func complete_func);

	/* These fields are for private use by the bus driver only. */
	struct device_driver driver;
	struct driver_attribute version_attr;
};

#define to_visor_driver(x) ((x) ? \
	(container_of(x, struct visor_driver, driver)) : (NULL))

/**
 * struct visor_device - A device type for things "plugged" into the visorbus
 * bus
 * visorchannel:		Points to the channel that the device is
 *				associated with.
 * channel_type_guid:		Identifies the channel type to the bus driver.
 * device:			Device struct meant for use by the bus driver
 *				only.
 * list_all:			Used by the bus driver to enumerate devices.
 * timer:		        Timer fired periodically to do interrupt-type
 *				activity.
 * being_removed:		Indicates that the device is being removed from
 *				the bus. Private bus driver use only.
 * visordriver_callback_lock:	Used by the bus driver to lock when handling
 *				channel events.
 * pausing:			Indicates that a change towards a paused state.
 *				is in progress. Only modified by the bus driver.
 * resuming:			Indicates that a change towards a running state
 *				is in progress. Only modified by the bus driver.
 * chipset_bus_no:		Private field used by the bus driver.
 * chipset_dev_no:		Private field used the bus driver.
 * state:			Used to indicate the current state of the
 *				device.
 * inst:			Unique GUID for this instance of the device.
 * name:			Name of the device.
 * pending_msg_hdr:		For private use by bus driver to respond to
 *				hypervisor requests.
 * vbus_hdr_info:		A pointer to header info. Private use by bus
 *				driver.
 * partition_uuid:		Indicates client partion id. This should be the
 *				same across all visor_devices in the current
 *				guest. Private use by bus driver only.
 */

struct visor_device {
	struct visorchannel *visorchannel;
	uuid_le channel_type_guid;
	/* These fields are for private use by the bus driver only. */
	struct device device;
	struct list_head list_all;
	struct timer_list timer;
	bool timer_active;
	bool being_removed;
	/* mutex to serialize visor_driver function callbacks */
	struct mutex visordriver_callback_lock;
	bool pausing;
	bool resuming;
	u32 chipset_bus_no;
	u32 chipset_dev_no;
	struct visorchipset_state state;
	uuid_le inst;
	u8 *name;
	struct controlvm_message_header *pending_msg_hdr;
	void *vbus_hdr_info;
	uuid_le partition_uuid;
};

#define to_visor_device(x) container_of(x, struct visor_device, device)

/**
 * visorbus_register_visor_driver() - registers the provided driver
 * @struct visor_driver *: the driver to register
 *
 * A particular type of visor driver calls this function to register
 * the driver.  The caller MUST fill in the following fields within the
 * #drv structure:
 *     name, version, owner, channel_types, probe, remove
 *
 * Here's how the whole Linux bus / driver / device model works.
 *
 * At system start-up, the visorbus kernel module is loaded, which registers
 * visorbus_type as a bus type, using bus_register().
 *
 * All kernel modules that support particular device types on a
 * visorbus bus are loaded.  Each of these kernel modules calls
 * visorbus_register_visor_driver() in their init functions, passing a
 * visor_driver struct.  visorbus_register_visor_driver() in turn calls
 * register_driver(&visor_driver.driver).  This .driver member is
 * initialized with generic methods (like probe), whose sole responsibility
 * is to act as a broker for the real methods, which are within the
 * visor_driver struct.  (This is the way the subclass behavior is
 * implemented, since visor_driver is essentially a subclass of the
 * generic driver.)  Whenever a driver_register() happens, core bus code in
 * the kernel does (see device_attach() in drivers/base/dd.c):
 *
 *     for each dev associated with the bus (the bus that driver is on) that
 *     does not yet have a driver
 *         if bus.match(dev,newdriver) == yes_matched  ** .match specified
 *                                                ** during bus_register().
 *             newdriver.probe(dev)  ** for visor drivers, this will call
 *                   ** the generic driver.probe implemented in visorbus.c,
 *                   ** which in turn calls the probe specified within the
 *                   ** struct visor_driver (which was specified by the
 *                   ** actual device driver as part of
 *                   ** visorbus_register_visor_driver()).
 *
 * The above dance also happens when a new device appears.
 * So the question is, how are devices created within the system?
 * Basically, just call device_add(dev).  See pci_bus_add_devices().
 * pci_scan_device() shows an example of how to build a device struct.  It
 * returns the newly-created struct to pci_scan_single_device(), who adds it
 * to the list of devices at PCIBUS.devices.  That list of devices is what
 * is traversed by pci_bus_add_devices().
 *
 * Return: integer indicating success (zero) or failure (non-zero)
 */
int visorbus_register_visor_driver(struct visor_driver *);

/**
 * visorbus_unregister_visor_driver() - unregisters the provided driver
 * @struct visor_driver *: the driver to unregister
 */
void visorbus_unregister_visor_driver(struct visor_driver *);

/**
 * visorbus_read_channel() - reads from the designated channel into
 *                           the provided buffer
 * @dev:    the device whose channel is read from
 * @offset: the offset into the channel at which reading starts
 * @dest:   the destination buffer that is written into from the channel
 * @nbytes: the number of bytes to read from the channel
 *
 * If receiving a message, use the visorchannel_signalremove()
 * function instead.
 *
 * Return: integer indicating success (zero) or failure (non-zero)
 */
int visorbus_read_channel(struct visor_device *dev,
			  unsigned long offset, void *dest,
			  unsigned long nbytes);

/**
 * visorbus_write_channel() - writes the provided buffer into the designated
 *                            channel
 * @dev:    the device whose channel is written to
 * @offset: the offset into the channel at which writing starts
 * @src:    the source buffer that is written into the channel
 * @nbytes: the number of bytes to write into the channel
 *
 * If sending a message, use the visorchannel_signalinsert()
 * function instead.
 *
 * Return: integer indicating success (zero) or failure (non-zero)
 */
int visorbus_write_channel(struct visor_device *dev,
			   unsigned long offset, void *src,
			   unsigned long nbytes);
/**
 * visorbus_enable_channel_interrupts() - enables interrupts on the
 *                                        designated device
 * @dev: the device on which to enable interrupts
 */
void visorbus_enable_channel_interrupts(struct visor_device *dev);

/**
 * visorbus_disable_channel_interrupts() - disables interrupts on the
 *                                         designated device
 * @dev: the device on which to disable interrupts
 */
void visorbus_disable_channel_interrupts(struct visor_device *dev);

/**
 * visorchannel_signalremove() - removes a message from the designated
 *                               channel/queue
 * @channel: the channel the message will be removed from
 * @queue:   the queue the message will be removed from
 * @msg:     the message to remove
 *
 * Return: boolean indicating whether the removal succeeded or failed
 */
bool visorchannel_signalremove(struct visorchannel *channel, u32 queue,
			       void *msg);

/**
 * visorchannel_signalinsert() - inserts a message into the designated
 *                               channel/queue
 * @channel: the channel the message will be added to
 * @queue:   the queue the message will be added to
 * @msg:     the message to insert
 *
 * Return: boolean indicating whether the insertion succeeded or failed
 */
bool visorchannel_signalinsert(struct visorchannel *channel, u32 queue,
			       void *msg);

/**
 * visorchannel_signalempty() - checks if the designated channel/queue
 *                              contains any messages
 * @channel: the channel to query
 * @queue:   the queue in the channel to query
 *
 * Return: boolean indicating whether any messages in the designated
 *         channel/queue are present
 */
bool visorchannel_signalempty(struct visorchannel *channel, u32 queue);

/**
 * visorchannel_get_uuid() - queries the UUID of the designated channel
 * @channel: the channel to query
 *
 * Return: the UUID of the provided channel
 */
uuid_le visorchannel_get_uuid(struct visorchannel *channel);

#define BUS_ROOT_DEVICE		UINT_MAX
struct visor_device *visorbus_get_device_by_id(u32 bus_no, u32 dev_no,
					       struct visor_device *from);
#endif
