#!/bin/sh
#
# Copyright © 2010 - 2015 UNISYS CORPORATION
# All rights reserved.

dir="`dirname $0`" 
if dkms status -m spardrivers | grep -q installed 
then 
    # Sure, we just uninstalled a spardrivers version, but there is still 
    # some other version installed.  This case happens when you use 
    # "rpm -U" to upgrade from one spardrivers version from another: 
    # * New version is installed 
    # * Old version is removed 
    echo "sPAR drivers remain." 
else 
    echo "No sPAR drivers remain; reverting sPAR changes to config files..." 
    SPARIZE=unsupported.sh
    if [ -e /etc/SuSE-release ] 
    then
        SPARIZE=sparize-sles.sh
    fi

    if [ -e /etc/redhat-release ]
    then
        SPARIZE=sparize-rhel.sh
    fi

    $dir/$SPARIZE -u 
    rm /etc/modprobe.d/spar.conf
fi 
echo "sPAR post-remove completed."
