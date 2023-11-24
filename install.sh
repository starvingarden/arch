#!/bin/bash

# see arch wiki page "Installation guide#Partition the disks"
# set keyboard variable and modify chroot script
# configure raid when using a single disk so that additional disks can be added later
# make logical volumes for each disk, then use btrfs raid 1 on each disk
# set default values for variables
# make rootPassword and encryptionPassword the same??
# incorporate data disks and data subvolumes for installs without data disks
# get disk serial number with lsblk -o name,serial (user should use this to physically label cable/disks osdisk1, etc.)
# user should specify disks in the order they want (osdisk1 will the 1st listed, osdisk2 2nd listed, etc.)
# change "lvm partitons" to "root partitions"
# see arch wiki page "btrfs#Multi-device file system" for information on how to convert raid levels, and add/remove/replace devices


######################################################
# YOU MUST SET ALL OF THESE VARIABLES UNLESS SPECIFIED
######################################################

#####################################################
# ALL VARIABLES MUST BE ENCLOSED INSIDE DOUBLE QUOTES
#####################################################





hostName=""
    # this is the device name
    # example: hostName="arch"

userName=""
    # this is your user name
    # example: userName="john"

userPassword=""
    # this is your user password
    # example: userPassword="abc123"

rootPassword=""
    # this is the root (administrator) password
    # example: rootPassword="abc123"

encryptionPassword=""
    # this is the password to be used for disk encryption
    # example: encryptionPassword="abc123"

osDisks=""
    # this is a list of space separated disks to use for the operating system
    # you must use 1 or 2 disks
    # if you use 2 disks, raid will automatically be applied to the operating system
    # run "fdisk -l" to list available disks
    # example: osDisks="sda nvme0n1"

dataDisks=""
    # this is a list of space separated disks to use for bulk storage
    # leave blank if you don't want to use any disks for bulk storage
    # you can use as many disks as you like
    # you cannot use any disks that will be used for the operating system (osDisks)
    # run "fdisk -l" to list available disks
    # example: dataDisks="sdb nvme1n1"

dataRaid=""
    # this determines if raid will be used for bulk storage disks
    # if using a singe data disk and you want to use raid later with another disk, enable this option
    # to enable, either leave blank or set to "true"
    # to disable, set to "false"
    # example: dataRaid="true"

diskWipe=""
    # this determines if disks will be securely wiped before proceeding
    # to enable, set to "true"
    # to disable, either leave blank or set to "false"
    # this can take a long time
    # example: diskWipe="true"

timeZone=""
    # this sets the time zone
    # run "timedatectl list-timezones" to list available timezones
    # example: timeZone="US/Central"

reflectorCode=""
    # this sets the country to download packages from
    # must set to 2 capital letters
    # run "reflector --list-countries" to list available countries and their codes
    # example: reflectorCode="US"

multiBoot=""
    # this determines if the bootloader will check for other operating systems
    # to enable, either leave blank or set to "true"
    # do disable, set to "false"
    # enable if you have already, or plan to dual boot on another disk
    # enable if you are unsure, (this setting has very little effect)
    # example: multiBoot="true"

customConfig=""
    # this determines if my own personal config files and settings will be used
    # to enable, set to "true"
    # to disable, either leave blank or set to "false"
    # for details on what this includes, see the "custom configurations" section in the config.sh script
    # example: customConfig="true"





#############################
# DO NOT CHANGE ANYTHING ELSE
#############################










# modify disk arrays
####################

# turn space separated strings into arrays
osDisks=($osDisks)
dataDisks=($dataDisks)

# change elements in disk arrays from the form "sda" to the form "/dev/sda"
for element in "${!osDisks[@]}"
do
    osDisks[$element]="/dev/${osDisks[$element]}"
done
for element in "${!dataDisks[@]}"
do
    dataDisks[$element]="/dev/${dataDisks[$element]}"
done










# install packages needed for installation
##########################################

printf "\e[1;32m\nInstalling packages needed for installation\n\e[0m"
sleep 3

pacman -S archlinux-keyring btrfs-progs ca-certificates lvm2 neofetch virt-what










# automatically set system variables
####################################

printf "\e[1;32m\nAutomatically setting variables for system information\n\e[0m"
sleep 3


# set arch url
archURL=$(grep -i 'url' /root/arch/.git/config | grep -Eo '[[:graph:]]*$')
# $archURL should be of the form of a url to the arch git repo


