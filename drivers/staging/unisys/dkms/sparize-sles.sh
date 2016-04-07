#!/bin/sh
#
# Copyright © 2010 - 2015 UNISYS CORPORATION
# All rights reserved.

# This script modifies a SLES11 Linux configuration to prepare it for booting
# up within sPAR, or UNdoes those changes (with "-u").

PROGNAME="`basename $0`"
DIRNAME="`dirname $0`"
SYSLOGNG_ADDON="$DIRNAME/syslogng.txt"  # stuff to go into syslog-ng.conf
SYSLOGNG_ADDON_VER=2                    # this MUST match the version specified in the
                                        # comment at the top of syslogng.txt
BACKUPSFX="~"                           # backup filename suffix
SPAR_DRACUT_CONF="$DIRNAME/spar.dracut-sles.conf"
KERNEL_CMDLINE_ARGS_COMMON=(
    "rdloaddriver=virthbamod"
    "rdloaddriver=visorchannel"
    "rdloaddriver=virtnicmod"
    "rdloaddriver=visorchipset"
    "visorchipset.major=245"
    "visorchipset.clientregwait=1"
    "visorchipset.serverregwait=1"
    "rdloaddriver=visorserialclient"
    "rdloaddriver=uischanmod"
    "rdloaddriver=virtpcimod"
    "rdloaddriver=visorclientbus"
    "rdloaddriver=visorvideoclient"
    "rdloaddriver=uislibmod"
    "uislibmod.disable_controlvm=1"
    "rdloaddriver=visorbus"
    "rdloaddriver=visorconinclient"
    "rdloaddriver=visornoop"
)
# We add these when s-Par drivers are added, but do NOT remove them when s-Par
# drivers are removed, because these are not necessarily s-Par specific.  It
# is safe to leave them.
KERNEL_CMDLINE_ARGS_ADDONLY=(
    "add_efi_memmap"
    "reboot=acpi"
    "nopat"
)
KERNEL_CMDLINE_ARGS_DELONLY=(
)
KERNEL_CMDLINE_ARGS_ADD="${KERNEL_CMDLINE_ARGS_COMMON[@]} ${KERNEL_CMDLINE_ARGS_ADDONLY[@]}"
KERNEL_CMDLINE_ARGS_DEL="${KERNEL_CMDLINE_ARGS_COMMON[@]} ${KERNEL_CMDLINE_ARGS_DELONLY[@]}"



