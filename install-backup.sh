#!/bin/bash

# see arch wiki page "Installation guide#Partition the disks"
# set keyboard variable and modify chroot script
# configure raid when only using a single disk so that additional disks can be added later
# set default values
# make rootPassword and encryptionPassword the same
# make logical volumes for each os disk, then use btrfs raid 1 on each os disk

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

pacman -S archlinux-keyring btrfs-progs ca-certificates neofetch virt-what










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
# $ramSize should be an integer in megabytes of the form 1000M


# check if raid should be used for the operating system
osdisksLength=$(echo "${#osDisks[@]}")
if [ "$osdisksLength" -gt 1 ]
then
    osRaid=true
else
    osRaid=false
fi


# set os partition(s)
# create empty arrays for os partitions
efiPartitions=()
swapPartitions=()
rootPartitions=()
for element in "${osDisks[@]}"
do
    # check if disk is an nvme
    nvme=$(echo "$element" | grep -io 'nvme')
    if [ -z "$nvme" ]
    then
        efiPartitions+=("$element"1)
        swapPartitions+=("$element"2)
        rootPartitions+=("$element"3)
    else
        efiPartitions+=("$element"p1)
        swapPartitions+=("$element"p2)
        rootPartitions+=("$element"p2)
    fi
done
# os partitions should be in the form of "/dev/sda1", "/dev/nvme0n1p2", etc.


# set name(s) for decrypted os partition(s)
# create empty arrays for decrypted os partition(s)
decryptedswappartitionNames=()
decryptedswapPartitions=()
decryptedrootpartitionNames=()
decryptedrootPartitions=()
for element in "${swapPartitions[@]}"
do
    shortPartition=$(echo -e "$element" | grep -Eio '[[:alnum:]]*$')
    decryptedpartitionName=("cryptswap-$shortPartition")
    decryptedPartition=("/dev/mapper/$decryptedpartitionName")
    decryptedswappartitionNames+=("$decryptedpartitionName")
    decryptedswapPartitions+=("$decryptedPartition")
done
for element in "${rootPartitions[@]}"
do
    shortPartition=$(echo -e "$element" | grep -Eio '[[:alnum:]]*$')
    decryptedpartitionName=("cryptroot-$shortPartition")
    decryptedPartition=("/dev/mapper/$decryptedpartitionName")
    decryptedrootpartitionNames+=("$decryptedpartitionName")
    decryptedrootPartitions+=("$decryptedPartition")
done
# decrypted swap partition names should be in the form of "cryptswap-sda2", "cryptswap-nvme0n1p2", etc.
# decrypted swap partitions should be in the form of "/dev/mapper/cryptswap-sda2", "/dev/mapper/cryptswap-nvme0n1p2", etc.
# decrypted root partition names should be in the form of "cryptroot-sda3", "cryptroot-nvme0n1p3", etc.
# decrypted root partitions should be in the form of "/dev/mapper/cryptroot-sda3", "/dev/mapper/cryptroot-nvme0n1p3", etc.


# set data partition(s)
# create an empty array for data partitions
dataPartitions=()
for element in "${dataDisks[@]}"
do
    # check if disk is an nvme
    nvme=$(echo "$element" | grep -io 'nvme')
    if [ -z "$nvme" ]
    then
        dataPartitions+=("$element"1)
    else
        dataPartitions+=("$element"p1)
    fi
done
# data partitions should be in the form of "/dev/sda1", "/dev/nvme0n1p1", etc.


# set name(s) for decrypted data partition(s)
# create empty arrays for decrypted data partition(s)
decrypteddatapartitionNames=()
decrypteddataPartitions=()
for element in "${dataPartitions[@]}"
do
    shortPartition=$(echo -e "$element" | grep -Eio '[[:alnum:]]*$')
    decryptedpartitionName=("cryptdata-$shortPartition")
    decryptedPartition=("/dev/mapper/$decryptedpartitionName")
    decrypteddatapartitionNames+=("$decryptedpartitionName")
    decrypteddataPartitions+=("$decryptedpartitionName")
done
# decrypted data partition names should be in the form of "cryptdata-sda1", "cryptdata-nvme0n1p1", etc.
# decrypted data partitions should be in the form of "/dev/mapper/cryptdata-sda1", "/dev/mapper/cryptdata-nvme0n1p1", etc.