# check if installing on virtual machine
virtualMachine=$(virt-what)
if [ -z "$virtualMachine" ]
then
    virtualMachine=false
else
    virtualMachine=true
fi


# check if installing on a laptop
laptopInstall=$(neofetch battery)
if [ -z "$laptopInstall" ]
then
    laptopInstall=false
else
    laptopInstall=true
fi


# set processor vendor
processorVendor=$(neofetch --cpu_brand on | grep -i 'cpu' | grep -Eio 'amd|intel' | awk '{print tolower($0)}')
if [ -z "$processorVendor" ]
then
    processorVendor=null
fi
# $processorVendor should be all lowercase and one of "amd", "intel", or "null"


# set graphics vendor
graphicsVendor=$(neofetch --gpu_brand on | grep -i 'gpu' | grep -Eio 'amd|intel|nvidia' | awk '{print tolower($0)}')
if [ -z "$graphicsVendor" ]
then
    graphicsVendor=null
fi
# $graphicsVendor should be all lowercase and one of "amd", "intel", "nvidia", or "null"


# set ram size
ramsizeInteger=$(free --mega | grep -i 'mem' | awk '{print $2}')
ramSize=$(echo "$ramsizeInteger"M)
# $ramSize should be an integer in gigabytes of the form 1000M


# check if raid should be used for the operating system
osdisksLength=$(echo "${#osDisks[@]}")
if [ "$osdisksLength" -gt 1 ]
then
    osRaid=true
else
    osRaid=false
fi


# set os partition(s) (used when creating filesystems)
# create empty arrays for os partitions
efiPartitions=()
lvmPartitions=()
# set os partitions
for element in "${osDisks[@]}"
do
    # check if disk is an nvme
    nvme=$(echo "$element" | grep -io 'nvme')
    if [ -z "$nvme" ]
    then
        efiPartitions+=("$element"1)
        lvmPartitions+=("$element"2)
    else
        efiPartitions+=("$element"p1)
        lvmPartitions+=("$element"p2)
    fi
done
# os partitions should be in the form of "/dev/sda1", "/dev/nvme0n1p2", etc.


# set os partition names (used when setting lvm names, encrypted container names, and creating os partitions)
# create empty arrays for os parition names
efipartitionNames=()
lvmpartitionNames=()
# set efi partition name(s)
for element in "${!osDisks[@]}"
do
    efiPartition=(osdisk"$element"p1)
    efipartitionNames+=("$efiPartition")
done
# set lvm partition name(s)
for element in "${!osDisks[@]}"
do
    lvmPartition=(osdisk"$element"p2)
    lvmpartitionNames+=("$lvmPartition")
done
# efi partition names should be in the form of "osdisk1p1", "osdisk2p1", etc.
# lvm partition names should be in the form of "osdisk1p2", "osdisk2p2", etc.


# set encrypted container name(s) (used when creating encrypted containers, physical volumes, volume groups, and unlocking encrypted containers)
# create empty array for encrypted container names
encryptedcontainerNames=()
for element in "${lvmpartitionNames}"
do
    encryptedcontainerNames+=(cryptlvm-"$element")
done
# encrypted container names should be of the form "cryptlvm-osdisk1p2", "cryptlvm-osdisk2p2", etc.


# set volume group name(s)
# create empty array for volume group names
volumegroupNames=()
for element in "${lvmpartitionNames[@]}"
do
    volumegroupNames+=(volgroup-"$element")
done
# volume groups should be in the form of "volgroup-osdisk1p2", "volgroup-osdisk2p2", etc.


# set logical volume names
# create empty arrays for logical volume names
swapNames=()
rootNames=()
for element in "${lvmpartitionNames[@]}"
do
    swapNames+=(swap-"$element")
    rootNames+=(root-"$element")
done
# logical volume names should be in the form of "swap-osdisk1p2", "root-osdisk1p2", etc.