TEST_MODE=0
if [ $TEST_MODE -eq 0 ]
then
    INITTAB=/etc/inittab
    BOOTLOCAL=/etc/init.d/boot.local
    IFCFGETH0=/etc/sysconfig/network/ifcfg-eth0
    UNSUPPORTEDMODS=/etc/modprobe.d/unsupported-modules
    if [ ! -r $UNSUPPORTEDMODS ]
    then
        UNSUPPORTEDMODS=$(ls /etc/modprobe.d/*-unsupported-modules.* 2>/dev/null)
    fi
    SUSERELEASE=/etc/SuSE-release
    SYSLOG_CONF=/etc/syslog-ng/syslog-ng.conf
    SYSLOG_PROFILE=/etc/apparmor.d/sbin.syslog-ng
    DRACUT_CONF_DIR=/etc/dracut.conf.d/
    DEFAULTGRUB=/etc/default/grub
    GRUBCFG=/boot/grub2/grub.cfg
else
    INITTAB=inittab
    BOOTLOCAL=boot.local
    IFCFGETH0=ifcfg-eth0
    UNSUPPORTEDMODS=unsupported-modules
    SUSERELEASE=SuSE-release
    SYSLOG_CONF=syslog-ng.conf
    SYSLOG_PROFILE=sbin.syslog-ng
    DRACUT_CONF_DIR=./
    DEFAULTGRUB=defaultgrub
    GRUBCFG=grub.cfg
fi


abend()
{
    echo 1>&2 "$PROGNAME failed: $*"
    exit 1
}



usage()
{
    echo 1>&2 "$PROGNAME -f|-u"
    echo 1>&2 "With '-f', make config file changes necessary for sPAR."
    echo 1>&2 "With '-u', undo config changes made for sPAR."
}



#
# fix_assignment_begin() / fix_assignment_add() / fix_assignment_del() /
# fix_assignment_end()
#
# These functions are used to generate a sed script that can be used to add
# or remove specific sub-strings from a variable assignment.
#
fix_assignment_begin()
{
    sed_script="$1"
    var_name="$2"
    # Generate sed notation to look for a variable assignment with
    # $var_name on the left-side of the =.
    echo "/^[ \\t]*$var_name[ \\t]*=/{" >>$sed_script
}

fix_assignment_add()
{
    sed_script="$1"
    s="$2"
    # Generate sed notation to add $s to the end of a double-quoted string,
    # but only if $s is not already in the string.
    echo "  /$s/!{"            >>$sed_script
    echo "    s/\"\$/ $s\"/"   >>$sed_script
    echo "  }"                 >>$sed_script
}

fix_assignment_del()
{
    sed_script="$1"
    s="$2"
    # Generate sed notation to delete $s from within a double-quoted string.
    # Note that we need to account for the possibilities that $s is at
    # the beginning of the string, end of the string, or both.
    echo "  s/ $s / /"      >>$sed_script
    echo "  s/\"$s /\"/"    >>$sed_script
    echo "  s/ $s\"/\"/"    >>$sed_script
    echo "  s/\"$s\"/\"\"/" >>$sed_script
}

fix_assignment_end()
{
    sed_script="$1"
    echo "}" >>$sed_script
    echo "p" >>$sed_script
}



# fixfile <filename> <sed_scriptname> <do_backup>
# Uses the sed script indicated by <sed_scriptname> to modify <filename>.
# If something changes, the prior contents of <filename> are backed up
# to <filename>$BACKUPSFX iff you specify 1 as <do_backup>.
fixfile()
{
    f="$1"
    sedprog="$2"
    do_backup="$3"
    if [ ! -w ${f} ]
    then
        echo "$PROGNAME: skipping $f (not found existing+writable)"
        return 0
    fi
    rm -f ${f}.new
    sed <$f -n -f $sedprog >${f}.new
    if [ ! -f ${f}.new ]
    then
        echo 1>&2 "fix-up of $f failed"
        return 0
    fi
    siz="`wc -c ${f}.new | awk '{ print $1 }'`"
    if [ "$siz" = "0" ]
    then
        echo 1>&2 "fix-up of $f failed (0-length output)"
        return 0
    fi
    if cmp -s $f ${f}.new
    then
        #echo "$PROGNAME: no changes to $f"
        rm ${f}.new
    else
        copyrc=0
        if [ "$do_backup" = "1" ]
        then
            # we changed something, so back up the original file, and copy in the
            # new one
            cp -p $f ${f}${BACKUPSFX}
            copyrc=$?
        fi
        if [ $copyrc -eq 0 ]
        then
            mv ${f}.new $f  || echo 1>&2 "fix-up of $f failed (can't overwrite)"
            echo "$PROGNAME: tweaked $f"
            return 1
        else
            echo 1>&2 "fix-up of $f failed (can't create backup file)"
            return 0
        fi
    fi
}



# Return success iff a partition with the specified label is online on the system.
#
partition_with_label_exists()
{
    label="$1"
    blkid | grep -q " LABEL=\"$label\" "
    return $?
}



#
# Fix /etc/init.d/boot.local.
#
fix_bootlocal()
{
    f="$1"
    if [ ! -w ${f} ]
    then
        echo "$PROGNAME: skipping $f (not found existing+writable)"
        return
    fi
    if ! grep -q "# sPAR$" $f
    then
        if cp -p $f ${f}${BACKUPSFX}
        then
            echo "mknod /dev/spcon c 240 0 # sPAR" >>$f || echo 1>&2 "fix-up of $f failed"
            echo "chmod 664 /dev/spcon     # sPAR" >>$f || echo 1>&2 "fix-up of $f failed"
            echo "$PROGNAME: tweaked $f"
        else
            echo 1>&2 "fix-up of $f failed (can't create backup file)"
        fi
    else
        echo "$PROGNAME: no changes to $f"
    fi
}



#
# Fix /etc/inittab.
#
fix_inittab()
{
    f="$1"
    if [ ! -w ${f} ]
    then
        echo "$PROGNAME: skipping $f (not found existing+writable)"
        return
    fi
    if ! grep -q "115200 spcon" $f
    then
        if cp -p $f ${f}${BACKUPSFX}
        then
            echo "S9:12345:respawn:/sbin/agetty -L 115200 spcon" >>$f || echo 1>&2 "fix-up of $f failed"
            echo "$PROGNAME: tweaked $f"
        else
            echo 1>&2 "fix-up of $f failed (can't create backup file)"
        fi
    else
        echo "$PROGNAME: no changes to $f"
    fi
}



#
# Fix /etc/modprobe.d/unsupported-modules
#
fix_unsupportedmods()
{
    f="$1"
    if [ ! -w ${f} ]
    then
        echo "$PROGNAME: skipping $f (not found existing+writable)"
        return
    fi
    x="allow_unsupported_modules"
    if ! grep -q "^$x[ \t][ \t]*1" $f
    then
        if grep -q "^$x[ \t][ \t]*0" $f
        then
            # we found "allow_unsupported_modules 0", so change it to 1
            sed -i${BACKUPSFX} "s/^$x[ \t][ \t]*0/$x 1/" $f || echo 1>&2 "fix-up of $f failed (sed failed)"
        else
            # we did NOT even find an "allow_unsupported_modules" spec; add one
            if cp -p $f ${f}${BACKUPSFX}
            then
                echo "$x 1" >>$f || echo 1>&2 "fix-up of $f failed"
            else
                echo 1>&2 "fix-up of $f failed (can't create backup file)"
            fi
        fi
        echo "$PROGNAME: tweaked $f"
    else
        # allow_unsupported_modules already found set correctly
        echo "$PROGNAME: no changes to $f"
    fi
}



#
# Fix /etc/syslog-ng/syslog-ng.conf
#
fix_syslogng()
{
    f="$1"
    ver="$2"
    if [ ! -w ${f} ]
    then
        echo "$PROGNAME: skipping $f (not found existing+writable)"
        return
    fi
    if grep -q "^# s-PAR syslog-ng config version $ver" $f
    then
        # already found set correctly
        echo "$PROGNAME: no changes to $f"
        return
    fi
    
    # At this point we know we are going to need to change the file.
    # So first, create a backup file.
    if ! cp -p $f ${f}${BACKUPSFX}
    then
        echo 1>&2 "fix-up of $f failed (can't create backup file)"
        return
    fi
    if grep -q "^# s-PAR syslog-ng config version" $f
    then
        # another version of syslog-ng changes were found; remove them first
        sed -i "/# s-PAR$/d" $f || echo 1>&2 "fix-up of $f failed (failed to remove prior version)"
    fi
    cat $SYSLOGNG_ADDON >>$f || echo 1>&2 "fix-up of $f failed (failed to append new text)"
    echo "$PROGNAME: tweaked $f"
}



#
# Adds or removes s-Par-specific strings from the GRUB_CMDLINE_LINUX string in
# the $DEFAULTGRUB file (/etc/default/grub), then re-generates the real 
# grub.cfg file.
#
fix_default_grub()
{
    add_or_remove="$1"
    if [ ! -w ${DEFAULTGRUB} ]
    then
        echo "$PROGNAME: skipping $DEFAULTGRUB (not found existing+writable)"
        return
    fi
    SED_SCRIPT_TEMP="`mktemp -q`"
    rc=$?
    if [ $rc -ne 0 -o "$SED_SCRIPT_TEMP" = "" ]
    then
        SED_SCRIPT_TEMP=""
        echo 1>&2 "failed to create temporary file"
        return
    fi
    fix_assignment_begin $SED_SCRIPT_TEMP "GRUB_CMDLINE_LINUX"
    if [ "$add_or_remove" = "add" ]
    then
        for arg in ${KERNEL_CMDLINE_ARGS_ADD[@]}
        do
            fix_assignment_add $SED_SCRIPT_TEMP "$arg"
        done
    else
        for arg in ${KERNEL_CMDLINE_ARGS_DEL[@]}
        do
            fix_assignment_del $SED_SCRIPT_TEMP "$arg"
        done
    fi
    fix_assignment_end $SED_SCRIPT_TEMP
    fixfile $DEFAULTGRUB $SED_SCRIPT_TEMP 1
    if [ $? -eq 1 ]
    then
        rm -f $SED_SCRIPT_TEMP
        echo "$PROGNAME: re-generating $GRUBCFG"
        if ! grub2-mkconfig -o $GRUBCFG
        then
            echo 1>&2 "grub2-mkconfig -o $GRUBCFG failed"
            return
        fi
    fi
    rm -f $SED_SCRIPT_TEMP
}



dracut_install()
{
    if [ ! -d /etc/dracut.conf.d/ ]
    then
        echo "$PROGNAME: distro does not use dracut; $SPAR_DRACUT_CONF ignored"
        return
    fi
    echo "$PROGNAME: installing dracut configuration $SPAR_DRACUT_CONF"
    if ! cp -a $SPAR_DRACUT_CONF $DRACUT_CONF_DIR/99-spar.conf
    then
        echo 1>&2 "failed to install $SPAR_DRACUT_CONF to $DRACUT_CONF_DIR/99-spar.conf"
        return
    fi
    #
    # 'depmod && dracut -f' will be run by dkms after this script exits, which
    # of course will inject the new s-Par modules specified in $SPAR_DRACUT_CONF
    # into the initrd.  But you MUST be running a version of dkms that contain's
    # Ben's patch (http://comments.gmane.org/gmane.linux.kernel.dkms.devel/864):
    #
    #    --- /usr/sbin/dkms	2012-06-11 10:39:12.000000000 -0400
    #    +++ dkms	2012-11-09 09:15:11.407276658 -0500
    #    @@ -276,7 +276,7 @@
    #         echo $"(If next boot fails, revert to $initrd.old-dkms image)"
    #     
    #         if [[ $mkinitrd = dracut ]]; then
    #    -	invoke_command "$mkinitrd $1" "$mkinitrd" background
    #    +	invoke_command "$mkinitrd -f $initrd_dir/$initrd $1" "$mkinitrd" background
    #         elif [[ $mkinitrd = update-initramfs ]]; then
    #        invoke_command "$mkinitrd -u" "$mkinitrd" background
    #         elif $mkinitrd --version >/dev/null 2>&1; then
    #
    fix_default_grub "add"
}



dracut_remove()
{
    fix_default_grub "remove"
    rm -f $DRACUT_CONF_DIR/99-spar.conf
    # 'dracut -f' will be run by dkms after this script exits, resulting in all
    # s-Par modules being removed from the initrd.  Refer to dracut_install()
    # for more details.
}



fix_syslogng_apparmor()
{
	case $1 in
	add)
		# check if rules are needed.
		if which apparmor_parser > /dev/null 2>&1 && ! grep -q "/dev/visordiag" $SYSLOG_PROFILE
		then
			# if so,
			# add new rule to apparmor profile.
			echo "$PROGNAME: updating $SYSLOG_PROFILE"
			sed -i -e 's/^}$/  \/dev\/visordiag.* rw,\n}/' $SYSLOG_PROFILE
			# then reload apparmor profile.
			echo "$PROGNAME: reloading $SYSLOG_PROFILE apparmor profile"
			apparmor_parser -r $SYSLOG_PROFILE
		fi
		;;
	remove)
		# check if rules are present.
		if which apparmor_parser > /dev/null 2>&1 && grep -q "/dev/visordiag" $SYSLOG_PROFILE
		then
			# if so,
			# remove the rule from the apparmor profile.
			echo "$PROGNAME: updating $SYSLOG_PROFILE"
			sed -i -e '/\/dev\/visordiag.* rw,/d' $SYSLOG_PROFILE
			# then reload apparmor profile.
			echo "$PROGNAME: reloading $SYSLOG_PROFILE apparmor profile"
			apparmor_parser -r $SYSLOG_PROFILE 
		fi
		;;
	*)
		echo Error! Must specify one valid option from "add" or "remove". 
		;;
	esac	
}



# Make config changes for sPAR.
#
# Note the error-recovery strategy here is that once we commit to starting,
# that we always try to push thru to the end, despite any errors we encounter 
# along the way.
#
add_spar()
{
    if [ ! -r $SUSERELEASE ]
    then
        echo "$PROGNAME: only supported for SuSE Linux"
        return 1
    fi
    
    fix_bootlocal       $BOOTLOCAL
    fix_inittab         $INITTAB
    fix_unsupportedmods $UNSUPPORTEDMODS
    fix_syslogng        $SYSLOG_CONF $SYSLOGNG_ADDON_VER
    fix_syslogng_apparmor add
    dracut_install

    return 0
}



# Undo sPAR config changes.
#
# Note the error-recovery strategy here is to always try to push thru to the 
# end, despite any errors we encounter along the way.
#
remove_spar()
{
    # Leave elilo.conf and fstab changes alone, as they should be harmless.
    
    #
    # Undo /etc/init.d/boot.local.
    #
    f=$BOOTLOCAL
    if grep -q "# sPAR$" $f
    then
        # we check so as to prevent making a backup file if there are no changes
        sed -i${BACKUPSFX} "/^.* # sPAR$/d" $f
    fi

    #
    # Undo /etc/inittab.
    #
    f=$INITTAB
    if grep -q "115200 spcon" $f
    then
        # we check so as to prevent making a backup file if there are no changes
        sed -i${BACKUPSFX} "/^.* 115200 spcon/d" $f
    fi

    #
    # Undo /etc/sysconfig/network/ifcfg-eth0.
    #
    f=$IFCFGETH0
    if grep -q "# sPAR$" $f
    then
        if cp -p $f ${f}${BACKUPSFX}
        then
            sed -i "s/^#NAME=\(.*\) # sPAR$/NAME=\1/" $f
            sed -i "/^.* # sPAR$/d" $f
        else
            echo 1>&2 "fix-up of $f failed (can't create backup file)"
        fi
    fi

    #
    # Undo /etc/syslog-ng/syslog-ng.conf.
    #
    f=$SYSLOG_CONF
    if grep -q "# s-PAR$" $f
    then
        if cp -p $f ${f}${BACKUPSFX}
        then
            sed -i "/# s-PAR$/d" $f || echo 1>&2 "fix-up of $f failed (failed to remove prior version)"
        else
            echo 1>&2 "fix-up of $f failed (can't create backup file)"
        fi
    fi
    
    fix_syslogng_apparmor remove
    dracut_remove

    # Leave unsupported-modules changes alone, as they should be harmless.

    return 0
}



op="$1"
if [ "$op" = "-f" ]
then
    add_spar
elif [ "$op" = "-u" ]
then
    remove_spar
else
    usage
    exit 1
fi
