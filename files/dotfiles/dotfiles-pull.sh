#!/bin/bash

# check if script is ready to be run
####################################

# check root status
currentUser=$(whoami)
if [ "$currentUser" == root ]
then
	printf "\e[1;31m\nYou should not run this script as the root user\n\e[0m"
	exit
fi

# get username
userName=$(whoami)

# exit if arch repo is not in the users home directory
archDirectory=$(ls /home/"$userName" | grep arch)
if [ "$archDirectory" != arch ]
then
	printf "\e[1;31m\narch repo must be in your home directory\n\e[0m"
	exit
fi










# pull dotfiles from arch repo
##############################

# alacritty
cp -r /home/"$userName"/arch/files/dotfiles/alacritty /home/"$userName"/.config

# albert
#cp /home/"$userName"/arch/files/dotfiles/albert/albert.conf /home/"$userName"/.config
#cp /home/"$userName"/arch/files/dotfiles/albert/engines.json /home/"$userName"/.config/albert/websearch
#cp -r /home/"$userName"/arch/files/dotfiles/albert/icons /home/"$userName"/.config/albert/websearch/icons

# bash
cp /home/"$userName"/arch/files/dotfiles/bash/.bash_profile /home/"$userName"
cp /home/"$userName"/arch/files/dotfiles/bash/.bashrc /home/"$userName"

# cava
cp -r /home/"$userName"/arch/files/dotfiles/cava /home/"$userName"/.config

# dark-theme
cp -r /home/"$userName"/arch/files/dotfiles/dark-theme /home/"$userName"/.config

# default-apps
cp /home/"$userName"/arch/files/dotfiles/default-apps/mimeapps.list /home/"$userName"/.config

# electron
cp /home/"$userName"/arch/files/dotfiles/electron/* /home/"$userName"/.config

# fuzzel
cp -r /home/"$userName"/arch/files/dotfiles/fuzzel /home/"$userName"/.config

# gammastep
cp -r /home/"$userName"/arch/files/dotfiles/gammastep /home/"$userName"/.config

# info
cp /home/"$userName"/arch/files/dotfiles/infokey /home/"$userName"/.infokey

# mako
cp -r /home/"$userName"/arch/files/dotfiles/mako /home/"$userName"/.config

# mpv
cp -r /home/"$userName"/arch/files/dotfiles/mpv /home/"$userName"/.config

# neofetch
cp -r /home/"$userName"/arch/files/dotfiles/neofetch /home/"$userName"/.config

# nvim
cp -r /home/"$userName"/arch/files/dotfiles/nvim /home/"$userName"/.config

# sway
cp -r /home/"$userName"/arch/files/dotfiles/sway /home/"$userName"/.config

# swaylock
cp -r /home/"$userName"/arch/files/dotfiles/swaylock /home/"$userName"/.config

# tealdeer
cp -r /home/"$userName"/arch/files/dotfiles/tealdeer /home/"$userName"/.config

# wallpapers
cp -r /home/"$userName"/arch/files/dotfiles/wallpapers /home/"$userName"/.config

# waybar
cp -r /home/"$userName"/arch/files/dotfiles/waybar /home/"$userName"/.config

# zathura
cp -r /home/"$userName"/arch/files/dotfiles/zathura /home/"$userName"/.config
