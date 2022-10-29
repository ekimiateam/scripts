#!/bin/bash
lediskuuid=$1
#TODO : try first partition of first disk

mkdir /media/mycomputer
mount -t auto -o acl /dev/disk/by-uuid/$lediskuuid  /media/mycomputer
# Share some things from running system, to keep various applications
# and the kernel happy.

#need pts
mount --bind /dev /media/mycomputer/dev
mount --bind /tmp /media/mycomputer/tmp
mount --bind /proc /media/mycomputer/proc
mount --bind /etc/resolv.conf /media/mycomputer/etc/resolv.conf
chroot /media/mycomputer
