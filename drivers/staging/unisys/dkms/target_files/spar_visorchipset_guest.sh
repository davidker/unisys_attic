#!/bin/sh
#
# Copyright (c) 2013 - 2015 UNISYS CORPORATION
# All rights reserved.

if [ "$ACTION" = "change" ]
then
	if [ "$SPAR_PARAHOTPLUG" = 1 ]
	then
		/sbin/spar_parahotplug.sh
	fi
fi
