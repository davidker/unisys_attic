#!/bin/sh
#
# Copyright © 2010 - 2015 UNISYS CORPORATION
# All rights reserved.

SPARIZE=unsupported.sh

if [ -e /etc/SuSE-release ] 
then
	SPARIZE=sparize-sles.sh
fi

if [ -e /etc/redhat-release ]
then
	SPARIZE=sparize-rhel.sh
fi

DIR="`dirname $0`"
cp $DIR/spar.conf /etc/modprobe.d/spar.conf
$DIR/$SPARIZE -f
