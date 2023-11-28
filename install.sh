#!/bin/bash

# see arch wiki page "Installation guide#Partition the disks"
# set keyboard variable and modify chroot script (/etc/vconsole.conf, etc.)
# set default values for variables
# incorporate data disks and data subvolumes for installs without data disks
# get disk serial number with lsblk -o name,serial (user should use this to physically label cable/disks osdisk1, etc.)
# user should specify disks in the order they want (osdisk1 will the 1st listed, osdisk2 2nd listed, etc.)
# see arch wiki page "btrfs#Multi-device file system" for information on how to convert raid levels, and add/remove/replace devices
# kpartx command to use disks that are already configured
# each disk has its own physical volume, volume group, and logical volume(s). RAID is used via btrfs
# use persistent block device naming for initramfs and grub configuration

######################################################
# YOU MUST SET ALL OF THESE VARIABLES UNLESS SPECIFIED
######################################################

#####################################################
# ALL VARIABLES MUST BE ENCLOSED INSIDE DOUBLE QUOTES
#####################################################





hostName="arch"
    # this is the device name
    # example: hostName="arch"

userName="johndoe"
    # this is your user name
    # example: userName="john"

userPassword="password"
    # this is your user password
    # example: userPassword="abc123"

rootPassword="password"
    # this is the root (administrator) password
    # example: rootPassword="abc123"

encryptionPassword="password"
    # this is the password to be used for disk encryption
    # example: encryptionPassword="abc123"

osDisks="vda"
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

timeZone="US/Central"
    # this sets the time zone
    # run "timedatectl list-timezones" to list available timezones
    # example: timeZone="US/Central"

reflectorCode="US"
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


# set os partition(s) (used when creating and mounting filesystems)
# create empty arrays for os partitions
efiPartitions=()
cryptosPartitions=()
# set os partitions
for element in "${osDisks[@]}"
do
    # check if disk is an nvme
    nvme=$(echo "$element" | grep -io 'nvme')
    if [ -z "$nvme" ]
    then
        efiPartitions+=("$element"1)
        cryptosPartitions+=("$element"2)
    else
        efiPartitions+=("$element"p1)
        cryptosPartitions+=("$element"p2)
    fi
done
# efi partitions should be in the form of "sda1", "nvme0n1p1", etc.
# encrypted os partitions should be in the form of "sda2", "nvme0n1p2", etc.


# set os partition names (used when creating os partitions and filesystems)
# create empty arrays for os parition names
efipartitionNames=()
cryptospartitionNames=()
# set efi partition name(s)
for element in "${!osDisks[@]}"
do
    efiPartition=(osdisk"$element"p1)
    efipartitionNames+=("$efiPartition")
done
# set os partition name(s)
for element in "${!osDisks[@]}"
do
    cryptosPartition=(osdisk"$element"p2)
    cryptospartitionNames+=("$cryptosPartition")
done
# efi partition names should be in the form of "osdisk0p1", "osdisk1p1", etc.
# encrypted os partition names should be in the form of "osdisk0p2", "osdisk1p2", etc.


# set os encrypted container name(s) (used when creating encrypted containers, physical volumes, volume groups, and unlocking encrypted containers)
# create empty array for os encrypted container names
osencryptedcontainerNames=()
for element in "${!osDisks[@]}"
do
    osencryptedcontainerNames+=(cryptos"$element")
done
# os encrypted container names should be of the form "cryptos0", "cryptos1", etc.


# set os volume group name(s)
# create empty array for os volume group names
osvolgroupNames=()
for element in "${!osDisks[@]}"
do
    osvolgroupNames+=(osvolgroup"$element")
done
# os volume group names should be in the form of "osvolgroup0", "osvolgroup1", etc.


# set os logical volume names
# create empty arrays for os logical volume names
swapNames=()
rootNames=()
for element in "${!osDisks[@]}"
do
    swapNames+=(swap"$element")
    rootNames+=(root"$element")