# verify variables for system information are correct
#echo -e "\n\n"
while true
do
    echo -e "arch URL=$archURL, virtual machine=$virtualMachine, laptop=$laptopInstall, processor vendor=$processorVendor, graphics vendor=$graphicsVendor, ram size=$ramSize, os raid=$osRaid, efi partitions=${efiPartitions[@]}, swap partitions=${swapPartitions[@]}, root partitions=${rootPartitions[@]}, decrypted swap partition names=${decryptedswappartitionNames[@]}, decrypted root partition names=${decryptedrootpartitionNames[@]}, decrypted swap partitions=${decryptedswapPartitions[@]}, decrypted root partitions=${decryptedrootPartitions[@]}, data partitions=${dataPartitions[@]}, decrypted data partition names=${decrypteddatapartitionNames[@]}, decrypted data partitions=${decrypteddataPartitions[@]}"
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

for element in "${dataDisks[@]}"
do
    echo "dataDisks+=($element)" >> ./variables.txt
done

for element in "${efiPartitions[@]}"
do
    echo "efiPartitions+=($element)" >> ./variables.txt
done

for element in "${swapPartitions[@]}"
do
    echo "swapPartitions+=($element)" >> ./variables.txt
done

for element in "${rootPartitions[@]}"
do
    echo "rootPartitions+=($element)" >> ./variables.txt
done

for element in "${decryptedswappartitionNames[@]}"
do
    echo "decryptedswappartitionNames+=($element)" >> ./variables.txt
done

for element in "${decryptedswapPartitions[@]}"
do
    echo "decryptedswapPartitions+=($element)" >> ./variables.txt
done

for element in "${decryptedrootpartitionNames[@]}"
do
    echo "decryptedrootpartitionNames+=($element)" >> ./variables.txt
done

for element in "${decryptedrootPartitions[@]}"
do
    echo "decryptedrootPartitions+=($element)" >> ./variables.txt
done

for element in "${dataPartitions[@]}"
do
    echo "dataPartitions+=($element)" >> ./variables.txt
done

for element in "${decrypteddatapartitionNames[@]}"
do
    echo "decrypteddatapartitionNames+=($element)" >> ./variables.txt
done

for element in "${decrypteddataPartitions[@]}"
do
    echo "decrypteddataPartitions+=($element)" >> ./variables.txt
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
for element in "${osDisks[@]}"
do
    # wipe the partition table
    sgdisk --zap-all "$element"
    # create partition #1 1GB in size
    sgdisk --new=1:0:+1G "$element"
    # set partition #1 type to "EFI system partition"
    sgdisk --typecode=1:ef00 "$element"
    # create partition #2 to the size of ram
    sgdisk --new=2:0:+"$ramSize" "$element"
    # set partition #2 type to "Linux swap"
    sgdisk --typecode=2:8200 "$element"
    # create partition #3 to the size of the rest of the disk
    sgdisk --new=3:0:0 "$element"
    # set partition #3 type to "Linux x86-64 root (/)"
    sgdisk --typecode=3:8304 "$element"
done
# create data partitions
for element in "${dataDisks[@]}"
do
    # wipe the partition table
    sgdisk --zap-all "$element"
    # create partition #1 to the size of the entire disk
    sgdisk --new=1:0:0 "$element"
    # set partition #1 type to "Linux filesystem"
    sgdisk --typecode=1:8300 "$element"
done


# encrypt necessary partitions
printf "\e[1;32m\nEncrypting necessary partitions\n\e[0m"
sleep 3
# set up encryption for swap partition(s)
for element in "${!swapPartitions[@]}"
do
    # encrypt swap partition(s)
    echo -e "$encryptionPassword" | cryptsetup luksFormat -q --type luks1 "${swapPartitions[$element]}"    # grub has limited support for luks2
    # decrypt and name decrypted swap partition(s) so it can be used
    echo -e "$encryptionPassword" | cryptsetup open "${swapPartitions[$element]}" "${decryptedswappartitionNames[$element]}"
