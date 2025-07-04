#!/bin/bash

#######
# notes
#######

# for os-prober (GRUB dual boot) to work, you may need to mount the windows efi partition with "mount /dev/{windows-efi-partition} /mnt/{foo}", then regenerate the grub config file with "grub-mkconfig -o /boot/grub/grub.cfg"
# each disk has its own physical volume, volume group, and logical volume(s). RAID is used via btrfs
# btrfs does NOT support having different raid levels in the same filesystem
# btrfs raid1 supports 2 or more disks, 50% of total storage utilization
# to create a non-raid filesystem across multiple drives (mkfs.btrfs -L filesystemLabel -f -m dup -d single /dev/sda1 /dev/sdb1 /dev/sdc1)
# to create a raid1 filesystem (mkfs.btrfs -L filesystemLabel -f -m raid1 -d raid1 /dev/sda1 /dev/sdb1 /dev/sdc1)
# to add a disk sdb1 to a single disk filesystem on sda1 and convert to raid1 (mount /dev/sda1 /mnt && btrfs device add /dev/sdb1 /mnt && btrfs balance start -dconvert=raid1 -mconvert=raid1 /mnt)
# see arch wiki page "btrfs#Multi-device file system" for information on how to convert raid levels, and add/remove/replace devices

######
# todo
######

# user should specify disks in the order they want (osdisk0 should be the 1st listed, osdisk1 2nd listed, etc.)
# kpartx command to use disks that are already configured??
# get rid of reflector code??? DONE
# import scripts git repo during config.sh
# change "not-snapped" directory to "data" DONE
# use better tools for automatically getting system information
# partition names, encrypted container names, volume group names, logical volume names, filesystem names, and logical volume paths should all be indexed starting with "1" instead of "0"???






#######################
# IMPORTANT INFORMATION
#######################

# You must set all of these variables unless using the default value
# To use the default value for a variable, leave it blank
# Not all variables have a default value, these variables cannot be left blank
# All variables must be enclosed inside double quotes





hostName=""
    # this is the device name
    # default value = "arch"
    # example: hostName="arch"

userName=""
    # this is your user name
    # default value = "johndoe"
    # example: userName="johndoe"

userPassword=""
    # this is your user password
    # default value = "password"
    # example: userPassword="password"

rootPassword=""
    # this is the root password
    # default value = "password"
    # example: rootPassword="password"

encryptionPassword=""
    # this is the password to be used for disk encryption
    # default value = "password"
    # example: encryptionPassword="password"

osDisks=""
    # this is a list of space separated disks to use for the operating system
    # you must use 1 or more disks
    # run "fdisk -l" to list available disks
    # NO DEFAULT VALUE
    # example: osDisks="sda nvme0n1"

osRaid=""
    # this determines if RAID1 will be used for the root filesystem
    # you must be using more than 1 os disks (osDisks) to enable
    # set to "true" or "false"
    # default value = "false"
    # example: osRaid="true"

dataDisks=""
    # this is a list of space separated disks to use for bulk storage
    # you can use as many disks as you like (including none)
    # you cannot use any disks that will be used for the operating system (osDisks)
    # run "fdisk -l" to list available disks
    # default value = ""
    # example: dataDisks="sdb nvme1n1"

dataRaid=""
    # this determines if RAID1 will be used for the bulk storage filesystem
    # you must be using more than 1 data disks (dataDisks) to enable
    # set to "true" or "false"
    # default value = "false"
    # example: dataRaid="true"

diskWipe=""
    # this determines if disks will be securely wiped before proceeding
    # this can take a long time
    # set to "true" or "false"
    # default value = "false"
    # example: diskWipe="true"

timeZone=""
    # this sets the time zone
    # run "timedatectl list-timezones" to list available timezones
    # default value = "US/Central"
    # example: timeZone="US/Central"

keyMap=""
    # this sets the keymap for your keyboard
    # run "localectl list-keymaps" to list available keymaps
    # default value = "us"
    # example: keyMap="us"

reflectorCode=""
    # this sets the country to download packages from
    # must set to 2 capital letters
    # run "reflector --list-countries" to list available countries and their codes
    # default value = "US"
    # example: reflectorCode="US"