done
# os logical volume names should be in the form of "swap0", "swap1", "root0", "root1", etc.










# verify variables for system information are correct
#echo -e "\n\n"
while true
do
    echo -e "arch URL=$archURL, virtual machine=$virtualMachine, laptop=$laptopInstall, processor vendor=$processorVendor, graphics vendor=$graphicsVendor, ram size=$ramSize, os raid=$osRaid, os disks=${osDisks[@]}, efi partitions=${efiPartitions[@]}, crypt os partitions=${cryptosPartitions[@]}, efi partition names=${efipartitionNames[@]}, crypt os partition names=${cryptospartitionNames[@]}, os encrypted container names=${osencryptedcontainerNames[@]}, os volume group names=${osvolgroupNames[@]}, os logical volume names=${swapNames[@]} ${rootNames[@]}"
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

for element in "${cryptosPartitions[@]}"
do
    echo "cryptosPartitions+=($element)" >> ./variables.txt
done

for element in "${efipartitionNames[@]}"
do
    echo "efipartitionNames+=($element)" >> ./variables.txt
done

for element in "${cryptospartitionNames[@]}"
do
    echo "cryptospartitionNames+=($element)" >> ./variables.txt
done

for element in "${osencryptedcontainerNames[@]}"
do
    echo "osencryptedcontainerNames+=($element)" >> ./variables.txt
done

for element in "${osvolgroupNames[@]}"
do
    echo "osvolgroupNames+=($element)" >> ./variables.txt
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
        cryptsetup open --type plain -d /dev/random /dev/"$element" to_be_wiped
        dd if=/dev/zero of=/dev/mapper/to_be_wiped status=progress
        cryptsetup close to_be_wiped
    done
    # wipe data disks
    for element in "${dataDisks[@]}"
    do
        cryptsetup open --type plain -d /dev/random /dev/"$element" to_be_wiped
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
    sgdisk --zap-all /dev/"${osDisks[$element]}"
    # create partition #1 1GB in size
    sgdisk --new=1:0:+1G /dev/"${osDisks[$element]}"
    # set partition #1 type to "EFI system partition"
    sgdisk --typecode=1:ef00 /dev/"${osDisks[$element]}"
    # create partition #2 to the size of the rest of the disk
    sgdisk --new=2:0:0 /dev/"${osDisks[$element]}"
    # set partition #2 type to "Linux LUKS"
    sgdisk --typecode=2:8309 /dev/"${osDisks[$element]}"
    # set names for os partitions
    # efi partition
    sgdisk --change-name=1:"${efipartitionNames[$element]}" /dev/"${osDisks[$element]}"
    # os partition
    sgdisk --change-name=2:"${cryptospartitionNames[$element]}" /dev/"${osDisks[$element]}"
done
# create data partition(s)
for element in "${!dataDisks[@]}"
do
    # wipe the partition table
    sgdisk --zap-all /dev/"${dataDisks[$element]}"
    # create partition #1 to the size of the entire disk
    sgdisk --new=1:0:0 /dev/"${dataDisks[$element]}"
    # set partition #1 type to "Linux LUKS"
    sgdisk --typecode=1:8309 /dev/"${dataDisks[$element]}"
    # set name for data partition
    sgdisk --change-name=1:"${cryptdatapartitonNames[$element]}" /dev/"${dataDisks[$element]}"
done


# encrypt necessary partitions
printf "\e[1;32m\nEncrypting necessary partitions\n\e[0m"
sleep 3
# set up encryption for root partition(s)
for element in "${!osDisks[@]}"
do
    # encrypt root partition(s)
    echo -e "$encryptionPassword" | cryptsetup luksFormat -q --type luks1 /dev/"${cryptosPartitions[$element]}"    # grub has limited support for luks2 (luks2 supports labels)
    # decrypt and name decrypted root partition(s) so it can be used
    echo -e "$encryptionPassword" | cryptsetup open /dev/"${cryptosPartitions[$element]}" "${osencryptedcontainerNames[$element]}"
