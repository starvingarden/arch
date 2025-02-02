#!/bin/bash

# chroot confirmation
#####################

printf "\e[1;32m\nChrooted into new environment and running chroot script\n\e[0m"
sleep 3










# import variables from install.sh
##################################

source ./variables.txt










# configure reflector and pacman, then install all needed packages
##################################################################

# configure reflector
printf "\e[1;32m\nConfiguring reflector\n\e[0m"
sleep 3
# install reflector
pacman -S --needed --noconfirm reflector
# configure reflector
#echo -e "--country $reflectorCode" >> /etc/xdg/reflector/reflector.conf
sed -Ei 's/--latest [[:graph:]]*/--latest 15/' /etc/xdg/reflector/reflector.conf
sed -Ei 's/--sort [[:graph:]]*/--sort rate/' /etc/xdg/reflector/reflector.conf
sed -Ei 's/--protocol [[:graph:]]*/--protocol https/' /etc/xdg/reflector/reflector.conf
systemctl enable reflector.timer


# configure pacman
printf "\e[1;32m\nConfiguring pacman\n\e[0m"
sleep 3
sed -i 's/#\[multilib\]/\[multilib\]/;/\[multilib\]/{n;s/#Include /Include /}' /etc/pacman.conf
pacman -Syu
pacman -S --needed --noconfirm pacman-contrib pacutils


# install microcode updates
if [ "$processorVendor" != null ]
then
    printf "\e[1;32m\nInstalling microcode updates\n\e[0m"
    sleep 3
    pacman -S --needed --noconfirm "$processorVendor"-ucode
fi


# install graphics drivers
if [ "$graphicsVendor" != null ]
then
    printf "\e[1;32m\nInstalling graphics drivers\n\e[0m"
    sleep 3
fi
if [ "$graphicsVendor" == amd ]
then
    pacman -S --needed xf86-video-amdgpu mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon libva-mesa-driver lib32-libva-mesa-driver mesa-vdpau lib32-mesa-vdpau  
fi
if [ "$graphicsVendor" == intel ]
then
    pacman -S --needed xf86-video-intel mesa lib32-mesa vulkan-intel
fi
if [ "$graphicsVendor" == nvidia ]
then
    pacman -S --needed nvidia nvidia-settings nvidia-utils lib32-nvidia-utils
fi


# install essential packages
printf "\e[1;32m\nInstalling essential packages\n\e[0m"
sleep 3
pacman -S --needed --noconfirm bash base-devel coreutils efibootmgr git grub networkmanager os-prober sudo tmux vim xdg-utils










# configure the system
######################

printf "\e[1;32m\nConfiguring the system\n\e[0m"
sleep 3


# set the time and language
ln -sf /usr/share/zoneinfo/"$timeZone" /etc/localtime
hwclock --systohc
sed -i 's/#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" >> /etc/locale.conf


# set the keymap for the sd-vconsole hook
echo -e "KEYMAP=$keyMap" > /etc/vconsole.conf


# set the hostname
echo -e "$hostName" >> /etc/hostname


# configure the network
echo -e "127.0.0.1   localhost" >> /etc/hosts
echo -e "::1         localhost" >> /etc/hosts
echo -e "127.0.1.1   $hostName" >> /etc/hosts
# enable network manager
systemctl enable NetworkManager


# configure fstab
# remove subvolid's
sed -i 's/,subvolid=[0-9]*//' /etc/fstab


# enable and speed up package builds
sed -i 's/#MAKEFLAGS=\"-j[0-9]*\"/MAKEFLAGS=\"-j$(nproc)\"/g' /etc/makepkg.conf


# generate a keyfile to decrypt swap and root partitions so that grub can decrypt them automatically on boot (see the following arch wiki pages)
# dm-crypt/Device encryption#Keyfiles
printf "\e[1;32m\nGenerating key file for encrypted partitions\n\e[0m"
sleep 3
# create directory to hold key file
mkdir /root/crypt-keys
# give directory appropriate permissions
chmod 000 /root/crypt-keys
# create key file
dd bs=512 count=4 if=/dev/random of=/root/crypt-keys/crypt-key.keyfile iflag=fullblock
chmod 000 /root/crypt-keys/crypt-key.keyfile
# add keyfile as a LUKS key to encrypted partitions
# add keyfile as a LUKS key to encrypted os partitions
for element in "${!cryptosPartitions[@]}"
do
    echo -e "$encryptionPassword" | cryptsetup luksAddKey /dev/"${cryptosPartitions[$element]}" /root/crypt-keys/crypt-key.keyfile
done
# add keyfile as a LUKS key to encrypted data partitions
for element in "${!cryptdataPartitions[@]}"
do
    echo -e "$encryptionPassword" | cryptsetup luksAddKey /dev/"${cryptdataPartitions[$element]}" /root/crypt-keys/crypt-key.keyfile
done


################################################################################
# add "microcode" to mkinitcpio hooks????? (see arch wiki news about mkinitcpio hook) (see microcode arch wiki page)