multiBoot=""
    # this determines if the bootloader will check for other operating systems
    # set to either "true" or "false"
    # enable if you have already, or plan to dual boot on another disk
    # enable if you are unsure, (this setting has very little effect)
    # default value = "true"
    # example: multiBoot="true"

customConfig=""
    # this determines if the repo owner's personal config files and settings will be used
    # for details on what this includes, see the "custom configurations" section in the config.sh script
    # set to either "true" or "false"
    # default value = "true"
    # example: customConfig="true"





#############################
# DO NOT CHANGE ANYTHING ELSE
#############################










# set default values for appropriate variables
##############################################

if [ -z "$hostName" ]
then
    hostName=arch
fi

if [ -z "$userName" ]
then
    userName=johndoe
fi

if [ -z "$userPassword" ]
then
    userPassword=password
fi

if [ -z "$rootPassword" ]
then
    rootPassword=password
fi

if [ -z "$encryptionPassword" ]
then
    encryptionPassword=password
fi

if [ -z "$osRaid" ]
then
    osRaid=false
fi

if [ -z "$dataRaid" ]
then
    dataRaid=false
fi

if [ -z "$diskWipe" ]
then
    diskWipe=false
fi

if [ -z "$timeZone" ]
then
    timeZone=US/Central
fi

if [ -z "$keyMap" ]
then
    keyMap=us
fi

if [ -z "$reflectorCode" ]
then
    reflectorCode=US
fi

if [ -z "$multiBoot" ]
then
    multiBoot=true
fi

if [ -z "$customConfig" ]
then
    customConfig=true
fi








# modify disk arrays
####################

# turn space separated strings into arrays
osDisks=($osDisks)
dataDisks=($dataDisks)










# install packages needed for installation
##########################################

printf "\e[1;32m\nInstalling packages needed for installation\n\e[0m"
sleep 3

pacman -S archlinux-keyring btrfs-progs ca-certificates lshw lvm2










# automatically set system variables
####################################

printf "\e[1;32m\nAutomatically setting variables for system information\n\e[0m"
sleep 3


# set arch url
archURL=$(grep -i 'url' /root/arch/.git/config | grep -Eo '[[:graph:]]*$')
# $archURL should be of the form of a url to the arch git repo


# check if installing on virtual machine
virtualMachine=$(hostnamectl chassis | grep -io 'vm')
if [ -z "$virtualMachine" ]
then
    virtualMachine=false
else
    virtualMachine=true
fi


# check if installing on a laptop
laptopInstall=$(hostnamectl chassis | grep -io 'laptop')
if [ -z "$laptopInstall" ]
then
    laptopInstall=false
else
    laptopInstall=true
fi


# set processor vendor
processorVendor=$(lshw -class cpu | grep -i 'vendor' | grep -Eio 'amd|intel' | awk '{print tolower($0)}' | head -n 1)
if [ -z "$processorVendor" ]
then
    processorVendor=null
fi
# $processorVendor should be all lowercase and one of "amd", "intel", or "null"


# set graphics vendor
graphicsVendor=$(lshw -class display | grep -i 'vendor' | grep -Eio 'amd|intel|nvidia' | awk '{print tolower($0)}' | head -n 1)
if [ -z "$graphicsVendor" ]
then
    graphicsVendor=null
fi
# $graphicsVendor should be all lowercase and one of "amd", "intel", "nvidia", or "null"


# set ram size
ramsizeInteger=$(free --mega | grep -i 'mem' | awk '{print $2}')
ramSize=$(echo "$ramsizeInteger"M)
# $ramSize should be an integer in megabytes of the form of 1000M





# set arrays for os disks
#########################

# set os partitions
# used when encrypting partition(s), and creating and mounting filesystems
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
# efi partition(s) should be in the form of "sda1", "nvme0n1p1", etc.
# encrypted os partition(s) should be in the form of "sda2", "nvme0n1p2", etc.


# set os partition names
# used to name os partitions
# create empty arrays for os partition names
efipartitionNames=()
cryptospartitionNames=()
# set efi partition name(s)
for element in "${!osDisks[@]}"
do
    efiPartition=(osdisk"$((element + 1))"p1)
    efipartitionNames+=("$efiPartition")