done
# set up encryption for data partition(s)
for element in "${!dataPartitions[@]}"
do
    # encrypt data partition(s)
    echo -e "$encryptionPassword" | cryptsetup luksFormat -q --type luks1 /dev/"${cryptdataPartitions[$element]}"    # grub has limited support for luks2 (luks2 supports labels)
    # decrypt and name decrypted data partition(s) so it can be used
    echo -e "$encryptionPassword" | cryptsetup open /dev/"${cryptdataPartitions[$element]}" "${dataencryptedcontainerNames[$element]}"
done


# create logical volumes
printf "\e[1;32m\nCreating logical volumes\n\e[0m"
sleep 3
for element in "${!osDisks[@]}"
do
    # create physical volume(s)
    pvcreate /dev/mapper/"${osencryptedcontainerNames[$element]}"
    # create volume group(s)
    vgcreate "${osvolgroupNames[$element]}" /dev/mapper/"${osencryptedcontainerNames[$element]}"
    # create logical volumes
    lvcreate -L "$ramSize" "${osvolgroupNames[$element]}" -n "${swapNames[$element]}"
    lvcreate -l 100%FREE "${osvolgroupNames[$element]}" -n "${rootNames[$element]}"
done


# create filesystems
printf "\e[1;32m\nCreating filesystems\n\e[0m"
sleep 3
# create efi filesystem(s)
for element in "${!osDisks[@]}"
do
    yes | mkfs.fat -F 32 -n "${efipartitionNames[$element]}" /dev/"${efiPartitions[$element]}"
done
# create swap filesystem(s)
for element in "${!osDisks[$element]}"
do
    mkswap -L "${swapNames[$element]}" /dev/"${osvolgroupNames[$element]}"/"${swapNames[$element]}"
done
# create root filesystem
if [ "$osRaid" == false ]
then
    for element in "${!osDisks[@]}"
    do
        yes | mkfs.btrfs -L "${rootNames[$element]}" -f -m dup -d single /dev/"${osvolgroupNames[$element]}"/"${rootNames[$element]}"
    done
fi
if [ "$osRaid" == true ]
then
    # set array for all root filesystem paths
    # create empty array for root filesystem paths
    rootPaths=()
    # set root filesystem paths
    for element in "${!osDisks[@]}"
    do
        rootPaths+=(/dev/"${osvolgroupNames[$element]}"/"${rootNames[$element]}")
    done
    yes | mkfs.btrfs -L rootraid -f -m raid1 -d raid1 "${rootPaths[@]}"
fi


# create btrfs subvolumes
printf "\e[1;32m\nCreating btrfs subvolumes\n\e[0m"
sleep 3
# mount root filesystem so that subvolumes can be created
mount /dev/"${osvolgroupNames[0]}"/"${rootNames[0]}" /mnt
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
mount -o noatime,compress=zstd,space_cache=v2,subvol=@ /dev/"${osvolgroupNames[0]}"/"${rootNames[0]}" /mnt
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
mount /dev/"${efiPartitions[0]}" /mnt/efi
# mount swap filesystem
swapon /dev/"${osvolgroupNames[0]}"/"${swapNames[0]}"
# mount btrfs filesystem
mount -o noatime,compress=zstd,space_cache=v2,subvol=@home /dev/"${osvolgroupNames[0]}"/"${rootNames[0]}" /mnt/home
mount -o noatime,compress=zstd,space_cache=v2,subvol=@data /dev/"${osvolgroupNames[0]}"/"${rootNames[0]}" /mnt/data
mount -o noatime,compress=zstd,space_cache=v2,subvol=@snapshots /dev/"${osvolgroupNames[0]}"/"${rootNames[0]}" /mnt/.snapshots
mount -o noatime,compress=zstd,space_cache=v2,subvol=@var /dev/"${osvolgroupNames[0]}"/"${rootNames[0]}" /mnt/var










# update the system clock
#########################

printf "\e[1;32m\nUpdating clock\n\e[0m"
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