# verify variables for system information are correct
#echo -e "\n\n"
while true
do
    echo -e "arch URL=$archURL, virtual machine=$virtualMachine, laptop=$laptopInstall, processor vendor=$processorVendor, graphics vendor=$graphicsVendor, ram size=$ramSize, os raid=$osRaid, os disks=${osDisks[@]}, efi partitions=${efiPartitions[@]}, lvm partitions=${lvmPartitions[@]}, efi partition names=${efipartitionNames[@]}, lvm partition names=${lvmpartitionNames[@]}, encrypted container names=${encryptedcontainerNames[@]}, volume group names=${volumegroupNames[@]}, logical volume names=${swapNames[@]} ${rootNames[@]}"
    read -rp $'\n'"Are the variables for system information correct? [Y/n] " systemInformation
    systemInformation=${systemInformation:-Y}
    case $systemInformation in
        [yY][eE][sS]|[yY])
            read -rp $'\n'"Are you sure the variables for system information are correct? [Y/n] " systeminformationConfirm
            systeminformationConfirm=${systeminformationConfirm:-Y}
            case $systeminformationConfirm in
                [yY][eE][sS]|[yY])
                    break
                    ;;
                [nN][oO]|[nN])
                    echo -e "\n\n"
                    ;;
                *)
                    ;;
            esac
            REPLY=
            ;;
        [nN][oO]|[nN])
            read -rp $'\n'"Are you sure the variables for system information are NOT correct? [Y/n] " systeminformationConfirm
            systeminformationConfirm=${systeminformationConfirm:-Y}
            case $systeminformationConfirm in
                [yY][eE][sS]|[yY])
                    exit
                    ;;
                [nN][oO]|[nN])
                    echo -e "\n\n"
                    ;;
                *)
                    ;;
            esac
            REPLY=
            ;;
        *)
            ;;
    esac
    REPLY=
done










# save variables so they can be used later
##########################################

echo -e "hostName=$hostName" > ./variables.txt
echo -e "userName=$userName" >> ./variables.txt
echo -e "userPassword=$userPassword" >> ./variables.txt
echo -e "rootPassword=$rootPassword" >> ./variables.txt
echo -e "encryptionPassword=$encryptionPassword" >> ./variables.txt
echo -e "dataRaid=$dataRaid" >> ./variables.txt
echo -e "diskWipe=$diskWipe" >> ./variables.txt
echo -e "timeZone=$timeZone" >> ./variables.txt
echo -e "reflectorCode=$reflectorCode" >> ./variables.txt
echo -e "multiBoot=$multiBoot" >> ./variables.txt
echo -e "customConfig=$customConfig" >> ./variables.txt
echo -e "archURL=$archURL" >> ./variables.txt
echo -e "virtualMachine=$virtualMachine" >> ./variables.txt
echo -e "laptopInstall=$laptopInstall" >> ./variables.txt
echo -e "processorVendor=$processorVendor" >> ./variables.txt
echo -e "graphicsVendor=$graphicsVendor" >> ./variables.txt
echo -e "ramSize=$ramSize" >> ./variables.txt
echo -e "osRaid=$osRaid" >> ./variables.txt
for element in "${osDisks[@]}"
do
    echo "osDisks+=($element)" >> ./variables.txt
done

for element in "${efiPartitions[@]}"
do
    echo "efiPartitions+=($element)" >> ./variables.txt
done

for element in "${lvmPartitions[@]}"
do
    echo "lvmPartitions+=($element)" >> ./variables.txt
done

for element in "${efipartitionNames[@]}"
do
    echo "efipartitionNames+=($element)" >> ./variables.txt
done

for element in "${lvmpartitionNames[@]}"
do
    echo "lvmpartitionNames+=($element)" >> ./variables.txt
done

for element in "${encryptedcontainerNames[@]}"
do
    echo "encryptedcontainerNames+=($element)" >> ./variables.txt
done

for element in "${volumegroupNames[@]}"
do
    echo "volumegroupNames+=($element)" >> ./variables.txt
done

for element in "${swapNames[@]}"
do
    echo "swapNames+=($element)" >> ./variables.txt
done

for element in "${rootNames[@]}"
do
    echo "rootNames+=($element)" >> ./variables.txt
done










# verify the system is ready for install
########################################

printf "\e[1;32m\nVerifying the system is ready to install the operating system\n\e[0m"
sleep 3

# verify that the system is booted in UEFI mode
ls /sys/firmware/efi/efivars

# verify that the internet is working
ping -c 5 archlinux.org










# configure storage
###################

printf "\e[1;32m\nConfiguring storage\n\e[0m"
sleep 3


# unmount any partitions from /mnt
umount -R /mnt