done
# set up encryption for root partition(s)
for element in "${!rootPartitions[@]}"
do
    # encrypt root partition(s)
    echo -e "$encryptionPassword" | cryptsetup luksFormat -q --type luks1 "${rootPartitions[$element]}"    # grub has limited support for luks2
    # decrypt and name decrypted root partition(s) so it can be used
    echo -e "$encryptionPassword" | cryptsetup open "${rootPartitions[$element]}" "${decryptedrootpartitionNames[$element]}"
done
# set up encryption for data partition(s)
for element in "${!dataPartitions[@]}"
do
    # encrypt data partition(s)
    echo -e "$encryptionPassword" | cryptsetup luksFormat -q --type luks1 "${dataPartitions[$element]}"    # grub has limited support for luks2
    # decrypt and name decrypted data partition(s) so it can be used
    echo -e "$encryptionPassword" | cryptsetup open "${dataPartitions[$element]}" "${decrypteddatapartitionNames[$element]}"
done


# create filesystems
printf "\e[1;32m\nCreating filesystems\n\e[0m"
sleep 3
# create efi filesystem(s)
for element in "${efiPartitions[@]}"
do
    yes | mkfs.fat -F32 "$element"
done
# create and enable swap filesystem(s)
for element in "${decryptedswapPartitions[@]}"
do
    mkswap "$element"
    swapon "${decryptedswapPartitions[0]}"
done
# create root filesystem(s)
################################ btrfs raid may need to be set up after creating and mounting subvolumes, possibly during chroot, use (btrfs device add -f "${decryptedrootPartitions[1]}" /mnt) and (btrfs balance start -dconvert=raid1 -mconvert=raid1 /mnt)
if [ "$osRaid" == true ]
then
    yes | mkfs.btrfs -f -m raid1 -d raid1 "${decryptedrootPartitions[@]}"
else
    yes | mkfs.btrfs -f "${decryptedrootPartitions[@]}"
fi
# create data filesystem(s)     #################### this may need to be changed
if [ "$dataRaid" == true ]
then
    yes | mkfs.btrfs -f -m raid1 -d raid1 "${decrypteddataPartitions[@]}"
else
    yes | mkfs.btrfs -f "${decrypteddataPartitions[@]}"
fi


# create btrfs subvolumes         ################### need to accomodate bulk storage
printf "\e[1;32m\nCreating btrfs subvolumes\n\e[0m"
sleep 3
# mount the encrypted root partiton to /mnt
mount "${decryptedrootPartitions[0]}" /mnt
# create subvolumes
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@data
btrfs subvolume create /mnt/@snapshots
btrfs subvolume create /mnt/@var


# create directories to mount other subvolumes and partitions    ################### need to accomodate bulk storage
printf "\e[1;32m\nMounting filesystems and btrfs subvolumes\n\e[0m"
sleep 3
# unmount partitions from /mnt
umount -R /mnt
# mount root subvolume to /mnt
mount -o noatime,compress=zstd,space_cache=v2,subvol=@ "${decryptedrootPartitions[0]}" /mnt
# make directories to mount other partitions and subvolumes
mkdir -p /mnt/efi
mkdir -p /mnt/home
mkdir -p /mnt/data
mkdir -p /mnt/.snapshots
mkdir -p /mnt/var


# mount other partitions and subvolumes   ################### need to accomodate bulk storage
mount "${efiPartitions[0]}" /mnt/efi
mount -o noatime,compress=zstd,space_cache=v2,subvol=@home "${decryptedrootPartitions[0]}" /mnt/home
mount -o noatime,compress=zstd,space_cache=v2,subvol=@data "${decryptedrootPartitions[0]}" /mnt/data
mount -o noatime,compress=zstd,space_cache=v2,subvol=@snapshots "${decryptedrootPartitions[0]}" /mnt/.snapshots
mount -o noatime,compress=zstd,space_cache=v2,subvol=@var "${decryptedrootPartitions[0]}" /mnt/var










# update the system clock
#########################

printf "\e[1;32m\nUpdating Clock\n\e[0m"
sleep 3
timedatectl set-ntp true










# install required linux packages
#################################

printf "\e[1;32m\nInstalling required linux packages\n\e[0m"
sleep 3
pacstrap -K /mnt base btrfs-progs cryptsetup linux linux-firmware










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
