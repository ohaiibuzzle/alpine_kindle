#!/bin/sh

if [ "$(mount | grep /tmp/alpine)" ] ; then
    echo "ATTENTION! Alpine's rootfs is still mounted."
    echo "Please unmount it (by starting the Alpine shell once then exit from it)"
    exit 1
fi

rm -rf /mnt/us/alpine

read -p "Alpine Linux has been deleted. Press any key to continue..."