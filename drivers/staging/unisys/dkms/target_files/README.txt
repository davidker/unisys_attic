Within this directory, place all files you want to be injected into the
dkms rpm (in addition to all of the driver source files), to be installed
into the target filesystem.  Note you will also need to modify the dkms
mkrpm .spec file (e.g., GuestLinux/spardrivers-dkms-mkrpm.spec) for each
file, to indicate how/where to install the file into the target filesystem.
