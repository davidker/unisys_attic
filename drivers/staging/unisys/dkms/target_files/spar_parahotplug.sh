#!/bin/sh
#
# Copyright (c) 2013 - 2015 UNISYS CORPORATION
# All rights reserved.
#
#
# This script disables or enables a pci device by unbinding or rebinding it from its driver.
# For disables, it first saves the driver's name in /tmp.  For enables, it reads the driver's
# name from /tmp (so it knows what driver to bind).
# It expects the following input in the form of externally defined variables:
#  SPAR_PARAHOTPLUG_STATE: 0 indicates a disable, 1 indicates an enable
#  SPAR_PARAHOTPLUG_PARTITION: partition number of this guest
#  SPAR_PARAHOTPLUG_GRACEFUL: 1 indicates a graceful request, 0 otherwise; for SR-IOV VFs,
#    "graceful" means the PF driver is up and running. This is not currently used. 
#  SPAR_PARAHOTPLUG_BUS: PCI bus # of device
#  SPAR_PARAHOTPLUG_DEVICE: PCI device # of device
#  SPAR_PARAHOTPLUG_FUNCTION: PCI function # of device

# ID for "device enabled failed" call home.  Must match duplicated definition in common/include/channels/EventLogMessages.h
dev_enable_failed=0xC00007D5

# Optional user-script name to call in the case of failed device enables
dev_enable_failed_user_script="/usr/local/sbin/spar_devenable_failed.sh"

# Directory the pci devices are found in.
dev_dir="/sys/bus/pci/devices"

# Temp directory we'll use to store driver names.
temp_dir="/tmp/spar/parahotplug"

# Bus/device/function of indicated device.
bdf=$(printf "0000:%02x:%02x.%01x" $SPAR_PARAHOTPLUG_BUS $SPAR_PARAHOTPLUG_DEVICE $SPAR_PARAHOTPLUG_FUNCTION)

if [ "$SPAR_PARAHOTPLUG_STATE" = 0 ]
then
	# Disable the device by unbinding it from its driver (if it's already bound).
	if [ -e $dev_dir/$bdf/driver ]
	then
		# Now save off the driver name so we know what to do when we get an "enable" later.
		mkdir -p $temp_dir
		rm -rf $temp_dir/$bdf
		driver=$(readlink -f $dev_dir/$bdf/driver)
		driver_name=$(basename "$driver")
		echo $driver > $temp_dir/$bdf

		vendor=$(cat $dev_dir/$bdf/vendor)
		device=$(cat $dev_dir/$bdf/device)

		# Unbind the device from the driver.
		echo $bdf > $driver/unbind
		logger "spar_parahotplug: disabled $bdf (unbound from $driver)"
	else
		logger "spar_parahotplug: tried to disable $bdf, but it's already disabled"
	fi

elif [ "$SPAR_PARAHOTPLUG_STATE" = 1 ]
then
	# Enable the specified device by rebinding the driver.  The name of the driver
	# should have been saved off in $temp_dir/$bdf during the "disable"; if it's
	# not there, then the device hasn't been previously disabled and it's safe to
	# do nothing.

	if [ -e $temp_dir/$bdf ]
	then
		driver=$(cat $temp_dir/$bdf);

		# Clean up the temp directory so we don't get confused next time.
		rm -rf $temp_dir/$bdf

		if [ -e $dev_dir/$bdf ]
		then
			if [ -e $driver ]
			then
				# Bind the device to the driver
				echo $bdf > $driver/bind
				logger "spar_parahotplug enabled $bdf (rebound to $driver)"
			else
				logger "spar_parahotplug: tried to enable $bdf, but invalid driver name ($driver) in $temp_dir"
			fi
		else
			logger "spar_parahotplug: tried to enable $bdf, but it doesn't exist"
		fi
	else
		driver="unknown"
		logger "spar_parahotplug: tried to enable $bdf, but driver name not in $temp_dir"
	fi

else
	logger "spar_parahotplug: bad state ($SPAR_PARAHOTPLUG_STATE)"
fi

# Sleep for a bit to allow sysfs to update
sleep .1

if [ -e $dev_dir/$bdf/driver ]
then
	logger "spar_parahotplug: reporting $bdf is enabled"
	enabled=1
else
	logger "spar_parahotplug: reporting $bdf is not enabled"
	enabled=0

	if [ "$SPAR_PARAHOTPLUG_STATE" = 1 ]
	then
		# If we get here for an enable request, then for whatever reason our attempts above to do the
		# enable have failed.  In other words, the device should be enabled but is not, which is a
		# serious problem.  Notify the user by issuing a Call Home.
		echo $dev_enable_failed 1 3 $bdf $driver $SPAR_PARAHOTPLUG_PARTITION > /proc/uislib/callhome

		# Call the user-created script (if it exists) to perform a custom response to a device enable failure.
		if [ -e $dev_enable_failed_user_script ]
		then
			$dev_enable_failed_user_script
		fi
	fi
fi

echo "$SPAR_PARAHOTPLUG_ID $enabled" > /proc/visorchipset/parahotplug

exit 0