# wipe disk(s)
if [ "$diskWipe" == true ]
then
    printf "\e[1;32m\nWiping disk(s)\n\e[0m"
    sleep 3
    # wipe os disks
    for element in "${osDisks[@]}"
    do
        cryptsetup open --type plain -d /dev/random "$element" to_be_wiped
        dd if=/dev/zero of=/dev/mapper/to_be_wiped status=progress
        cryptsetup close to_be_wiped
    done
    # wipe data disks
    for element in "${dataDisks[@]}"
    do
        cryptsetup open --type plain -d /dev/random "$element" to_be_wiped
        dd if=/dev/zero of=/dev/mapper/to_be_wiped status=progress
        cryptsetup close to_be_wiped
    done
fi


# create partitions
printf "\e[1;32m\nCreating partitions\n\e[0m"
sleep 3
# create os partitions
for element in "${!osDisks[@]}"
do
    # wipe the partition table
    sgdisk --zap-all "${osDisks[$element]}"
    # create partition #1 1GB in size
    sgdisk --new=1:0:+1G "${osDisks[$element]}"
    # set partition #1 type to "EFI system partition"
    sgdisk --typecode=1:ef00 "${osDisks[$element]}"
    # create partition #2 to the size of the rest of the disk
    sgdisk --new=2:0:0 "${osDisks[$element]}"
    # set partition #2 type to "Linux LUKS"
    sgdisk --typecode=2:8309 "${osDisks[$element]}"
    # set names for os partitions
    # efi partition
    sgdisk --change-name=1:"${efipartitionNames[$element]}"
    # lvm partition
    sgdisk --change-name=2:"${lvmpartitionNames[$element]}"
done
# create data partition(s)
for element in "${!dataDisks[@]}"
do
    # wipe the partition table
    sgdisk --zap-all "${dataDisks[$element]}"
    # create partition #1 to the size of the entire disk
    sgdisk --new=1:0:0 "${dataDisks[$element]}"
    # set partition #1 type to "Linux filesystem"
    sgdisk --typecode=1:8300 "${dataDisks[$element]}"
    # set name for data partition
    sgdisk --change-name=1:datadisk"$element"p1
done


# encrypt necessary partitions
printf "\e[1;32m\nEncrypting necessary partitions\n\e[0m"
sleep 3
# set up encryption for LVM partition(s)
for element in "${!lvmPartitions[@]}"
do
    # encrypt lvm partition(s)
    echo -e "$encryptionPassword" | cryptsetup luksFormat -q --type luks1 "${lvmPartitions[$element]}"    # grub has limited support for luks2
    # decrypt and name decrypted lvm partition(s) so it can be used
    echo -e "$encryptionPassword" | cryptsetup open "${lvmPartitions[$element]}" "${encryptedcontainerNames[$element]}"
done
# set up encryption for data partition(s)
for element in "${!dataPartitions[@]}"
do
    # encrypt data partition(s)
    echo -e "$encryptionPassword" | cryptsetup luksFormat -q --type luks1 "${dataPartitions[$element]}"    # grub has limited support for luks2
    # decrypt and name decrypted data partition(s) so it can be used
    echo -e "$encryptionPassword" | cryptsetup open "${dataPartitions[$element]}" "${decrypteddatapartitionNames[$element]}"
done


# create logical volumes
printf "\e[1;32m\nCreating logical volumes\n\e[0m"
sleep 3
# create physical volume(s)
for element in "${encryptedcontainerNames[@]}"
do
    pvcreate /dev/mapper/"$element"
done
# create volume group(s)
for element in "${!encryptedcontainerNames[@]}"
do
    vgcreate "${volumegroupNames[$element]}" /dev/mapper/"${encryptedcontainerNames[$element]}"
done
# create logical volumes
for element in "${!lvmpartitionNames[@]}"
do
    lvcreate -L "$ramSize" "${volumegroupNames[$element]}" -n "${swapNames[$element]}"
    lvcreate -l 100%FREE "${volumegroupNames[$element]}" -n "${rootNames[$element]}"
done


# create filesystems
printf "\e[1;32m\nCreating filesystems\n\e[0m"
sleep 3
# create efi filesystem(s)
for element in "${!efiPartitions[@]}"
do
    yes | mkfs.fat -F 32 -n "${efipartitionNames[$element]}" "${efiPartitions[$element]}"
