#!/bin/bash

# automatically get information
###############################

# check root status
currentUser=$(whoami)
if [ "$currentUser" != root ]
then
    printf "\e[1;31m\nYou must be logged in as root to run this script\n\e[0m"
    exit
fi


# get root parition
rootPartition=$(df | grep -E '/$' | grep -Eio '/dev/[[:graph:]]*')










# remove no longer needed subvolumes
####################################

# mount the top level subvolume
mount "$rootPartition" -o subvolid=5 /mnt


# delete the no longer needed subvolume @old along with all its contents
rm -r /mnt/@old/*
btrfs subvolume delete /mnt/@old


# reboot the system
printf "\e[1;32m\nCleanup complete. Enter \"reboot\" to reboot the system\n\e[0m"
