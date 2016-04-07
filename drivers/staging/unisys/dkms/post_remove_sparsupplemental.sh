#!/bin/sh

# Post remove operations for sparsupplemental rpm go here.

# Remove the changes for the sparwdrt (watchdog timer)
if [ -e /etc/centos-release ]
then
	\rm /etc/sysconfig/modules/sparwdrt.modules
	\mv /etc/watchdog-original.conf /etc/watchdog.conf
fi