done
# set encrypted os partition name(s)
for element in "${!osDisks[@]}"
do
    cryptosPartition=(osdisk"$((element + 1))"p2)
    cryptospartitionNames+=("$cryptosPartition")
done
# efi partition name(s) should be in the form of "osdisk1p1", "osdisk2p1", etc.
# encrypted os partition name(s) should be in the form of "osdisk1p2", "osdisk2p2", etc.


# set os encrypted container name(s)
# used to name os encrypted container(s)
# create empty array for os encrypted container name(s)
osencryptedcontainerNames=()
for element in "${!osDisks[@]}"
do
    osencryptedcontainerNames+=(cryptos"$element")
done
# os encrypted container name(s) should be of the form "cryptos0", "cryptos1", etc.


# set os volume group name(s)
# used to name os volume group(s)
# create empty array for os volume group name(s)
osvolgroupNames=()
for element in "${!osDisks[@]}"
do
    osvolgroupNames+=(osvolgroup"$element")
done
# os volume group name(s) should be in the form of "osvolgroup0", "osvolgroup1", etc.


# set os logical volume name
# used to name os logical volumes
# create empty arrays for os logical volume names
swaplvNames=()
rootlvNames=()
for element in "${!osDisks[@]}"
do
    swaplvNames+=(swaplv"$element")
    rootlvNames+=(rootlv"$element")
done
# os logical volume names should be in the form of "swaplv0", "swaplv1", "rootlv0", "rootlv1", etc.


# set os filesystem names
# used to name os filesystems
# create empty arrays for os filesystem names
efifsNames=()
swapfsNames=()
rootfsNames=()
# set os filesystem names
for element in "${!osDisks[@]}"
do
    efifsNames+=(efi"$element")
    swapfsNames+=(swap"$element")
    # set non-RAID root filesystem name
    if [ "$osRaid" == false ]
    then
        rootfsNames=(rootfs)
    fi
    # set RAID1 root filesystem name
    if [ "$osRaid" == true ]
    then
        rootfsNames=(rootraidfs)
    fi
done
# non-root os filesystem names should be in the form of "efifs0", "efifs1", "swapfs0", "swapfs1", etc.
# a non-RAID root filesystem name should be "rootfs"
# a RAID1 root filesystem name should be "rootraidfs"


# set array for all root logical volume path(s)
# used when creating root filesystem
# create empty array for all root logical volume path(s)
rootlvPaths=()
# set root logical volume paths
for element in "${!osDisks[@]}"
do
    rootlvPaths+=(/dev/"${osvolgroupNames[$element]}"/"${rootlvNames[$element]}")
done
# root logical volume path(s) should be in the form of "/dev/osvolgroup0/rootlv0", "/dev/osvolgroup1/rootlv1"





# set arrays for data disks
###########################

# set data partition(s)
# used when encrypting partition(s)
# create an empty array for encrypted data partition(s)
cryptdataPartitions=()
# set data partitions
for element in "${dataDisks[@]}"
do
    # check if disk is an nvme
    nvme=$(echo "$element" | grep -io 'nvme')
    if [ -z "$nvme" ]
    then
        cryptdataPartitions+=("$element"1)
    else
        cryptdataPartitions+=("$element"p1)
    fi
done
# data partition(s) should be in the form of "sda1", "nvme0n1p1", etc.


# set data partition name(s)
# used to name encrypted data partition(s)
# create an empty array for encrypted data partition name(s)
cryptdatapartitionNames=()
# set encrypted data partition name(s)
for element in "${!dataDisks[@]}"
do
    cryptdataPartition=(datadisk"$element"p1)
    cryptdatapartitionNames+=("$cryptdataPartition")
done
# encrypted data partition name(s) should be in the form of "datadisk0p1", "datadisk1p1", etc.


# set data encrypted container name(s)
# used to name data encrypted container(s)
# create empty array for data encrypted container name(s)
dataencryptedcontainerNames=()
for element in "${!dataDisks[@]}"
do
    dataencryptedcontainerNames+=(cryptdata"$element")