# configure mkinitcpio.conf (see the following arch wiki pages)
# dm-crypt/Encrypting an entire system
printf "\e[1;32m\nConfiguring initcpio\n\e[0m"
sleep 3
# add btrfs into binaries so that btrfs-check will work (see arch wiki page "btrfs#Troubleshooting")
sed -i 's/BINARIES=()/BINARIES=(btrfs)/' /etc/mkinitcpio.conf
# add the keyfile to files to embed the keyfile in the initramfs and unlock the root partition(s) on boot (see arch wiki page "dm-crypt/Device encryption#Unlocking the root partition at boot")
sed -i 's|FILES=()|FILES=(/root/crypt-keys/crypt-key.keyfile)|' /etc/mkinitcpio.conf
# change hooks from udev to systemd
# change the "udev" hook to the "systemd" hook (see arch wiki page "btrfs#Multi-device_file_system")
sed -i '/^HOOKS=/ s/udev/systemd/' /etc/mkinitcpio.conf
# remove the "consolefont" hook (see arch wiki page "dm-crypt/Encrypting an entire system#Encrypted boot partition (GRUB)")
sed -i '/^HOOKS=/ s/consolefont //g' /etc/mkinitcpio.conf
# change the "keymap" hook to the "sd-vconsole" hook
sed -i '/^HOOKS=/ s/keymap/sd-vconsole/' /etc/mkinitcpio.conf
# add/move additional hooks
# add the sd-encrypt and lvm2 hooks before the filesystems hook for encryption support (see arch wiki pages "dm-crypt/System configuration#mkinitcpio" and "dm-crypt/Encrypting an entire system#LVM on LUKS")
sed -i '/^HOOKS=/ s/filesystems/sd-encrypt lvm2 &/g' /etc/mkinitcpio.conf
# move the keyboard hook to before the autodetect hook (see arch wiki page "dm-crypt/System configuration")
sed -i '/^HOOKS=/ s/keyboard //g' /etc/mkinitcpio.conf
sed -i '/^HOOKS=/ s/autodetect/keyboard &/g' /etc/mkinitcpio.conf
# regenerate the intramfs
mkinitcpio -P
# secure the keyfile embedded in the initramfs
chmod 600 /boot/initramfs-linux*


# get kernel parameter variables for grub
# get first encrypted os partition uuid
cryptospartitionUUID=$(blkid -s UUID -o value /dev/"${cryptosPartitions[0]}")


# configure grub (see the following arch wiki pages)
# dm-crypt/Encrypting an entire system
# dm-crypt/Swap encryption
printf "\e[1;32m\nConfiguring grub\n\e[0m"
sleep 3
# edit /etc/default/grub
# set grub timeout
sed -i 's/GRUB_TIMEOUT=[0-9]*/GRUB_TIMEOUT=300/' /etc/default/grub
# enable booting from encrypted devices
sed -i 's/#GRUB_ENABLE_CRYPTODISK=y/GRUB_ENABLE_CRYPTODISK=y/' /etc/default/grub
# add the following kernel parameters
# rd.luks.name=$cryptosPartitionUUID=${encryptedcontainerNames[0]} (specifies unlocking and naming of the root partition on boot)
# rd.luks.key=$cryptosPartitionUUID=/root/crypt-keys/crypt-key.keyfile
# root=/dev/${osvolgroupNames[0]}/${rootlvNames[0]}
# resume=/dev/${osvolgroupNames[0]}/${swaplvNames[0]} (enables resuming from swap hibernation)
# sysctl.vm.swappiness=0 (sets swappiness on boot)
sed -i "s|GRUB_CMDLINE_LINUX_DEFAULT=\"|GRUB_CMDLINE_LINUX_DEFAULT=\"rd.luks.name=$cryptospartitionUUID=${osencryptedcontainerNames[0]} rd.luks.key=$cryptospartitionUUID=/root/crypt-keys/crypt-key.keyfile root=/dev/${osvolgroupNames[0]}/${rootlvNames[0]} resume=/dev/${osvolgroupNames[0]}/${swaplvNames[0]} sysctl.vm.swappiness=0 |" /etc/default/grub
if [ "$multiBoot" == true ]
then
    # show other operating systems in grub boot menu
    sed -i 's/#GRUB_DISABLE_OS_PROBER=false/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub
fi
# install grub
grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=GRUB --recheck
# generate the grub config file
grub-mkconfig -o /boot/grub/grub.cfg


# configure users
printf "\e[1;32m\nConfiguring users\n\e[0m"
sleep 3
# configure root user
echo -e "$rootPassword\n$rootPassword" | passwd root
#sed -i 's/^# root ALL=(ALL:ALL) ALL/root ALL=(ALL:ALL) ALL/' /etc/sudoers
#echo -e "root ALL=(ALL:ALL) ALL" >> /etc/sudoers
# configure user
useradd -m -g users -G wheel -s /bin/bash "$userName"
#useradd -mG wheel "$userName"
echo -e "$userPassword\n$userPassword" | passwd "$userName"
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
#echo -e "%wheel ALL=(ALL:ALL) ALL" >> /etc/sudoers


# import files
printf "\e[1;32m\nImporting files\n\e[0m"
sleep 3
# save arch repo
su -c "git clone $archURL /home/$userName/arch" "$userName"
# save packages.txt
su -c "cp /home/$userName/arch/packages.txt /home/$userName" "$userName"
# save config.sh
su -c "cp /home/$userName/arch/config.sh /home/$userName" "$userName"
chmod +x /home/"$userName"/config.sh


# set global environment variables
if [ "$virtualMachine" == true ]
then
    #echo -e "\n# enables mouse cursor on virtual machines"    >>  /etc/bash.bashrc
    #echo -e "WLR_NO_HARDWARE_CURSORS=1"                       >>  /etc/bash.bashrc
    sleep 1
fi


# save custom config file
if [ "$customConfig" == true ]
then
    touch /home/"$userName"/.customconfig
fi










# exit the chroot environment (does this automatically when script ends)
########################################################################

printf "\e[1;32m\nExiting the chroot environment\n\e[0m"
sleep 3
