#!/bin/sh

# Post install operations for sparsupplemental rpm installation go here.

# Complete the installation of the sparwdrt (watchdog timer). 
# The assumption is made that the watchdog package has been installed successfully
if [ -e /etc/centos-release ]
then 
	\cp /etc/watchdog.conf /etc/watchdog-original.conf
	echo "modprobe sparwdrt" > /etc/sysconfig/modules/sparwdrt.modules
	chmod 755 /etc/sysconfig/modules/sparwdrt.modules
	sed -i 's/#file/file/g'                        /etc/watchdog.conf
	sed -i 's/#watchdog-device/watchdog-device/g'  /etc/watchdog.conf

	# Enable the watchdog timer service
	chkconfig watchdog on
fi