done
# data encrypted container name(s) should be of the form "cryptdata0", "cryptdata1", etc.


# set data volume group name(s)
# used to name data volume group(s)
# create empty array for data volume group name(s)
datavolgroupNames=()
for element in "${!dataDisks[@]}"
do
    datavolgroupNames+=(datavolgroup"$element")
done
# data volume group name(s) should be in the form of "datavolgroup0", "datavolgroup1", etc.


# set data logical volume name(s)
# create empty array for data logical volume name(s)
datalvNames=()
for element in "${!dataDisks[@]}"
do
    datalvNames+=(datalv"$element")
done
# data logical volume name(s) should be in the form of "datalv0", "datalv1", etc.


# set data filesystem name
# used to name data filesystem
# create empty array for data filesystem name
datafsNames=()
# only set data filesystem names if using data disks
if [ "${#dataDisks[@]}" -gt 0 ]
then
    # set non-RAID data filesystem name
    if [ "$dataRaid" == false ]
    then
        datafsNames=(datafs)
    fi
    # set RAID1 data filesystem name
    if [ "$dataRaid" == true ]
    then
        datafsNames=(dataraidfs)
    fi
fi
# a non-RAID data fileystem should be "datafs"
# a RAID1 data filesystem should be "dataraidfs"


# set array for all data logical volume path(s)
# used when creating data filesystem
# create empty array for data logical volume path(s)
datalvPaths=()
# set data logical volume paths
for element in "${!dataDisks[@]}"
do
    datalvPaths+=(/dev/"${datavolgroupNames[$element]}"/"${datalvNames[$element]}")
done
# data logical volume path(s) should be in the form of "/dev/datavolgroup0/datalv0", "/dev/datavolgroup1/datalv1"










# verify variables for system information are correct
#echo -e "\n\n"
while true
do
    echo -e "arch URL=$archURL, virtual machine=$virtualMachine, laptop=$laptopInstall, processor vendor=$processorVendor, graphics vendor=$graphicsVendor, ram size=$ramSize, os disks=${osDisks[@]}, efi partitions=${efiPartitions[@]}, crypt os partitions=${cryptosPartitions[@]}, efi partition names=${efipartitionNames[@]}, crypt os partition names=${cryptospartitionNames[@]}, os encrypted container names=${osencryptedcontainerNames[@]}, os volume group names=${osvolgroupNames[@]}, os logical volume names=${swaplvNames[@]} ${rootlvNames[@]}, os filesystem names=${efifsNames[@]} ${swapfsNames[@]} ${rootfsNames[@]}, root logical volume paths=${rootlvPaths[@]}, crypt data partitions=${cryptdataPartitions[@]}, crypt data partition names=${cryptdatapartitionNames[@]}, data encrypted container names=${dataencryptedcontainerNames[@]}, data volume group names=${datavolgroupNames[@]}, data logical volume names=${datalvNames[@]}, data filesystem names=${datafsNames[@]}, data logical volume paths=${datalvPaths[@]}"
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
echo -e "osRaid=$osRaid" >> ./variables.txt
echo -e "dataRaid=$dataRaid" >> ./variables.txt
echo -e "diskWipe=$diskWipe" >> ./variables.txt
echo -e "timeZone=$timeZone" >> ./variables.txt
echo -e "keyMap=$keyMap" >> ./variables.txt
echo -e "reflectorCode=$reflectorCode" >> ./variables.txt
echo -e "multiBoot=$multiBoot" >> ./variables.txt
echo -e "customConfig=$customConfig" >> ./variables.txt
echo -e "archURL=$archURL" >> ./variables.txt
echo -e "virtualMachine=$virtualMachine" >> ./variables.txt
echo -e "laptopInstall=$laptopInstall" >> ./variables.txt
echo -e "processorVendor=$processorVendor" >> ./variables.txt
echo -e "graphicsVendor=$graphicsVendor" >> ./variables.txt
echo -e "ramSize=$ramSize" >> ./variables.txt
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

for element in "${swaplvNames[@]}"
do
    echo "swaplvNames+=($element)" >> ./variables.txt
done

for element in "${rootlvNames[@]}"
do
    echo "rootlvNames+=($element)" >> ./variables.txt
