install() {
    DIR="`dirname $0`"
    echo "configuring sPar on this system."
    cp $DIR/spar.dracut.conf /etc/dracut.conf.d
    grubby --update-kernel=ALL --args="rdloaddriver=visorhba rdloaddriver=visornic rdloaddriver=visorbus rdloaddriver=visorinput nopat reboot=acpi add_efi_memmap"
    dracut -f
}

remove() {
    echo "reverting from sPar configuration"
    rm /etc/dracut.conf.d/spar.dracut.conf
    grubby --update-kernel=ALL --remove-args="rdloaddriver=visorhba rdloaddriver=visornic rdloaddriver=visorbus rdloaddriver=visorinput nopat reboot=acpi add_efi_memmap"
}

#!/bin/bash
if [ "$1" = "-u" ]
then
    remove
else
    install
fi

