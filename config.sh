#!/bin/bash

# check to see if system is ready to run config.sh
##################################################

# check root status
currentUser=$(whoami)
if [ "$currentUser" != root ]
then
    printf "\e[1;31m\nYou must be logged in as root to run this script\n\e[0m"
    exit
fi

# check to see if required packages were installed from packages.txt
paruExists=$(pacman -Qqs paru)
if [ "$paruExists" != paru ]
then
    printf "\e[1;31m\nRequired packages not installed from packages.txt\n\e[0m"
    exit
fi










# automatically get system information
######################################

# get username
userName=$(users | grep -Eio '^[[:graph:]]*[^ ]')


# # check if installing on a laptop
laptopInstall=$(neofetch battery)
if [ -z "$laptopInstall" ]
then
    laptopInstall=false
else
    laptopInstall=true
fi


# get root subvolume id
#rootSubvolumeID=$(btrfs subvolume list / | grep -i '@$' | grep -Eio 'id [0-9]*' | grep -Eio '[0-9]*')


# get customConfig variable
customConfig=$(ls -a /home/"$userName" | grep -io 'customconfig')
if [ "$customConfig" == customconfig ]
then
    customConfig=true
else
    customConfig=false
fi










# verify system information gathered automatically is correct
while true
do
    echo -e "username=$userName, laptop=$laptopInstall, custom configurations=$customConfig"
    read -rp $'\n'"Are the variables for system information correct? [Y/n] " systemInformation
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










# configure snapshots
#####################

printf "\e[1;32m\nConfiguring snapshots\n\e[0m"
sleep 3

# set root subvolume as default subvolume so we can boot from snapshots of root subvolume
#btrfs subvolume set-default "$rootSubvolumeID" /

# create necessary directories in /.snapshots
mkdir /.snapshots/root
mkdir /.snapshots/home
mkdir /.snapshots/backups
mkdir /.snapshots/root/pre-update
mkdir /.snapshots/home/pre-update
mkdir /.snapshots/root/hourly
mkdir /.snapshots/home/hourly
mkdir /.snapshots/root/daily
mkdir /.snapshots/home/daily
mkdir /.snapshots/root/weekly
mkdir /.snapshots/home/weekly
#mkdir /.snapshots/root/monthly
#mkdir /.snapshots/home/monthly
#mkdir /.snapshots/root/yearly
#mkdir /.snapshots/home/yearly

# set permissions for /.snapshot directory
chmod -R 700 /.snapshots

# configure not-snapped directory
chmod 755 /not-snapped
mkdir /not-snapped/"$userName"
chown "$userName":users /not-snapped/"$userName"
chmod 744 /not-snapped/"$userName"
su -c "mkdir /not-snapped/$userName/downloading" "$userName"