done

for element in "${efifsNames[@]}"
do
    echo "efifsNames+=($element)" >> ./variables.txt
done

for element in "${swapfsNames[@]}"
do
    echo "swapfsNames+=($element)" >> ./variables.txt
done

for element in "${rootfsNames[@]}"
do
    echo "rootfsNames+=($element)" >> ./variables.txt
done

for element in "${rootlvPaths[@]}"
do
    echo "rootlvPaths+=($element)" >> ./variables.txt
done

for element in "${dataDisks[@]}"
do
    echo "dataDisks+=($element)" >> ./variables.txt
done

for element in "${cryptdataPartitions[@]}"
do
    echo "cryptdataPartitions+=($element)" >> ./variables.txt
done

for element in "${cryptdatapartitionNames[@]}"
do
    echo "cryptdatapartitionNames+=($element)" >> ./variables.txt
done

for element in "${dataencryptedcontainerNames[@]}"
do
    echo "dataencryptedcontainerNames+=($element)" >> ./variables.txt
done

for element in "${datavolgroupNames[@]}"
do
    echo "datavolgroupNames+=($element)" >> ./variables.txt
done

for element in "${datalvNames[@]}"
do
    echo "datalvNames+=($element)" >> ./variables.txt
done

for element in "${datafsNames[@]}"
do
    echo "datafsNames+=($element)" >> ./variables.txt
done

for element in "${datalvPaths[@]}"
do
    echo "datalvPaths+=($element)" >> ./variables.txt
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
# encrypt os partition(s)
for element in "${!osDisks[@]}"
do
    # encrypt os partition(s)
    echo -e "$encryptionPassword" | cryptsetup luksFormat -q --type luks1 /dev/"${cryptosPartitions[$element]}"    # grub has limited support for luks2 (luks2 supports labels)
    # decrypt and name decrypted os partition(s) so they can be used
    echo -e "$encryptionPassword" | cryptsetup open /dev/"${cryptosPartitions[$element]}" "${osencryptedcontainerNames[$element]}"
done
# encrypt data partition(s)
for element in "${!dataDisks[@]}"
do
    # encrypt data partition(s)
    echo -e "$encryptionPassword" | cryptsetup luksFormat -q --type luks1 /dev/"${cryptdataPartitions[$element]}"    # grub has limited support for luks2 (luks2 supports labels)
    # decrypt and name decrypted data partition(s) so they can be used
    echo -e "$encryptionPassword" | cryptsetup open /dev/"${cryptdataPartitions[$element]}" "${dataencryptedcontainerNames[$element]}"
done


# create logical volumes
printf "\e[1;32m\nCreating logical volumes\n\e[0m"
sleep 3
# create os logical volumes
for element in "${!osDisks[@]}"
do
    # create physical volume(s)
    pvcreate /dev/mapper/"${osencryptedcontainerNames[$element]}"
    # create volume group(s)
    vgcreate "${osvolgroupNames[$element]}" /dev/mapper/"${osencryptedcontainerNames[$element]}"
    # create logical volumes
    lvcreate -L "$ramSize" "${osvolgroupNames[$element]}" -n "${swaplvNames[$element]}"
    lvcreate -l 100%FREE "${osvolgroupNames[$element]}" -n "${rootlvNames[$element]}"
done
# create data logical volume(s)
for element in "${!dataDisks[@]}"
do
    # create physical volume(s)
    pvcreate /dev/mapper/"${dataencryptedcontainerNames[$element]}"
    # create volume group(s)
    vgcreate "${datavolgroupNames[$element]}" /dev/mapper/"${dataencryptedcontainerNames[$element]}"
    # create logical volume(s)
    lvcreate -l 100%FREE "${datavolgroupNames[$element]}" -n "${datalvNames[$element]}"
done


# create filesystems
printf "\e[1;32m\nCreating filesystems\n\e[0m"
sleep 3
# create efi filesystem(s)
for element in "${!osDisks[@]}"
do
    yes | mkfs.fat -F 32 -n "${efifsNames[$element]}" /dev/"${efiPartitions[$element]}"
