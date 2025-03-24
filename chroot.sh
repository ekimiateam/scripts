#!/bin/bash
lepartuuid=$1
#TODO : try first partition of first disk

mkdir -p /media/mycomputer
mount -t auto -o acl /dev/disk/by-uuid/$lepartuuid  /media/mycomputer
# Share some things from running system, to keep various applications
# and the kernel happy.

#need pts
mount --bind /dev /media/mycomputer/dev
mount --bind /tmp /media/mycomputer/tmp
mount --bind /proc /media/mycomputer/proc
mount --bind /run  /media/mycomputer/run
mount -t sysfs /sys /media/mycomputer/sys
mount  --bind /dev/pts /media/mycomputer/dev/pts 
#mount --bind /etc/resolv.conf /media/mycomputer/etc/resolv.conf
chroot /media/mycomputer