# configure btrfs scripts         (make 1 script that properly names all snapshots)
chmod +x /home/"$userName"/arch/files/scripts/btrfs/*
cp /home/"$userName"/arch/files/scripts/btrfs/* /usr/local/bin

cp /usr/local/bin/snapshot.sh /usr/local/bin/snapshot-pre-update.sh
sed -i 's/SNAPSHOTFREQUENCY/pre-update/' /usr/local/bin/snapshot-pre-update.sh
sed -i 's/MAXSNAPSHOTCOUNT/10/' /usr/local/bin/snapshot-pre-update.sh

cp /usr/local/bin/snapshot.sh /usr/local/bin/snapshot-hourly.sh
sed -i 's/SNAPSHOTFREQUENCY/hourly/' /usr/local/bin/snapshot-hourly.sh
sed -i 's/MAXSNAPSHOTCOUNT/24/' /usr/local/bin/snapshot-hourly.sh

cp /usr/local/bin/snapshot.sh /usr/local/bin/snapshot-daily.sh
sed -i 's/SNAPSHOTFREQUENCY/daily/' /usr/local/bin/snapshot-daily.sh
sed -i 's/MAXSNAPSHOTCOUNT/7/' /usr/local/bin/snapshot-daily.sh

cp /usr/local/bin/snapshot.sh /usr/local/bin/snapshot-weekly.sh
sed -i 's/SNAPSHOTFREQUENCY/weekly/' /usr/local/bin/snapshot-weekly.sh
sed -i 's/MAXSNAPSHOTCOUNT/4/' /usr/local/bin/snapshot-weekly.sh

#cp /usr/local/bin/snapshot.sh /usr/local/bin/snapshot-monthly.sh
#sed -i 's/SNAPSHOTFREQUENCY/monthly/' /usr/local/bin/snapshot-monthly.sh
#sed -i 's/MAXSNAPSHOTCOUNT/12/' /usr/local/bin/snapshot-monthly.sh

#cp /usr/local/bin/snapshot.sh /usr/local/bin/snapshot-yearly.sh
#sed -i 's/SNAPSHOTFREQUENCY/yearly/' /usr/local/bin/snapshot-yearly.sh
#sed -i 's/MAXSNAPSHOTCOUNT/3/' /usr/local/bin/snapshot-yearly.sh



# configure btrfs systemd units
cp -r /home/"$userName"/arch/files/systemd/system/btrfs/snapshots/* /etc/systemd/system
systemctl daemon-reload
systemctl enable snapshot-hourly.timer
systemctl enable snapshot-daily.timer
systemctl enable snapshot-weekly.timer
#systemctl enable snapshot-monthly.timer
#systemctl enable snapshot-yearly.timer

# take snapshots before config.sh
btrfs subvolume snapshot -r / /.snapshots/root/pre-update/before-config.sh
btrfs subvolume snapshot -r /home /.snapshots/home/pre-update/before-config.sh










# configure system
##################

printf "\e[1;32m\nConfiguring system\n\e[0m"
sleep 3

# enable shadow
#systemctl enable shadow.timer

# configure flatpak
# create a symlink so that flatpaks are in /usr/share/applications
#ln -s /var/lib/flatpak /usr/share/applications

# backup boot partition on kernel updates (see arch wiki page "System backup#Snapshots and /boot partition")
mkdir /etc/pacman.d/hooks
cp /home/"$userName"/arch/files/95-bootbackup.hook /etc/pacman.d/hooks

# set systemd default target
########## see what the default target is out of the box
#systemctl set-default graphical.target

# enable clock sync
systemctl enable systemd-timesyncd.service

# enable cpupower
systemctl enable cpupower.service

# automatically clean pacman package cache weekly
# enable paccache
systemctl enable paccache.timer

# enable firewall
#systemctl enable firewalld.service

# enable man-db.timer
systemctl start man-db.service
systemctl enable man-db.timer

# enable disk trim       ################# read about trim https://wiki.archlinux.org/title/Solid_state_drive#dm-crypt https://wiki.archlinux.org/title/Dm-crypt/Specialties#Discard/TRIM_support_for_solid_state_drives_(SSD)
#systemctl enable fstrim.timer

# configure bluetooth
#systemctl enable bluetooth.service
# dont turn on bluetooth on boot
sed -i 's/#AutoEnable=true/AutoEnable=false/' /etc/bluetooth/main.conf

# configure mlocate
sed -i 's/PRUNEPATHS = "/PRUNEPATHS = "\/.snapshots /' /etc/updatedb.conf
updatedb
#systemctl enable updatedb.timer

# configure audio
#su -c "systemctl --user enable wireplumber.service" "$userName"
#su -c "systemctl --user enable pipewire-pulse.service" "$userName"

# configure framework laptop (see framework laptop page on the arch wiki)
if [ "$laptopInstall" == true ]
then
    # fix brightness and airplane mode key bug
    # configure proper kernel modules
    echo -e "blacklist hid_sensor_hub" > /etc/modprobe.d/framework-als-deactivate.conf
    mkinitcpio -P
    
    # allow user to change screen brightness
    gpasswd -a "$userName" video
    
    # enable hibernate on low battery (see arch wiki page "Laptop#Hibernate on low battery level")
    cp /home/"$userName"/arch/files/99-lowbat.rules /etc/udev/rules.d
    
    # configure tlp
    #sed -i 's/#PCIE_ASPM_ON_BAT=default/PCIE_ASPM_ON_BAT=powersupersave/' /etc/tlp.conf    
fi










# set custom configurations
###########################

if [ "$customConfig" == true ]
then

printf "\e[1;32m\nSetting custom configurations\n\e[0m"
sleep 3

# remove custom config file
rm /home/"$userName"/.customconfig

# create .config directory for user
su -c "mkdir /home/$userName/.config" "$userName"

# create .bin directory for user and add to PATH for user
su -c "mkdir /home/$userName/.bin" "$userName"

# enable sway 
# add user to seat group
gpasswd -a "$userName" seat
# enable seatd daemon
systemctl enable seatd.service

# configure pacman
sed -i 's/#Color/Color/' /etc/pacman.conf

# configure printing
systemctl enable avahi-daemon.service
sed -i 's/mymachines/mymachines mdns_minimal [NOTFOUND=return]/' /etc/nsswitch.conf
systemctl enable cups.socket

# disable power saving mode for sound card
#sed -i 's/load-module module-suspend-on-idle/#load-module module-suspend-on-idle/' /etc/pulse/default.pa

# configure virtual machine manager (libvirt) if package is installed
libvirtExists=$(pacman -Qqs libvirt)
if [ -n "$libvirtExists" ]
then
    # allow any user in the wheel group to start and stop libvirtd.service (for sway compatibility)
    echo -e "%wheel ALL=(ALL) NOPASSWD: /usr/bin/systemctl start libvirtd.service" >> /etc/sudoers.d/libvirt
    echo -e "%wheel ALL=(ALL) NOPASSWD: /usr/bin/systemctl stop libvirtd.service" >> /etc/sudoers.d/libvirt
fi

# configure jackett is package is installed
jackettExists=$(pacman -Qqs jackett)
if [ -n "$jackettExists" ]
then
    # allow any user in the wheel group to start and stop jackett.service (for sway compatibility)
    echo -e "%wheel ALL=(ALL) NOPASSWD: /usr/bin/systemctl start jackett.service" >> /etc/sudoers.d/jackett
    echo -e "%wheel ALL=(ALL) NOPASSWD: /usr/bin/systemctl stop jackett.service" >> /etc/sudoers.d/jackett
fi

# add user to input group for ydotool, and waybar compatibility with keyboard modes
gpasswd -a "$userName" input





# import dotfiles
#################

# make dotfiles-pull.sh executable
chmod +x /home/"$userName"/arch/files/dotfiles/dotfiles-pull.sh

# run dotfiles-pull.sh
su -c "/home/$userName/arch/files/dotfiles/dotfiles-pull.sh" "$userName"

# use certain dotfiles for root user
# nvim
cp -r /home/"$userName"/arch/files/dotfiles/nvim /root/.config





# save scripts and give run permissions
#######################################

# system scripts
################

# display-brightness
cp /home/"$userName"/arch/files/scripts/display-brightness/display-brightness-decrease.sh /usr/local/bin
cp /home/"$userName"/arch/files/scripts/display-brightness/display-brightness-increase.sh /usr/local/bin
chmod +x /usr/local/bin/display-brightness-decrease.sh
chmod +x /usr/local/bin/display-brightness-increase.sh

# eject
cp /home/"$userName"/arch/files/scripts/eject/eject.sh /usr/local/bin
chmod +x /usr/local/bin/eject.sh

# fuzzel
cp /home/"$userName"/arch/files/scripts/fuzzel/fuzzel-theme.sh /usr/local/bin
chmod +x /usr/local/bin/fuzzel-theme.sh

# jackett
cp /home/"$userName"/arch/files/scripts/jackett/jackett-stop.sh /usr/local/bin
chmod +x /usr/local/bin/jackett-stop.sh

# malware
cp /home/"$userName"/arch/files/scripts/malware/malware.sh /usr/local/bin
chmod +x /usr/local/bin/malware.sh

# network
cp /home/"$userName"/arch/files/scripts/network/internet-check.sh /usr/local/bin
cp /home/"$userName"/arch/files/scripts/network/vpn.sh /usr/local/bin
chmod +x /usr/local/bin/internet-check.sh
chmod +x /usr/local/bin/vpn.sh

# pipewire
cp /home/"$userName"/arch/files/scripts/pipewire/pipewire-max-volume.sh /usr/local/bin
chmod +x /usr/local/bin/pipewire-max-volume.sh

# sleep
cp /home/"$userName"/arch/files/scripts/sleep/sleep.sh /usr/local/bin
chmod +x /usr/local/bin/sleep.sh

# stop-daemons
cp /home/"$userName"/arch/files/scripts/stop-daemons/jackett-stop.sh /usr/local/bin
cp /home/"$userName"/arch/files/scripts/stop-daemons/libvirt-stop.sh /usr/local/bin
chmod +x /usr/local/bin/jackett-stop.sh
chmod +x /usr/local/bin/libvirt-stop.sh

# sway
cp /home/"$userName"/arch/files/scripts/sway/default-app.sh /usr/local/bin
cp /home/"$userName"/arch/files/scripts/sway/sway-config.sh /usr/local/bin
chmod +x /usr/local/bin/default-app.sh
chmod +x /usr/local/bin/sway-config.sh

# theme
cp /home/"$userName"/arch/files/scripts/theme/theme.sh /usr/local/bin
chmod +x /usr/local/bin/theme.sh


# user scripts
##############





# save and enable custom systemd units
######################################

# system units
##############

# malware scanner
cp /home/"$userName"/arch/files/systemd/system/malware/malware.service /etc/systemd/system
cp /home/"$userName"/arch/files/systemd/system/malware/malware.timer /etc/systemd/system
systemctl daemon-reload
systemctl enable malware.timer

# sleep
cp -r /home/"$userName"/arch/files/systemd/system/sleep/sleep.conf.d /etc/systemd
cp -r /home/"$userName"/arch/files/systemd/system/sleep/logind.conf.d /etc/systemd
systemctl daemon-reload



# user units
############

# nnn plugins
cp /home/"$userName"/arch/files/systemd/user/nnnplugins/nnnplugins.service /etc/systemd/user
cp /home/"$userName"/arch/files/systemd/user/nnnplugins/nnnplugins.timer /etc/systemd/user
systemctl --user daemon-reload
systemctl --global enable nnnplugins.timer



# system and user units
#######################

# tealdeer
cp /home/"$userName"/arch/files/systemd/both/tealdeer/tealdeer.service /etc/systemd/system
cp /home/"$userName"/arch/files/systemd/both/tealdeer/tealdeer.timer /etc/systemd/system
cp /home/"$userName"/arch/files/systemd/both/tealdeer/tealdeer.service /etc/systemd/user
cp /home/"$userName"/arch/files/systemd/both/tealdeer/tealdeer.timer /etc/systemd/user
systemctl daemon-reload
systemctl --user daemon-reload
systemctl enable tealdeer.timer
systemctl --global enable tealdeer.timer

# trash
cp /home/"$userName"/arch/files/systemd/both/trash/trash.service /etc/systemd/system
cp /home/"$userName"/arch/files/systemd/both/trash/trash.timer /etc/systemd/system
cp /home/"$userName"/arch/files/systemd/both/trash/trash.service /etc/systemd/user
cp /home/"$userName"/arch/files/systemd/both/trash/trash.timer /etc/systemd/user
systemctl daemon-reload
systemctl --user daemon-reload
systemctl enable trash.timer
systemctl --global enable trash.timer

fi










# remove files, and reboot
##########################

# remove no longer needed files
rm -r /home/"$userName"/arch
rm /home/"$userName"/packages.txt
rm /home/"$userName"/config.sh

# take after config.sh snapshots
btrfs subvolume snapshot -r / /.snapshots/root/pre-update/after-config.sh
btrfs subvolume snapshot -r /home /.snapshots/home/pre-update/after-config.sh

# reboot
printf "\e[1;32m\nConfig complete. Enter \"reboot\" to reboot the system\n\e[0m"
