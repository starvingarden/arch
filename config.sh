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










# configure system
##################

printf "\e[1;32m\nConfiguring system\n\e[0m"
sleep 3

# enable shadow
#systemctl enable shadow.timer

# configure flatpak
# create a symlink so that flatpaks are in /usr/share/applications
#ln -s /var/lib/flatpak /usr/share/applications

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

# configure plocate
# include btrfs filesystems in results
sed -i 's/PRUNE_BIND_MOUNTS = "yes"/PRUNE_BIND_MOUNTS = "no"/' /etc/updatedb.conf
# exclude /.snapshots directory from results
sed -i 's/PRUNEPATHS = "/PRUNEPATHS = "\/.snapshots /' /etc/updatedb.conf
updatedb
#systemctl enable plocate-updatedb.timer

# configure gnome-keyring (see arch wiki page GNOME/Keyring)
# automatically change keyring password with user password
echo "password    optional    pam_gnome_keyring.so" >> /etc/pam.d/passwd
# automatically unlock the keyring on login
# edit the file /etc/pam.d/login
# add "auth optional pam_gnome_keyring.so" at the end of the "auth" section
lineNumber=$(grep -n "auth" login | tail -n 1 | grep -Eo '^[0-9]*')
sed -i "${lineNumber}a auth       optional     pam_gnome_keyring.so" login
# add "session optional pam_gnome_keyring.so auto_start at the end of the "session" section
lineNumber=$(grep -n "session" /etc/pam.d/login | tail -n 1 | grep -Eo '^[0-9]*')
sed -i "${lineNumber}a session optional pam_gnome_keyring.so auto_start" /etc/pam.d/login

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