done
# create swap filesystem(s)
for element in "${!swapNames[$element]}"
do
#    mkswap -L "${swapNames[$element]}" /dev/"${volumegroupNames[$element]}"/"${swapNames[$element]}"
done
# create root filesystem
if [ "$osRaid" == false ]
then
    yes | mkfs.btrfs -L root -f -m dup -d single /dev/"${volumegroupNames[0]}"/"${rootNames[0]}"
fi
if [ "$osRaid" == true ]
then
    # set array for all root filesystem paths
    # create empty array for root filesystem paths
    rootPaths=()
    # set root filesystem paths
    for element in "${!volumegroupNames[@]}"
    do
        rootPaths+=(/dev/"${volumegroupNames[$element]}"/"${rootNames[$element]}")
    done
    yes | mkfs.btrfs -L root -f -m raid1 -d raid1 "${rootPaths[@]}"
fi


# create btrfs subvolumes
printf "\e[1;32m\nCreating btrfs subvolumes\n\e[0m"
sleep 3
# mount root filesystem so that subvolumes can be created
mount /dev/"${volumegroupNames[0]}"/"${rootNames[0]}" /mnt
# create btrfs subvolumes
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@data
btrfs subvolume create /mnt/@snapshots
btrfs subvolume create /mnt/@var


# create directories to mount filesystems
printf "\e[1;32m\nCreating directories to mount filesystems\n\e[0m"
sleep 3
# unmount partitions from /mnt
umount -R /mnt
# mount root subvolume to /mnt
mount -o noatime,compress=zstd,space_cache=v2,subvol=@ /dev/"${volumegroupNames[0]}"/"${rootNames[0]}" /mnt
# make directories to mount other partitions and subvolumes
mkdir -p /mnt/efi
mkdir -p /mnt/home
mkdir -p /mnt/data
mkdir -p /mnt/.snapshots
mkdir -p /mnt/var


# mount filesystems
printf "\e[1;32m\nMounting filesystems\n\e[0m"
sleep 3
# mount efi filesystem
mount "${efiPartitions[0]}" /mnt/efi
# mount swap filesystem
#swapon /dev/"${volumegroupNames[0]}"/"${swapNames[0]}"
# mount btrfs filesystem
mount -o noatime,compress=zstd,space_cache=v2,subvol=@home /dev/"${volumegroupNames[0]}"/"${rootNames[0]}" /mnt/home
mount -o noatime,compress=zstd,space_cache=v2,subvol=@data /dev/"${volumegroupNames[0]}"/"${rootNames[0]}" /mnt/data
mount -o noatime,compress=zstd,space_cache=v2,subvol=@snapshots /dev/"${volumegroupNames[0]}"/"${rootNames[0]}" /mnt/.snapshots
mount -o noatime,compress=zstd,space_cache=v2,subvol=@var /dev/"${volumegroupNames[0]}"/"${rootNames[0]}" /mnt/var










# update the system clock
#########################

printf "\e[1;32m\nUpdating Clock\n\e[0m"
sleep 3
timedatectl set-ntp true










# install required linux packages
#################################

printf "\e[1;32m\nInstalling required linux packages\n\e[0m"
sleep 3
pacstrap -K /mnt base btrfs-progs cryptsetup linux linux-firmware lvm2










# generate an fstab file
########################

printf "\n\e[1;32mGenerating fstab file\n\e[0m"
sleep 3
genfstab -U /mnt >> /mnt/etc/fstab










# prepeare to change root into the new system and run chroot script
###################################################################

printf "\e[1;32m\nChrooting into new environment and running chroot script\n\e[0m"
sleep 3

# copy the variables file to destination system's root partition so that chroot script can access the file from inside of chroot
cp ./variables.txt /mnt

# copy the chroot script to destination system's root partition
cp ./chroot.sh /mnt

# change file permission of chroot script to make it executable
chmod +x /mnt/chroot.sh

# change root into the new environment and run chroot script
arch-chroot /mnt /chroot.sh










# finish installation
#####################

printf "\e[1;32m\nFinishing installation\n\e[0m"
sleep 3

# delete variables and chroot.sh
rm /mnt/variables.txt
rm /mnt/chroot.sh

# unmount all partitions
umount -R /mnt

# reboot the system
printf "\e[1;32m\nInstallation Complete. After rebooting, read the \"packages.txt\" file in your home directory. Enter \"reboot\" to reboot the system\n\e[0m"
