#!/bin/bash

# this is a bash script that unmounts then powers off all removable usb storage devices





# unmount all usb partitions
############################

# get list of all partitions mounted at /run/media
partitionNames=$(df | grep '/run/media/' | grep -Eo '^[[:graph:]]*')

# unmount all partitions mounted at /run/media
for partitionName in $partitionNames
do
	# unmount partition
	#echo -e "partitionName=$partitionName"
	udisksctl unmount --block-device="$partitionName"
done





# power off all usb storage devices
###################################

# get list of all block devices
diskNames=$(ls /sys/block)

# power off all usb disks
for disk in $diskNames
do
	if udevadm info --query=property --path=/sys/block/"$disk" | grep -q ^ID_USB
	then
		diskPath=/dev/"$disk"
		#echo -e "diskPath=$diskPath"
		udisksctl power-off --block-device="$diskPath"
		echo -e "Powered-off $disk"
	fi
done
