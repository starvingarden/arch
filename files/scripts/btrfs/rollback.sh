#!/bin/bash

# choose subvolume @, @home, or both to restore
###############################################

echo -e "\n\n"
# set the "$subVolumes" array to the available subvolumes to restore
subVolumes=("@" "@home" "@ and @home")
# prompt user to select one of @ or @home
PS3=$'\n'"Enter the number for the subvolume(s) you want to restore: "
select subVolume in "${subVolumes[@]}"
do
    if (( REPLY > 0 && REPLY <= "${#subVolumes[@]}" ))
    then
        read -rp $'\n'"Are you sure you want to restore the subvolume(s) \"$subVolume\"? [Y/n] " subvolumeConfirm
        subvolumeConfirm=${subvolumeConfirm:-Y}
        case $subvolumeConfirm in
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
    else
        printf "\e[1;31m\nInvalid option. Try another one\n\e[0m"
        sleep 3
        echo -e "\n\n"
        REPLY=
    fi
done
# the variable $subVolume should be one of "@", "@home, or "@ and @home"



# set folder in /.snapshots to get snapshots from
#################################################

if [ "$subVolume" == @ ]
then
    snapshotFolder=root
elif [ "$subVolume" == @home ]
then
    snapshotFolder=home
fi



# get the snapshot(s) you want to restore
#########################################

echo -e "\n\n"
# set the "$snapShots" array to the available snapshots to restore
readarray -t snapShots < <(btrfs subvolume list -o /.snapshots | grep "$snapshotFolder" | grep -Eo '@[[:print:]]*$')
PS3=$'\n'"Enter the number for the snapshot you want to restore: "
select snapShot in "${snapShots[@]}"
do
    if (( REPLY > 0 && REPLY <= "${#snapShots[@]}" ))
    then
        read -rp $'\n'"Are you sure you want to select the snapshot \"$snapShot\"? [Y/n] " snapshotConfirm
        snapshotConfirm=${snapshotConfirm:-Y}
        case $snapshotConfirm in
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
    else
        printf "\e[1;31m\nInvalid option. Try another one\n\e[0m"
        sleep 3
        echo -e "\n\n"
        REPLY=
    fi
done



# if restoring @home and multiple directories exist inside /home, only restore the necessary directories
########################################################################################################

# determine if the user needs to be asked about the home subvolume
if [ "$subVolume" == @home ]
then
    directoryNumber=$(ls /home | grep -Eoc '[[:graph:]]')
    if [ "$directoryNumber" -gt 1 ]
    then
        while true
        do
            # ask if user wants to restore the entire @home subvolume
            read -rp $'\n'"Restoring the @home subvolume will restore data for the entire home directory. Instead would you like to only restore data for a particular directory in /home? [Y/n] " partialRestore
            partialRestore=${partialRestore:-Y}
            case $partialRestore in
                [yY][eE][sS]|[yY])
                    partialRestore=true
                    ;;
                [nN][oO]|[nN])
                    partialRestore=false
                    ;;
                *)
                    ;;
            esac
            REPLY=

            # confirm if user wants to restore the entire @home subvolume
            if [ "$partialRestore" == true ]
            then
                read -rp $'\n'"Are you sure you want to restore data for a particular directory in /home instead of the entire home directory? [Y/n] " partialrestoreConfirm
                partialrestoreConfirm=${partialrestoreConfirm:-Y}
                case $partialrestoreConfirm in
                    [yY][eE][sS]|[yY])
                        break
                        ;;
                    [nN][oO]|[nN])
                        ;;
                    *)
                        ;;
                esac
                REPLY=
            elif [ "$partialRestore" == false ]
            then
                read -rp $'\n'"Are you sure you want to restore the entire home directory? [Y/n] " partialrestoreConfirm
                partialrestoreConfirm=${partialrestoreConfirm:-Y}
                case $partialrestoreConfirm in
                    [yY][eE][sS]|[yY])
                        break
                        ;;
                    [nN][oO]|[nN])
                        ;;
                    *)
                        ;;
                esac
                REPLY=
            fi
        done
    fi
fi



# if the user wants to perform a partial restore of the /home directory, backup the necessary /home subdirectories
##################################################################################################################

if [ "$partialRestore" == true ]
then
    echo -e "\n\n"
    # get the home directory you want to restore so others can be backed up
    readarray -t restoreDirectories < <(ls /home)
    PS3=$'\n'"Enter the number for the home directory you want to restore so that others can be backed up: "
    select restoreDirectory in "${restoreDirectories[@]}"
    do
        if (( REPLY > 0 && REPLY <= "${#restoreDirectories[@]}" ))
        then
            read -rp $'\n'"Are you sure you want to restore the home directory /home/$restoreDirectory? [Y/n] " restoredirectoryConfirm
            restoredirectoryConfirm=${restoredirectoryConfirm:-Y}
            case $restoredirectoryConfirm in
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
        else
            printf "\e[1;31m\nInvalid option. Try another one\n\e[0m"
            sleep 3
            echo -e "\n\n"
            REPLY=
        fi
    done

    # delete already existing backups
    rm -rf /.snapshots/backups/*

    # backup necessary directories
    # set number of backups that should exist
    maxbackupNumber=$(echo -e "$directoryNumber - 1" | bc)
    while true
    do
        # check how many directories have been backed up
        backupNumber=$(ls /.snapshots/backups | grep -Eoc '[[:graph:]]')
        if [ "$backupNumber" -lt "$maxbackupNumber" ]
        then
            # set directory to back up
            backupDirectory=$(ls /home | grep -E '[[:graph:]]' | grep -Ev "$restoreDirectory" | head -n 1)
    
            # backup directory
            mv /home/"$backupDirectory" /.snapshots/backups
        else
            break
        fi
    done
fi



# restore snapshot(s)
#####################

# mount the top level subvolume
mount "$rootPartition" -o subvolid=5 /mnt

# move subvolume to be restored to another location (change name of @home to @old)
mv /mnt/"$subVolume" /mnt/@old

# create a read-write snapshot of the read-only snapshot to restore
btrfs subvolume snapshot /mnt/"$snapShot" /mnt/"$subVolume"

# restore backed up home subdirectories if needed
if [ "$partialRestore" == true ]
then
    mv /mnt/@snapshots/backups/* /mnt/@home
fi