done
# create swap filesystem(s)
for element in "${!osDisks[$element]}"
do
    mkswap -L "${swapfsNames[$element]}" /dev/"${osvolgroupNames[$element]}"/"${swaplvNames[$element]}"
done
# create root filesystem
# create non-RAID root filesystem
if [ "$osRaid" == false ]
then
    yes | mkfs.btrfs -L "${rootfsNames[@]}" -f -m dup -d single "${rootlvPaths[@]}"
fi
# create RAID1 root filesystem
if [ "$osRaid" == true ]
then
    yes | mkfs.btrfs -L "${rootfsNames[@]}" -f -m raid1 -d raid1 "${rootlvPaths[@]}"
fi
# create data filesystems if necessary
if [ "${#dataDisks[@]}" -ne 0 ]
then
    # create non-RAID data filesystem
    if [ "$dataRaid" == false ]
    then
        yes | mkfs.btrfs -L "${datafsNames[@]}" -f -m dup -d single "${datalvPaths[@]}"
    fi
    # create RAID1 data filesystem
    if [ "$dataRaid" == true ]
    then
        yes | mkfs.btrfs -L "${datafsNames[@]}" -f -m raid1 -d raid1 "${datalvPaths[@]}"
    fi
fi


# create btrfs subvolumes
printf "\e[1;32m\nCreating btrfs subvolumes\n\e[0m"
sleep 3
# create btrfs subvolumes for root filesystem
# mount root logical volume so that root subvolumes can be created
mount /dev/"${osvolgroupNames[0]}"/"${rootlvNames[0]}" /mnt
# create btrfs subvolumes
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@snapshots
btrfs subvolume create /mnt/@var
# create data btrfs subvolume on root logical volume if not using any data disks
if [ "${#dataDisks[@]}" -eq 0 ]
then
    btrfs subvolume create /mnt/@data
fi
# unmount root logical volume from /mnt
umount -R /mnt
# create btrfs subvolume for data filesystem if necessary
if [ "${#dataDisks[@]}" -ne 0 ]
then
    # mount data logical volume so that the data subvolume can be created
    mount /dev/"${datavolgroupNames[0]}"/"${datalvNames[0]}" /mnt
    btrfs subvolume create /mnt/@data
    # unmount data logical volume from /mnt
    umount -R /mnt
fi


# create directories to mount filesystems
printf "\e[1;32m\nCreating directories to mount filesystems\n\e[0m"
sleep 3
# mount root subvolume to /mnt
mount -o noatime,compress=zstd,space_cache=v2,subvol=@ /dev/"${osvolgroupNames[0]}"/"${rootlvNames[0]}" /mnt
# make directories to mount other partitions and subvolumes
mkdir -p /mnt/efi
mkdir -p /mnt/home
mkdir -p /mnt/.snapshots
mkdir -p /mnt/var
mkdir -p /mnt/data


# mount filesystems
printf "\e[1;32m\nMounting filesystems\n\e[0m"
sleep 3
# mount efi filesystem
mount /dev/"${efiPartitions[0]}" /mnt/efi
# mount swap filesystem
swapon /dev/"${osvolgroupNames[0]}"/"${swaplvNames[0]}"
# mount root subvolumes
mount -o noatime,compress=zstd,space_cache=v2,subvol=@home /dev/"${osvolgroupNames[0]}"/"${rootlvNames[0]}" /mnt/home
mount -o noatime,compress=zstd,space_cache=v2,subvol=@snapshots /dev/"${osvolgroupNames[0]}"/"${rootlvNames[0]}" /mnt/.snapshots
mount -o noatime,compress=zstd,space_cache=v2,subvol=@var /dev/"${osvolgroupNames[0]}"/"${rootlvNames[0]}" /mnt/var
if [ "${#dataDisks[@]}" -eq 0 ]
then
    mount -o noatime,compress=zstd,space_cache=v2,subvol=@data /dev/"${osvolgroupNames[0]}"/"${rootlvNames[0]}" /mnt/data
fi
if [ "${#dataDisks[@]}" -ne 0 ]
then
    mount -o noatime,compress=zstd,space_cache=v2,subvol=@data /dev/"${datavolgroupNames[0]}"/"${datalvNames[0]}" /mnt/data
fi










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
